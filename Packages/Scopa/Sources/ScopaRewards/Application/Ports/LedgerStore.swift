import Foundation

/// Where the ledger is kept.
///
/// Deliberately `async` even though today's answer comes off a local disk instantly. The
/// second implementation is a server, and the difference between an interface that can wait
/// and one that cannot is every call site in the app.
public protocol LedgerStore: Sendable {
    /// Everything on record, oldest first.
    func load() async throws -> [LedgerEntry]

    /// Adds entries to the end. The caller has already dropped anything with a key that is
    /// on record, so a store never has to think about duplicates itself.
    func append(_ entries: [LedgerEntry]) async throws
}

/// A ledger that lives only as long as the process. For tests and previews.
public actor MemoryLedgerStore: LedgerStore {
    private var entries: [LedgerEntry]

    public init(_ entries: [LedgerEntry] = []) {
        self.entries = entries
    }

    public func load() async throws -> [LedgerEntry] { entries }

    public func append(_ new: [LedgerEntry]) async throws { entries += new }
}
