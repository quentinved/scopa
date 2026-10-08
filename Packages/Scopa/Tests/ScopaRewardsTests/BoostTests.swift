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

    @Test func runsStack() async throws {
        let wallet = try await wallet(holding: Boost.price * 2)
        try await wallet.buyBoost()
        try await wallet.buyBoost()
        #expect(try await wallet.purse().boostedGamesLeft == Boost.games * 2)
    }
}
