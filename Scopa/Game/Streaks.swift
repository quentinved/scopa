import ScopaRewards

/// What a run of daily deals pays: denari at each mark, plus a felt at seven days that is not
/// for sale. Paid every time a run reaches a mark, not once per lifetime.
enum Streaks {
    struct Milestone: Hashable {
        let days: Int
        let denari: Denari
        /// Handed over by the streak only, never for sale.
        let felt: TableFelt?
    }

    static let milestones = [
        Milestone(days: 3, denari: 20, felt: nil),
        Milestone(days: 7, denari: 50, felt: .festa),
        Milestone(days: 14, denari: 120, felt: nil),
        Milestone(days: 30, denari: 300, felt: nil),
    ]

    /// The mark a run has just arrived at, if today's deal took it there.
    static func milestone(reachedAt days: Int) -> Milestone? {
        milestones.first { $0.days == days }
    }

    /// The next milestone ahead of this run.
    static func next(after days: Int) -> Milestone? {
        milestones.first { $0.days > days }
    }

    /// The milestone that awards this felt, if one does.
    static func milestone(for felt: TableFelt) -> Milestone? {
        milestones.first { $0.felt == felt }
    }
}
