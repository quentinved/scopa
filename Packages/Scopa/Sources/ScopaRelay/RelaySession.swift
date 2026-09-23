import Foundation
import ScopaCore
import os

/// One table's traffic, over a web socket to the Worker.
///
/// The Worker relays and nothing else: it never looks inside an envelope, so the rules of
/// Scopa stay entirely on the phones and the same host-and-guests shape runs over this that
/// runs over Wi-Fi and over Game Center. Who hosts is not worked out here: the table has a
/// host from the moment it is opened, and the Worker says who on the way in.
///
/// A socket does not survive a phone going in a pocket, so this one is rebuilt whenever it
/// drops. The table itself outlives the connection: the Worker keeps the room, the host
/// keeps the game, and a player who comes back is welcomed back to the seat they had.
public final class RelaySession: NSObject, GameTransport, @unchecked Sendable {
    static let log = Logger(subsystem: "com.quentinvedrenne.scopa", category: "relay")

    public let localPlayer: Player
    public let code: String
    public let incoming: AsyncStream<Envelope>
    /// Only real bad news: the table is gone, or we have stopped being able to reach it.
    /// A drop that is being reconnected says nothing, because it usually fixes itself
    /// before anybody could have read the message.
    public let problems: AsyncStream<String>
    /// One value each time the socket has been remade after a drop. A guest sends its join
    /// again when this fires, so the host can catch it up; the host has nothing to do.
    public let reconnects: AsyncStream<Void>

    private let baseURL: URL
    private let incomingContinuation: AsyncStream<Envelope>.Continuation
    private let problemsContinuation: AsyncStream<String>.Continuation
    private let reconnectsContinuation: AsyncStream<Void>.Continuation

    private let lock = NSLock()
    private var socket: URLSessionWebSocketTask?
    private var declaredHost: PlayerID?
    private var isClosed = false
    private var hasConnected = false
    private var pump: Task<Void, Never>?
    private var keepAlive: Task<Void, Never>?
    private var opening: OnceBox<Void>?

    /// How many times a first connection is tried before the join screen is told it failed.
    /// A pocket of no signal is worth one more go; a wrong code is not worth ten.
    private static let firstTries = 3
    /// And how long a table that has been sat at is fought for before giving up on it.
    private static let reconnectTries = 12
    /// A ping often enough to keep the phone's carrier from quietly dropping an idle
    /// socket. It is a control frame, so the room stays asleep and costs nothing.
    private static let pingInterval = Duration.seconds(25)

    init(baseURL: URL, code: String, localPlayer: Player) {
        self.baseURL = baseURL
        self.code = code
        self.localPlayer = localPlayer
        (incoming, incomingContinuation) = AsyncStream.makeStream(of: Envelope.self, bufferingPolicy: .unbounded)
        (problems, problemsContinuation) = AsyncStream.makeStream(of: String.self, bufferingPolicy: .bufferingNewest(1))
        (reconnects, reconnectsContinuation) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
        super.init()
    }

    deinit {
        disconnect()
    }

    /// The id that deals. Whoever opened the table, as the Worker tells it on the way in.
    public var hostID: PlayerID {
        lock.withLock { declaredHost } ?? localPlayer.id
    }

    public var isHost: Bool { hostID == localPlayer.id }

