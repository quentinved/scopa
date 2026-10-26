import Foundation

/// Won and lost, which is all a share needs.
public struct WonLost: Hashable, Codable, Sendable {
    public var won: Int
    public var lost: Int

    public init(won: Int = 0, lost: Int = 0) {
        self.won = won
        self.lost = lost
    }

    public var played: Int { won + lost }
    /// Out of a hundred, rounded. Nil before the first game, where nought would be unkind.
    public var percentWon: Int? { played > 0 ? Int((Double(won) / Double(played) * 100).rounded()) : nil }

    mutating func count(_ won: Bool) {
        if won { self.won += 1 } else { lost += 1 }
    }
}

/// Somebody you have sat down with, and how it has gone between you.
public struct Rivalry: Hashable, Codable, Sendable, Identifiable {
    /// "id:…" where the table gave them a stable id, "name:…" on a phone passed round.
    public let id: String
    /// As they last called themselves.
    public var name: String
    /// Across the table only. A game neither of you won, level on points, is in neither.
    public var record: WonLost
    /// Games on the same side.
    public var partnered: Int
    public var lastPlayed: Date
    /// How the last game across the table went, and when. Nil until there has been one.
    public var lastWon: Bool?
    public var lastFaced: Date?

    public var met: Int { record.played + partnered }

    static func key(for seat: LoggedGame.Seat) -> String {
        if let id = seat.playerID { return "id:" + id }
        return "name:" + seat.name.trimmingCharacters(in: .whitespaces).lowercased()
    }
}

/// A keepsake: how far it went, when, and against whom.
public struct Best: Hashable, Codable, Sendable {
    public var value: Int
    public var date: Date
    /// The best of the other side's names, for "against Laurence".
    public var against: String?
    /// Your points and theirs, where the score is the point.
    public var score: [Int]?
}

/// Everything the record adds up to, folded in one game at a time so it never shrinks when
/// the oldest games fall out of the log.
public struct RecordTotals: Hashable, Codable, Sendable {
    /// What was counted before the log existed: wins and losses with no game behind them.
    public var before: WonLost
    /// Scope, settebelli and clean sweeps from the same counters, for the same reason.
    public var scopeBefore: Int
    public var settebelliBefore: Int
    public var cappottiBefore: Int

    /// The logged games, all of them and by group.
    public var logged = WonLost()
    public var groups: [LoggedGame.Group: WonLost] = [:]
    public var scope = 0
    public var settebelli = 0
    public var cappotti = 0
    public var primiere = 0
    public var since: Date?

    public var biggestWin: Best?
    public var mostScope: Best?
    /// Wins in a row: the one going now, and the longest there has been.
    public var run = 0
    public var longestRun: Best?

    public var rivals: [String: Rivalry] = [:]
    /// By the bot's name, across the table.
    public var bots: [String: WonLost] = [:]

    public init(before: WonLost = WonLost(), scope: Int = 0, settebelli: Int = 0, cappotti: Int = 0) {
        self.before = before
        scopeBefore = scope
        settebelliBefore = settebelli
        cappottiBefore = cappotti
    }

    /// Every game this phone knows of, logged or not.
    public var all: WonLost { WonLost(won: before.won + logged.won, lost: before.lost + logged.lost) }
    public var allScope: Int { scopeBefore + scope }
    public var allSettebelli: Int { settebelliBefore + settebelli }
    public var allCappotti: Int { cappottiBefore + cappotti }

    mutating func fold(_ game: LoggedGame) {
        logged.count(game.won)
        groups[game.group, default: WonLost()].count(game.won)
        scope += game.scope
        settebelli += game.settebelli
        cappotti += game.cappotti
        primiere += game.primiere ?? 0
        since = min(since ?? game.date, game.date)
        foldBests(game)
        for seat in game.seats where !seat.isYou { meet(seat, in: game) }
    }

    private mutating func foldBests(_ game: LoggedGame) {
        let against = game.opponents.max { (game.scores[safe: $0.side] ?? 0) < (game.scores[safe: $1.side] ?? 0) }?.name
        if game.won, game.margin > (biggestWin?.value ?? 0) {
            biggestWin = Best(value: game.margin, date: game.date, against: against, score: [game.mine, game.theirs])
        }
        if game.scope > (mostScope?.value ?? 0) {
            mostScope = Best(value: game.scope, date: game.date, against: against)
        }
        run = game.won ? run + 1 : 0
        if run > (longestRun?.value ?? 0) { longestRun = Best(value: run, date: game.date) }
    }

    private mutating func meet(_ seat: LoggedGame.Seat, in game: LoggedGame) {
        let result = game.result(against: seat)
        if seat.isBot {
            if let result { bots[seat.name, default: WonLost()].count(result) }
            return
        }
        let key = Rivalry.key(for: seat)
        var rival = rivals[key] ?? Rivalry(id: key, name: seat.name, record: WonLost(), partnered: 0,
                                           lastPlayed: game.date)
        rival.name = seat.name
        rival.lastPlayed = max(rival.lastPlayed, game.date)
        if seat.side == game.yourSide {
            rival.partnered += 1
        } else if let result {
            rival.record.count(result)
            rival.lastWon = result
            rival.lastFaced = game.date
        }
        rivals[key] = rival
    }
}
