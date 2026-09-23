/// One deal of the deck, from the first hand to the last card played.
public struct Round: Hashable, Codable, Sendable {
    public var stock: [Card]
    public var table: [Card]
    /// Indexed by seat.
    public var hands: [[Card]]
    /// Indexed by side.
    public var captures: [[Card]]
    /// Scope scored so far, indexed by side.
    public var scope: [Int]
    public var turnSeat: Int
    public var lastCaptureSide: Int?

    public var handsAreEmpty: Bool { hands.allSatisfy(\.isEmpty) }
    /// True when the card about to be played is the very last of the round.
    public var isOnLastCard: Bool { stock.isEmpty && hands.reduce(0) { $0 + $1.count } == 1 }
}

public enum Phase: Hashable, Codable, Sendable {
    case awaitingDeal
    case playing
    case roundOver(RoundScore)
    case finished(winnerSide: Int)
}

public struct GameState: Hashable, Codable, Sendable {
    public let configuration: GameConfiguration
    /// Cumulative points, indexed by side.
    public var scores: [Int]
    /// Which deal of the deck this is, counting from one. Informational only.
    public var roundNumber: Int
    public var dealerSeat: Int
    public var round: Round?
    public var phase: Phase

    public init(configuration: GameConfiguration, dealerSeat: Int = 0) {
        self.configuration = configuration
        self.scores = Array(repeating: 0, count: configuration.sideCount)
        self.roundNumber = 0
        self.dealerSeat = dealerSeat
        self.round = nil
        self.phase = .awaitingDeal
    }

    public var isFinished: Bool {
        if case .finished = phase { return true }
        return false
    }
}
