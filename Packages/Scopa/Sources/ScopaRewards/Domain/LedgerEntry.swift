import Foundation

/// What an entry did to the purse.
public enum Reason: Hashable, Codable, Sendable {
    /// Denari came in off the table.
    case earned(Award)
    /// Denari went out on something in the shop. The item is named here and nowhere else,
    /// so what you own is a fact about the ledger rather than a second list beside it.
    case bought(ShopItem.ID)
    /// A welcome balance, a gift, or an adjustment. The string says who to blame.
    case granted(String)
    /// Denari put on the table before a wager game. Stored as a negative amount, and never
    /// given back: leaving the table mid-game forfeits it, which is the whole point.
    case staked(Stake)
    /// The pot, collected by the winner of a wager game.
    case wonStake(Stake)
}

/// One immutable line of the ledger.
///
/// The purse is kept as a list of these rather than as a running total, which is the single
/// decision in the whole design worth defending. A balance is a summary, and a summary of a
/// history you did not keep cannot be checked, explained, or merged. Keep the history and
/// the balance is free. Keep only the balance and the history is gone for good, including
/// on the day this has to be reconciled with a server.
public struct LedgerEntry: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let date: Date
    /// Signed: positive when earned, negative when spent.
    public let amount: Denari
    public let reason: Reason
    /// How the game was played, when the entry came from one.
    public let mode: TableMode?
    /// The same for every replay of the same event, and different for every other one.
    /// It is what makes crediting a game twice impossible after a crash, a reconnection or
    /// an upload the server has already seen.
    public let key: String

    public init(
        id: UUID = UUID(),
        date: Date,
        amount: Denari,
        reason: Reason,
        mode: TableMode? = nil,
        key: String
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.reason = reason
        self.mode = mode
        self.key = key
    }
}
