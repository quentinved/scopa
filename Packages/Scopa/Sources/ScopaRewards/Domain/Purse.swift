import Foundation

/// The ledger read as an answer: what you have, and what you own.
///
/// Everything here is folded from the entries and nothing is stored beside them, so the
/// balance and the shelf of owned items cannot drift apart from each other.
public struct Purse: Hashable, Sendable {
    /// Oldest first, the order they happened in.
    public let entries: [LedgerEntry]
    public let balance: Denari
    public let owned: Set<ShopItem.ID>

    public init(entries: [LedgerEntry] = []) {
        self.entries = entries
        var balance = Denari.zero
        var owned: Set<ShopItem.ID> = []
        for entry in entries {
            balance += entry.amount
            if case .bought(let item) = entry.reason { owned.insert(item) }
        }
        self.balance = balance
        self.owned = owned
    }

    public func owns(_ item: ShopItem) -> Bool { owned.contains(item.id) }
    public func owns(_ item: ShopItem.ID) -> Bool { owned.contains(item) }
    public func canAfford(_ item: ShopItem) -> Bool { balance >= item.price }

    /// Newest first, for a history screen.
    public var history: [LedgerEntry] { entries.reversed() }

    /// Every dedupe key already spent, so an entry is never applied twice.
    public var keys: Set<String> { Set(entries.map(\.key)) }

    /// When the last game was settled, whatever its outcome. This is what makes the
    /// first-game-of-the-day bonus a question the ledger answers rather than a date the app
    /// has to remember separately and keep in step.
    public var lastGameSettled: Date? {
        entries.last { entry in
            guard case .earned(let award) = entry.reason else { return false }
            return award.earning == .wonGame || award.earning == .lostGame
        }?.date
    }

    /// Whether a game finishing at `date` is the first of its day.
    public func isFirstGame(of date: Date, calendar: Calendar = .current) -> Bool {
        guard let last = lastGameSettled else { return true }
        return !calendar.isDate(last, inSameDayAs: date)
    }
}
