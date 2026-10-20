import Testing
import ScopaCore
@testable import ScopaRewards

@Suite struct Giving {
    private let sevenOfCups = Card(.seven, of: .cups)
    private let id = "6F1C2A8E-0000-4000-8000-000000000001"

    private func album(_ counts: [Card: Int]) -> Album { Album(counts: counts) }

    @Test func onlyASpareGoesAndTheAlbumKeepsItsOwnCopy() {
        #expect(CardGift.refusal(of: sevenOfCups, in: album([sevenOfCups: 2]), givenToday: 0) == nil)
        #expect(CardGift.refusal(of: sevenOfCups, in: album([sevenOfCups: 1]), givenToday: 0) == .noSpare)
        #expect(CardGift.refusal(of: sevenOfCups, in: album([:]), givenToday: 0) == .noSpare)
    }

    @Test func theSettebelloIsFoundNeverGiven() {
        #expect(CardGift.refusal(of: .settebello, in: album([.settebello: 5]), givenToday: 0) == .settebello)
    }

    @Test func oneCardADay() {
        #expect(CardGift.refusal(of: sevenOfCups, in: album([sevenOfCups: 3]), givenToday: 1) == .givenToday)
    }

    @Test func aGiftIsKeyedOnItsVolumeCardDayAndId() {
        let key = Departures.giftKey(sevenOfCups, from: .napoli, day: "2026-10-12", id: id)
        #expect(key == "album/out/napoli/7c/gift/2026-10-12/6f1c2a8e-0000-4000-8000-000000000001")
    }

    @Test func departuresAreReadOffTheLedgerKeysAndNothingElse() {
        let keys = [
            Departures.giftKey(sevenOfCups, from: .riviera, day: "2026-10-11", id: "a"),
            Departures.giftKey(sevenOfCups, from: .riviera, day: "2026-10-12", id: "b"),
            Departures.giftKey(sevenOfCups, from: .napoli, day: "2026-10-12", id: "c"),
            "album/out/riviera/1b/scambio/d",
            "album/out/nowhere/7c/gift/2026-10-12/e",
            "album/out/riviera/99c/gift/2026-10-12/f",
            "pack/1234", "daily/card/2026-10-12",
        ]
        let gone = Departures(keys: keys)
        #expect(gone.count(of: sevenOfCups, in: .riviera) == 2)
        #expect(gone.count(of: sevenOfCups, in: .napoli) == 1)
        #expect(gone.count(of: Card(.ace, of: .clubs), in: .riviera) == 1)
        #expect(gone.gifts(on: "2026-10-12") == 2)
        #expect(gone.gifts(on: "2026-10-11") == 1)
    }

    /// The ledger is a set of keys, so the same gift arriving from two devices leaves once.
    @Test func theSameGiftTwiceLeavesOnce() {
        let key = Departures.giftKey(sevenOfCups, from: .riviera, day: "2026-10-12", id: id)
        let gone = Departures(keys: Set([key, key, key.uppercased().lowercased()]))
        #expect(gone.count(of: sevenOfCups, in: .riviera) == 1)
    }

    @Test func thePageShowsWhatWasFoundLessWhatLeft() {
        let found = album([sevenOfCups: 4, .settebello: 1])
        let gone = Departures(keys: [Departures.giftKey(sevenOfCups, from: .riviera, day: "2026-10-12", id: "a")])
        let shown = found.less(gone, in: .riviera)
        #expect(shown.count(of: sevenOfCups) == 3)
        #expect(shown.spares(of: sevenOfCups) == 2)
        #expect(shown.count(of: .settebello) == 1)
        #expect(found.less(gone, in: .napoli) == found)
    }

    /// Two devices that each gave the same last spare before hearing of the other keep the card.
    @Test func aFoundCardNeverLeavesThePage() {
        let found = album([sevenOfCups: 2])
        let gone = Departures(keys: ["a", "b", "c"].map {
            Departures.giftKey(sevenOfCups, from: .riviera, day: "2026-10-12", id: $0)
        })
        #expect(found.less(gone, in: .riviera).count(of: sevenOfCups) == 1)
        #expect(album([:]).less(gone, in: .riviera).has(sevenOfCups) == false)
    }

    /// What was found still only climbs, so a card found after one was given is a spare again.
    @Test func aCardFoundAfterOneWasGivenIsASpareAgain() {
        var found = album([sevenOfCups: 2])
        let gone = Departures(keys: [Departures.giftKey(sevenOfCups, from: .riviera, day: "2026-10-12", id: "a")])
        #expect(found.less(gone, in: .riviera).spares(of: sevenOfCups) == 0)
        let opened = found.open(Pack(cards: [sevenOfCups]))
        #expect(opened.found == [.spare(sevenOfCups, Rarity.prime.spare)])
        #expect(found.less(gone, in: .riviera).spares(of: sevenOfCups) == 1)
    }
}
