import ScopaRewards

/// Pays the album's road: a stop every ten cards found across the volumes. See `AlbumRoad`.
///
/// Read off the ledger, which is the only thing that can say a stop was paid, so a stop
/// reached on the phone is paid on the phone and never again on the iPad. Settled on the
/// album's page only, after an opening or a trade has left the screen.
@MainActor
enum AlbumRoadPayout {
    /// A stop just paid, for the page to show.
    struct Paid: Equatable {
        let stop: Int
        let prize: AlbumRoad.Prize
        /// The album was past more than one unpaid stop: only this one paid.
        let isCatchUp: Bool
    }

    /// Pays the stop the album has reached, if it has not been paid. Nil when nothing was owed.
    static func settle(book: AlbumBook, purse: PurseStore) async -> Paid? {
        guard purse.isReady else { return nil }
        let paid = Set(purse.purse.keys.compactMap(AlbumRoad.stop(forKey:)))
        let owed = AlbumRoad.owed(found: book.foundInAll, paid: paid)
        guard let stop = owed.stop else { return nil }
        let prize = AlbumRoad.prize(at: stop)
        let fresh = await purse.awardAlbumStop(prize.denari, key: AlbumRoad.key(for: stop),
                                               waiving: owed.waived.map(AlbumRoad.key(for:)))
        guard fresh == true else { return nil }
        if case .pack(let tier) = prize { book.give(tier) }
        return Paid(stop: stop, prize: prize, isCatchUp: owed.isCatchUp)
    }
}

extension AlbumRoad.Prize {
    /// What it pays in denari, nothing for a pack.
    var denari: Denari {
        if case .denari(let amount) = self { amount } else { .zero }
    }
}
