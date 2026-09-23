import Foundation
import ScopaCore

/// Watches one game go by and works out what it paid.
///
/// It reads the same `GameEvent`s the screens already receive, so nothing in the rules had
/// to learn that money exists. A guest earns from its own copy of the events exactly as the
/// host does, without a coin crossing the wire.
/// `Codable` so a game put down halfway can pick its tally back up: the scope already
/// swept would otherwise go unpaid when the game is finished after a relaunch.
public struct RewardTally: Hashable, Codable, Sendable {
    public enum Outcome: Hashable, Codable, Sendable { case won, lost }

    /// Names this game in the ledger, and with it every dedupe key the game produces.
    public let gameID: UUID
    /// The scoring side being paid. On a hot seat table one device plays every seat, so the
    /// app picks the seat whose phone it is and lets it lose like anybody else.
    public let side: Int
    public let mode: TableMode

    private let configuration: GameConfiguration
    private(set) public var scope = 0
    private(set) public var settebelli = 0
    private(set) public var cappotti = 0
    private(set) public var outcome: Outcome?

    public init(gameID: UUID = UUID(), side: Int, configuration: GameConfiguration, mode: TableMode) {
        self.gameID = gameID
        self.side = side
        self.configuration = configuration
        self.mode = mode
    }

    public mutating func observe(_ events: [GameEvent]) {
        for event in events { observe(event) }
    }

    public mutating func observe(_ event: GameEvent) {
        switch event {
        case .scopa(let seat):
            if configuration.side(ofSeat: seat) == side { scope += 1 }

        case .roundEnded(let score):
            // Won outright, on purpose: a table that pays both sides for a category they
            // ended level on is a house rule between friends, and a cappotto shared with
            // the other side is not one. What it pays out stays what the rulebook pays for.
            let mine = ScoreCategory.allCases.filter { (score.categoryWinners[$0] ?? nil) == side }
            if mine.contains(.settebello) { settebelli += 1 }
            if mine.count == ScoreCategory.allCases.count { cappotti += 1 }
            // A daily deal is one round, so its end is the game's end. More points than the
            // bot wins it; level is a loss, which is the same rule the ladder ranks by.
            if mode.isDailyDeal {
                let theirs = score.points.enumerated().filter { $0.offset != side }.map(\.element).max() ?? 0
                outcome = score.points[side] > theirs ? .won : .lost
            }

        case .gameEnded(let winner):
            outcome = winner == side ? .won : .lost

        case .dealt, .played, .captured, .leftoverSwept:
            break
        }
    }

    /// True once the game actually finished.
    public var isSettled: Bool { outcome != nil }

    /// The end-of-game tally, in the order it should be read out.
    /// Empty until the game ends: leaving a table halfway through pays nothing.
    public func awards(firstOfDay: Bool) -> [Award] {
        guard let outcome else { return [] }
        var awards: [Award]
        if mode.isDailyDeal {
            awards = [Award(.dailyDeal)]
            if outcome == .won { awards.append(Award(.dailyDealWon)) }
        } else {
            awards = [Award(outcome == .won ? .wonGame : .lostGame)]
        }
        if scope > 0 { awards.append(Award(.scopa, count: scope)) }
        if settebelli > 0 { awards.append(Award(.settebello, count: settebelli)) }
        if cappotti > 0 { awards.append(Award(.cappotto, count: cappotti)) }
        // The daily deal is its own once-a-day thing and never counts as the day's first game.
        if firstOfDay, !mode.isDailyDeal { awards.append(Award(.firstOfDay)) }
        return awards
    }

    /// What names this game in every dedupe key. A daily deal is named by its day rather
    /// than by the game, so playing the same day twice pays only once.
    private var gameKey: String {
        if case .dailyDeal(let day) = mode { return "daily/\(day)" }
        return "game/\(gameID.uuidString)"
    }

    public var total: Denari {
        awards(firstOfDay: false).reduce(.zero) { $0 + $1.value }
    }

    /// The same tally as ledger entries. Keys are built from the game and the reason, so
    /// settling a game a second time, after a reconnection or a screen shown twice, credits
    /// nothing.
    public func entries(on date: Date = .now, firstOfDay: Bool) -> [LedgerEntry] {
        awards(firstOfDay: firstOfDay).map { award in
            LedgerEntry(
                date: date,
                amount: award.value,
                reason: .earned(award),
                mode: mode,
                key: "\(gameKey)/\(award.earning.rawValue)"
            )
        }
    }
}
