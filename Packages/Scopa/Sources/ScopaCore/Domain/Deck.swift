public enum Deck {
    /// All 40 cards in a fixed order.
    public static let standard: [Card] = Suit.allCases.flatMap { suit in
        Rank.allCases.map { Card($0, of: suit) }
    }

    public static func shuffled(using rng: inout some RandomNumberGenerator) -> [Card] {
        standard.shuffled(using: &rng)
    }

    /// A deck in the order `Rules.deal` reads it, so `table` goes face up and `deals[0][seat]`
    /// is that seat's first hand, `deals[1][seat]` its second, and so on. Shorter than forty
    /// cards when the round should be that short.
    public static func stacked(table: [Card], deals: [[[Card]]]) -> [Card] {
        // Dealt from the end: the table first, then seat 0, seat 1 and on, deal by deal.
        deals.reversed().flatMap { hands in hands.reversed().flatMap { $0 } } + table
    }
}

/// Deterministic SplitMix64 generator. Seed it to replay a game or make tests reproducible.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
