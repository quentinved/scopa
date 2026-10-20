import Testing
import ScopaCore
@testable import ScopaRewards

/// The card today's deal hands over, the odds it is drawn at, and the runs that pay a pack.
@Suite struct DailyCards {
    @Test func finishingDrawsAtTheEarnedPacksOddsAndAWinAtTheNextTiers() {
        #expect(DailyCard.odds(won: false) == .mazzetto)
        #expect(DailyCard.odds(won: true) == .bottega)
        #expect(PackTier.on(.album).firstIndex(of: DailyCard.odds(won: true))
            == PackTier.on(.album).firstIndex(of: DailyCard.odds(won: false)).map { $0 + 1 })
    }

    @Test func aWinIsLikelierToTurnUpEveryRarityAboveANumeral() {
        for rarity in Rarity.allCases where rarity > .plain {
            #expect(DailyCard.chance(ofAtLeast: rarity, won: true) > DailyCard.chance(ofAtLeast: rarity, won: false))
        }
        // Every card is something, and the odds add up to the deck.
        #expect(abs(DailyCard.chance(ofAtLeast: .plain, won: false) - 1) < 1e-9)
        #expect(abs(DailyCard.chance(ofAtLeast: .plain, won: true) - 1) < 1e-9)
    }

    /// The printed odds are the odds: a long run of draws lands close to them.
    @Test func theDrawMatchesThePrintedOdds() {
        var generator = SeededGenerator(seed: 20_261_012)
        for won in [false, true] {
            let draws = 20_000
            let good = (0..<draws).count { _ in
                DailyCard.draw(won: won, using: &generator).rarity >= .court
            }
            let expected = DailyCard.chance(ofAtLeast: .court, won: won)
            #expect(abs(Double(good) / Double(draws) - expected) < 0.015)
        }
    }

    @Test func aPackComesEverySeventhDayBottegaFirstThenVelluto() {
        #expect(DailyCard.pack(onStreak: 0) == nil)
        #expect(DailyCard.pack(onStreak: 1) == nil)
        #expect(DailyCard.pack(onStreak: 6) == nil)
        #expect(DailyCard.pack(onStreak: 7) == .bottega)
        #expect(DailyCard.pack(onStreak: 8) == nil)
        #expect(DailyCard.pack(onStreak: 14) == .velluto)
        #expect(DailyCard.pack(onStreak: 21) == .velluto)
        #expect(DailyCard.pack(onStreak: 70) == .velluto)
        let paying = (1...60).filter { DailyCard.pack(onStreak: $0) != nil }
        #expect(paying == [7, 14, 21, 28, 35, 42, 49, 56])
        // Packs from the album's shelf only: the shop's hold no cards.
        #expect(paying.compactMap(DailyCard.pack(onStreak:)).allSatisfy { $0.shelf == .album })
    }

    @Test func theNextPackDayIsAlwaysAheadOfTheRun() {
        #expect(DailyCard.nextPack(after: 0) == 7)
        #expect(DailyCard.nextPack(after: 6) == 7)
        #expect(DailyCard.nextPack(after: 7) == 14)
        #expect(DailyCard.nextPack(after: 13) == 14)
        #expect(DailyCard.nextPack(after: -3) == 7)
    }

    /// Keyed on the day, so the same day pays once wherever it was played, and kept apart
    /// from the deal's own denari, which are keyed beside them.
    @Test func keysNameTheDayAndNeverCollideWithTheDealsDenari() throws {
        #expect(DailyCard.cardKey(day: "2026-10-12") == "daily/2026-10-12/card")
        #expect(DailyCard.packKey(day: "2026-10-12") == "daily/2026-10-12/pack")
        #expect(DailyCard.cardKey(day: "2026-10-12") != DailyCard.cardKey(day: "2026-10-13"))
        let players = [Player(id: PlayerID(rawValue: "a"), name: "a"), Player(id: PlayerID(rawValue: "b"), name: "b")]
        let configuration = try GameConfiguration(players: players)
        var tally = RewardTally(side: 0, configuration: configuration, mode: .dailyDeal(day: "2026-10-12"))
        tally.observe(.gameEnded(winnerSide: 0))
        let keys = Set(tally.entries(firstOfDay: true).map(\.key))
        #expect(keys.contains("daily/2026-10-12/dailyDeal"))
        #expect(!keys.contains(DailyCard.cardKey(day: "2026-10-12")))
        #expect(!keys.contains(DailyCard.packKey(day: "2026-10-12")))
    }
}
