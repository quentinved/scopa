/// Leagues, divisions and the points that move a player between them.
///
/// A rating is a plain integer: 100 points per division, 3 divisions per league. The
/// player only ever sees "Silver II" and a bar. A league once reached is a floor for the season.
///
/// Gran Maestro, past Maestro I, has no divisions and no top: its points are shown as they
/// are, and its best players are placed on the season's board rather than in a league.
public enum League: Int, CaseIterable, Codable, Sendable, Hashable, Comparable {
    case bronze, silver, gold, platinum, diamond, maestro, granMaestro

    public static func < (a: League, b: League) -> Bool { a.rawValue < b.rawValue }

    public var name: String {
        switch self {
        case .bronze: "Bronze"
        case .silver: "Silver"
        case .gold: "Gold"
        case .platinum: "Platinum"
        case .diamond: "Diamond"
        case .maestro: "Maestro"
        case .granMaestro: "Gran Maestro"
        }
    }

    /// Losses cost half in the lower leagues.
    public var isForgiving: Bool { self <= .silver }

    /// Every league but the last is climbed in three divisions of a hundred points.
    public var hasDivisions: Bool { self != .granMaestro }
}

/// Where a rating puts you, in the words the player sees.
public struct Standing: Hashable, Codable, Sendable {
    public let league: League
    /// 3 is the bottom of the league, 1 the top. Gran Maestro is all one division, 1.
    public let division: Int
    /// Points into the division, 0 to 99. In Gran Maestro, points past its floor, with no top.
    public let progress: Int

    public init(league: League, division: Int, progress: Int) {
        self.league = league
        self.division = division
        self.progress = progress
    }

    /// "Silver II", or "Gran Maestro".
    public var title: String {
        league.hasDivisions ? "\(league.name) \(["I", "II", "III"][division - 1])" : league.name
    }

    /// Divisions climbed from Bronze III. Gran Maestro is one step past Maestro I, however
    /// many points it holds.
    public var step: Int {
        guard league.hasDivisions else { return Ranking.grandStep }
        return league.rawValue * Ranking.divisionsPerLeague + (Ranking.divisionsPerLeague - division)
    }

    /// Gran Maestro's points, nil in a league with divisions.
    public var points: Int? { league.hasDivisions ? nil : progress }
}

public enum Ranking {
    public static let pointsPerDivision = 100
    public static let divisionsPerLeague = 3
    /// Where Gran Maestro starts: the rating past Maestro I's last point.
    public static let grandFloor = League.granMaestro.rawValue * divisionsPerLeague * pointsPerDivision
    /// Gran Maestro's one step, past Maestro I's seventeen.
    public static let grandStep = grandFloor / pointsPerDivision
    /// Gran Maestro has no top. This is only a number to clamp at.
    public static let top = grandFloor + 999_999

    public static func standing(for rating: Int) -> Standing {
        let clamped = min(max(rating, 0), top)
        guard clamped < grandFloor else { return Standing(league: .granMaestro, division: 1, progress: clamped - grandFloor) }
        let step = clamped / pointsPerDivision
        let league = League(rawValue: step / divisionsPerLeague) ?? .maestro
        return Standing(league: league, division: divisionsPerLeague - step % divisionsPerLeague, progress: clamped % pointsPerDivision)
    }

    // MARK: Gran Maestro's board

    /// The Gran Maestri placed this high on the season's board are its Campioni, the way the
    /// last tier of a ladder is the few at the top of it rather than a number to reach.
    public static let campioni = 10
    /// And only once they hold this many points, so an empty top tier early in a season does
    /// not hand the title to whoever arrived first.
    public static let campionePoints = 300

    /// Whether a place on Gran Maestro's board, with these points, is a Campione's.
    public static func isCampione(place: Int?, points: Int) -> Bool {
        guard let place else { return false }
        return place <= campioni && points >= campionePoints
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
    /// the price. Within the ration it is part of the run like any other game: with so few
    /// people about, a run against people only never got going.
    public static let houseWin = 25
    public static let houseLoss = -5

    /// In Gran Maestro the house is a measure rather than a climb: a win pays less and a loss
    /// costs more, so its points say how often a player beats the house and not only how
    /// often they sat down with it. Even odds still gain, a little, and the run on top.
    public static let grandHouseWin = 15
    public static let grandHouseLoss = -10

    /// What a house game is worth to a player at this rating, won and lost.
    public static func houseStakes(for rating: Int) -> (win: Int, loss: Int) {
        rating >= grandFloor ? (grandHouseWin, grandHouseLoss) : (houseWin, houseLoss)
    }

    /// House games per day the ladder counts. Past this they move nothing, the run included,
    /// which is the only brake on the house: fifteen wins is +495 with the run.
    public static let houseGamesPerDay = 15

    /// The division the house plays at a table: the strongest real player's there, so a pair
    /// cannot meet an easier house by letting the weaker friend lead. Bronze III when nobody
    /// at the table has a rank.
    public static func houseStep(among steps: [Int]) -> Int {
        min(max(steps.max() ?? 0, 0), grandStep)
    }

    /// A rating for a house chair to wear: `jitter` points into the division it plays at, so
    /// two house chairs read as two players and both read as the league they play at.
    public static func houseRating(atStep step: Int, jitter: Int) -> Int {
        let step = min(max(step, 0), grandStep)
        return step * pointsPerDivision + (jitter % pointsPerDivision + pointsPerDivision) % pointsPerDivision
    }

    /// What one house game does to a rating, before the floor is applied. `streak` is the run
    /// standing before it, as for `change`.
    public static func houseChange(won: Bool, streak: Int = 0, rating: Int = 0) -> Int {
        let stakes = houseStakes(for: rating)
        return won ? stakes.win + streakBonus(after: streak) : stakes.loss
    }

    /// A rating after a change, clamped to the season floor and the top. The floor rises
    /// to the start of any league the new rating reaches.
    public static func apply(_ change: Int, to rating: Int, floor: Int) -> (rating: Int, floor: Int) {
        let next = min(max(rating + change, floor), top)
        return (next, max(floor, Ranking.floor(of: standing(for: next).league)))
    }
}
