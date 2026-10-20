import Foundation
import Testing
import ScopaCore
@testable import ScopaRewards

@Suite struct Trading {
    private let two = Card(.two, of: .coins)
    private let three = Card(.three, of: .cups)
    private let ace = Card(.ace, of: .swords)
    private let knave = Card(.knave, of: .cups)
    private let king = Card(.king, of: .swords)
    private let seven = Card(.seven, of: .cups)

    @Test func twentySpareNumeralsBringInAMissingNumeral() throws {
        let album = Album(counts: [two: 11, three: 11])
        let offer = try #require(Scambio.offer(for: ace, in: album))
        #expect(offer.count == 20)
        #expect(offer.count(of: .plain) == 20)
        #expect(Scambio.offer(for: ace, in: Album(counts: [two: 20])) == nil)
    }

    @Test func numeralsNeverPayForACourt() {
        let album = Album(counts: [two: 30, three: 30])
        #expect(Scambio.offer(for: king, in: album) == nil)
    }

    @Test func fifteenSpareCourtsBringInACourt() throws {
        let album = Album(counts: [knave: 16, two: 9])
        let offer = try #require(Scambio.offer(for: king, in: album))
        #expect(offer.spares == [knave: 15])
        #expect(Scambio.offer(for: king, in: Album(counts: [knave: 15, two: 60])) == nil)
    }

    /// The sevens only ever come out of a pack, whatever is piled up against them.
    @Test func nothingBuysASeven() {
        let piles = Album(counts: [knave: 99, king: 99, Card(.seven, of: .swords): 99, two: 99])
        #expect(Scambio.offer(for: seven, in: piles) == nil)
        #expect(!Scambio.offers(in: piles).contains { $0.card.rarity == .prime })
    }

    @Test func spareSevensStillPayForACourt() throws {
        let sevens = Card(.seven, of: .swords)
        let offer = try #require(Scambio.offer(for: king, in: Album(counts: [sevens: 9])))
        #expect(offer.spares == [sevens: 8])
        #expect(Scambio.offer(for: king, in: Album(counts: [sevens: 8])) == nil)
    }

    /// The settebello only ever comes out of a pack, whatever is piled up against it.
    @Test func nothingBuysTheSettebello() {
        let piles = Album(counts: [knave: 99, king: 99, seven: 99, Card(.seven, of: .swords): 99, two: 99])
        #expect(Scambio.offer(for: .settebello, in: piles) == nil)
        #expect(!Scambio.offers(in: piles).contains { $0.card == .settebello })
    }

    @Test func aSpareSettebelloIsNeverTraded() {
        let album = Album(counts: [.settebello: 9])
        #expect(Scambio.offer(for: ace, in: album) == nil)
    }

    @Test func aCourtThatTipsThePriceOverLeavesNoNumeralOverpaid() throws {
        let album = Album(counts: [two: 19, knave: 2])
        let offer = try #require(Scambio.offer(for: ace, in: album))
        #expect(offer.spares == [two: 17, knave: 1])
    }

    @Test func theSparesWithTheMostCopiesGoFirst() throws {
        let album = Album(counts: [two: 22, three: 4])
        let offer = try #require(Scambio.offer(for: ace, in: album))
        #expect(offer.spares == [two: 20])
    }

    /// A hundred packs' worth of cards before a volume trades, counted off the cards that came.
    @Test func tradingWaitsForAHundredPacks() {
        #expect(Scambio.packsBeforeTrading == 100)
        #expect(Scambio.packsOpened(into: Album(counts: [two: 299])) == 99)
        #expect(Scambio.packsOpened(into: Album(counts: [two: 150, three: 150])) == 100)
    }

    @Test func aCardAlreadyInTheAlbumIsNotTradedFor() {
        #expect(Scambio.offer(for: two, in: Album(counts: [two: 9])) == nil)
    }

    @Test func offersListTheRarestFirst() {
        let album = Album(counts: [knave: 16, two: 22, Card(.ace, of: .coins): 1])
        let offers = Scambio.offers(in: album)
        #expect(offers.first?.card.rarity == .court)
        #expect(offers.contains { $0.card.rarity == .plain })
    }
}

@Suite struct TradedSpares {
    private let two = Card(.two, of: .coins)
    private let knave = Card(.knave, of: .cups)
    private let king = Card(.king, of: .clubs)

    @Test func aTradeLeavesTheAlbumAsOneLedgerKeyPerSpare() throws {
        let album = Album(counts: [two: 3, knave: 16])
        let offer = try #require(Scambio.offer(for: king, in: album))
        let keys = Scambio.departureKeys(for: offer, from: .napoli)
        #expect(keys.count == offer.count)
        #expect(keys.allSatisfy { $0.hasPrefix("album/out/napoli/") && $0.contains("/scambio/10b/") })
        let gone = Departures(keys: keys)
        #expect(gone.count(of: knave, in: .napoli) == 15)
        #expect(gone.count(of: knave, in: .riviera) == 0)
    }

    /// The ledger merges by union, so the trade read twice, or from two devices, leaves once.
    @Test func theSameTradeTwiceLeavesOnce() throws {
        let album = Album(counts: [two: 21])
        let offer = try #require(Scambio.offer(for: Card(.ace, of: .clubs), in: album))
        let keys = Scambio.departureKeys(for: offer, from: .riviera)
        let gone = Departures(keys: Set(keys + keys))
        let left = album.less(gone, in: .riviera)
        #expect(left.spares(of: two) == 0)
        #expect(left.has(two))
        #expect(Scambio.offer(for: Card(.ace, of: .cups), in: left) == nil)
    }
}
