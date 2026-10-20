import Foundation

/// What one day's reminder is about, picked from what is actually waiting that day.
public enum Nudge: Hashable, Sendable {
    /// The week's tasks close at midnight tonight, or tomorrow night, with some still open.
    case weeklyClosing(left: Int, tonight: Bool)
    /// The ranked season closes within one day, or two. Its end is a UTC month, so whole days
    /// are as close as it can honestly be put.
    case seasonClosing(days: Int, league: Int, division: Int)
    /// A run of daily deals that ends at midnight unless the day's deal is played.
    case streak(days: Int)
    /// The everyday knock: the wheel's free turn, the day's deal, or both, and any packs.
    case daily(wheel: Bool, deal: Bool, packs: Int)
    /// The app has not been opened for a few days, with one real thing to come back to.
    case comeback(days: Int, hook: Hook)

    public enum Hook: Hashable, Sendable {
        case packs(Int)
        case weekly(left: Int)
        case newWeek
        case wheel
    }
}

/// What the plan is drawn from, read off the books when the app is in front.
public struct NudgeFacts: Hashable, Sendable {
    /// When the last daily deal was played, which sets the hour of the knock.
    public var lastDeal: Date?
    public var wheelSpentToday = false
    public var dealPlayedToday = false
    /// Daily deals in a row, up to today when it is played and up to yesterday when not.
    public var streak = 0
    /// When this week's tasks close, how many are still open, and whether any has moved.
    public var weekEnds: Date?
    public var weeklyLeft = 0
    public var weeklyStarted = false
    /// When the ranked season closes and where the player stands, for someone who plays it.
    public var seasonEnds: Date?
    public var league: Int?
    public var division = 1
    /// Album packs waiting to be opened.
    public var packs = 0

    public init() {}
}

/// At most one knock a day, at the hour the player usually plays, saying the most pressing
/// thing that day holds. Planned a week ahead and planned again every time the app is in
/// front, so a day the player already came for loses its knock.
public enum NudgePlanner {
    public struct Planned: Hashable, Sendable {
        public let fire: Date
        public let nudge: Nudge
        /// Picks between wordings, so the same sentence does not arrive two days running.
        public let variant: Int
    }

    /// Days of everyday knocks, today included.
    public static let horizon = 7
    /// Days without opening the app after which a comeback goes out instead.
    public static let comebacks = [3, 7]
    /// No knock in the small hours or late at night, whenever the last deal was played.
    public static let hours = 10...21
    /// A shorter run is not news.
    static let streakWorthTelling = 2

    public static func plan(_ facts: NudgeFacts, now: Date, calendar: Calendar = .current) -> [Planned] {
        let hour = usualHour(facts.lastDeal, calendar: calendar)
        let last = max(horizon - 1, comebacks.max() ?? 0)
        return (0...last).compactMap { offset in
            guard let fire = fireDate(offset, hour: hour, now: now, calendar: calendar), fire > now,
                  let nudge = nudge(offset, at: fire, facts, calendar: calendar) else { return nil }
            let variant = calendar.ordinality(of: .day, in: .era, for: fire) ?? offset
            return Planned(fire: fire, nudge: nudge, variant: variant)
        }
    }

    /// The hour of the last deal played, kept to the daytime, or early evening when there is none.
    public static func usualHour(_ lastDeal: Date?, calendar: Calendar) -> Int {
        guard let lastDeal else { return 18 }
        return min(max(calendar.component(.hour, from: lastDeal), hours.lowerBound), hours.upperBound)
    }

    static func fireDate(_ offset: Int, hour: Int, now: Date, calendar: Calendar) -> Date? {
        guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else { return nil }
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)
    }

    /// One day's knock. Today gets one only while the wheel or the deal is still waiting.
    static func nudge(_ offset: Int, at fire: Date, _ facts: NudgeFacts, calendar: Calendar) -> Nudge? {
        if comebacks.contains(offset) { return .comeback(days: offset, hook: hook(at: fire, facts)) }
        guard offset < horizon else { return nil }
        let wheel = offset > 0 || !facts.wheelSpentToday
        let deal = offset > 0 || !facts.dealPlayedToday
        guard wheel || deal else { return nil }
        return closing(at: fire, facts, calendar: calendar)
            ?? streak(offset, facts)
            ?? .daily(wheel: wheel, deal: deal, packs: facts.packs)
    }

    /// A deadline with something riding on it: the week's tasks first, then the season.
    static func closing(at fire: Date, _ facts: NudgeFacts, calendar: Calendar) -> Nudge? {
        // The week ends at a local midnight, so one day from the start of the knock's is tonight.
        if facts.weeklyStarted, facts.weeklyLeft > 0, let ends = facts.weekEnds, fire < ends,
           let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: fire), to: ends).day,
           days <= 2 {
            return .weeklyClosing(left: facts.weeklyLeft, tonight: days <= 1)
        }
        if let ends = facts.seasonEnds, let league = facts.league, fire < ends {
            let days = Int((ends.timeIntervalSince(fire) / 86_400).rounded(.up))
            if days <= 2 { return .seasonClosing(days: days, league: league, division: facts.division) }
        }
        return nil
    }

    /// A run at risk: today while its deal is unplayed, or tomorrow once today's is in.
    /// Any later and the run is already gone, unless the app was opened, which plans again.
    static func streak(_ offset: Int, _ facts: NudgeFacts) -> Nudge? {
        guard facts.streak >= streakWorthTelling else { return nil }
        let atRisk = offset == 0 ? !facts.dealPlayedToday : offset == 1 && facts.dealPlayedToday
        return atRisk ? .streak(days: facts.streak) : nil
    }

    /// The one real thing a comeback names: sealed packs, then the week, then the wheel.
    static func hook(at fire: Date, _ facts: NudgeFacts) -> Nudge.Hook {
        if facts.packs > 0 { return .packs(facts.packs) }
        if let ends = facts.weekEnds, fire >= ends { return .newWeek }
        if facts.weeklyStarted, facts.weeklyLeft > 0 { return .weekly(left: facts.weeklyLeft) }
        return .wheel
    }
}
