/// A regional rule a table may play on top of classic Scopa. Any mix may be on at once;
/// none of them is the rulebook game.
public enum HouseRule: String, CaseIterable, Codable, Sendable, Hashable {
    /// Four in two teams, ten cards each and nothing on the table: the whole deck is dealt at once.
    case scopone
    /// The king of coins is a point of its own, like the settebello.
    case reBello
    /// Ace, two and three of coins score three, and one more for every coin that runs on from them.
    case napola
    /// An ace takes everything on the table. Taking it all that way is not a scopa.
    case assoPigliaTutto
}

public extension Set where Element == HouseRule {
    /// Whether playing `card` and clearing the table that way scores a scopa. An ace that
    /// takes everything because it may is not a sweep anyone earned.
    func sweepScores(playing card: Card) -> Bool {
        !(contains(.assoPigliaTutto) && card.rank == .ace)
    }
}
