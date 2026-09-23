/// What one seat is allowed to see. Other hands are reduced to counts.
public struct PlayerView: Hashable, Codable, Sendable {
    public struct Opponent: Hashable, Codable, Sendable {
        public let seat: Int
        public let player: Player
        public let cardsInHand: Int
    }

    public let seat: Int
    public let hand: [Card]
    public let table: [Card]
    public let opponents: [Opponent]
    public let stockCount: Int
    public let captureCounts: [Int]
    /// This seat's own pile. Captures happen face up, so this is public information.
    public let captures: [Card]
    /// Every side's pile, indexed by side. Also public, and what lets a bot count the deck.
    public let capturedBySide: [[Card]]
    /// Who took the last cards, and so sweeps whatever is left at the end of the round.
    public let lastCaptureSide: Int?
    public let scope: [Int]
    public let scores: [Int]
    public let turnSeat: Int?
    public let phase: Phase
    /// Which deal of the deck this is, counting from one.
    public let roundNumber: Int
    public let configuration: GameConfiguration

    public init(seat: Int, hand: [Card], table: [Card], opponents: [Opponent], stockCount: Int, captureCounts: [Int],
                captures: [Card] = [], capturedBySide: [[Card]] = [], lastCaptureSide: Int? = nil,
                scope: [Int], scores: [Int], turnSeat: Int?, phase: Phase, roundNumber: Int,
                configuration: GameConfiguration) {
        self.seat = seat
        self.hand = hand
        self.table = table
        self.opponents = opponents
        self.stockCount = stockCount
        self.captureCounts = captureCounts
        self.captures = captures
        self.capturedBySide = capturedBySide
        self.lastCaptureSide = lastCaptureSide
        self.scope = scope
        self.scores = scores
        self.turnSeat = turnSeat
        self.phase = phase
        self.roundNumber = roundNumber
        self.configuration = configuration
    }

    public var isMyTurn: Bool { turnSeat == seat }

    public var isFinished: Bool {
        if case .finished = phase { true } else { false }
    }
    public var mySide: Int { configuration.side(ofSeat: seat) }

    /// Cards still held by everyone, including this seat.
    public var cardsInPlay: Int { hand.count + opponents.reduce(0) { $0 + $1.cardsInHand } }

    /// The card about to be played is the last of the round, so clearing the table scores no scopa.
    public var isOnLastCard: Bool { stockCount == 0 && cardsInPlay == 1 }

    /// Which deal of this round we are on, counting from one. Derived from the stock, so
    /// nothing extra crosses the wire.
    public var handNumber: Int {
        let perDeal = configuration.seatCount * GameConfiguration.handSize
        guard perDeal > 0 else { return 1 }
        let dealt = Deck.standard.count - GameConfiguration.tableSize - stockCount
        return max(1, Int((Double(dealt) / Double(perDeal)).rounded(.up)))
    }

    /// Whether taking `captures` would sweep the table and score a scopa.
    public func isScopa(taking captures: [Card]) -> Bool {
        !captures.isEmpty && captures.count == table.count && !isOnLastCard
    }
}

public extension GameState {
    func view(forSeat seat: Int) -> PlayerView {
        let round = self.round
        let opponents = configuration.players.enumerated()
            .filter { $0.offset != seat }
            .map { PlayerView.Opponent(seat: $0.offset, player: $0.element, cardsInHand: round?.hands[$0.offset].count ?? 0) }

        return PlayerView(
            seat: seat,
            hand: round?.hands[seat] ?? [],
            table: round?.table ?? [],
            opponents: opponents,
            stockCount: round?.stock.count ?? 0,
            captureCounts: round?.captures.map(\.count) ?? Array(repeating: 0, count: configuration.sideCount),
            captures: round?.captures[safe: configuration.side(ofSeat: seat)] ?? [],
            capturedBySide: round?.captures ?? Array(repeating: [], count: configuration.sideCount),
            lastCaptureSide: round?.lastCaptureSide,
            scope: round?.scope ?? Array(repeating: 0, count: configuration.sideCount),
            scores: scores,
            turnSeat: phase == .playing ? round?.turnSeat : nil,
            phase: phase,
            roundNumber: roundNumber,
            configuration: configuration
        )
    }
}

/// Counting what is left, from this seat.
public extension PlayerView {
    /// How many cards of a rank nobody has seen: not in this hand, not on the table, not in
    /// anybody's pile. Captures happen face up, so this is counting rather than peeking.
    func unseen(_ rank: Rank) -> Int {
        let seen = hand.count { $0.rank == rank }
            + table.count { $0.rank == rank }
            + capturedBySide.reduce(0) { $0 + $1.count { $0.rank == rank } }
        return max(0, Suit.allCases.count - seen)
    }
}

/// Decoded by hand, in an extension so the memberwise init survives: a view from a build
/// that did not carry the piles still reads, with empty ones.
extension PlayerView {
    private enum CodingKeys: String, CodingKey {
        case seat, hand, table, opponents, stockCount, captureCounts, captures, capturedBySide, lastCaptureSide,
             scope, scores, turnSeat, phase, roundNumber, configuration
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            seat: try c.decode(Int.self, forKey: .seat),
            hand: try c.decode([Card].self, forKey: .hand),
            table: try c.decode([Card].self, forKey: .table),
            opponents: try c.decode([Opponent].self, forKey: .opponents),
            stockCount: try c.decode(Int.self, forKey: .stockCount),
            captureCounts: try c.decode([Int].self, forKey: .captureCounts),
            captures: try c.decodeIfPresent([Card].self, forKey: .captures) ?? [],
            capturedBySide: try c.decodeIfPresent([[Card]].self, forKey: .capturedBySide) ?? [],
            lastCaptureSide: try c.decodeIfPresent(Int.self, forKey: .lastCaptureSide),
            scope: try c.decode([Int].self, forKey: .scope),
            scores: try c.decode([Int].self, forKey: .scores),
            turnSeat: try c.decodeIfPresent(Int.self, forKey: .turnSeat),
            phase: try c.decode(Phase.self, forKey: .phase),
            roundNumber: try c.decode(Int.self, forKey: .roundNumber),
            configuration: try c.decode(GameConfiguration.self, forKey: .configuration)
        )
    }
}
