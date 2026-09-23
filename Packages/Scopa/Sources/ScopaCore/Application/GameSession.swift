/// The single source of truth for a game. Only the host runs one; guests only see `PlayerView`s.
extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

public actor GameSession {
    public private(set) var state: GameState
    /// The game so far, written down as it is played. Complete once the game has ended.
    public private(set) var record: GameRecord
    private var rng: any RandomNumberGenerator & Sendable

    public init(configuration: GameConfiguration, rng: any RandomNumberGenerator & Sendable = SeededGenerator(seed: UInt64.random(in: .min ... .max))) {
        self.state = GameState(configuration: configuration)
        self.record = GameRecord(configuration: configuration, dealerSeat: state.dealerSeat)
        self.rng = rng
    }

    /// Picks a game up where it was left: the state as it stood and the record so far, as
    /// a `HotSeatTable` snapshot hands them back. The generator is fresh: nothing already
    /// dealt depends on it, and the next shuffle is as random as the first.
    public init(state: GameState, record: GameRecord, rng: any RandomNumberGenerator & Sendable = SeededGenerator(seed: UInt64.random(in: .min ... .max))) {
        self.state = state
        self.record = record
        self.rng = rng
    }

    /// Deals the next round. No-op while a round is in progress or after the game ended.
    @discardableResult
    public func startRound() -> [GameEvent] {
        switch state.phase {
        case .awaitingDeal, .roundOver:
            let deck = Rules.shuffledDeck(using: &rng)
            let (next, events) = Rules.deal(deck, into: state)
            state = next
            record.rounds.append(.init(deck: deck))
            return events
        case .playing, .finished:
            return []
        }
    }

    /// Validates and applies a move, then deals or ends the round when needed.
    public func play(_ move: Move) throws(MoveError) -> [GameEvent] {
        let (next, events) = try Rules.apply(move, to: state)
        state = next
        // Only a move the rules took is written down, so the record replays clean.
        record.rounds[record.rounds.count - 1].moves.append(move)
        return events
    }

    public func play(_ card: Card, capturing captures: [Card] = [], by player: PlayerID) throws(MoveError) -> [GameEvent] {
        guard let seat = state.configuration.seat(of: player) else { throw .notPlaying }
        return try play(Move(seat: seat, card: card, captures: captures))
    }

    public func view(for player: PlayerID) -> PlayerView? {
        state.configuration.seat(of: player).map(state.view(forSeat:))
    }

    public func views() -> [PlayerID: PlayerView] {
        Dictionary(uniqueKeysWithValues: state.configuration.players.enumerated().map { ($0.element.id, state.view(forSeat: $0.offset)) })
    }
}
