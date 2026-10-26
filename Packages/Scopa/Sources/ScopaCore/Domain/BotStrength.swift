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
    /// How often the house follows its own advice at the bottom of Bronze.
    static let houseFollowsFloor = 0.50
    /// The line the lower ladder is drawn on, from Bronze III to where it once reached at
    /// Maestro I. Kept as it was so nothing below Diamond moved when the top was retuned.
    static let houseLineCeiling = 0.95
    static let houseLineSpan = 17

    /// Divisions from Bronze III to Gran Maestro, as `Standing.step` counts them.
    static let topStep = Ranking.grandStep

    /// Gold III, where the ramp bends: below it the house hardens as it always has, and from
    /// there to Diamond I more gently, so Diamond plays about the way Platinum used to. Until
    /// 1.4 Diamond I took its own advice 87 times in a hundred, and players there were losing
    /// round after round to it.
    static let houseBendsAt = 6
    /// Diamond I, the last division of the bend.
    static let houseBendsUntil = 14
    /// How often the house follows its own advice at Diamond I.
    static let houseFollowsBelowMaestro = 0.80

    /// Maestro III to I, then Gran Maestro: two points of `follows` a division. Until 1.5 the
    /// house searched from Maestro III, playing each round out over the hands it could not
    /// see and solving the last hand outright, at 0.95 by Maestro I. Fair, but it read at the
    /// table as a house that always held the card it needed, and a Maestro I could not win.
    /// The hard setting keeps the search for anyone who wants it.
    static let houseFollowsAtTop: [Double] = [0.82, 0.84, 0.86, 0.88]

    /// How much sloppier the house plays for each ranked game in a row lost to it, and how
    /// many of those it counts. A bad run gets a kinder table, and a win puts it back.
    static let reliefPerLoss = 0.05
    public static let reliefLosses = 3

    /// What the house plays like at a ranked table, `step` divisions above Bronze III, for a
    /// player who has lost `losses` ranked games in a row to it.
    ///
    /// A shallow ramp of a few points of `follows` per division, so the opponent hardens
    /// without anyone being told. It never reaches perfect, and it never counts the deck: the
    /// hard setting is for that. Only ranked uses this. Wager tables and the daily deal use a
    /// fixed opponent, see `TableStore.contestLevel`.
    public static func house(atStep step: Int, losing losses: Int = 0) -> BotStrength {
        let step = min(max(step, 0), topStep)
        let relief = Double(min(max(losses, 0), reliefLosses)) * reliefPerLoss
        return BotStrength(searches: false, follows: houseFollows(atStep: step) - relief)
    }

    private static func houseFollows(atStep step: Int) -> Double {
        if step > houseBendsUntil { return houseFollowsAtTop[min(step - houseBendsUntil - 1, houseFollowsAtTop.count - 1)] }
        let line = ramp(houseFollowsFloor, houseLineCeiling, over: step, of: houseLineSpan)
        guard step >= houseBendsAt else { return line }
        let bend = ramp(houseFollowsFloor, houseLineCeiling, over: houseBendsAt, of: houseLineSpan)
        let span = houseBendsUntil - houseBendsAt
        return bend + (houseFollowsBelowMaestro - bend) * Double(step - houseBendsAt) / Double(span)
    }

    /// The house in the middle division of a league, for copy that describes it. Gran
    /// Maestro has only the one.
    public static func house(in league: League) -> BotStrength {
        guard league.hasDivisions else { return house(atStep: Ranking.grandStep) }
        return house(atStep: league.rawValue * Ranking.divisionsPerLeague + 1)
    }

    private static func ramp(_ low: Double, _ high: Double, over step: Int, of span: Int) -> Double {
        guard span > 0 else { return high }
        return low + (high - low) * Double(step) / Double(span)
    }
}
