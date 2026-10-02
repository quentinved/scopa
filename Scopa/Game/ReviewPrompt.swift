import Foundation

/// When to ask for an App Store rating. Ratings are much of what lifts the app in a search
/// for "scopa", so the ask comes at the kindest moment there is: back in the lobby after a
/// win, at the end of a long sitting, from someone who has played enough to have an opinion.
///
/// The ask is our own card first (`ReviewAskCard`); only a yes goes on to iOS's sheet, which
/// iOS shows at most three times a year whatever is asked.
@MainActor
enum ReviewPrompt {
    // MARK: The dials

    /// Games finished, ever, before the first ask.
    static let gamesBefore = 5
    /// Wins, ever, before the first ask.
    static let winsBefore = 3
    /// Games in one sitting that make it a long one: about half an hour against the bots.
    static let longSitting = 3
    /// Or two games spread over this long, for a slow table.
    static let longSittingTime: TimeInterval = 20 * 60
    /// A gap between two games longer than this starts a new sitting.
    static let sittingBreak: TimeInterval = 15 * 60
    /// After "later", the card waits this long.
    static let laterWait: TimeInterval = 14 * 86_400
    /// After a yes or a no, a new version and this long.
    static let answeredWait: TimeInterval = 90 * 86_400

    /// Where Settings sends someone who wants to write a review.
    static let writeReviewURL = URL(string: "https://apps.apple.com/app/id6810455597?action=write-review")!

    // MARK: The sitting, in memory only

    private static var sittingStart: Date?
    private static var lastGameEnd: Date?
    private static var sittingGames = 0

    /// Set when a game made it the moment. The lobby takes it on its way back in.
    private(set) static var isDue = false

    /// Counts a finished game, and marks the ask as due if this is the moment.
    static func count(_ gameID: UUID, won: Bool, now: Date = .now) {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: Key.lastGame) != gameID.uuidString else { return }
        defaults.set(gameID.uuidString, forKey: Key.lastGame)
        let finished = defaults.integer(forKey: Key.finished) + 1
        let wins = defaults.integer(forKey: Key.wins) + (won ? 1 : 0)
        defaults.set(finished, forKey: Key.finished)
        defaults.set(wins, forKey: Key.wins)
        countSitting(now: now)
        guard won, finished >= gamesBefore, wins >= winsBefore, isLongSitting(now: now),
              mayAsk(now: now) else { return }
        isDue = true
    }

    /// The lobby is showing the card: it is spent until the player answers or waits it out.
    static func take() -> Bool {
        defer { isDue = false }
        return isDue
    }

    enum Answer { case rated, later }

    /// Writes down when the card may come back.
    static func answered(_ answer: Answer, now: Date = .now) {
        let defaults = UserDefaults.standard
        switch answer {
        case .later:
            defaults.set(now.addingTimeInterval(laterWait), forKey: Key.nextAsk)
        case .rated:
            defaults.set(now.addingTimeInterval(answeredWait), forKey: Key.nextAsk)
            defaults.set(version, forKey: Key.answeredVersion)
        }
    }

    // MARK: Workings

    private static func countSitting(now: Date) {
        if let lastGameEnd, now.timeIntervalSince(lastGameEnd) <= sittingBreak {
            sittingGames += 1
        } else {
            sittingStart = now
            sittingGames = 1
        }
        lastGameEnd = now
    }

    private static func isLongSitting(now: Date) -> Bool {
        let span = sittingStart.map { now.timeIntervalSince($0) } ?? 0
        return sittingGames >= longSitting || (sittingGames >= 2 && span >= longSittingTime)
    }

    private static func mayAsk(now: Date) -> Bool {
        let defaults = UserDefaults.standard
        // The old ask went straight to iOS's sheet; a version it already asked in counts.
        for key in [Key.answeredVersion, Key.systemAskedVersion] where defaults.string(forKey: key) == version {
            return false
        }
        guard let next = defaults.object(forKey: Key.nextAsk) as? Date else { return true }
        return now >= next
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private enum Key {
        static let finished = "review.finished"
        static let wins = "review.wins"
        static let answeredVersion = "review.answeredVersion"
        static let nextAsk = "review.nextAsk"
        static let systemAskedVersion = "review.askedVersion"
        /// The last game counted, so a summary that appears twice is not two games.
        static let lastGame = "review.lastGame"
    }
}
