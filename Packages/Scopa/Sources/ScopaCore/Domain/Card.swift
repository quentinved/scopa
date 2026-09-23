/// The four suits of the 40-card Italian deck.
public enum Suit: String, CaseIterable, Codable, Sendable, Hashable {
    case coins, cups, swords, clubs

    /// One letter per suit, from the Italian names: denari, coppe, spade, bastoni.
    public var initial: Character {
        switch self {
        case .coins: "d"
        case .cups: "c"
        case .swords: "s"
        case .clubs: "b"
        }
    }
}

/// Ranks 1 to 10. `rawValue` is the capture value used when summing table cards.
public enum Rank: Int, CaseIterable, Codable, Sendable, Hashable, Comparable {
    case ace = 1, two, three, four, five, six, seven, knave, knight, king

    public var isFace: Bool { rawValue >= Rank.knave.rawValue }

    public static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct Card: Hashable, Codable, Sendable, Identifiable, CustomStringConvertible {
    public let suit: Suit
    public let rank: Rank

    public init(_ rank: Rank, of suit: Suit) {
        self.suit = suit
        self.rank = rank
    }

    public var id: Card { self }
    /// "7d" for the seven of coins. Italian initials, because three English suit names start with c.
    public var description: String { "\(rank.rawValue)\(suit.initial)" }

    /// The 7 of coins, worth one point on its own.
    public static let settebello = Card(.seven, of: .coins)
}

public extension Sequence where Element == Card {
    var rankSum: Int { reduce(0) { $0 + $1.rank.rawValue } }
}
