import Foundation
import Testing
import ScopaCore
@testable import ScopaRewards

/// Perla, the album after Oro: when it opens, where foils go then, what it pays, how it travels.
@Suite struct PerlaAlbum {
    private static func full() -> Album {
        var album = Album()
        _ = album.open(Pack(cards: Deck.standard))
        return album
    }

    private static func all(but missing: Card) -> Album {
        var album = Album()
        _ = album.open(Pack(cards: Deck.standard.filter { $0 != missing }))
        return album
    }

    @Test func perlaOpensOnlyOnceOroIsFull() {
        #expect(FoilShelf().open == .oro)
        #expect(FoilShelf(oro: Self.all(but: .settebello)).open == .oro)
        #expect(FoilShelf(oro: Self.full()).open == .perla)
        // A full Perla stays the open one: its foils pay spares, as a full Oro's once did.
        #expect(FoilShelf(oro: Self.full(), perla: Self.full()).open == .perla)
        #expect(FoilAlbum.oro < .perla)
    }

    @Test func foilsGoIntoPerlaOnceOroIsFull() {
        var shelf = FoilShelf(oro: Self.full())
        let cards = [Card(.two, of: .cups), Card(.king, of: .swords)]
        let gilt = shelf.fold(FoilRoll(pack: Pack(cards: cards), foils: [true, false]))
        #expect(gilt.album == .perla)
        #expect(gilt.foil(at: 0) == .new(Card(.two, of: .cups)))
        #expect(gilt.foil(at: 1) == nil)
        #expect(shelf.perla.found == 1)
        #expect(shelf.oro == Self.full())
    }

    @Test func untilThenFoilsGoIntoOro() {
        var shelf = FoilShelf()
        let gilt = shelf.fold(FoilRoll(pack: Pack(cards: [.settebello]), foils: [true]))
        #expect(gilt.album == .oro)
        #expect(shelf.oro.found == 1)
        #expect(shelf.perla.found == 0)
    }

    /// The pack that finishes Oro is Oro's to the end; the next one is Perla's.
    @Test func thePackThatFinishesOroIsStillGold() {
        var shelf = FoilShelf(oro: Self.all(but: .settebello))
        let last = shelf.fold(FoilRoll(pack: Pack(cards: [.settebello, Card(.ace, of: .coins)]), foils: [true, true]))
        #expect(last.album == .oro)
        #expect(last.isComplete)
        #expect(last.foil(at: 1) == .spare(Card(.ace, of: .coins), Oro.spare(of: .plain)))
        #expect(shelf.perla.found == 0)
        let next = shelf.fold(FoilRoll(pack: Pack(cards: [Card(.ace, of: .coins)]), foils: [true]))
        #expect(next.album == .perla)
        #expect(next.foil(at: 0) == .new(Card(.ace, of: .coins)))
    }

    /// Perla keeps Oro's rules: a foil it already has becomes one it lacks, and its last
    /// gap always shines.
    @Test func perlaKeepsOrosRules() {
        var generator = SeededGenerator(seed: 41)
        var shelf = FoilShelf(oro: Self.full(), perla: Self.all(but: .settebello))
        let (pack, gilt) = shelf.gild(Pack(cards: [Card(.four, of: .clubs), .settebello], tier: .mazzetto),
                                      using: &generator)
        #expect(gilt.album == .perla)
        #expect(gilt.foil(at: 1) == .new(.settebello))
        #expect(gilt.isComplete)
        #expect(pack.cards[1] == .settebello)

        var swapped = FoilShelf(oro: Self.full())
        _ = swapped.fold(FoilRoll(pack: Pack(cards: [Card(.three, of: .cups)]), foils: [true]))
        let again = swapped.fold(FoilRoll(pack: Pack(cards: [Card(.three, of: .cups)]), foils: [true]))
        #expect(again.foil(at: 0) == .spare(Card(.three, of: .cups), Oro.spare(of: .plain)))
        let rolled = Oro.gild(Pack(cards: [Card(.three, of: .cups)]), foils: [true], against: swapped.perla,
                              using: &generator)
        #expect(rolled.pack.cards[0] != Card(.three, of: .cups))
        #expect(rolled.pack.cards[0].rarity == .plain)
    }

