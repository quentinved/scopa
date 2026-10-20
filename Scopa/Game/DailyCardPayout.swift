import Foundation
import ScopaCore
import ScopaRewards
import SwiftUI

/// Hands over what today's deal is worth besides its denari: one card for the album, and a
/// pack every seventh day of a run.
///
/// Both are claimed in the ledger before anything is drawn, keyed on the day, so a deal
/// replayed, a summary shown twice or the same day played on the iPad pays once. The card
/// then goes in the album and pays for itself exactly the way a pack's card does.
@MainActor
enum DailyCardPayout {
    /// Nil when nothing was owed: the day was already paid for. `offersVideo` leaves a lost
    /// deal's card face down and unclaimed, for the reveal to draw once its odds are chosen.
    static func settle(_ tally: RewardTally, day: String, store: TableStore, purse: PurseStore,
                       toaster: Toaster, locale: Locale, offersVideo: Bool) async -> DailyGift? {
        guard tally.isSettled else { return nil }
        let won = tally.outcome == .won
        let waits = !won && offersVideo && !purse.purse.keys.contains(DailyCard.cardKey(day: day))
        let card = waits ? nil : await card(day: day, won: won, store: store, purse: purse)
        let days = store.dailyBook.streak(endingOn: day)
        let pack = await pack(day: day, days: days, store: store, purse: purse)
        // Told in the lobby, where the album is a tap away.
        if let pack { toaster.hold(toast(for: pack, days: days, locale: locale)) }
        guard card != nil || waits || pack != nil else { return nil }
        return DailyGift(card: card, won: won, pack: pack, days: days, day: day, isUndrawn: waits)
    }

    /// Draws the card a lost deal left face down, at the winner's odds when a video was
    /// watched for it. Nil when the day was paid meanwhile, on this phone or another.
    static func draw(_ gift: DailyGift, watched: Bool, store: TableStore, purse: PurseStore) async -> DailyGift? {
        guard gift.isUndrawn, let day = gift.day,
              let card = await card(day: day, won: watched, store: store, purse: purse) else { return nil }
        var drawn = gift
        drawn.card = card
        drawn.isUndrawn = false
        drawn.watchedFor = watched
        return drawn
    }

    /// Draws the day's card into the album, and pays what a spare or a finished suit is worth.
    private static func card(day: String, won: Bool, store: TableStore,
                             purse: PurseStore) async -> AlbumBook.Opening? {
        guard await purse.claim(DailyCard.cardKey(day: day)) == true else { return nil }
        var generator = SystemRandomNumberGenerator()
        let drawn = DailyCard.draw(won: won, volume: store.albumBook.openVolume, using: &generator)
        let opened = store.albumBook.openCard(drawn, odds: DailyCard.odds(won: won), drawn: true)
        await purse.awardPack(opened.denari, key: opened.key)
        if opened.deck { await purse.award(opened.volume) }
        if opened.gilt.count > 0 { await OroPayout.settle(book: store.albumBook, purse: purse) }
        return opened
    }

    /// Leaves the run's pack on the album's shelf, on the days a run pays one.
    private static func pack(day: String, days: Int, store: TableStore, purse: PurseStore) async -> PackTier? {
        guard let tier = DailyCard.pack(onStreak: days),
              await purse.claim(DailyCard.packKey(day: day)) == true else { return nil }
        store.albumBook.give(tier)
        return tier
    }

    static func toast(for tier: PackTier, days: Int, locale: Locale) -> Toast {
        Toast(symbol: "gift.fill", tint: Palette.gold,
              title: String(localized: "\(days) days in a row", locale: locale),
              detail: String(localized: "A \(tier.title) pack is waiting in the album", locale: locale))
    }
}
