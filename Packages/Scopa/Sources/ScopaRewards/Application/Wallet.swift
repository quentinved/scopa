import Foundation

public enum PurchaseError: Error, Hashable, Sendable {
    case alreadyOwned
    /// How much more was needed.
    case tooDear(short: Denari)
}

/// The only thing allowed to write to the ledger.
///
/// Every path in is guarded by a dedupe key, so double-tapping a buy button, replaying a
/// finished game, or re-applying a batch a server has already recorded are all no-ops
/// rather than money.
public actor Wallet {
    private let store: any LedgerStore
    private var current = Purse()
    private var isLoaded = false

    public init(store: any LedgerStore) {
        self.store = store
    }

    /// What is in the purse, reading the ledger first if it has not been read yet.
    ///
    /// It is a function rather than a property so that there is no way to ask before the
    /// answer exists: a stored `purse` would hand out an empty one to whoever asked first
    /// after launch.
    public func purse() async throws -> Purse {
        try await loadIfNeeded()
        return current
    }

    /// Re-reads the ledger from the store, whether or not it has been read before.
    @discardableResult
    public func reload() async throws -> Purse {
        current = Purse(entries: try await store.load())
        isLoaded = true
        return current
    }

    /// Adds whatever the purse has not seen before. Returns only the entries that actually
    /// landed, which is exactly what an end-of-game screen should be counting up.
    @discardableResult
    public func credit(_ entries: [LedgerEntry]) async throws -> [LedgerEntry] {
        try await loadIfNeeded()
        var seen = current.keys
        let fresh = entries.filter { seen.insert($0.key).inserted }
        guard !fresh.isEmpty else { return [] }
        try await store.append(fresh)
        current = Purse(entries: current.entries + fresh)
        return fresh
    }

    /// Pays out a finished game. Whether it is the first of the day is read off the ledger
    /// rather than asked of the caller, so there is no second date to keep in step.
    @discardableResult
    public func settle(_ tally: RewardTally, on date: Date = .now) async throws -> [LedgerEntry] {
        try await loadIfNeeded()
        guard tally.isSettled else { return [] }
        return try await credit(tally.entries(on: date, firstOfDay: current.isFirstGame(of: date)))
    }

    @discardableResult
    public func buy(_ item: ShopItem, on date: Date = .now) async throws -> Purse {
        try await loadIfNeeded()
        guard !current.owns(item) else { throw PurchaseError.alreadyOwned }
        guard current.canAfford(item) else { throw PurchaseError.tooDear(short: item.price - current.balance) }

        // Owning something twice is meaningless, which makes the item its own dedupe key.
        try await credit([
            LedgerEntry(date: date, amount: -item.price, reason: .bought(item.id), key: "buy/\(item.id.rawValue)")
        ])
        return current
    }

    /// Hands an item over for nothing, once.
    ///
    /// For anything a player was already using before it had a price. Recording it as a
    /// purchase at zero keeps ownership a fact about the ledger rather than a second list.
    @discardableResult
    public func grandfather(_ item: ShopItem, on date: Date = .now) async throws -> Purse {
        try await loadIfNeeded()
        guard !current.owns(item) else { return current }
        try await credit([
            LedgerEntry(date: date, amount: .zero, reason: .bought(item.id),
                        key: "grandfather/\(item.id.rawValue)")
        ])
        return current
    }

    /// Hands one item over for nothing, keyed so the same reason never hands it over twice.
    /// A streak kept, a milestone passed: earned rather than bought, and the key says which.
    @discardableResult
    public func unlock(_ item: ShopItem, key: String, on date: Date = .now) async throws -> Purse {
        try await loadIfNeeded()
        guard !current.owns(item) else { return current }
        try await credit([LedgerEntry(date: date, amount: .zero, reason: .bought(item.id), key: key)])
        return current
    }

    /// Hands the whole catalogue over for nothing, once.
    ///
    /// Recorded as ordinary purchases at zero, each tagged with `note`, so the ledger still
    /// says why a thing is owned. A server will want to tell a gift from a purchase.
    @discardableResult
    public func unlockEverything(in catalogue: Catalogue, note: String, on date: Date = .now) async throws -> Purse {
        try await loadIfNeeded()
        let entries = catalogue.items
            .filter { !current.owns($0) }
            .map { LedgerEntry(date: date, amount: .zero, reason: .bought($0.id), key: "\(note)/\($0.id.rawValue)") }
        guard !entries.isEmpty else { return current }
        try await credit(entries)
        return current
    }

    /// Puts a stake on the table for one game. Refused when the purse is short, and a
    /// no-op when this game's stake is already down.
    @discardableResult
    public func stake(_ stake: Stake, gameID: UUID, on date: Date = .now) async throws -> Purse {
        try await loadIfNeeded()
        let key = "stake/\(gameID.uuidString)"
        guard !current.keys.contains(key) else { return current }
        guard current.balance >= stake.amount else { throw WagerError.short(stake.amount - current.balance) }
        try await credit([LedgerEntry(date: date, amount: -stake.amount, reason: .staked(stake), key: key)])
        return current
    }

    /// Puts a stake back where it came from, for a table that never opened.
    ///
    /// Only for a game whose stake is on record and was never paid out, and only once. A
    /// refund is money, so it is keyed like every other credit here.
    @discardableResult
    public func refund(_ stake: Stake, gameID: UUID, on date: Date = .now) async throws -> [LedgerEntry] {
        try await loadIfNeeded()
        guard current.keys.contains("stake/\(gameID.uuidString)"),
              !current.keys.contains("payout/\(gameID.uuidString)") else { return [] }
        return try await credit([
            LedgerEntry(date: date, amount: stake.amount, reason: .granted("refund"), key: "refund/\(gameID.uuidString)")
        ])
    }

    /// Hands the pot to the winner. Only for a game whose stake is on record, and only
    /// once, so a summary shown twice pays nothing the second time.
    @discardableResult
    public func payOut(_ stake: Stake, players: Int = 2, gameID: UUID, on date: Date = .now) async throws -> [LedgerEntry] {
        try await loadIfNeeded()
        guard current.keys.contains("stake/\(gameID.uuidString)") else { return [] }
        return try await credit([
            LedgerEntry(date: date, amount: stake.payout(players: players), reason: .wonStake(stake), key: "payout/\(gameID.uuidString)")
        ])
    }

    /// A gift or an adjustment: a welcome balance, an apology, something a server hands out.
    /// `key` is what stops it being handed out twice.
    @discardableResult
    public func grant(_ amount: Denari, note: String, key: String, on date: Date = .now) async throws -> [LedgerEntry] {
        try await credit([LedgerEntry(date: date, amount: amount, reason: .granted(note), key: key)])
    }

    private func loadIfNeeded() async throws {
        guard !isLoaded else { return }
        try await reload()
    }
}
