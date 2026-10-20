import Foundation
import ScopaCore
import ScopaRewards

/// Today's card, shown without playing the deal for it. Nothing is written to the album or
/// the ledger: only the reveal is played.
///
/// `-dailyCard` turns over a card drawn at a win's odds; `-dailyCard settebello` (or
/// `plain`, `court`, `prime`) one of that rarity, and `-dailyCard court spare` one already
/// in the album. `-dailyCard lost` leaves it face down, for the odds a video buys after a
/// lost deal. `-dailyStreakPack` opens on the pack a run of seven brings, already set
/// down; `-dailyStreakPack 14` on the one fourteen days bring.
extension DebugLaunch {
    static var dailyStartsOnPack: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-dailyStreakPack")
        #else
        false
        #endif
    }

    /// The gift to reveal, or nil when neither flag was passed. Drawn once, so a redraw of
    /// the screen does not swap the card under the reveal.
    static let dailyGift: DailyGift? = sampleGift()

    private static func sampleGift() -> DailyGift? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let cardAt = arguments.firstIndex(of: "-dailyCard")
        guard cardAt != nil || dailyStartsOnPack else { return nil }
        let words = cardAt.map { Array(arguments.dropFirst($0 + 1).prefix { !$0.hasPrefix("-") }) } ?? []
        let card = sampleCard(named: words.first)
        let found: Album.Found = words.contains("spare") ? .spare(card, card.rarity.spare) : .new(card)
        let opening = AlbumBook.Opening(volume: .riviera, tier: DailyCard.odds(won: true), found: [found],
                                        suits: [], deck: false, won: [])
        let days = streakDays
        let lost = words.contains("lost")
        return DailyGift(card: lost ? nil : opening, won: !lost,
                         pack: dailyStartsOnPack ? DailyCard.pack(onStreak: days) : nil, days: days, isUndrawn: lost)
        #else
        return nil
        #endif
    }

    /// The face-down card of `-dailyCard lost`, drawn at the odds picked without touching
    /// the album or the ledger.
    static func drawnSample(_ gift: DailyGift, watched: Bool) -> DailyGift? {
        #if DEBUG
        var generator = SystemRandomNumberGenerator()
        let card = DailyCard.draw(won: watched, using: &generator)
        var drawn = gift
        drawn.card = AlbumBook.Opening(volume: .riviera, tier: DailyCard.odds(won: watched), found: [.new(card)],
                                       suits: [], deck: false, won: [])
        drawn.isUndrawn = false
        drawn.watchedFor = watched
        return drawn
        #else
        return nil
        #endif
    }

    /// A card of the rarity named, by its case or its English title, or one drawn at a win's odds.
    private static func sampleCard(named name: String?) -> Card {
        let rarity = Rarity.allCases.first { "\($0)" == name || $0.title.lowercased() == name }
        if let rarity, let card = Deck.standard.filter({ $0.rarity == rarity }).randomElement() { return card }
        var generator = SystemRandomNumberGenerator()
        return DailyCard.draw(won: true, using: &generator)
    }

    /// The run `-dailyStreakPack` reached: seven unless told, rounded to a day that pays.
    private static var streakDays: Int {
        let arguments = ProcessInfo.processInfo.arguments
        let asked = arguments.firstIndex(of: "-dailyStreakPack").flatMap { Int(arguments[safe: $0 + 1] ?? "") } ?? 7
        return max(asked / DailyCard.packEvery, 1) * DailyCard.packEvery
    }
}