    @Test func perlaFoilsTravelAsTheirOwnCodes() {
        #expect(FoilAlbum.perla.code(of: .settebello) == "perla/7d")
        #expect(FoilAlbum.perla.card(fromCode: "perla/7d") == .settebello)
        for card in Deck.standard {
            #expect(FoilAlbum.perla.card(fromCode: FoilAlbum.perla.code(of: card)) == card)
        }
        // Neither album reads the other's, and an older build's Oro reads none of Perla's.
        #expect(FoilAlbum.perla.card(fromCode: "oro/7d") == nil)
        #expect(Oro.card(fromCode: "perla/7d") == nil)
        #expect(FoilAlbum.perla.card(fromCode: "7d") == nil)
        #expect(Volume(rawValue: "perla") == nil)
        // Oro's names are the ones it always had.
        #expect(FoilAlbum.oro.code(of: .settebello) == Oro.code(of: .settebello))
        #expect(FoilAlbum.oro.prizeKey == "oro/bordo")
        #expect(FoilAlbum.oro.suitKey(.cups) == Oro.suitKey(.cups))
    }

    @Test func perlaHasLedgerKeysOfItsOwn() {
        let keys = FoilAlbum.allCases.flatMap { album in Suit.allCases.map(album.suitKey) + [album.prizeKey] }
        #expect(Set(keys).count == keys.count)
        #expect(FoilAlbum.perla.suitKey(.coins) == "perla/coins")
        #expect(FoilAlbum.perla.prizeKey == "perla/madreperla")
    }

    @Test func perlaSuitsPayAStepUpFromOros() {
        #expect(FoilAlbum.oro.suitPack == Oro.suitPack)
        #expect(FoilAlbum.oro.suitPack == .bottega)
        #expect(FoilAlbum.perla.suitPack == .velluto)
        #expect(FoilAlbum.perla.suitPack.cards >= FoilAlbum.oro.suitPack.cards)
    }

    /// The suit packs and the prize are claimed in the ledger under their keys, so finishing
    /// Perla on two phones, or settling it twice, pays once.
    @Test func perlaIsPaidOnce() async throws {
        let wallet = Wallet(store: MemoryLedgerStore())
        let prize = ShopItem(id: "edge.madreperla", kind: .cardEdge, title: "Madreperla", detail: "card edge madreperla",
                             price: .zero, grade: .leggendario)
        _ = try await wallet.unlock(prize, key: FoilAlbum.perla.prizeKey)
        _ = try await wallet.unlock(prize, key: FoilAlbum.perla.prizeKey)
        let purse = try await wallet.purse()
        #expect(purse.owns(prize))
        #expect(purse.entries.count { $0.key == FoilAlbum.perla.prizeKey } == 1)
        let first = try await wallet.grant(.zero, note: FoilAlbum.perla.suitKey(.cups), key: FoilAlbum.perla.suitKey(.cups))
        let second = try await wallet.grant(.zero, note: FoilAlbum.perla.suitKey(.cups), key: FoilAlbum.perla.suitKey(.cups))
        #expect(first.count == 1)
        #expect(second.isEmpty)
        // Oro's suit is a claim of its own.
        let oro = try await wallet.grant(.zero, note: FoilAlbum.oro.suitKey(.cups), key: FoilAlbum.oro.suitKey(.cups))
        #expect(oro.count == 1)
    }

    /// The printed time is the simulated one, from the day Perla opens.
    @Test func anOrdinaryPlayerFillsPerlaInAboutAsLongAsOro() {
        var generator = SeededGenerator(seed: 20_261_018)
        let days = (0..<120).map { _ in PerlaPlayer.daysToFinish(using: &generator) }.sorted()
        let median = days[days.count / 2]
        #expect(abs(Double(median - FoilAlbum.perla.typicalDays)) < Double(FoilAlbum.perla.typicalDays) * 0.12)
        #expect(FoilAlbum.perla.typicalDays <= FoilAlbum.oro.typicalDays)
        #expect(days[days.count * 9 / 10] < 400)
    }
}

/// `OroTests`' ordinary player, starting the day Oro is full: five games a day, an earned
/// Mazzetto every third, today's card every day, and the Velluto a finished suit pays.
private enum PerlaPlayer {
    static func daysToFinish(using generator: inout SeededGenerator) -> Int {
        var full = Album()
        _ = full.open(Pack(cards: Deck.standard))
        var shelf = FoilShelf(oro: full)
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
            packs += (0..<owed).map { _ in Pack.draw(FoilAlbum.perla.suitPack, using: &generator) }
            owed = 0
            for pack in packs { owed += shelf.gild(pack, using: &generator).gilt.suits.count }
            if shelf.perla.isComplete { return day }
        }
        return 3_000
    }
}
