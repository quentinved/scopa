/// How hard a bot plays, as two dials. `BotLevel` names three points on them; the house at
/// a ranked table mixes its own from the division it sits in. Neither dial ever shows the
/// bot more than its seat can see.
public struct BotStrength: Hashable, Sendable {
    /// Whether it plays the round out over the possible hidden hands, or only weighs the table one move ahead.
    public let searches: Bool

    /// How often it plays the move it thinks is best, 0 to 1. Below one it sometimes takes
    /// the next one down, which is how a beginner plays: nearly right.
    public let follows: Double

    public init(searches: Bool, follows: Double) {
        self.searches = searches
        self.follows = min(max(follows, 0), 1)
    }

    public var isExact: Bool { follows >= 1 }
}

extension BotLevel {
    public var strength: BotStrength {
        switch self {
        case .easy: BotStrength(searches: false, follows: 0.62)
        case .normal: BotStrength(searches: false, follows: 1)
        case .hard: BotStrength(searches: true, follows: 1)
        }
    }
}

extension BotStrength {
    /// The step (Maestro III) at which the house starts searching. Measured: a search that
    /// then plays a different card is weaker than plain weighing until `follows` is near 0.9.
    static let houseSearchesFrom = 15

    /// How often the house follows its own advice at the bottom of Bronze and the top of Maestro.
    static let houseFollowsFloor = 0.50
    static let houseFollowsCeiling = 0.95

    /// Divisions from Bronze III to Maestro I, as `Standing.step` counts them.
    static let topStep = League.allCases.count * Ranking.divisionsPerLeague - 1

    /// What the house plays like at a ranked table, `step` divisions above Bronze III.
    ///
    /// A shallow ramp of about 2.5 points of `follows` per division, so the opponent hardens
    /// without anyone being told. It never reaches perfect: the hard setting is for that.
    /// Only ranked uses this. Wager tables and the daily deal use a fixed opponent, see `TableStore.contestLevel`.
    public static func house(atStep step: Int) -> BotStrength {
        let step = min(max(step, 0), topStep)
        return BotStrength(searches: step >= houseSearchesFrom,
                           follows: ramp(houseFollowsFloor, houseFollowsCeiling, over: step, of: topStep))
    }

    /// The house in the middle division of a league, for copy that describes it.
    public static func house(in league: League) -> BotStrength {
        house(atStep: league.rawValue * Ranking.divisionsPerLeague + 1)
    }

    private static func ramp(_ low: Double, _ high: Double, over step: Int, of span: Int) -> Double {
        guard span > 0 else { return high }
        return low + (high - low) * Double(step) / Double(span)
    }
}
