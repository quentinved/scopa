import Foundation

/// When to ask for an App Store rating: just after a win, once the player has played enough
/// to have an opinion, and once per version at most. Ratings are much of what lifts the app
/// in a search for "scopa".
///
/// iOS shows the sheet at most three times a year whatever is asked, so this only picks
/// the moment and never promises the sheet appears.
enum ReviewPrompt {
    private enum Key {
        static let finished = "review.finished"
        static let wins = "review.wins"
        static let askedVersion = "review.askedVersion"
        /// The last game counted, so a summary that appears twice is not two games.
        static let lastGame = "review.lastGame"
    }

    /// Counts a finished game, and says whether this is the moment to ask.
    static func shouldAsk(after gameID: UUID, won: Bool) -> Bool {
        let defaults = UserDefaults.standard
        let game = gameID.uuidString
        guard defaults.string(forKey: Key.lastGame) != game else { return false }
        defaults.set(game, forKey: Key.lastGame)
        let finished = defaults.integer(forKey: Key.finished) + 1
        let wins = defaults.integer(forKey: Key.wins) + (won ? 1 : 0)
        defaults.set(finished, forKey: Key.finished)
        defaults.set(wins, forKey: Key.wins)

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        guard won, wins >= 3, finished >= 5, defaults.string(forKey: Key.askedVersion) != version else {
            return false
        }
        defaults.set(version, forKey: Key.askedVersion)
        return true
    }
}
