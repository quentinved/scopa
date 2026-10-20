import Foundation
import Observation
import os
import ScopaRewards
import StoreKit

/// Denari sold for money: the three bags' prices, the purchase, and the rule that makes a
/// consumable safe.
///
/// The denari go into the ledger before the App Store is told the purchase is done. A phone
/// that dies in between is handed the same purchase again on the next launch, and the
/// ledger's key on the transaction stops it paying twice. Nothing is restored: Apple keeps
/// no record of a consumable, so the account's purse is what carries them to other devices.
@MainActor
@Observable
final class DenariSale {
    /// What the App Store prices here. Empty until it answers, and for good in a storefront
    /// where denari are not sold.
    private(set) var products: [DenariBag: Product] = [:]
    private(set) var state: State = .idle
    /// The bag whose purchase sheet is up, so only its row waits.
    private(set) var buying: DenariBag?
    /// Bumped whenever a bag lands, for the sound and the haptic.
    private(set) var landed = 0
    /// A bag that landed with no purchase sheet up: an Ask to Buy approved, or one left open
    /// by the last launch. Said in a toast, since nothing on screen is waiting for it.
    private(set) var arrival: Arrival?

    enum State: Equatable {
        case idle, buying
        /// Waiting on someone else, such as a parent approving Ask to Buy.
        case pending
        /// The App Store refused or could not be reached; the player may try again.
        case failed
        /// Paid for, but the ledger could not be written. Comes back on the next launch.
        case notSaved
    }

    struct Arrival: Equatable {
        let bag: DenariBag
        let transaction: UInt64
    }

    /// What happened to one transaction handed over by the App Store.
    private enum Outcome { case paid, alreadyPaid, notSaved, ignored }

    var isOnSale: Bool {
        #if DEBUG
        if DebugLaunch.showsDenariSheet { return true }
        #endif
        return !products.isEmpty
    }

    // MARK: Listening

    /// Prices the bags, settles anything left open, then follows the App Store for the life
    /// of the app. Called once the purse has been read, since every path here writes to it.
    func watch(crediting purse: PurseStore) async {
        await loadProducts()
        for await result in Transaction.unfinished {
            await settleArrival(result, into: purse)
        }
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await result in Transaction.updates { await self.settleArrival(result, into: purse) }
            }
            group.addTask {
                for await _ in Storefront.updates { await self.loadProducts() }
            }
        }
    }

    /// Asks the App Store for the prices again. Called wherever they are shown, so a first
    /// answer from before the account settled never lasts past the next look.
    func loadProducts() async {
        guard DenariBag.isSold(in: await Storefront.current?.countryCode) else {
            products = [:]
            return
        }
        do {
            let found = try await Product.products(for: DenariBag.allCases.map(\.productID))
            products = Dictionary(found.compactMap { product in
                DenariBag(productID: product.id).map { ($0, product) }
            }, uniquingKeysWith: { first, _ in first })
        } catch {
            Log.shop.error("Denari bags did not load: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func settleArrival(_ result: VerificationResult<Transaction>, into purse: PurseStore) async {
        guard case .verified(let transaction) = result else { return }
        if await settle(transaction, into: purse) == .paid, let bag = DenariBag(productID: transaction.productID) {
            arrival = Arrival(bag: bag, transaction: transaction.id)
        }
    }

    /// Pays a transaction into the purse, then closes it. Left open when the purse could not
    /// be written, so the App Store hands it over again. A refund comes back as the same
    /// transaction, revoked: the denari have usually been spent by then and are not taken back.
    private func settle(_ transaction: Transaction, into purse: PurseStore) async -> Outcome {
        guard let bag = DenariBag(productID: transaction.productID) else { return .ignored }
        guard transaction.revocationDate == nil else {
            await transaction.finish()
            return .ignored
        }
        switch await purse.credit(bag, transaction: transaction.id) {
        case nil:
            return .notSaved
        case let fresh?:
            await transaction.finish()
            guard fresh else { return .alreadyPaid }
            landed += 1
            return .paid
        }
    }

    // MARK: Buying

    func buy(_ bag: DenariBag, into purse: PurseStore) async {
        guard state != .buying else { return }
        if products[bag] == nil { await loadProducts() }
        guard let product = products[bag] else { return }
        state = .buying
        buying = bag
        defer { buying = nil }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                state = await settle(transaction, into: purse) == .notSaved ? .notSaved : .idle
            case .success(.unverified):
                state = .failed
            case .pending:
                state = .pending
            case .userCancelled:
                state = .idle
            @unknown default:
                state = .idle
            }
        } catch {
            Log.shop.error("Denari purchase failed: \(error.localizedDescription, privacy: .public)")
            state = .failed
        }
    }
}
