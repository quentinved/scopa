import Foundation
import ScopaCore
import ScopaRewards

/// What the ranked road pays on the way up: a few denari at three stops inside every
/// division, and a pack for the division itself. Leagues keep their own ceremony and
/// prizes; these are the steps between them.
///
/// Once per stop per season, keyed in the ledger, so two devices or an answer read twice
/// pay once. Only climbs this phone has seen pay: the first answer it reads sets where the
/// counting starts, so a player already high on the ladder the day this arrived is not
/// handed every stop below at once.
enum DivisionGifts {
    /// Points from one stop to the next: three of denari inside a division, then its pack.
    static let stride = 25
    static let stopsPerDivision = Ranking.pointsPerDivision / stride

    /// "2026-10|29": the season, and the highest stop already counted in it.
    private static let markKey = "divisionGifts.stop"
    /// The same mark counted in whole divisions, as the first build of this kept it.
    private static let divisionMarkKey = "divisionGifts.mark"

    /// What one stop on the road pays. A stop is `stride` points of rating, counted from the
    /// bottom of Bronze III; every fourth is the top of a division.
    enum Reward: Hashable {
        case denari(Denari)
        case pack(PackTier)
    }

    static func reward(at stop: Int) -> Reward {
        guard stop % stopsPerDivision != 0 else { return .pack(tier(for: stop / stopsPerDivision)) }
        return .denari(denari(inDivision: stop / stopsPerDivision))
    }

    /// The denari at a stop inside the division `step`, more the higher the league. A stop
    /// is a win and a bit, so it is worth about one game's own pay.
    static func denari(inDivision step: Int) -> Denari {
        switch league(of: step) {
        case .bronze, .silver: 30
        case .gold, .platinum: 50
        case .diamond, .maestro: 80
        }
    }

    /// The pack a division pays, better the higher the league.
    static func tier(for step: Int) -> PackTier {
        switch league(of: step) {
        case .bronze, .silver: .bottega
        case .gold, .platinum: .velluto
        case .diamond, .maestro: .reliquia
        }
    }

    private static func league(of step: Int) -> League {
        League(rawValue: step / Ranking.divisionsPerLeague) ?? .maestro
    }

    /// The stop a rating has reached.
    static func stop(for rating: Int) -> Int { min(max(rating, 0), Ranking.top) / stride }

    /// The stops this answer climbs past the mark, lowest first, and moves the mark up to
    /// it. Empty for an answer without a season, or for someone who has not played.
    static func climbed(in rank: Ladder.RankAnswer, defaults: UserDefaults = .standard) -> [Int] {
        guard let season = rank.season, rank.games > 0 else { return [] }
        let stop = stop(for: rank.rating)
        let counted = mark(season: season, stop: stop, defaults: defaults)
        defaults.set("\(season)|\(max(stop, counted))", forKey: markKey)
        return stop > counted ? Array(counted + 1...stop) : []
    }

    /// Where counting picks up: this season's mark, the bottom of the league after a new
    /// season, or right here for a phone that has never counted.
    private static func mark(season: String, stop: Int, defaults: UserDefaults) -> Int {
        let perLeague = Ranking.divisionsPerLeague * stopsPerDivision
        if let (markSeason, at) = read(markKey, defaults) {
            // A new season starts everyone at the bottom of their league.
            return markSeason == season ? at : min(stop, stop / perLeague * perLeague)
        }
        // A phone that counted whole divisions has had their packs and none of the stops.
        if let (markSeason, step) = read(divisionMarkKey, defaults), markSeason == season {
            return step * stopsPerDivision
        }
        return stop
    }

    private static func read(_ key: String, _ defaults: UserDefaults) -> (String, Int)? {
        let parts = defaults.string(forKey: key)?.split(separator: "|").map(String.init) ?? []
        guard parts.count == 2, let at = Int(parts[1]) else { return nil }
        return (parts[0], at)
    }

    /// The ledger's name for one stop. A division's pack keeps the name it was first paid
    /// under, so nothing paid already is paid again.
    static func key(season: String, stop: Int) -> String {
        let step = stop / stopsPerDivision
        let within = stop % stopsPerDivision
        return within == 0 ? "division/\(season)/\(step)" : "division/\(season)/\(step).\(within)"
    }
}
