import Foundation
import Observation
import os
import StoreKit

/// The one thing Scopa sells for money: a table with no interruptions.
///
/// A non-consumable, so it is bought once, belongs to the Apple account and comes back on
/// every device signed in to it. It takes away the banner and the full screen ad; the
/// opt-in video stays, since it is only ever asked for. Since 2026-10-08 it also pays
/// `Boost.passGift` once and half again on every game (`Boost.passPercent`), at the owner's
/// request, so denari now come with real money: see `Boost` before turning stakes back on.
@MainActor
@Observable
final class AdFreePass {
    static let productID = "com.quentinvedrenne.scopa.noads"

    /// Owned, as far as this device knows. Read from the disk at launch so the banner does
    /// not flash on before StoreKit answers, then corrected by it.
    private(set) var isOwned: Bool

    /// The product as the App Store prices it here, once it has answered.
    private(set) var product: Product?

    private(set) var state: State = .idle

    enum State: Equatable {
        case idle, buying, restoring
        /// Waiting on someone else, such as a parent approving Ask to Buy.
        case pending
        /// The App Store refused or could not be reached; the player may try again.
        case failed
        /// A restore found no purchase on this Apple account.
        case nothingToRestore
    }

    private static let ownedKey = "adFree.owned"

    init() {
        #if DEBUG
        // `-adFree` plays as though it had been bought, writing nothing down.
        if DebugLaunch.ownsAdFree {
            isOwned = true
            return
        }
        #endif
        isOwned = UserDefaults.standard.bool(forKey: Self.ownedKey)
    }

    // MARK: Listening

    /// Loads the price, settles what is owned, then follows the App Store for the life of
    /// the app: an approved Ask to Buy, a purchase on another device, a refund.
    func watch() async {
        await loadProduct()
        await refresh()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.followTransactions() }
            group.addTask { await self.followStorePromotions() }
            group.addTask { await self.followStorefront() }
        }
    }

    /// The account's country can settle after launch: a first answer given before it has
    /// is priced in dollars. Priced again whenever the storefront changes.
    private func followStorefront() async {
        for await storefront in Storefront.updates {
            Log.ads.info("Storefront is now \(storefront.countryCode, privacy: .public)")
            await loadProduct()
        }
    }

    /// Only its own: a bag of denari must stay open until `DenariSale` has paid it.
    private func followTransactions() async {
        for await update in Transaction.updates {
            // Unsigned too, as `entitlement()` believes it: an approved Ask to Buy skipped here
            // left a paying player with ads until the next launch.
            let transaction = update.unsafePayloadValue
            guard transaction.productID == Self.productID else { continue }
            await transaction.finish()
            await refresh()
        }
    }

    /// A purchase begun on the App Store page, where the promotional image offers it.
    /// StoreKit hands it over once the app is open, and it goes through the usual sheet.
    private func followStorePromotions() async {
        for await intent in PurchaseIntent.intents where intent.product.id == Self.productID {
            product = intent.product
            await buy()
        }
    }

    /// Asks StoreKit for the price again. Called wherever the price is shown, so a stale
    /// first answer never lasts past the next look.
    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            Log.ads.error("No-ads product did not load: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Reads what StoreKit holds on the device, which also works offline.
    ///
    /// Only a refund takes the pass away. StoreKit's answer can come back empty or unsigned
    /// on a reinstall, a new phone, a phone offline or with its clock wrong, and until 1.4 an
    /// empty answer was taken for "not bought": players who had paid got their ads back.
    private func refresh() async {
        #if DEBUG
        if DebugLaunch.ownsAdFree { return }
        #endif
        switch await entitlement() {
        case .owned: setOwned(true)
        case .refunded: setOwned(false)
        case .unknown: setOwned(isOwned || ledgerSaysOwned)
        }
    }

    private enum Entitlement { case owned, refunded, unknown }

    /// What StoreKit says of the purchase. An unsigned answer is believed: the price of being
    /// wrong is a free table for somebody, and the price of the other mistake is ads for a
    /// player who paid to be rid of them.
    private func entitlement() async -> Entitlement {
        for await result in Transaction.currentEntitlements {
            let transaction = result.unsafePayloadValue
            guard transaction.productID == Self.productID, transaction.revocationDate == nil else { continue }
            if case .unverified(_, let error) = result {
                Log.ads.error("No-ads entitlement is unsigned, kept anyway: \(error.localizedDescription, privacy: .public)")
            }
            return .owned
        }
        guard let latest = await Transaction.latest(for: Self.productID) else { return .unknown }
        return latest.unsafePayloadValue.revocationDate == nil ? .owned : .refunded
    }

    /// The account's word for it: the pass's gift is in the ledger, which follows the player
    /// from device to device and is only ever paid once a device saw the purchase. Enough to
    /// keep a paying player's table quiet while StoreKit has nothing to say; a refund StoreKit
    /// does know of still wins.
    private var ledgerSaysOwned = false

    /// Told once the purse is read, and again whenever the account brings a gift in.
    func believeLedger(_ paid: Bool) async {
        guard paid, !ledgerSaysOwned else { return }
        ledgerSaysOwned = true
        await refresh()
    }

    private func setOwned(_ owned: Bool) {
        if owned != isOwned { Log.ads.info("No-ads pass is now \(owned ? "owned" : "not owned", privacy: .public)") }
        isOwned = owned
        UserDefaults.standard.set(owned, forKey: Self.ownedKey)
    }

    // MARK: Buying

    func buy() async {
        // Claimed before the load, so a second tap while it runs cannot open a second sheet.
        guard state != .buying else { return }
        state = .buying
        if product == nil { await loadProduct() }
        guard let product else {
            state = .idle
            return
        }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                setOwned(true)
                state = .idle
            case .success(.unverified(let transaction, let error)):
                // Paid for, by StoreKit's own word; the signature is not the player's problem.
                Log.ads.error("No-ads purchase is unsigned, kept anyway: \(error.localizedDescription, privacy: .public)")
                await transaction.finish()
                setOwned(true)
                state = .idle
            case .pending:
                state = .pending
            case .userCancelled:
                state = .idle
            @unknown default:
                state = .idle
            }
        } catch {
            Log.ads.error("No-ads purchase failed: \(error.localizedDescription, privacy: .public)")
            state = .failed
        }
        // The purchase sheet has settled the account by now, so the price shown is too.
        await loadProduct()
    }

    /// Asks the App Store for the account's purchases again. Only needed after a reinstall
    /// that somehow lost them, but the App Store requires it to be offered.
    func restore() async {
        guard state != .restoring else { return }
        state = .restoring
        do {
            try await AppStore.sync()
            await refresh()
            state = isOwned ? .idle : .nothingToRestore
        } catch StoreKitError.userCancelled {
            state = .idle
        } catch {
            await refresh()
            state = isOwned ? .idle : .failed
        }
    }
}
