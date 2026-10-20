import ScopaCore

/// A spare card handed to a friend: which cards may go, and how many a day.
///
/// It is a gift and not a market, so the limits are the gift's own. Only a spare leaves, so
/// nobody empties a page to fill a friend's; one a day, so it is a kindness rather than a
/// way of moving an album from one phone to another; and never the settebello.
///
/// The settebello is the one card the whole album is built to keep scarce. A spare one
/// already pays the most a card can, and if it could be handed on, two friends could
/// pour every one they found into a single album and the hardest card to find would
/// become an errand. It is found, never given.
public enum CardGift {
    /// Cards one player may give in a day. The Worker holds the sender to the same.
    public static let perDay = 1

    /// Why a card cannot be given.
    public enum Refusal: Hashable, Sendable {
        /// The seven of coins is found, never given.
        case settebello
        /// Only a spare goes: the album keeps its own copy.
        case noSpare
        /// Today's card has already gone.
        case givenToday
    }

    /// Why this card cannot go, or nil when it can. `album` is the page as it is shown, with
    /// whatever has already left it taken off; `givenToday` counts gifts on the sender's day.
    public static func refusal(of card: Card, in album: Album, givenToday: Int) -> Refusal? {
        if card == .settebello { return .settebello }
        if album.spares(of: card) < 1 { return .noSpare }
        if givenToday >= perDay { return .givenToday }
        return nil
    }
}
