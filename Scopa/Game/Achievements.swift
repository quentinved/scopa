import Foundation
import ScopaCore
import ScopaGameCenter
import ScopaRewards

/// Game Center achievements, by the ids set up in App Store Connect.
///
/// The counts live on the device rather than being read back from Game Center, so a game
/// played signed out still counts once the player signs in. Every report sends all twelve and
/// Game Center keeps whichever value is higher.
enum Achievements {
    /// The ids, exactly as they must be entered in App Store Connect.
    enum ID {
        static let firstScopa = "first_scopa"
        static let fiftyScope = "scope_50"
        static let firstSettebello = "first_settebello"
        static let settebello25 = "settebello_25"
        static let firstCappotto = "first_cappotto"
        static let firstWin = "first_win"
        static let wins25 = "wins_25"
        static let wins100 = "wins_100"
        static let firstDaily = "first_daily"
        static let streak7 = "daily_streak_7"
        static let streak30 = "daily_streak_30"
        static let firstOnlineWin = "first_online_win"

        static let all = [firstScopa, fiftyScope, firstSettebello, settebello25, firstCappotto, firstWin,
                          wins25, wins100, firstDaily, streak7, streak30, firstOnlineWin]
    }

    private enum Key {
        static let scope = "achievements.scope"
        static let settebelli = "achievements.settebelli"
        static let cappotti = "achievements.cappotti"
        static let wins = "achievements.wins"
        static let losses = "achievements.losses"
        static let daily = "achievements.daily"
        static let onlineWins = "achievements.onlineWins"
        /// The last game counted, so a summary that appears twice is not two games.
        static let lastGame = "achievements.lastGame"
    }

    /// What the player has to show for every game they have finished, which is what the
    /// profile puts under their name.
    ///
    /// Losses are counted from here on. A phone that has been played for a month before
    /// this existed knows its wins and not its losses, so `played` would be wrong for
    /// those — which is why nothing here adds the two together and calls it games played.
    struct Record: Hashable {
        var wins: Int
        var losses: Int

        var hasPlayed: Bool { wins + losses > 0 }
    }

    static var record: Record {
        let defaults = UserDefaults.standard
        return Record(wins: defaults.integer(forKey: Key.wins), losses: defaults.integer(forKey: Key.losses))
    }

    /// The counters as they stand, for the seat marks that are earned rather than bought.
    static func markProgress(streak: Int, suits: Set<Suit> = [], deck: Bool = false) -> MarkProgress {
        let defaults = UserDefaults.standard
        return MarkProgress(suits: suits, deck: deck, wins: defaults.integer(forKey: Key.wins),
                            scope: defaults.integer(forKey: Key.scope), streak: streak)
    }

    /// A finished game, whatever it paid. `streak` is the daily run as it stands after it.
    ///
    /// Counted once per game. The summary that calls this is paid for by a ledger that
    /// cannot pay twice, so it is written to be safe to run twice — and it is, for denari.
    /// Counters are not: a second pass would be a second win.
    static func record(_ tally: RewardTally, won: Bool, streak: Int) {
        let game = tally.gameID.uuidString
        guard UserDefaults.standard.string(forKey: Key.lastGame) != game else { return }
        UserDefaults.standard.set(game, forKey: Key.lastGame)
        let scope = bump(Key.scope, by: tally.scope)
        let settebelli = bump(Key.settebelli, by: tally.settebelli)
        let cappotti = bump(Key.cappotti, by: tally.cappotti)
        let wins = bump(Key.wins, by: won ? 1 : 0)
        _ = bump(Key.losses, by: won ? 0 : 1)
        let daily = bump(Key.daily, by: tally.mode.isDailyDeal ? 1 : 0)
        let online: Bool = if case .multipeer = tally.mode { true } else { false }
        let onlineWins = bump(Key.onlineWins, by: won && online ? 1 : 0)

        func percent(_ count: Int, of target: Int) -> Double { Double(count) / Double(target) * 100 }
        let progress: [String: Double] = [
            ID.firstScopa: percent(scope, of: 1),
            ID.fiftyScope: percent(scope, of: 50),
            ID.firstSettebello: percent(settebelli, of: 1),
            ID.settebello25: percent(settebelli, of: 25),
            ID.firstCappotto: percent(cappotti, of: 1),
            ID.firstWin: percent(wins, of: 1),
            ID.wins25: percent(wins, of: 25),
            ID.wins100: percent(wins, of: 100),
            ID.firstDaily: percent(daily, of: 1),
            ID.streak7: percent(streak, of: 7),
            ID.streak30: percent(streak, of: 30),
            ID.firstOnlineWin: percent(onlineWins, of: 1),
        ]
        GameCenter.report(progress.filter { $0.value > 0 })
    }

    #if DEBUG
    /// Plants a record the way `-denari` plants coins, so the profile can be looked at
    /// without playing forty games first.
    static func pretend(wins: Int, losses: Int) {
        UserDefaults.standard.set(wins, forKey: Key.wins)
        UserDefaults.standard.set(losses, forKey: Key.losses)
    }
    #endif

    /// Adds to a stored counter and returns its new value.
    private static func bump(_ key: String, by amount: Int) -> Int {
        let value = UserDefaults.standard.integer(forKey: key) + amount
        UserDefaults.standard.set(value, forKey: key)
        return value
    }
}
