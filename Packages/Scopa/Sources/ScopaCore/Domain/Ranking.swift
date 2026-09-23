/// Leagues, divisions and the points that move a player between them.
///
/// A rating is a plain integer: 100 points per division, 3 divisions per league. The
/// player only ever sees "Silver II" and a bar. A league once reached is a floor for the season.
public enum League: Int, CaseIterable, Codable, Sendable, Hashable, Comparable {
    case bronze, silver, gold, platinum, diamond, maestro

    public static func < (a: League, b: League) -> Bool { a.rawValue < b.rawValue }

    public var name: String {
        switch self {
        case .bronze: "Bronze"
        case .silver: "Silver"
        case .gold: "Gold"
        case .platinum: "Platinum"
        case .diamond: "Diamond"
        case .maestro: "Maestro"
        }
    }

    /// Losses cost half in the lower leagues.
    public var isForgiving: Bool { self <= .silver }
}

/// Where a rating puts you, in the words the player sees.
public struct Standing: Hashable, Codable, Sendable {
    public let league: League
    /// 3 is the bottom of the league, 1 the top.
    public let division: Int
    /// Points into the division, 0 to 99.
    public let progress: Int

    public init(league: League, division: Int, progress: Int) {
        self.league = league
        self.division = division
        self.progress = progress
    }

    /// "Silver II".
    public var title: String { "\(league.name) \(["I", "II", "III"][division - 1])" }

    /// Divisions climbed from Bronze III.
    public var step: Int { league.rawValue * Ranking.divisionsPerLeague + (Ranking.divisionsPerLeague - division) }
}

public enum Ranking {
    public static let pointsPerDivision = 100
    public static let divisionsPerLeague = 3
    public static let top = League.allCases.count * divisionsPerLeague * pointsPerDivision - 1

    public static func standing(for rating: Int) -> Standing {
        let clamped = min(max(rating, 0), top)
        let step = clamped / pointsPerDivision
        let league = League(rawValue: step / divisionsPerLeague) ?? .maestro
        return Standing(league: league, division: divisionsPerLeague - step % divisionsPerLeague, progress: clamped % pointsPerDivision)
    }

    /// The rating a league starts at.
    public static func floor(of league: League) -> Int {
        league.rawValue * divisionsPerLeague * pointsPerDivision
    }

    /// What one result against one opponent is worth, by how many divisions above
    /// (positive) or below (negative) you they stand.
    ///
    /// An even table pays 20, which is what sets the pace of the whole ladder: a division
    /// is five wins, a league fifteen.
    public static func points(won: Bool, opponentAbove steps: Int, in league: League) -> Int {
        if won {
            switch steps {
            case 1...: return 30
            case 0: return 20
            case -1: return 12
            default: return 5
            }
        }
        let loss: Int
        switch steps {
        case 1...: loss = -5
        case 0: loss = -12
        default: loss = -20
        }
        return league.isForgiving ? loss / 2 : loss
    }

    /// The most one table of any size pays, before the run on top of it.
    public static let tableCap = 40

    /// The change for one player of a finished game. A winner collects from each loser,
    /// capped at 40, and the run they are on is paid on top of that cap. A loser pays only
    /// against the winner, and their run ends.
    ///
    /// `streak` is how many wins in a row stood *before* this game.
    public static func change(for rating: Int, others: [Int], won: Bool, winner: Int?, streak: Int = 0) -> Int {
        let mine = standing(for: rating)
        if won {
            let gained = others.reduce(0) { $0 + points(won: true, opponentAbove: standing(for: $1).step - mine.step, in: mine.league) }
            return min(gained, tableCap) + streakBonus(after: streak)
        }
        guard let winner else { return 0 }
        return points(won: false, opponentAbove: standing(for: winner).step - mine.step, in: mine.league)
    }

    // MARK: Runs

    /// Every win in a row past the first adds this much.
    public static let streakStep = 2
    /// Where a run stops paying more, so a long one is a bonus and not a ladder of its own.
    public static let streakCap = 10

    /// What a win is worth over the table itself, given the wins already standing in a row
    /// behind it. Nothing for the first win of a run, 10 from the sixth on.
    public static func streakBonus(after wins: Int) -> Int {
        min(max(wins, 0) * streakStep, streakCap)
    }

    /// The run after one result: a win lengthens it, a loss ends it.
    public static func streak(after won: Bool, from streak: Int) -> Int {
        won ? max(streak, 0) + 1 : 0
    }

    // MARK: The house

    /// A ranked game against the house pays a win in full and prices the loss at a fifth of
    /// it: an evening alone climbs, and the ration below is what keeps it honest rather than
    /// the price. It neither lengthens a run nor ends one — a run is something people take
    /// off each other.
    public static let houseWin = 25
    public static let houseLoss = -5

    /// House games per day the ladder counts. Past this they move nothing, which is the only
    /// brake on the house now that a win off it pays like a real one: ten wins is +250.
    public static let houseGamesPerDay = 10

    /// What one house game does to a rating, before the floor is applied.
    public static func houseChange(won: Bool) -> Int { won ? houseWin : houseLoss }

    /// A rating after a change, clamped to the season floor and the top. The floor rises
    /// to the start of any league the new rating reaches.
    public static func apply(_ change: Int, to rating: Int, floor: Int) -> (rating: Int, floor: Int) {
        let next = min(max(rating + change, floor), top)
        return (next, max(floor, Ranking.floor(of: standing(for: next).league)))
    }
}
