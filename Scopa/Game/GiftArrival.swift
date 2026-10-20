import ScopaCore

/// A card a friend sent, already in the album, waiting to be turned over.
struct GiftArrival: Identifiable, Equatable {
    let id: String
    /// Who sent it, by their Game Center name.
    let from: String
    /// What it did in the album: new, or a spare and what it paid.
    let opening: AlbumBook.Opening

    var card: Card? { opening.cards.first }
}

/// Somebody a card can go to: a Game Center friend who plays Scopa.
struct GiftFriend: Identifiable, Hashable {
    /// Their Game Center id, which is what the Worker knows them by.
    let id: String
    let name: String
}
