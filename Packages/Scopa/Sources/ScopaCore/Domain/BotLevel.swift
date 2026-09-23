/// How well the machine plays. Every level sees only what a player in that seat sees.
/// What changes is how much it thinks and how often it follows its own advice.
public enum BotLevel: String, CaseIterable, Codable, Sendable, Hashable {
    /// Takes the obvious capture and sometimes a worse move on purpose.
    case easy
    /// Weighs the table one move ahead.
    case normal
    /// Plays the rest of the round out over the possible hidden hands.
    case hard

    public static let `default` = BotLevel.normal

    public var title: String {
        switch self {
        case .easy: "Easy"
        case .normal: "Normal"
        case .hard: "Hard"
        }
    }

    public var detail: String {
        switch self {
        case .easy: "Takes what it sees and misses the rest"
        case .normal: "Weighs the table and what a move leaves behind"
        case .hard: "Counts the deck and plays the round out before it moves"
        }
    }
}
