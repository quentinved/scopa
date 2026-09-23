import Foundation

/// Names the house uses for the empty chairs of an online table.
///
/// It used to carry the lobby's head count as well — a figure derived from the clock, mostly
/// invented, and the loudest thing on the masthead. The masthead shows the grade instead, so
/// what is left here is the cast.
enum Presence {
    /// Names for the empty chairs of an online table, kept separate from `BotNames` so house
    /// strangers and the user's own bots never read as the same cast.
    static let people = [
        "Giulia", "Matteo", "Chiara", "Lorenzo", "Sofia",
        "Alessandro", "Martina", "Francesco", "Elena", "Davide",
        "Valentina", "Marco", "Beatrice", "Riccardo", "Aurora",
        "Tommaso", "Ginevra", "Federico", "Alice", "Stefano",
        "Noemi", "Pietro", "Livia", "Andrea", "Bianca",
    ]

    /// One name, for a single empty chair.
    static func stranger() -> String { people.randomElement() ?? BotNames.dealer }

    /// `count` names, no two the same, for one table.
    static func strangers(_ count: Int) -> [String] {
        Array(people.shuffled().prefix(max(0, count)))
    }
}
