import Foundation
import SwiftUI
import ScopaGameCenter
import ScopaRewards

/// A code the house hands out, worth a reward to every player who types it, once each. See
/// `Server/src/coupons.ts`, and `Tools/coupons.sh` for making one.
///
/// Signed with Game Center like a friend code, so the Worker can hold a player to one use
/// whichever device they type it on.
enum Coupon {
    /// What a coupon is worth. Any of the three may be empty, never all of them.
    struct Reward: Decodable, Equatable {
        let code: String
        let denari: Denari
        private let packs: [String]
        private let items: [String]

        /// A tier this build does not know is dropped rather than failing the reward.
        var tiers: [PackTier] { packs.compactMap(PackTier.init(rawValue:)) }

        /// Only what a pack could turn up. Something earned — a streak's felt, an album's
        /// prize — is never handed over by a code, whatever the code says.
        var shopItems: [ShopItem] {
            let catalogue = Cosmetics.catalogue
            return items.compactMap { catalogue[ShopItem.ID($0)] }.filter(Cosmetics.isInPacks)
        }

        /// Its name in the ledger, which is what stops it paying twice.
        var key: String { "coupon/\(code)" }
    }

    enum Outcome: Equatable {
        case reward(Reward)
        /// Taken before. The reward rides along when it was this device that took it, since
        /// the first answer may never have arrived.
        case alreadyRedeemed(Reward?)
        case expired
        case usedUp
        case unknown
        case notSignedIn
        case offline
        case unreachable
    }

    static func redeem(_ code: String) async -> Outcome {
        guard let baseURL = Ladder.baseURL else { return .unreachable }
        guard GameCenter.isSignedIn else { return .notSignedIn }
        do {
            let request = try await request(code, to: baseURL.appending(path: "v1/coupons/redeem"))
            let (data, response) = try await URLSession.shared.data(for: request)
            return outcome(of: data, status: (response as? HTTPURLResponse)?.statusCode ?? 0)
        } catch is URLError {
            return .offline
        } catch {
            return .unreachable
        }
    }

    private static func request(_ code: String, to url: URL) async throws -> URLRequest {
        struct Post: Encodable {
            let code: String
            let device: String
            let identity: GameCenterIdentity
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        let post = Post(code: code, device: Device.id, identity: try await GameCenter.identity())
        request.httpBody = try JSONEncoder().encode(post)
        return request
    }

    private static func outcome(of data: Data, status: Int) -> Outcome {
        struct Refusal: Decodable { let error: String? }
        let reward = try? JSONDecoder().decode(Reward.self, from: data)
        switch status {
        case 200: return reward.map(Outcome.reward) ?? .unreachable
        case 409: return .alreadyRedeemed(reward)
        case 410:
            let refusal = try? JSONDecoder().decode(Refusal.self, from: data)
            return refusal?.error == "used up" ? .usedUp : .expired
        case 400, 404: return .unknown
        default: return .unreachable
        }
    }
}

/// The shop's one field for a code: a coupon first, then, if there is no such coupon, a
/// friend's code. Pays whatever is owed and says what arrived, or why nothing did.
@MainActor
enum PromoCode {
    /// What arrived, for the panel to show.
    struct Receipt: Equatable {
        var denari: Denari
        var tiers: [PackTier]
        var items: [ShopItem]
        /// Whose code it was, when it was a friend's.
        var friend: String?
    }

    enum Answer: Equatable {
        case received(Receipt)
        case refused(LocalizedStringKey)
    }

    static func use(_ code: String, purse: PurseStore, book: AlbumBook) async -> Answer {
        if Passphrase.opensShop(code) { return await openShop(purse: purse) }
        switch await Coupon.redeem(code) {
        case .reward(let reward), .alreadyRedeemed(let reward?): return await pay(reward, purse: purse, book: book)
        case .alreadyRedeemed(nil): return .refused("You have already used this code.")
        case .expired: return .refused("This code has expired.")
        case .usedUp: return .refused("This code has run out.")
        case .notSignedIn: return .refused("Sign in to Game Center first, so your code counts once.")
        case .offline: return .refused("You seem to be offline. Try again once you are connected.")
        case .unreachable: return .refused("The code could not be checked. Try again in a moment.")
        case .unknown: return await useFriendCode(code, purse: purse, book: book)
        }
    }

    /// The shop's phrase: checked on the phone, so it works offline and signed out.
    private static func openShop(purse: PurseStore) async -> Answer {
        guard let items = await purse.unlockShop() else {
            return .refused("The shop could not be opened on this device.")
        }
        guard !items.isEmpty else { return .refused("You already own everything in the shop.") }
        return .received(Receipt(denari: .zero, tiers: [], items: items))
    }

    /// The purse decides whether this is news: a coupon it has already paid, on this device or
    /// another, is refused here rather than paid again. The packs follow only a fresh payment,
    /// because the album keeps no keys of its own.
    private static func pay(_ reward: Coupon.Reward, purse: PurseStore, book: AlbumBook) async -> Answer {
        switch await purse.redeem(reward) {
        case true?:
            reward.tiers.forEach(book.give)
            return .received(Receipt(denari: reward.denari, tiers: reward.tiers, items: reward.shopItems))
        case false?: return .refused("You have already used this code.")
        case nil: return .refused("Your coupon could not be saved. Try the code again.")
        }
    }

    /// Paid the way the settings' panel pays one, and remembered the same way, so that panel
    /// thanks the friend rather than asking for a code again.
    private static func useFriendCode(_ code: String, purse: PurseStore, book: AlbumBook) async -> Answer {
        switch await FriendCode.redeem(code) {
        case .gift(let gift):
            FriendCode.usedOwner = gift.owner
            guard gift.fresh else { return .refused("You have already used this code.") }
            if let tier = gift.tier { book.give(tier) }
            await purse.awardFriendCode(gift.denari)
            return .received(Receipt(denari: gift.denari, tiers: gift.tier.map { [$0] } ?? [], items: [],
                                     friend: gift.owner))
        case .usedAnother(let owner):
            FriendCode.usedOwner = owner
            return .refused("You have already used a friend's code. There is one per player.")
        case .unknown: return .refused("No code by that name.")
        case .notSignedIn: return .refused("Sign in to Game Center first, so your code counts once.")
        case .unreachable: return .refused("The code could not be checked. Try again in a moment.")
        }
    }
}
