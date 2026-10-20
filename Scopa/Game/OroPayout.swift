import ScopaCore
import ScopaRewards

/// Pays what the foil albums have earned: a pack left waiting for each suit of foils, a
/// Bottega in Oro and a Velluto in Perla, and the album's card edge once its last foil is in.
///
/// Read off the albums as they stand rather than off one opening, so a suit finished on the
/// other phone is paid here too. Every payout is claimed in the ledger first, so running this
/// as often as anything changes pays each one once, on whichever device gets there first.
@MainActor
enum OroPayout {
    static func settle(book: AlbumBook, purse: PurseStore) async {
        for album in FoilAlbum.allCases { await settle(album, book: book, purse: purse) }
    }

    private static func settle(_ album: FoilAlbum, book: AlbumBook, purse: PurseStore) async {
        let pages = book.foils(album)
        for suit in Suit.allCases where pages.isComplete(suit) {
            if await purse.claim(album.suitKey(suit)) == true { book.give(album.suitPack) }
        }
        guard pages.isComplete, let edge = CardEdge.prize(of: album).shopItem, !purse.owns(edge) else { return }
        await purse.win(edge, key: album.prizeKey)
    }
}
