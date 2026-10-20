import Foundation
import Testing
@testable import ScopaRewards

@Suite struct DenariBags {
    @Test func everyBagHasItsOwnProduct() {
        let ids = DenariBag.allCases.map(\.productID)
        #expect(Set(ids).count == ids.count)
        for bag in DenariBag.allCases {
            #expect(DenariBag(productID: bag.productID) == bag)
        }
        #expect(DenariBag(productID: "com.quentinvedrenne.scopa.noads") == nil)
    }

    @Test func biggerBagsPayMore() {
        let amounts = DenariBag.allCases.map(\.denari)
        #expect(amounts == amounts.sorted())
    }

    @Test func aTransactionPaysOnce() async throws {
        let wallet = Wallet(store: MemoryLedgerStore())
        let paid = try await wallet.credit(.borsellino, transaction: 2_000_000_123)
        #expect(paid.map(\.amount) == [DenariBag.borsellino.denari])
        #expect(try await wallet.credit(.borsellino, transaction: 2_000_000_123).isEmpty)
        try await wallet.credit(.borsellino, transaction: 2_000_000_124)
        #expect(try await wallet.purse().balance == DenariBag.borsellino.denari * 2)
    }

    @Test func notSoldInBelgiumOrTheNetherlands() {
        #expect(!DenariBag.isSold(in: "BEL"))
        #expect(!DenariBag.isSold(in: "nld"))
        #expect(DenariBag.isSold(in: "FRA"))
        #expect(DenariBag.isSold(in: nil))
    }
}
