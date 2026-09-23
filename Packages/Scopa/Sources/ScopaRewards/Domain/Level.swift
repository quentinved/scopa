/// The slow number: how much has been played, ever.
///
/// The game already counts three other kinds of progress, and this one is deliberately
/// unlike all of them. A league says how well you are playing *this month* and is taken
/// away at the end of it. A seat mark is a jump — thirty wins, then nothing until fifty.
/// Denari are spent and gone. Experience only ever goes up, never resets, and is never
/// spent: it is the number that says how long somebody has been at this table.
///
/// So it pays for *finishing* rather than for winning. A game lost to the end is worth
/// less than a game won and much more than a game walked out of, which is the same rule
/// `Earning.lostGame` is written on.
public extension Earning {
    /// What one of these is worth in experience.
    ///
    /// Kept beside `unitValue` on purpose: what a game pays in coins and what it pays in
    /// experience are one decision, and two pages would drift apart by the second edit.
    var experience: Int {
        switch self {
        case .wonGame: 40
        case .lostGame: 15
        case .scopa: 5
        case .settebello: 8
        case .cappotto: 20
        // The day's first game and the daily deal pay their bonus in coins. Experience is
        // for what happened at the table, not for what the calendar says.
        case .firstOfDay: 0
        case .dailyDeal: 25
        case .dailyDealWon: 15
        }
    }
}

/// Where a lifetime of experience puts a player: the level, and how far into it they are.
public struct Level: Hashable, Sendable, Codable {
    /// Level 1 is where everybody starts, before a single game.
    public let number: Int
    /// Experience earned into this level, from 0 to `cost`.
    public let progress: Int
    /// What this level costs in full.
    public let cost: Int

    public init(number: Int, progress: Int, cost: Int) {
        self.number = number
        self.progress = progress
        self.cost = cost
    }

    /// How full the bar is, 0 to 1.
    public var fraction: Double { cost > 0 ? Double(progress) / Double(cost) : 0 }
    /// What the next level still costs from here.
    public var toGo: Int { max(cost - progress, 0) }

    // MARK: The curve

    /// What the first level costs, and how much more every level costs than the one below
    /// it. A straight line rather than a curve that doubles: doubling makes the twentieth
    /// level a second job, and this is a card game somebody plays on a train.
    ///
    /// At roughly forty a game that is a level every three games at the start and every
    /// eight or so by level twenty — fast while it is new, slow once it means something.
    public static let first = 100
    public static let step = 25

    /// What it costs to climb out of `number` into the next one.
    public static func cost(of number: Int) -> Int { first + step * max(number - 1, 0) }

    // MARK: What a level pays

    /// Every tenth level is a milestone, and a milestone brings a pack with its denari.
    public static let milestoneEvery = 10

    /// The pack a milestone brings. Not the `mazzetto`, which turns up every few games
    /// anyway: a pack that ten levels promise has to be one worth waiting ten levels for.
    public static let milestonePack = PackTier.velluto

    /// What reaching `number` pays. It grows with the level, as the level's cost does, so
    /// the twentieth still feels like something next to the handful of games it took.
    public static func denari(reaching number: Int) -> Denari {
        Denari(50 + 10 * max(number - 2, 0))
    }

    /// Whether reaching `number` brings `milestonePack` as well.
    public static func isMilestone(_ number: Int) -> Bool {
        number > 1 && number % milestoneEvery == 0
    }

    /// Where a total lands. Counted rather than solved: the arithmetic is a dozen
    /// subtractions for a lifetime of play, and a closed form here is a place for an
    /// off-by-one to hide.
    public static func reached(with experience: Int) -> Level {
        var left = max(experience, 0)
        var number = 1
        while left >= cost(of: number) {
            left -= cost(of: number)
            number += 1
        }
        return Level(number: number, progress: left, cost: cost(of: number))
    }
}
