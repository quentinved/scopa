import Foundation

/// Denari on top of what a game pays, from two places: the no-ads pass, which adds half
/// again to every game for good, and a run of doubled games bought in the shop for denari.
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
    public static let passGift: Denari = 2_000

    public static let passNote = "pass"
    public static let note = "boost"
    /// Once per Apple account's ledger, whichever device saw the purchase first.
    public static let passGiftKey = "pass/denari"

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
}
