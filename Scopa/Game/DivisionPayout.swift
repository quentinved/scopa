import SwiftUI
import ScopaCore
import ScopaRewards

/// Pays the stops of the ranked road one ladder answer climbed past, and words them as a
/// single piece of news.
///
/// One toast per answer however many stops it crossed: a big win, a new season or the first
/// answer after an update can pass three at once, and three toasts with the same words read
/// as one toast shown three times.
@MainActor
enum DivisionPayout {
    /// Pays every stop climbed and not yet in the ledger. Nil when nothing new was paid.
    static func settle(_ rank: Ladder.RankAnswer, store: TableStore, purse: PurseStore,
                       locale: Locale) async -> Toast? {
        guard let season = rank.season else { return nil }
        var paid: [Int] = []
        for stop in DivisionGifts.climbed(in: rank) {
            let reward = DivisionGifts.reward(at: stop)
            let denari: Denari = if case .denari(let amount) = reward { amount } else { .zero }
            guard await purse.awardDivision(key: DivisionGifts.key(season: season, stop: stop), denari: denari) == true
            else { continue }
            if case .pack(let tier) = reward { store.albumBook.give(tier) }
            paid.append(stop)
        }
        return toast(for: paid, locale: locale)
    }

    /// The one toast for the stops paid, lowest first: the highest division reached when a
    /// pack came with them, otherwise the stops inside the division.
    static func toast(for stops: [Int], locale: Locale) -> Toast? {
        guard let top = stops.last else { return nil }
        let packs = stops.compactMap { stop -> (stop: Int, tier: PackTier)? in
            if case .pack(let tier) = DivisionGifts.reward(at: stop) { (stop, tier) } else { nil }
        }
        let coins = stops.reduce(0) { sum, stop in
            if case .denari(let amount) = DivisionGifts.reward(at: stop) { sum + amount.coins } else { sum }
        }
        guard let pack = packs.last else {
            let title = name(of: top, locale: locale)
            return Toast(symbol: "flag.fill", tint: Palette.gold,
                         title: stops.count == 1
                            ? String(localized: "A stop on the way through \(title)", locale: locale)
                            : String(localized: "\(stops.count) stops on the way through \(title)", locale: locale),
                         detail: String(localized: "+\(coins) denari", locale: locale))
        }
        let title = name(of: pack.stop, locale: locale)
        return Toast(symbol: "gift.fill", tint: Palette.gold,
                     title: String(localized: "\(title) reached", locale: locale),
                     detail: packDetail(packs.map(\.tier), coins: coins, locale: locale))
    }

    private static func packDetail(_ tiers: [PackTier], coins: Int, locale: Locale) -> String {
        guard tiers.count == 1, let tier = tiers.first else {
            return String(localized: "\(tiers.count) packs are waiting in the album, and \(coins) denari are in your purse.",
                          locale: locale)
        }
        return coins == 0
            ? String(localized: "A \(tier.title) pack is waiting in the album", locale: locale)
            : String(localized: "A \(tier.title) pack is waiting in the album, and \(coins) denari are in your purse.",
                     locale: locale)
    }

    /// The division a stop sits in; for a pack, the one its top opens onto.
    private static func name(of stop: Int, locale: Locale) -> String {
        Ranking.standing(for: stop * DivisionGifts.stride).leagueTitle(locale: locale)
    }
}
