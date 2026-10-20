import Testing
import ScopaCore
@testable import ScopaRewards

/// The gold album: the foil odds, what a foil turns into, what Oro pays, and how long it takes.
@Suite struct OroAlbum {
    /// Gold keeps the deck's order in every pack and every volume: one numeral shines more
    /// often than one court, a court than a seven, a seven than the settebello.
    @Test func aRarerCardIsARarerFoil() {
        for volume in [Volume.riviera, .intarsio, .tarocchi] {
            for tier in PackTier.on(.album) {
                let perCard = Rarity.allCases.map { rarity in
                    Pack.keptChance(of: rarity, in: tier, volume: volume)
                        / Double(Deck.standard.count { $0.rarity == rarity })
                        * Oro.chance(of: rarity, in: tier, volume: volume)
                }
                #expect(perCard == perCard.sorted(by: >))
                #expect(Rarity.allCases.allSatisfy { (0..<1).contains(Oro.chance(of: $0, in: tier, volume: volume)) })
            }
        }
        // About one earned card in nineteen, and more out of the dear packs.
        #expect(abs(1 / Oro.chance(in: .mazzetto) - 19) < 1)
        #expect(Oro.chance(in: .reliquia) > Oro.chance(in: .velluto))
        #expect(Oro.chance(in: .velluto) > Oro.chance(in: .bottega))
        #expect(Oro.chance(in: .bottega) > Oro.chance(in: .mazzetto))
    }

    /// The same, counted off real packs, promises kept: gold aces outnumber gold sevens.
    @Test func goldAcesOutnumberGoldSevens() {
        var generator = SeededGenerator(seed: 20_261_018)
        for tier in [PackTier.mazzetto, .reliquia] {
            var aces = 0
            var sevens = 0
            for _ in 0..<30_000 {
                let roll = Oro.gild(Pack.draw(tier, using: &generator), against: Album(), using: &generator)
                aces += roll.foilCards.count { $0.rank == .ace }
                sevens += roll.foilCards.count { $0.rank == .seven }
            }
            #expect(aces > sevens * 3 / 2)
        }
    }

    @Test func aFoilOroAlreadyHasBecomesAMissingOneOfTheSameRarity() {
        var oro = Album()
        _ = oro.open(Pack(cards: [Card(.three, of: .cups)]))
        var generator = SeededGenerator(seed: 1)
        let pack = Pack(cards: [Card(.three, of: .cups), Card(.king, of: .swords)])
        let gilded = Oro.gild(pack, foils: [true, false], against: oro, using: &generator)
        let swapped = gilded.pack.cards[0]
        #expect(swapped != Card(.three, of: .cups))
        #expect(swapped.rarity == .plain)
        #expect(!oro.has(swapped))
        // A card that did not shine is left as it was drawn.
        #expect(gilded.pack.cards[1] == Card(.king, of: .swords))
        #expect(gilded.foilCards == [swapped])
    }

    @Test func twoFoilsInOnePackNeverLandOnTheSameGap() {
        var generator = SeededGenerator(seed: 3)
        var oro = Album()
        let courts = Deck.standard.filter { $0.rarity == .court }
        for card in courts.dropLast(2) { _ = oro.open(Pack(cards: [card])) }
        let pack = Pack(cards: [courts[0], courts[0]])
        let gilded = Oro.gild(pack, foils: [true, true], against: oro, using: &generator)
        #expect(Set(gilded.pack.cards) == Set(courts.suffix(2)))
    }

    @Test func aFullRarityPaysFiveSparesInstead() {
        var oro = Album()
        let primes = Deck.standard.filter { $0.rarity == .prime }
        for card in primes { _ = oro.open(Pack(cards: [card])) }
        var generator = SeededGenerator(seed: 5)
        let gilded = Oro.gild(Pack(cards: [primes[1]]), foils: [true], against: oro, using: &generator)
        #expect(gilded.pack.cards == [primes[1]])
        let gilt = Oro.fold(gilded, into: &oro)
        #expect(gilt.foil(at: 0) == .spare(primes[1], Rarity.prime.spare * 5))
        #expect(gilt.denari == Oro.spare(of: .prime))
        #expect(!gilt.hasNew)
    }

    @Test func foldingSaysWhatEachPlaceDidInThePacksOrder() {
        var oro = Album()
        let cards = [Card(.ace, of: .coins), Card(.two, of: .coins), Card(.seven, of: .cups)]
        let gilt = Oro.fold(FoilRoll(pack: Pack(cards: cards), foils: [false, true, true]), into: &oro)
        #expect(gilt.foil(at: 0) == nil)
        #expect(gilt.foil(at: 1) == .new(Card(.two, of: .coins)))
        #expect(gilt.foil(at: 2) == .new(Card(.seven, of: .cups)))
        #expect(gilt.count == 2)
        #expect(oro.found == 2)
    }

