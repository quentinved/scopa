import Foundation
import Testing
@testable import ScopaRewards

private func wallet(holding amount: Denari) async throws -> Wallet {
    let wallet = Wallet(store: MemoryLedgerStore())
    try await wallet.grant(amount, note: "test", key: "test/start")
    return wallet
}

@Suite struct Boosting {
    @Test func thePassAddsHalfAgainRoundedUp() {
        #expect(Boost.passBonus(on: 40) == 20)
        #expect(Boost.passBonus(on: 25) == 13)
        #expect(Boost.passBonus(on: 1) == 1)
    }

    /// The ledger remembers a purchase for the app to fall back on, and only once its gift
    /// was paid: a purse with denari of its own proves nothing.
    @Test func theLedgerRemembersThePass() async throws {
        let wallet = try await wallet(holding: 300)
        #expect(try await wallet.purse().hasHadPass == false)
        try await wallet.credit(Boost.passGiftEntries())
        #expect(try await wallet.purse().hasHadPass)
    }

    /// A 1.4 beta tester was topped up to 5,000; the gift grew to 10,000 after, and the
    /// difference reaches them without paying anything twice.
    @Test func aTesterToppedUpBeforeTheRaiseGetsTheDifference() async throws {
        let wallet = Wallet(store: MemoryLedgerStore())
        try await wallet.grant(Boost.firstPassGift, note: Boost.passNote, key: Boost.passGiftKey)
        try await wallet.grant(Boost.firstTopUp, note: Boost.passNote, key: Boost.passTopUpKey)
        try await wallet.credit(Boost.passGiftEntries())
        #expect(try await wallet.purse().balance == Boost.passGift + Boost.passThanks)
        #expect(Boost.passGift == 10_000)
    }

    @Test func aRunDoublesItsGamesAndThenStops() async throws {
        let wallet = try await wallet(holding: Boost.price)
        try await wallet.buyBoost()
        #expect(try await wallet.purse().balance == .zero)
        for _ in 0..<Boost.games {
            let paid = try await wallet.boost(30, gameID: UUID(), withPass: false)
            #expect(paid.map(\.amount) == [30])
        }
        #expect(try await wallet.purse().boostedGamesLeft == 0)
        #expect(try await wallet.boost(30, gameID: UUID(), withPass: false).isEmpty)
    }

    @Test func aGameSettledTwicePaysAndUsesOnce() async throws {
        let wallet = try await wallet(holding: Boost.price)
        try await wallet.buyBoost()
        let game = UUID()
        _ = try await wallet.boost(30, gameID: game, withPass: true)
        let again = try await wallet.boost(30, gameID: game, withPass: true)
        #expect(again.isEmpty)
        #expect(try await wallet.purse().boostedGamesLeft == Boost.games - 1)
    }

    @Test func thePassAndARunStack() async throws {
        let wallet = try await wallet(holding: Boost.price)
        try await wallet.buyBoost()
        let paid = try await wallet.boost(40, gameID: UUID(), withPass: true)
        #expect(paid.map(\.amount) == [20, 40])
    }

    @Test func aShortPurseCannotBuyARun() async throws {
        let wallet = try await wallet(holding: 100)
        await #expect(throws: PurchaseError.tooDear(short: Boost.price - 100)) { try await wallet.buyBoost() }
    }

    @Test func thePassGiftPaysOnce() async throws {
        let wallet = Wallet(store: MemoryLedgerStore())
        let fresh = try await wallet.credit(Boost.passGiftEntries())
        #expect(fresh.reduce(Denari.zero) { $0 + $1.amount } == Boost.passGift + Boost.passThanks)
        #expect(fresh.contains { $0.key == Boost.passPackKey })
        #expect(fresh.contains { $0.key == Boost.passThanksKey })
        #expect(try await wallet.credit(Boost.passGiftEntries()).isEmpty)
    }

    @Test func anOwnerFromBeforeIsToppedUp() async throws {
        let wallet = Wallet(store: MemoryLedgerStore())
        try await wallet.grant(Boost.firstPassGift, note: Boost.passNote, key: Boost.passGiftKey)
        try await wallet.credit(Boost.passGiftEntries())
        #expect(try await wallet.purse().balance == Boost.passGift + Boost.passThanks)
    }

    /// An owner already paid the whole gift, by an early 1.4 build, is handed the thank-you
    /// alone, and only once.
    @Test func everyOwnerIsThankedOnce() async throws {
        let wallet = Wallet(store: MemoryLedgerStore())
        try await wallet.credit(Boost.passGiftEntries().filter { $0.key != Boost.passThanksKey })
        let fresh = try await wallet.credit(Boost.passGiftEntries())
        #expect(fresh.map(\.key) == [Boost.passThanksKey])
        #expect(fresh.map(\.amount) == [Boost.passThanks])
        #expect(try await wallet.credit(Boost.passGiftEntries()).isEmpty)
        #expect(try await wallet.purse().balance == Boost.passGift + Boost.passThanks)
    }

    /// The other phone's ledger arriving with the thank-you in it pays nothing more here.
    @Test func theThankYouFromAnotherDeviceIsNotPaidAgain() async throws {
        let wallet = Wallet(store: MemoryLedgerStore())
        try await wallet.credit(Boost.passGiftEntries())
        let elsewhere = Boost.passGiftEntries(on: .now.addingTimeInterval(3_600))
        #expect(try await wallet.credit(elsewhere).isEmpty)
        #expect(try await wallet.purse().balance == Boost.passGift + Boost.passThanks)
    }

    @Test func runsStack() async throws {
        let wallet = try await wallet(holding: Boost.price * 2)
        try await wallet.buyBoost()
        try await wallet.buyBoost()
        #expect(try await wallet.purse().boostedGamesLeft == Boost.games * 2)
    }
}
