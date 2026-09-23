import Testing
import ScopaCore
@testable import ScopaRewards

@Suite struct Collecting {
    @Test func theDeckIsSortedIntoFortyCardsOfFourKinds() {
        let deck = Deck.standard
        #expect(deck.count == 40)
        #expect(deck.count { $0.rarity == .settebello } == 1)
        #expect(deck.count { $0.rarity == .prime } == 3)
        #expect(deck.count { $0.rarity == .court } == 12)
        #expect(deck.count { $0.rarity == .plain } == 24)
        #expect(Card.settebello.rarity == .settebello)
    }

    /// The whole point of the ranking: the cards a scopa player wants are the scarce ones.
    @Test func theBetterTheCardTheRarerAndTheDearerASpareOne() {
        for (lower, higher) in zip(Rarity.allCases, Rarity.allCases.dropFirst()) {
            #expect(higher.weight <= lower.weight)
            #expect(higher.spare > lower.spare)
        }
    }

    @Test func anEmptyAlbumHasNothingAndIsNotComplete() {
        let album = Album()
        #expect(album.found == 0)
        #expect(!album.isComplete)
        #expect(album.fraction == 0)
        #expect(album.missing(in: .coins).count == 10)
    }

    @Test func aCardFoundTwiceIsOnThePageOnceAndPaysForTheSpare() {
        var album = Album()
        let opened = album.open(Pack(cards: [.settebello, .settebello, Card(.three, of: .cups)]))
        #expect(album.found == 2)
        #expect(album.count(of: .settebello) == 2)
        #expect(album.spares(of: .settebello) == 1)
        #expect(opened.found.count { $0.isNew } == 2)
        #expect(Album.denari(in: opened.found) == Rarity.settebello.spare)
    }

    /// No pack is ever a dud: a pack of cards already collected is paid for in denari.
    @Test func aPackOfNothingNewIsStillWorthSomething() {
        var album = Album()
        let card = Card(.king, of: .swords)
        _ = album.open(Pack(cards: [card, card, card]))
        let again = album.open(Pack(cards: [card, card, card]))
        #expect(again.found.allSatisfy { !$0.isNew })
        #expect(Album.denari(in: again.found) == Rarity.court.spare * 3)
    }

    @Test func aSuitIsAnnouncedOnceTheCardThatFinishesItArrives() {
        var album = Album()
        let coins = Deck.standard.filter { $0.suit == .coins }
        let opened = album.open(Pack(cards: Array(coins.prefix(9)) + [Card(.two, of: .cups)]))
        #expect(opened.suits.isEmpty)
        #expect(!album.isComplete(.coins))

        let finished = album.open(Pack(cards: [coins[9]]))
        #expect(finished.suits == [.coins])
        #expect(album.isComplete(.coins))

        // And never announced twice, however many spares turn up afterwards.
        let again = album.open(Pack(cards: [coins[9]]))
        #expect(again.suits.isEmpty)
    }

    @Test func theWholeDeckIsAnnouncedOnceAndOnlyOnce() {
        var album = Album()
        let first = album.open(Pack(cards: Array(Deck.standard.dropLast())))
        #expect(!first.deck)
        let last = album.open(Pack(cards: [Deck.standard[Album.size - 1]]))
        #expect(last.deck)
        #expect(album.isComplete)
        #expect(album.fraction == 1)
        #expect(album.open(Pack(cards: [Card.settebello])).deck == false)
    }

    /// The four suit marks are worn off this, so it has to say yes only for a suit that is
    /// really finished — and keep saying yes once it is.
    @Test func aSuitCountsAsCollectedOnlyWhenEveryCardOfItIsIn() {
        var album = Album()
        #expect(album.completedSuits.isEmpty)
        let coins = Deck.standard.filter { $0.suit == .coins }
        _ = album.open(Pack(cards: Array(coins.dropLast())))
        #expect(album.completedSuits.isEmpty)
        _ = album.open(Pack(cards: [coins[9]]))
        #expect(album.completedSuits == [.coins])
        _ = album.open(Pack(cards: Deck.standard.filter { $0.suit == .cups }))
        #expect(album.completedSuits == [.coins, .cups])
    }

    @Test func aPackHoldsThreeCardsOfTheRealDeck() {
        var generator = SystemRandomNumberGenerator()
        let pack = Pack.draw(using: &generator)
        #expect(pack.cards.count == Pack.size)
        #expect(pack.cards.allSatisfy { Deck.standard.contains($0) })
    }

    /// Weighted, not uniform: over a long run the numerals have to outnumber the sevens.
    @Test func plainCardsTurnUpFarMoreOftenThanGoodOnes() {
        // The deck's own generator, seeded, so a bad afternoon cannot fail the build.
        var generator = SeededGenerator(seed: 20_260_917)
        var counts: [Rarity: Int] = [:]
        for _ in 0..<3_000 {
            counts[Pack.drawOne(using: &generator).rarity, default: 0] += 1
        }
        #expect((counts[.plain] ?? 0) > (counts[.court] ?? 0))
        #expect((counts[.court] ?? 0) > (counts[.settebello] ?? 0))
        // And the scarcest card is still reachable: an album nobody can finish is a chore.
        #expect((counts[.settebello] ?? 0) > 0)
    }
}
