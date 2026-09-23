import Foundation
import ScopaRewards

/// How a finished game left the player, to the extent that it changes whether an ad follows.
enum GameEnding {
    /// A game with no denari on it.
    case ordinary
    /// A wager game the player lost, so the stake went with it. Never followed by an ad.
    case lostStake
}

/// Every rule about when a full screen ad may interrupt the player, in one place.
///
/// The limits are deliberately tight: Scopa is played in short bursts, so an ad after every
/// game reads as a toll. The banner and the opt-in ad are the intended earners.
@MainActor
struct AdPolicy {
    // MARK: The dials

    /// Games finished before the first interruption, so a first sitting is left alone.
    static let graceGames = 3

    /// Games between interruptions afterwards, so every other game at most.
    static let gamesBetween = 2

    /// Shortest gap between two interruptions. Pass-and-play games can end minutes apart.
    static let quietPeriod: TimeInterval = 4 * 60

    /// Hard ceiling per day, whatever the other rules allow.
    static let dailyCap = 4

    /// What one opt-in ad pays, set just under a game's winnings (roughly thirty-five
    /// denari) so that watching ads never beats playing.
    static let reward: Denari = 30

    /// Opt-in ads per day. Three pays ninety denari against a three hundred denari deck.
    static let rewardsPerDay = 3

    // MARK: What has happened so far

    private(set) var gamesFinished: Int
    private(set) var rewardsWatched: Int
    private var gamesSinceLast: Int
    private var shownToday: Int
    private var rewardsToday: Int
    private var day: Int
    private var last: Date?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, now: Date = .now) {
        self.defaults = defaults
        gamesFinished = defaults.integer(forKey: Key.gamesFinished)
        rewardsWatched = defaults.integer(forKey: Key.rewardsWatched)
        gamesSinceLast = defaults.integer(forKey: Key.gamesSinceLast)
        shownToday = defaults.integer(forKey: Key.shownToday)
        rewardsToday = defaults.integer(forKey: Key.rewardsToday)
        day = defaults.integer(forKey: Key.day)
        last = defaults.object(forKey: Key.last) as? Date
        rollOver(to: now)
    }

    // MARK: The interruption

    /// A game reached its end. Counted whether or not an ad follows, since the grace
    /// period and the every-other-game rule both count games played.
    mutating func finishedGame() {
        gamesFinished += 1
        gamesSinceLast += 1
        defaults.set(gamesFinished, forKey: Key.gamesFinished)
        defaults.set(gamesSinceLast, forKey: Key.gamesSinceLast)
    }

    /// Whether a full screen ad may follow this ending.
    mutating func allowsInterstitial(after ending: GameEnding, now: Date = .now) -> Bool {
        rollOver(to: now)
        guard gamesFinished > Self.graceGames else { return false }
        guard ending != .lostStake else { return false }
        guard gamesSinceLast >= Self.gamesBetween else { return false }
        guard shownToday < Self.dailyCap else { return false }
        guard let last else { return true }
        return now.timeIntervalSince(last) >= Self.quietPeriod
    }

    /// Records a shown ad. Call only once the network confirms it appeared, so a failed
    /// presentation does not spend the player's allowance.
    mutating func showedInterstitial(now: Date = .now) {
        shownToday += 1
        gamesSinceLast = 0
        last = now
        defaults.set(shownToday, forKey: Key.shownToday)
        defaults.set(gamesSinceLast, forKey: Key.gamesSinceLast)
        defaults.set(now, forKey: Key.last)
    }

    // MARK: The one they choose

    /// How many opt-in ads are left today. Non-mutating on purpose: the shop asks on every
    /// redraw, so the day roll-over is not written here.
    func rewardsLeftToday(now: Date = .now) -> Int {
        let used = Self.ordinal(of: now) == day ? rewardsToday : 0
        return max(0, Self.rewardsPerDay - used)
    }

    /// One opt-in ad was watched through. The lifetime count keys the payment in the
    /// ledger, so the same watch cannot be paid twice.
    ///
    /// It also stamps `last`, so the quiet period keeps a full screen ad from following
    /// straight after the video.
    mutating func watchedReward(now: Date = .now) {
        rollOver(to: now)
        rewardsToday += 1
        rewardsWatched += 1
        last = now
        defaults.set(rewardsToday, forKey: Key.rewardsToday)
        defaults.set(rewardsWatched, forKey: Key.rewardsWatched)
        defaults.set(now, forKey: Key.last)
    }

    // MARK: The day

    /// Daily allowances refill at local midnight rather than twenty-four hours after the
    /// last ad, so an evening player gets the same allowance every evening.
    private mutating func rollOver(to now: Date) {
        let today = Self.ordinal(of: now)
        guard today != day else { return }
        day = today
        shownToday = 0
        rewardsToday = 0
        defaults.set(day, forKey: Key.day)
        defaults.set(0, forKey: Key.shownToday)
        defaults.set(0, forKey: Key.rewardsToday)
    }

    private static func ordinal(of date: Date) -> Int {
        Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
    }

    private enum Key {
        static let gamesFinished = "ads.gamesFinished"
        static let gamesSinceLast = "ads.gamesSinceLast"
        static let shownToday = "ads.shownToday"
        static let rewardsToday = "ads.rewardsToday"
        static let rewardsWatched = "ads.rewardsWatched"
        static let day = "ads.day"
        static let last = "ads.lastInterstitial"
    }
}
