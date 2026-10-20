import Foundation

/// Ranked games lost to the house in a row, on this phone: what has the house play a notch
/// kinder on a bad run (`BotStrength.house(atStep:losing:)`). Any ranked win puts it back.
///
/// Kept here rather than on the ladder, which only counts wins in a row. Only tables this
/// phone deals for the house alone read it: a table with other people at it is everyone's.
enum HouseRelief {
    private static let key = "ranked.houseLosses"

    static var losses: Int { UserDefaults.standard.integer(forKey: key) }

    static func record(won: Bool) {
        UserDefaults.standard.set(won ? 0 : losses + 1, forKey: key)
    }
}
