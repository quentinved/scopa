import Foundation
import ScopaRewards

/// Every rule about when a full screen ad may interrupt the player, in one place.
///
/// Since 2026-10-16 one follows every finished game, once a new player has finished their
/// first two: the full screen ad is what earns, and the daily cap and the quiet period that
/// used to thin them out left a long sitting with no ads at all. A wager lost is no longer
/// an exception either. The no-ads purchase is `AdsStore`'s to check, not this.
@MainActor
struct AdPolicy {
    // MARK: The dials

    /// Games finished before the first interruption, ever, so a first sitting is left alone.
    static let graceGames = 2

    /// What one opt-in ad pays at least: a hundred, about three games' winnings, so a
    /// video is worth the half minute it takes. A game paid out again for an ad pays its
    /// own winnings when they are bigger. There is no daily allowance: the player asks for
    /// every one, and AdMob's own frequency cap is the place for a ceiling if one is wanted.
    static let reward: Denari = 100

    // MARK: What has happened so far

    private(set) var gamesFinished: Int
    private(set) var rewardsWatched: Int

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        gamesFinished = defaults.integer(forKey: Key.gamesFinished)
        rewardsWatched = defaults.integer(forKey: Key.rewardsWatched)
    }

    // MARK: The interruption

    /// A game reached its end. Counted whether or not an ad follows, since the grace
    /// period counts games played.
    mutating func finishedGame() {
        gamesFinished += 1
        defaults.set(gamesFinished, forKey: Key.gamesFinished)
    }

    /// Whether a full screen ad follows the game just counted by `finishedGame()`.
    var allowsInterstitial: Bool { gamesFinished > Self.graceGames }

    /// Whether the game now being played will be followed by one, so an ad is only fetched
    /// for a game that will show it.
    var allowsInterstitialAfterThisGame: Bool { gamesFinished + 1 > Self.graceGames }

    // MARK: The one they choose

    /// One opt-in ad was watched through. The lifetime count keys the payment in the
    /// ledger, so the same watch cannot be paid twice. It no longer holds back the full
    /// screen ad at the end of the game it doubled.
    mutating func watchedReward() {
        rewardsWatched += 1
        defaults.set(rewardsWatched, forKey: Key.rewardsWatched)
    }

    private enum Key {
        static let gamesFinished = "ads.gamesFinished"
        static let rewardsWatched = "ads.rewardsWatched"
    }
}
