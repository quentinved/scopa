import Foundation
import Observation
import ScopaRewards

/// Where the week's tasks stand, and whether the badge for them is worn.
///
/// Three values in `UserDefaults` rather than a file: the week's name, a count per task, and
/// the last week that was finished. The ladder is told about progress, but the phone stays
/// the authority for the badge so it appears the moment it is won.
@MainActor
@Observable
final class ChallengeBook {
    private enum Key {
        static let week = "challenge.week"
        static let counts = "challenge.counts"
        static let finished = "challenge.finished"
    }

    private let defaults: UserDefaults

    /// The week the counts belong to. Stored counts from any other week are dropped on load.
    private(set) var week: String

    /// How far along each of the week's tasks this phone has got, in the order of `goals`.
    private(set) var counts: [Int]

    /// The last week whose tasks were all finished, if any. The badge is drawn from this.
    private(set) var finishedWeek: String?

    init(defaults: UserDefaults = .standard, now: Date = .now) {
        self.defaults = defaults
        let week = WeeklyChallenge.week(for: now)
        self.week = week
        self.finishedWeek = defaults.string(forKey: Key.finished)
        self.counts = Self.zeros
        readCounts()
    }

    /// Reads the week again, for a book already on screen. `AccountSync` calls it after
    /// folding in what the player's other device has got done this week.
    ///
    /// The same rule as `init`: counts belong to the week they were stored under, and any
    /// other week starts at nothing.
    func readStoredAgain(now: Date = .now) {
        week = WeeklyChallenge.week(for: now)
        finishedWeek = defaults.string(forKey: Key.finished)
        readCounts()
    }

    private static var zeros: [Int] { Array(repeating: 0, count: WeeklyChallenge.tasksPerWeek) }

    /// The stored counts if they are this week's, and nothing otherwise. A list of the wrong
    /// length is a count from the one-goal weeks, which asked for something else.
    private func readCounts() {
        let stored = defaults.array(forKey: Key.counts) as? [Int]
        if defaults.string(forKey: Key.week) == week, let stored, stored.count == Self.zeros.count {
            counts = stored
        } else {
            counts = Self.zeros
            defaults.set(week, forKey: Key.week)
            defaults.set(counts, forKey: Key.counts)
        }
    }

    /// This week's tasks, fixed by the week's name.
    var goals: [WeeklyChallenge.Goal] { WeeklyChallenge.goals(for: week) }

    /// Whether one task is done.
    func isFinished(_ slot: Int) -> Bool { counts[slot] >= goals[slot].target }

    /// How far along one task, 0 to 1, for its bar.
    func progress(_ slot: Int) -> Double {
        let target = goals[slot].target
        guard target > 0 else { return 0 }
        return min(Double(counts[slot]) / Double(target), 1)
    }

    /// How many of the week's tasks are done.
    var tasksDone: Int { goals.indices.filter { isFinished($0) }.count }

    /// Whether every task is done and the badge earned.
    var isFinished: Bool { tasksDone == goals.count }

    /// Progress across the whole week, each task counted only up to its target so a pile of
    /// sweeps cannot stand in for the wins still owed. This is what the board ranks by.
    var steps: Int { zip(counts, goals).map { min($0, $1.target) }.reduce(0, +) }

    /// Every step the week asks for.
    var totalSteps: Int { goals.map(\.target).reduce(0, +) }

    /// How far along the week as a whole, 0 to 1: every task weighed the same, so four
    /// cappotti count for as much of the ring as a hundred sweeps.
    var progress: Double {
        guard !goals.isEmpty else { return 0 }
        return goals.indices.map { progress($0) }.reduce(0, +) / Double(goals.count)
    }

    /// When this week ends and the next goal starts.
    var endsAt: Date? { WeeklyChallenge.end(of: week) }

    // MARK: The badge

    /// Whether there is a badge to wear right now. A badge is worn only through the week it was
    /// won in, so each new week it has to be earned again.
    var wearsHonour: Bool { finishedWeek == week }

    /// What goes on the wire so other phones at the table draw the badge too. Nil when there is
    /// nothing to show, which is also what an older build sends.
    var honourOnWire: String? { wearsHonour ? finishedWeek : nil }

    /// Whether a badge sent by another phone is one this week honours: it must name this week,
    /// so a laurel from last week, sent by an older build, is not drawn.
    static func honours(_ wire: String?, on week: String) -> Bool {
        guard let wire, !wire.isEmpty else { return false }
        return wire == week
    }

    // MARK: Counting

    /// What one game finished: the tasks it completed, by slot, and whether it was the one
    /// that completed the week.
    struct Finish: Equatable {
        var slots: [Int] = []
        var week = false
    }

    /// Counts a finished game towards every task at once. Returns the tasks this game
    /// completed, and nothing on any other game, so each reward is paid exactly once.
    @discardableResult
    func record(_ tally: RewardTally, won: Bool, now: Date = .now) -> Finish? {
        rollOver(to: now)
        let wasFinished = isFinished
        var finish = Finish()
        var moved = false
        for (slot, goal) in goals.enumerated() {
            let credit = goal.credit(for: tally, won: won)
            guard credit > 0 else { continue }
            let before = isFinished(slot)
            counts[slot] += credit
            moved = true
            if !before, isFinished(slot) { finish.slots.append(slot) }
        }
        guard moved else { return nil }
        defaults.set(counts, forKey: Key.counts)
        if !wasFinished, isFinished {
            finish.week = true
            finishedWeek = week
            defaults.set(week, forKey: Key.finished)
        }
        return finish.slots.isEmpty ? nil : finish
    }

    /// Moves to a new week if one has started since this was last touched. Called before counting
    /// so a game played after midnight on Sunday counts for the week it was played in.
    func rollOver(to now: Date = .now) {
        let current = WeeklyChallenge.week(for: now)
        guard current != week else { return }
        week = current
        counts = Self.zeros
        defaults.set(current, forKey: Key.week)
        defaults.set(counts, forKey: Key.counts)
    }

    #if DEBUG
    /// `-challenge 9` puts every task that far along, capped at its target, so the card, the
    /// bars and the finish can be checked without playing a week of Scopa first.
    func pretend(count: Int) {
        counts = goals.map { min(count, $0.target) }
        defaults.set(counts, forKey: Key.counts)
        if isFinished {
            finishedWeek = week
            defaults.set(week, forKey: Key.finished)
        }
    }
    #endif
}
