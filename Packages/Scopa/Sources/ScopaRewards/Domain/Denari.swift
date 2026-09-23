/// The currency, named after the coin suit the deck is already drawn with.
///
/// A whole number of coins and never a fraction. It exists as its own type rather than a
/// plain `Int` because the game is full of integers that must never be added to each other,
/// such as points, scope, seats and scores. This is the one you can spend.
public struct Denari: Hashable, Sendable, Comparable, AdditiveArithmetic, ExpressibleByIntegerLiteral {
    public var coins: Int

    public init(_ coins: Int) { self.coins = coins }
    public init(integerLiteral value: Int) { self.coins = value }

    public static let zero = Denari(0)

    public var isZero: Bool { coins == 0 }
    /// Whether this is money coming in. Spending is stored as a negative amount.
    public var isCredit: Bool { coins > 0 }
    /// The size of the amount, with the direction dropped.
    public var magnitude: Denari { Denari(abs(coins)) }

    public static func + (a: Denari, b: Denari) -> Denari { Denari(a.coins + b.coins) }
    public static func - (a: Denari, b: Denari) -> Denari { Denari(a.coins - b.coins) }
    public static prefix func - (a: Denari) -> Denari { Denari(-a.coins) }
    public static func * (a: Denari, times: Int) -> Denari { Denari(a.coins * times) }
    public static func < (a: Denari, b: Denari) -> Bool { a.coins < b.coins }
}

/// Written to the ledger as a bare number, not `{"coins": 25}`. The file is meant to be
/// handed to a server one day, and a plain integer is the easier half of that conversation.
extension Denari: Codable {
    public init(from decoder: any Decoder) throws {
        coins = try decoder.singleValueContainer().decode(Int.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(coins)
    }
}

extension Denari: CustomStringConvertible {
    public var description: String { String(coins) }
}
