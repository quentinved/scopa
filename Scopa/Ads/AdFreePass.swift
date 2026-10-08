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

    private func followTransactions() async {
        for await update in Transaction.updates {
            guard case .verified(let transaction) = update else { continue }
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

    /// Reads the entitlement StoreKit holds on the device, which also works offline.
    private func refresh() async {
        var owned = false
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement,
                  transaction.productID == Self.productID,
                  transaction.revocationDate == nil else { continue }
            owned = true
        }
        #if DEBUG
        if DebugLaunch.ownsAdFree { return }
        #endif
        setOwned(owned)
    }

    private func setOwned(_ owned: Bool) {
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
