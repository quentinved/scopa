import Foundation

/// Who a ranked table has just sat this phone down with, for the short moment that says so
/// before the table: a person the search found, or the house when the house was taken. Set as
/// soon as it is known, while the seating carries on underneath.
struct MatchFound: Equatable, Identifiable {
    let id = UUID()
    /// This phone's side of the table, its own name first. A duo puts the partner second, and
    /// a four against the house the house partner behind you.
    let ours: [String]
    /// The other side: one name heads-up, two across a four or a duo.
    let theirs: [String]
    /// The division the house plays at, when the other side is the house. Its chairs wear this
    /// league at the table too, see `TableStore.tableHouseStep`.
    var houseStep: Int? = nil

    var isHouse: Bool { houseStep != nil }

    /// How long the moment covers the screen. The seating never waits for it; bots already at
    /// the table hold their first card until it lifts.
    static var length: Duration { DebugLaunch.holdsMatchFound ? .seconds(8) : .milliseconds(2700) }
}
