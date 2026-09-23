/// A whole game as played: each round's shuffled deck and every move in order. The rules
/// are pure, so this replays exactly. The host sends it to everyone when the game ends.
public struct GameRecord: Hashable, Codable, Sendable {
    public struct RecordedRound: Hashable, Codable, Sendable {
        /// All forty cards in shuffled order, exactly what `Rules.deal` was given.
        public var deck: [Card]
        public var moves: [Move]

        public init(deck: [Card], moves: [Move] = []) {
            self.deck = deck
            self.moves = moves
        }
    }

    public let configuration: GameConfiguration
    /// Who dealt the first round.
    public let dealerSeat: Int
    public var rounds: [RecordedRound]

    public init(configuration: GameConfiguration, dealerSeat: Int, rounds: [RecordedRound] = []) {
        self.configuration = configuration
        self.dealerSeat = dealerSeat
        self.rounds = rounds
    }

    /// Whether at least one card was played.
    public var hasMoves: Bool { rounds.contains { !$0.moves.isEmpty } }

    /// A stable hash of the decks, used to seed anything that must make the same random
    /// choice about this game every time. `hashValue` is reseeded per process, so it cannot serve.
    public var signature: UInt64 {
        var value: UInt64 = 0xcbf2_9ce4_8422_2325
        for round in rounds {
            for card in round.deck {
                let index = UInt64(card.rank.rawValue) &* 8 &+ UInt64(Suit.allCases.firstIndex(of: card.suit) ?? 0)
                value = (value ^ index) &* 0x0000_0100_0000_01b3
            }
        }
        return value
    }

    /// Every move with the state it was made in, then the final state. Stops at the first
    /// move the rules refuse, which a record written by the rules never contains.
    public func replay() -> (steps: [(state: GameState, move: Move)], final: GameState) {
        var state = GameState(configuration: configuration, dealerSeat: dealerSeat)
        var steps: [(state: GameState, move: Move)] = []
        for round in rounds {
            state = Rules.deal(round.deck, into: state).0
            for move in round.moves {
                guard let next = try? Rules.apply(move, to: state).0 else { return (steps, state) }
                steps.append((state, move))
                state = next
            }
        }
        return (steps, state)
    }
}
