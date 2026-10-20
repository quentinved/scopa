import Foundation
import ScopaCore
import ScopaRewards

/// Trading spares for a card the open volume is missing. The rates are `Scambio`'s.
///
/// Spares leave the way a gift does, as keyed lines in the ledger, so a trade made on the
/// phone is spent on the iPad too and never comes back with the next merge of counts. The
/// card itself goes in like a pack's, which is also what pays a suit or a volume it finished.
extension AlbumBook {
    /// The open volume as a trade sees it: found, less what has already left.
    var tradingAlbum: Album { shown(openVolume) }

    /// Packs' worth of cards the open volume has taken in, towards opening trades there.
    var packsTowardTrading: Int { Scambio.packsOpened(into: album(openVolume)) }

    /// Trades open in a volume only after `Scambio.packsBeforeTrading` packs into it.
    var tradingIsOpen: Bool {
        #if DEBUG
        if DebugLaunch.scambio != nil { return true }
        #endif
        return packsTowardTrading >= Scambio.packsBeforeTrading
    }

    /// Every missing card the spares could bring in now, the rarest first.
    var offers: [Scambio.Offer] { tradingIsOpen ? Scambio.offers(in: tradingAlbum) : [] }

    func offer(for card: Card) -> Scambio.Offer? {
        tradingIsOpen ? Scambio.offer(for: card, in: tradingAlbum) : nil
    }

    /// A trade made: what went, and the card that came in for it.
    struct Trade: Identifiable {
        let offer: Scambio.Offer
        let opening: Opening

        var id: UUID { opening.id }
    }

    /// Makes the trade: the spares leave first, then the card comes in. Nil when the spares
    /// are no longer there, or their leaving could not be saved, and then nothing changed.
    func trade(for card: Card, purse: PurseStore) async -> Trade? {
        noteDepartures(in: purse.purse)
        guard let offer = offer(for: card) else { return nil }
        let keys = Scambio.departureKeys(for: offer, from: openVolume)
        guard await purse.recordDepartures(keys, note: "scambio") == true else { return nil }
        noteDepartures(in: purse.purse)
        let opened = openCard(card, odds: .mazzetto)
        await purse.awardPack(opened.denari, key: opened.key)
        if opened.deck { await purse.award(opened.volume) }
        return Trade(offer: offer, opening: opened)
    }

    /// Cards found across the volumes opened so far, which is how far along the album's road
    /// it is. A volume still locked cannot have been collected into.
    var foundInAll: Int {
        Volume.allCases.filter { $0.isOpen(given: album(_:)) }.reduce(0) { $0 + album($1).found }
    }
}
