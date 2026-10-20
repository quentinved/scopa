import ScopaRewards

/// What today's deal handed over besides its denari: the day's card, already in the album,
/// and the pack a run brought, already waiting on its shelf. Either can be missing when the
/// day was paid before, on this phone or another, so the reveal only shows what is new.
struct DailyGift: Equatable {
    /// The card, as its opening: what it was, and whether it was new or a spare.
    var card: AlbumBook.Opening?
    /// The deal was won, so the card was drawn at the better odds.
    let won: Bool
    /// The pack the run reached today, if it reached one.
    let pack: PackTier?
    /// Days in a row, today's included.
    let days: Int
    /// The deal's day, which keys the card in the ledger. Nil in the debug reveal.
    var day: String? = nil
    /// A lost deal's card, still face down and not yet claimed: the player picks its odds
    /// first, the loser's or, for a video, the winner's.
    var isUndrawn = false
    /// A video was watched for it, so a lost deal's card came at the winner's odds.
    var watchedFor = false

    /// Something to turn over on the way out.
    var hasCard: Bool { card != nil || isUndrawn }
}