    /// Connects, and returns once the table has said hello. That is the first moment
    /// `isHost` has an answer, and so the first moment the game can be set up.
    public func connect() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let box = OnceBox(continuation)
            lock.withLock { opening = box }
            start()
        }
    }

    public func disconnect() {
        let (task, pump, keepAlive) = lock.withLock {
            defer { isClosed = true; socket = nil; self.pump = nil; self.keepAlive = nil }
            return (socket, self.pump, self.keepAlive)
        }
        pump?.cancel()
        keepAlive?.cancel()
        task?.cancel(with: .goingAway, reason: nil)
        incomingContinuation.finish()
        problemsContinuation.finish()
        reconnectsContinuation.finish()
    }

    // MARK: GameTransport

    public func send(_ message: GameMessage, to recipient: Recipient) async throws {
        let envelope = Envelope(from: localPlayer.id, message: message)
        guard let sealed = String(data: try Wire.encode(envelope), encoding: .utf8) else {
            throw TransportError.joinFailed
        }
        let frame = try JSONEncoder().encode(Outbound(to: Self.address(of: recipient, host: hostID), data: sealed))
        guard let text = String(data: frame, encoding: .utf8) else { throw TransportError.joinFailed }
        guard let socket = lock.withLock({ self.socket }) else { throw TransportError.notConnected }
        try await socket.send(.string(text))
    }

    private static func address(of recipient: Recipient, host: PlayerID) -> String {
        switch recipient {
        case .all: "all"
        case .host: "host"
        case .player(let id): "p:\(id.rawValue)"
        }
    }

    // MARK: The socket

    private var socketURL: URL {
        let path = baseURL.appending(path: "v1/rooms/\(code)/socket")
        guard var components = URLComponents(url: path, resolvingAgainstBaseURL: false) else { return path }
        // https over the wire, ws in the URL: URLSession wants the socket scheme.
        components.scheme = components.scheme == "http" ? "ws" : "wss"
        components.queryItems = [
            URLQueryItem(name: "player", value: localPlayer.id.rawValue),
            URLQueryItem(name: "name", value: localPlayer.name),
        ]
        return components.url ?? path
    }

    private func start() {
        let task = Task { [weak self] in await self?.run() ?? () }
        lock.withLock { pump = task }
    }

    /// Connects, listens, and connects again when that ends badly, until the table is left
    /// or it stops being worth trying.
    private func run() async {
        var failures = 0
        while !lock.withLock({ isClosed }), !Task.isCancelled {
            let carried = await listen()
            if lock.withLock({ isClosed }) || Task.isCancelled { return }
            failures = carried ? 0 : failures + 1

            let seated = lock.withLock { hasConnected }
            let limit = seated ? Self.reconnectTries : Self.firstTries
            if failures >= limit {
                Self.log.error("Gave up on table \(self.code, privacy: .public) after \(failures) tries")
                if seated {
                    problemsContinuation.yield("The connection to the table was lost")
                } else {
                    finishOpening(.failure(RelayError.unreachable("Could not reach the table")))
                }
                return
            }
            // A second or two, then four, then eight, and no longer than ten.
            let backoff = min(10.0, pow(2.0, Double(min(failures, 4))))
            try? await Task.sleep(for: .seconds(backoff))
        }
    }

    /// One connection, from open to close. Returns whether it ever got as far as being a
    /// working table, so a drop after an hour of play is not treated like a bad code.
    private func listen() async -> Bool {
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: socketURL)
        lock.withLock { socket = task }
        task.resume()
        startPinging(task)
        defer {
            lock.withLock { keepAlive?.cancel(); keepAlive = nil }
            task.cancel(with: .goingAway, reason: nil)
        }

        var welcomed = false
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                guard case .string(let text) = message, let data = text.data(using: .utf8) else { continue }
                if handle(data) { welcomed = true }
            } catch {
                if !lock.withLock({ isClosed }) {
                    Self.log.info("Table \(self.code, privacy: .public) dropped: \(error.localizedDescription, privacy: .public)")
                }
                return welcomed
            }
        }
        return welcomed
    }

    /// Returns whether this was the welcome, which is what tells `listen` the connection
    /// was a real one rather than a refusal.
    private func handle(_ data: Data) -> Bool {
        guard let frame = try? JSONDecoder().decode(Inbound.self, from: data) else { return false }
        switch frame.type {
        case "welcome":
            welcome(frame)
            return true

        case "relay":
            guard let sealed = frame.data?.data(using: .utf8), let envelope = try? Wire.decode(sealed) else { return false }
            incomingContinuation.yield(envelope)

        case "left":
            // Told the way Multipeer and Game Center tell it, so the host covers the empty
            // seat exactly the same way however the player was connected.
            guard let who = frame.player.map({ PlayerID(rawValue: $0) }) else { return false }
            incomingContinuation.yield(Envelope(from: who, message: .leave(who)))

        case "joined":
            // The guest announces itself properly with a `join`; this is only the Worker
            // being polite, and there is nothing for the game to do about it.
            break

        default:
            break
        }
        return false
    }

    /// The first welcome is `connect()` returning. Every one after it is a socket that came
    /// back, and a guest has a join to send again.
    private func welcome(_ frame: Inbound) {
        let host = frame.host.map { PlayerID(rawValue: $0) }
        let returning = lock.withLock {
            defer { declaredHost = host; hasConnected = true }
            return hasConnected
        }
        Self.log.info("Seated at table \(self.code, privacy: .public), host \(frame.host ?? "?", privacy: .public)")
        finishOpening(.success(()))
        if returning { reconnectsContinuation.yield(()) }
    }

    private func startPinging(_ task: URLSessionWebSocketTask) {
        let pinger = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pingInterval)
                guard !Task.isCancelled else { return }
                task.sendPing { error in
                    if let error { Self.log.debug("Ping failed: \(error.localizedDescription, privacy: .public)") }
                }
                _ = self
            }
        }
        lock.withLock { keepAlive?.cancel(); keepAlive = pinger }
    }

    private func finishOpening(_ result: Result<Void, Error>) {
        let box = lock.withLock {
            defer { opening = nil }
            return opening
        }
        box?.resume(result)
    }
}

/// What goes up: a message for somebody, already sealed. The Worker routes by `to` and
/// never opens `data`.
private struct Outbound: Encodable {
    let to: String
    let data: String
}

/// What comes down. One shape for every kind of frame, because only `type` decides which
/// of the fields mean anything.
private struct Inbound: Decodable {
    let type: String
    let host: String?
    let from: String?
    let data: String?
    let player: String?
}

/// A continuation that can only be resumed once, however many times the socket comes and
/// goes underneath it.
private final class OnceBox<T: Sendable>: @unchecked Sendable {
    private var continuation: CheckedContinuation<T, Error>?
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<T, Error>) {
        let taken: CheckedContinuation<T, Error>? = lock.withLock {
            defer { continuation = nil }
            return continuation
        }
        taken?.resume(with: result)
    }
}
