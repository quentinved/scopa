/// A guest's side of the table: joins, plays, and mirrors what the host sends.
public actor GuestClient {
    public enum ClientError: Error, Sendable {
        case notSeated
    }

    public let updates: AsyncStream<TableUpdate>
    public private(set) var view: PlayerView?

    private let transport: any GameTransport
    private let continuation: AsyncStream<TableUpdate>.Continuation
    private var pump: Task<Void, Never>?

    public init(transport: any GameTransport) {
        self.transport = transport
        (updates, continuation) = UpdateStream.make()
    }

    public var localPlayer: Player { transport.localPlayer }

    public func start() {
        guard pump == nil else { return }
        pump = Task { [transport] in
            for await envelope in transport.incoming { self.handle(envelope.message) }
        }
    }

    public func stop() {
        pump?.cancel()
        pump = nil
        continuation.finish()
    }

    public func join() async throws {
        try await transport.send(.join(localPlayer), to: .host)
    }

    public func leave() async throws {
        try await transport.send(.leave(localPlayer.id), to: .host)
    }

    /// Tells the host this phone is walking out of the game on purpose. See `GameMessage.forfeit`.
    public func forfeit() async throws {
        try await transport.send(.forfeit, to: .host)
    }

    /// Sends the best available move when this seat's clock runs out.
    public func playAutomatically() async throws {
        guard let view, let move = Rules.automaticMove(for: view) else { return }
        try await play(move.card, capturing: move.captures)
    }

    public func react(_ reaction: Reaction) async throws {
        try await transport.send(.react(reaction), to: .host)
    }

    public func play(_ card: Card, capturing captures: [Card] = []) async throws {
        guard let view else { throw ClientError.notSeated }
        try await transport.send(.play(Move(seat: view.seat, card: card, captures: captures)), to: .host)
    }

    private func handle(_ message: GameMessage) {
        switch message {
        case .lobby(let lobby): continuation.yield(.lobby(lobby))
        case .joinRefused: continuation.yield(.joinRefused)
        case .view(let v):
            view = v
            continuation.yield(.view(v))
        case .events(let e): continuation.yield(.events(e))
        case .rejected(let r): continuation.yield(.rejected(r))
        case .playerLeft(let id): continuation.yield(.playerLeft(id))
        case .reacted(let player, let reaction): continuation.yield(.reacted(player: player, reaction: reaction))
        case .record(let record): continuation.yield(.record(record))
        case .packedRecord(let packed):
            if let record = Wire.unpack(packed) { continuation.yield(.record(record)) }
        case .leave(let id): continuation.yield(.playerLeft(id))
        case .playerReturned(let id): continuation.yield(.playerReturned(id))
        case .tableClosed: continuation.yield(.tableClosed)
        case .join, .play, .react, .forfeit: return
        }
    }
}
