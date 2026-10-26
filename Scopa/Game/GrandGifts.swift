import Foundation
import ScopaCore
import ScopaRewards

/// Gran Maestro's road. It has no divisions and no top, so the divisions' pattern, coins at
/// three stops and a pack at the fourth, would pour a Reliquia out every hundred points.
/// Instead every hundred points pays denari, and every fifth hundred a Reliquia with them.
///
/// Once per stop per season, like the divisions' road, and only for climbs this phone has
/// seen. The ledger keys are its own: "division/2026-10/gran/3" can never be a division's,
/// whose last part is always a number.
enum GrandGifts {
    /// Points from one stop to the next.
    static let stride = 100
    /// What every stop pays.
    static let denari: Denari = 100
    /// Every this many stops, a pack on top.
    static let packEvery = 5
    static let tier = PackTier.reliquia

    /// "2026-10|3": the season, and the highest stop already counted in it.
    private static let markKey = "grandGifts.stop"

    /// The pack a stop pays beside its denari, on every fifth. Nil on the others.
    static func pack(at stop: Int) -> PackTier? {
        stop > 0 && stop.isMultiple(of: packEvery) ? tier : nil
    }

    /// Hundreds of points past Gran Maestro's floor. Nought below it.
    static func stop(for rating: Int) -> Int { max(rating - Ranking.grandFloor, 0) / stride }

    /// How far the next stop is, and the pack it carries if it carries one. Nil below Gran
    /// Maestro, whose stops are the divisions'.
    static func next(after rating: Int) -> (points: Int, pack: PackTier?)? {
        guard rating >= Ranking.grandFloor else { return nil }
        let stop = stop(for: rating) + 1
        return (Ranking.grandFloor + stop * stride - rating, pack(at: stop))
    }

    /// The stops this answer climbs past the mark, lowest first, and moves the mark up to it.
    static func climbed(in rank: Ladder.RankAnswer, defaults: UserDefaults = .standard) -> [Int] {
        guard let season = rank.season, rank.games > 0, rank.rating >= Ranking.grandFloor else { return [] }
        let stop = stop(for: rank.rating)
        let counted = mark(season: season, stop: stop, defaults: defaults)
        defaults.set("\(season)|\(max(stop, counted))", forKey: markKey)
        return stop > counted ? Array(counted + 1...stop) : []
    }

    /// This season's mark; nought after a new season, which starts Gran Maestro again at its
    /// floor; or right here for a phone that has never counted, so a player already high in
    /// it the day this arrives is not handed every stop below at once.
    private static func mark(season: String, stop: Int, defaults: UserDefaults) -> Int {
        let parts = defaults.string(forKey: markKey)?.split(separator: "|").map(String.init) ?? []
        guard parts.count == 2, let at = Int(parts[1]) else { return stop }
        return parts[0] == season ? at : 0
    }

    static func key(season: String, stop: Int) -> String { "division/\(season)/gran/\(stop)" }
}

extension DivisionPayout {
    /// Pays Gran Maestro's stops this answer climbed, and words them as one toast. Nil when
    /// nothing new was paid.
    static func settleGrand(_ rank: Ladder.RankAnswer, store: TableStore, purse: PurseStore,
                            locale: Locale) async -> Toast? {
        guard let season = rank.season else { return nil }
        var paid: [Int] = []
        for stop in GrandGifts.climbed(in: rank) {
            let key = GrandGifts.key(season: season, stop: stop)
            guard await purse.awardDivision(key: key, denari: GrandGifts.denari) == true else { continue }
            if let tier = GrandGifts.pack(at: stop) { store.albumBook.give(tier) }
            paid.append(stop)
        }
        guard let top = paid.last else { return nil }
        let coins = paid.count * GrandGifts.denari.coins
        let packs = paid.compactMap(GrandGifts.pack(at:))
        let title = String(localized: "\(top * GrandGifts.stride) points in Gran Maestro", locale: locale)
        guard !packs.isEmpty else {
            return Toast(symbol: "flag.fill", tint: Palette.gold, title: title,
                         detail: String(localized: "+\(coins) denari", locale: locale))
        }
        return Toast(symbol: "gift.fill", tint: Palette.gold, title: title,
                     detail: packDetail(packs, coins: coins, locale: locale))
    }
}
