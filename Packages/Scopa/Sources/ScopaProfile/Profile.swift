import Foundation

/// One player's account as it travels between their devices.
///
/// Everything here is merged rather than overwritten, because two devices are two copies and
/// both of them change while they are apart. There is no moment at which one of them is
/// simply right, so every field carries the rule it merges by: a preference by its clock, a
/// counter by the larger value, a collection by union. Nothing is decided by arrival order.
///
/// The purse is deliberately not here. It is a ledger of keyed entries, and `Wallet` already
/// merges one by folding in whatever it has not seen — a better merge than anything this
/// could do, and the reason `LedgerEntry` carries a key at all.
public struct Profile: Codable, Hashable, Sendable {
    /// One preference, and when it was last changed on the device that changed it.
    ///
    /// The clock is what makes a preference mergeable at all. Without one, a phone coming
    /// back from a week offline would hand its own stale felt to the iPad that changed it
    /// yesterday, simply by syncing second.
    public struct Setting: Codable, Hashable, Sendable {
        public var value: String
        public var at: Date

        public init(_ value: String, at: Date) {
            self.value = value
            self.at = at
        }
    }

    /// Preferences and the cosmetics in use, under the same keys the device stores them by.
    /// Merged one key at a time: changing the felt here and the language there keeps both.
    public var settings: [String: Setting]

    /// Counters that only ever climb — games won, scope made, experience earned. The larger
    /// of the two wins.
    ///
    /// Two devices that each play a game while apart come back with one game between them
    /// rather than two. That is the honest cost of counting without asking a server after
    /// every hand, and it errs downwards, which for a count of wins is the right way round:
    /// nobody is handed a win they did not play.
    public var counters: [String: Int]

    /// The album, by card code — "7d" for the seven of coins. A count of one card only ever
    /// climbs, so the larger wins, card by card.
    public var album: [String: Int]

    /// Suits whose completion bonus has already been paid for. A set, so union is the merge.
    public var paidSuits: Set<String>
    /// Whether the whole deck's bonus has been paid for. Paid once, so either side saying
    /// yes settles it.
    public var paidDeck: Bool

    /// The week the challenge counts belong to, as "2026-W37".
    public var challengeWeek: String
    /// Progress towards the single goal of the one-goal weeks. Nothing reads it any more; it
    /// is carried, merged the same way as before, because a device still on an older build
    /// refuses a profile without it and would stop syncing altogether.
    public var challengeCount: Int
    /// Progress towards each of that week's tasks, in the order the week sets them. Merged
    /// only within one week, task by task: a count from last week is not progress towards
    /// this one.
    public var challengeCounts: [Int]
    /// The last week whose goal was finished, which is what the badge is drawn from.
    public var finishedWeek: String?

    public init(
        settings: [String: Setting] = [:],
        counters: [String: Int] = [:],
        album: [String: Int] = [:],
        paidSuits: Set<String> = [],
        paidDeck: Bool = false,
        challengeWeek: String = "",
        challengeCount: Int = 0,
        challengeCounts: [Int] = [],
        finishedWeek: String? = nil
    ) {
        self.settings = settings
        self.counters = counters
        self.album = album
        self.paidSuits = paidSuits
        self.paidDeck = paidDeck
        self.challengeWeek = challengeWeek
        self.challengeCount = challengeCount
        self.challengeCounts = challengeCounts
        self.finishedWeek = finishedWeek
    }

    /// Written by hand only so a profile from before the week had several tasks still reads:
    /// it has no `challengeCounts`, and that means none of this week's tasks are started.
    public init(from decoder: any Decoder) throws {
        let profile = try decoder.container(keyedBy: CodingKeys.self)
        settings = try profile.decode([String: Setting].self, forKey: .settings)
        counters = try profile.decode([String: Int].self, forKey: .counters)
        album = try profile.decode([String: Int].self, forKey: .album)
        paidSuits = try profile.decode(Set<String>.self, forKey: .paidSuits)
        paidDeck = try profile.decode(Bool.self, forKey: .paidDeck)
        challengeWeek = try profile.decode(String.self, forKey: .challengeWeek)
        challengeCount = try profile.decode(Int.self, forKey: .challengeCount)
        challengeCounts = try profile.decodeIfPresent([Int].self, forKey: .challengeCounts) ?? []
        finishedWeek = try profile.decodeIfPresent(String.self, forKey: .finishedWeek)
    }

    public static let empty = Profile()

    // MARK: Merging

    /// The two copies folded into one, by the rule each field is documented with.
    ///
    /// Commutative and idempotent on every field, which is what lets a device merge in any
    /// order, as often as it likes, without the answer drifting. Worth keeping that way: the
    /// moment one field stops being either, syncing twice stops meaning syncing once.
    public static func merged(_ mine: Profile, _ theirs: Profile) -> Profile {
        let week = max(mine.challengeWeek, theirs.challengeWeek)
        return Profile(
            settings: mine.settings.merging(theirs.settings) { mine, theirs in
                // A tie goes to neither in particular, so it is broken on the value to keep
                // the merge commutative: two devices must not settle on different answers.
                if theirs.at == mine.at { return max(mine.value, theirs.value) == mine.value ? mine : theirs }
                return theirs.at > mine.at ? theirs : mine
            },
            counters: mine.counters.merging(theirs.counters, uniquingKeysWith: max),
            album: mine.album.merging(theirs.album, uniquingKeysWith: max),
            paidSuits: mine.paidSuits.union(theirs.paidSuits),
            paidDeck: mine.paidDeck || theirs.paidDeck,
            challengeWeek: week,
            // Only the side that is on the winning week has anything to say about its count.
            challengeCount: max(mine.challengeWeek == week ? mine.challengeCount : 0,
                                theirs.challengeWeek == week ? theirs.challengeCount : 0),
            challengeCounts: largerByTask(mine.challengeWeek == week ? mine.challengeCounts : [],
                                          theirs.challengeWeek == week ? theirs.challengeCounts : []),
            finishedWeek: [mine.finishedWeek, theirs.finishedWeek].compactMap { $0 }.max()
        )
    }

    /// Two lists of task counts, the larger of each. The longer list's tail is kept as it is,
    /// so a side that has not started the week yet takes nothing away.
    private static func largerByTask(_ mine: [Int], _ theirs: [Int]) -> [Int] {
        (0..<max(mine.count, theirs.count)).map { task in
            max(mine.indices.contains(task) ? mine[task] : 0, theirs.indices.contains(task) ? theirs[task] : 0)
        }
    }

    /// The same, folded over a list. `Profile.empty` is its identity.
    public static func merged(_ profiles: [Profile]) -> Profile {
        profiles.reduce(.empty) { merged($0, $1) }
    }

    // MARK: On the wire

    /// ISO dates, because the Worker stores this as JSON and reads the dates back in
    /// JavaScript. Apple's reference-date doubles would be unreadable there.
    public static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    public static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
