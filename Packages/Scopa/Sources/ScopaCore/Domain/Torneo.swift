/// A run of games played one after another, each against somebody new, where a loss sends
/// the run back to the first game. Only how far it has got is kept here: who sits down at
/// each game is the caller's to say.
public struct Torneo: Hashable, Sendable {
    /// What one finished game did to the run.
    public enum Step: Hashable, Sendable {
        /// Won, and the next game is up.
        case next
        /// The last game won. The run is over, and a new one starts from the first.
        case champion
        /// Lost, and back to the first.
        case lost
    }

    public let games: Int
    /// Games won so far in this run, always fewer than `games`.
    public private(set) var won: Int

    /// A count read back from storage is clamped, so a run never points past its last game.
    public init(games: Int, won: Int = 0) {
        self.games = max(games, 1)
        self.won = min(max(won, 0), self.games - 1)
    }

    /// The game about to be played, counted from nought.
    public var game: Int { won }

    public var isLastGame: Bool { won == games - 1 }

    @discardableResult
    public mutating func record(won game: Bool) -> Step {
        guard game else {
            won = 0
            return .lost
        }
        guard !isLastGame else {
            won = 0
            return .champion
        }
        won += 1
        return .next
    }
}
