import Foundation

/// Denari on top of what a game pays, from two places: the no-ads pass, which adds half
/// again to every game for good, and a run of doubled games bought in the shop for denari.
/// The pass also hands over `passGift` and a `passPack` once, and `passThanks` on top.
///
/// Both are paid off a game's own earnings, never off a level, a task or a campaign prize,
/// and both are entries in the ledger keyed on the game, so how many boosted games are left
/// is a fact the ledger answers like the balance.
public enum Boost {
    /// What a run of doubled games costs in the shop.
    public static let price: Denari = 250
    /// How many finished games one run doubles.
    public static let games = 10
    /// What the no-ads pass adds to every game, in percent of what it earned.
    public static let passPercent = 50
    /// The denari the no-ads pass hands over once, when it is bought.
    public static let passGift: Denari = 10_000
    /// The pack that comes with them, left waiting in the album.
    public static let passPack: PackTier = .reliquia

    public static let passNote = "pass"
    public static let note = "boost"
    /// Once per Apple account's ledger, whichever device saw the purchase first.
    static let passGiftKey = "pass/denari"
    /// The pass paid 2,000 under `passGiftKey` until 1.4. The rest is a line of its own, so
    /// an owner from before is topped up to the same gift rather than paid it twice.
    static let firstPassGift: Denari = 2_000
    static let passTopUpKey = "pass/denari/more"
    /// The 1.4 betas topped the gift up to 5,000 under `passTopUpKey`; it then grew to
    /// 10,000. The rest is a third line, so a tester already topped up is paid the difference.
    static let firstTopUp: Denari = 3_000
    static let passRaiseKey = "pass/denari/raise"
    public static let passPackKey = "pass/pack"
    /// 1.4's thank-you to everyone with the pass, whenever they bought it: a line of its own,
    /// so it is paid once per account on top of whatever the gift already paid.
    public static let passThanks: Denari = 2_000
    public static let passThanksKey = "pass/thanks"

    /// The pass's gift as one write: the denari, the pack's claim and the thank-you land
    /// together or not at all, and the ledger keeps only the lines it has not seen.
    public static func passGiftEntries(on date: Date = .now) -> [LedgerEntry] {
        [(passGiftKey, firstPassGift), (passTopUpKey, firstTopUp),
         (passRaiseKey, passGift - firstPassGift - firstTopUp), (passPackKey, .zero), (passThanksKey, passThanks)]
            .map { LedgerEntry(date: date, amount: $0.1, reason: .granted(passNote), key: $0.0) }
    }

    static let purchasePrefix = "boost.buy/"
    static let gamePrefix = "boost.game/"

    /// A purchase is its own event, so each one is keyed afresh.
    static func purchaseKey() -> String { purchasePrefix + UUID().uuidString }
    static func gameKey(_ gameID: UUID) -> String { gamePrefix + gameID.uuidString }
    static func passKey(_ gameID: UUID) -> String { "pass.game/\(gameID.uuidString)" }

    /// Half again, rounded up so a game that paid anything pays at least one more.
    public static func passBonus(on earned: Denari) -> Denari {
        Denari((earned.coins * passPercent + 99) / 100)
    }
}

extension Purse {
    /// Doubled games bought and not yet played out.
    public var boostedGamesLeft: Int {
        let bought = keys.filter { $0.hasPrefix(Boost.purchasePrefix) }.count
        let used = keys.filter { $0.hasPrefix(Boost.gamePrefix) }.count
        return max(0, bought * Boost.games - used)
    }

    public var canAffordBoost: Bool { balance >= Boost.price }

    /// The pass's gift is in the ledger, so a device of this account once saw it bought.
    public var hasHadPass: Bool {
        keys.contains(Boost.passGiftKey) || keys.contains(Boost.passTopUpKey)
    }
}
