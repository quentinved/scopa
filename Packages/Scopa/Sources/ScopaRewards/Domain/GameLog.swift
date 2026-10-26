import Foundation

/// Every game finished on this phone: the last few hundred in full, and totals that have
/// counted every one of them since the log began.
///
/// The two halves are kept apart on purpose. The games are what the page lists; the totals
/// are what it is built on, so a head-to-head from three years ago is still in them long
/// after the games themselves have fallen off the end.
public struct GameLog: Hashable, Codable, Sendable {
    /// How many games are kept in full.
    public static let kept = 200

    /// Oldest first.
    public private(set) var games: [LoggedGame] = []
    public private(set) var totals: RecordTotals
    /// The last game written, beside the list: the list drops its oldest, this never forgets
    /// the one just written, which is the one a summary drawn twice brings back.
    public private(set) var lastGame: UUID?

    public init(totals: RecordTotals = RecordTotals()) {
        self.totals = totals
    }

    /// Writes a game down. False for one that is already in, which changes nothing.
    @discardableResult
    public mutating func add(_ game: LoggedGame) -> Bool {
        guard game.id != lastGame, !games.contains(where: { $0.id == game.id }) else { return false }
        lastGame = game.id
        totals.fold(game)
        games.append(game)
        if games.count > Self.kept { games.removeFirst(games.count - Self.kept) }
        return true
    }

    public func game(_ id: UUID) -> LoggedGame? {
        games.last { $0.id == id }
    }

    /// Nothing logged and nothing carried over from before.
    public var isEmpty: Bool { games.isEmpty && totals.all.played == 0 }

    // MARK: Rivals

    /// The people you have played most, either side of the table, most first; the latest
    /// meeting breaks a tie.
    public func rivals(limit: Int = 8) -> [Rivalry] {
        Array(totals.rivals.values.sorted(by: Self.mostMet).prefix(limit))
    }

    /// Where it stands with the person across the table you have played most, after `id`.
    /// Nil for a game with nobody real across it.
    public func standing(after id: UUID) -> Rivalry? {
        guard let game = game(id) else { return nil }
        return game.opponents
            .filter { !$0.isBot }
            .compactMap { totals.rivals[Rivalry.key(for: $0)] }
            .filter { $0.record.played > 0 }
            .min { Self.mostMet($0, $1) }
    }

    private static func mostMet(_ a: Rivalry, _ b: Rivalry) -> Bool {
        a.met != b.met ? a.met > b.met : a.lastPlayed > b.lastPlayed
    }
}