    @Test func aSuitAndTheWholeOfOroAreToldOnceTheyFill() {
        var oro = Album()
        let coins = Deck.standard.filter { $0.suit == .coins }
        let first = Oro.fold(FoilRoll(pack: Pack(cards: Array(coins.dropLast())),
                                     foils: Array(repeating: true, count: 9)), into: &oro)
        #expect(first.suits.isEmpty)
        let last = Oro.fold(FoilRoll(pack: Pack(cards: [coins[9]]), foils: [true]), into: &oro)
        #expect(last.suits == [.coins])
        let rest = Deck.standard.filter { $0.suit != .coins }
        let whole = Oro.fold(FoilRoll(pack: Pack(cards: rest), foils: rest.map { _ in true }), into: &oro)
        #expect(whole.isComplete)
        #expect(Set(whole.suits) == [.cups, .swords, .clubs])
    }

    @Test func foilsTravelAsTheirOwnCodes() {
        #expect(Oro.code(of: .settebello) == "oro/7d")
        #expect(Oro.card(fromCode: "oro/7d") == .settebello)
        #expect(Oro.card(fromCode: "napoli/7d") == nil)
        #expect(Oro.card(fromCode: "7d") == nil)
        for card in Deck.standard { #expect(Oro.card(fromCode: Oro.code(of: card)) == card) }
        #expect(Oro.suitKey(.cups) == "oro/cups")
        #expect(Set(Suit.allCases.map(Oro.suitKey)).count == 4)
        #expect(!Suit.allCases.map(Oro.suitKey).contains(Oro.prizeKey))
    }

    @Test func gildingNeverChangesTheOddsOfARarity() {
        var generator = SeededGenerator(seed: 11)
        var oro = Album()
        var plain = 0
        var court = 0
        for _ in 0..<6_000 {
            let gilded = Oro.gild(Pack.draw(.mazzetto, using: &generator), against: oro, using: &generator)
            _ = Oro.fold(gilded, into: &oro)
            plain += gilded.pack.cards.count { $0.rarity == .plain }
            court += gilded.pack.cards.count { $0.rarity == .court }
        }
        let cards = 18_000.0
        #expect(abs(Double(plain) / cards - Pack.chance(of: .plain, in: .mazzetto)) < 0.012)
        #expect(abs(Double(court) / cards - Pack.chance(of: .court, in: .mazzetto)) < 0.012)
    }

    /// The printed time is the simulated one, and the bias is what makes it finishable.
    @Test func anOrdinaryPlayerFillsOroInAboutSevenMonths() {
        var generator = SeededGenerator(seed: 20_261_012)
        let days = (0..<120).map { _ in OroPlayer.daysToFinish(using: &generator) }.sorted()
        let median = days[days.count / 2]
        let late = days[days.count * 9 / 10]
        #expect(abs(Double(median - Oro.typicalDays)) < Double(Oro.typicalDays) * 0.12)
        // The settebello is the rarest gold on purpose, which lengthens the unlucky end; the
        // last gap always shining is what keeps it in the same year.
        #expect(late < 400)
        #expect(days.last ?? 0 < 600)
    }

    @Test func pureChanceWouldTakeMoreThanTwiceAsLong() {
        var generator = SeededGenerator(seed: 7)
        let days = (0..<30).map { _ in OroPlayer.daysToFinish(biased: false, using: &generator) }.sorted()
        #expect(days[days.count / 2] > Oro.typicalDays * 2)
    }
}

/// One ordinary player: five games a day, an earned Mazzetto every third, today's card won
/// every other day, and the Bottega a finished suit of foils pays. Nothing bought.
private enum OroPlayer {
    static func daysToFinish(biased: Bool = true, using generator: inout SeededGenerator) -> Int {
        var oro = Album()
        var games = 0
        var owed = 0
        for day in 1...3_000 {
            var packs: [Pack] = []
            for _ in 0..<5 {
                games += 1
                if games % Pack.gamesPerPack == 0 { packs.append(Pack.draw(.mazzetto, using: &generator)) }
            }
            let won = Bool.random(using: &generator)
            packs.append(Pack(cards: [DailyCard.draw(won: won, using: &generator)], tier: DailyCard.odds(won: won)))
            packs += (0..<owed).map { _ in Pack.draw(Oro.suitPack, using: &generator) }
            owed = 0
            for pack in packs {
                let gilded = biased ? Oro.gild(pack, against: oro, using: &generator)
                    : FoilRoll(pack: pack, foils: pack.cards.map {
                        Double.random(in: 0..<1, using: &generator)
                            < Oro.chance(of: $0.rarity, in: pack.tier, promised: pack.cards.count == pack.tier.cards)
                    })
                owed += Oro.fold(gilded, into: &oro).suits.count
            }
            if oro.isComplete { return day }
        }
        return 3_000
    }
}
