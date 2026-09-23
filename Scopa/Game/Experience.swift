import Foundation
import ScopaRewards

/// The experience this phone has earned, and the level it comes to.
///
/// Kept on the device beside `Achievements`, and for its reason: a game played signed out
/// still counts. Nothing here is sent anywhere — a level is what somebody has played, not
/// a claim about how well, so there is nothing for a server to check.
enum Experience {
    private enum Key {
        static let total = "experience.total"
        /// The last game counted, so a summary built twice is never two games.
        static let lastGame = "experience.lastGame"
        /// Set once the games played before any of this existed have been counted.
        static let seeded = "experience.seeded"
    }

    static var total: Int { UserDefaults.standard.integer(forKey: Key.total) }

    static var level: Level { Level.reached(with: total) }

    /// Counts what was played before experience existed, once.
    ///
    /// A phone with forty wins on it does not arrive at level one. Losses were only
    /// counted from the same release as this, so a long-standing phone is seeded from its
    /// wins and comes out a little light — which is the right way round: it credits what
    /// is known and invents nothing.
    static func seedFromWhatWasPlayed() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Key.seeded) else { return }
        defaults.set(true, forKey: Key.seeded)
        let record = Achievements.record
        guard record.hasPlayed else { return }
        let seeded = record.wins * Earning.wonGame.experience + record.losses * Earning.lostGame.experience
        defaults.set(max(total, seeded), forKey: Key.total)
    }

    /// What one game was worth, and where it moved the bar from and to.
    struct Gain: Equatable {
        let gained: Int
        let before: Level
        let after: Level

        var levelledUp: Bool { after.number > before.number }
    }

    /// A finished game, counted once. Returns what it was worth, or nil for a game that
    /// had already been counted.
    ///
    /// Paid off the same awards the summary reads out, so what a game is worth in
    /// experience can never disagree with what it was seen to be worth. The day's first
    /// game is not among them: `firstOfDay` is a bonus in coins, and asking for it here
    /// would mean asking the purse which day it is.
    @discardableResult
    static func record(_ tally: RewardTally) -> Gain? {
        guard tally.isSettled else { return nil }
        let defaults = UserDefaults.standard
        let game = tally.gameID.uuidString
        guard defaults.string(forKey: Key.lastGame) != game else { return nil }
        defaults.set(game, forKey: Key.lastGame)
        let gained = tally.awards(firstOfDay: false).reduce(0) { $0 + $1.earning.experience * $1.count }
        let before = level
        defaults.set(total + gained, forKey: Key.total)
        return Gain(gained: gained, before: before, after: level)
    }

    #if DEBUG
    /// Plants a total, so the profile's bar can be looked at without a hundred games
    /// behind it. `-level 1290`.
    static func pretend(total: Int) {
        UserDefaults.standard.set(true, forKey: Key.seeded)
        UserDefaults.standard.set(max(total, 0), forKey: Key.total)
    }
    #endif
}
