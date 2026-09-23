import Foundation

/// In-process transport: every player on one device. Used by tests, previews, and pass-and-play.
public final class LoopbackNetwork: Sendable {
    private struct State {
        var inboxes: [PlayerID: AsyncStream<Envelope>.Continuation] = [:]
        var host: PlayerID?
    }

    private let lock = NSLock()
    nonisolated(unsafe) private var state = State()

    public init() {}

    /// The first transport created becomes the host.
    public func transport(for player: Player) -> LoopbackTransport {
        let (stream, continuation) = AsyncStream.makeStream(of: Envelope.self, bufferingPolicy: .unbounded)
        lock.withLock {
            state.inboxes[player.id] = continuation
            if state.host == nil { state.host = player.id }
        }
        return LoopbackTransport(network: self, localPlayer: player, incoming: stream)
    }

    /// Drops a player as if their device went away; the host hears a `leave`.
    public func disconnect(_ id: PlayerID) {
        let (inbox, host) = lock.withLock { (state.inboxes.removeValue(forKey: id), state.host) }
        inbox?.finish()
        if let host, host != id { deliver(Envelope(from: id, message: .leave(id)), to: [host]) }
    }

    func send(_ envelope: Envelope, to recipient: Recipient) throws {
        let targets: [PlayerID] = lock.withLock {
            switch recipient {
            case .all: Array(state.inboxes.keys.filter { $0 != envelope.from })
            case .host: state.host.map { [$0] } ?? []
            case .player(let id): state.inboxes[id] != nil ? [id] : []
            }
        }
        if case .player = recipient, targets.isEmpty { throw TransportError.peerNotFound }
        deliver(envelope, to: targets)
    }

    private func deliver(_ envelope: Envelope, to targets: [PlayerID]) {
        let inboxes = lock.withLock { targets.compactMap { state.inboxes[$0] } }
        for inbox in inboxes { inbox.yield(envelope) }
    }
}

public final class LoopbackTransport: GameTransport {
    public let localPlayer: Player
    public let incoming: AsyncStream<Envelope>
    private let network: LoopbackNetwork

    init(network: LoopbackNetwork, localPlayer: Player, incoming: AsyncStream<Envelope>) {
        self.network = network
        self.localPlayer = localPlayer
        self.incoming = incoming
    }

    public func send(_ message: GameMessage, to recipient: Recipient) async throws {
        try network.send(Envelope(from: localPlayer.id, message: message), to: recipient)
    }
}
