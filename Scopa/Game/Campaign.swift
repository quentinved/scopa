import SwiftUI
import ScopaCore
import ScopaRewards

/// The solo campaign: thirty-six tables across Italy, region by region, each a little harder
/// than the last.
///
/// Every stage is a table the engine already deals — a seat count, a target, a clock, a
/// primiera, the house rules of the region — against bots whose strength climbs through
/// the same two dials the settings and the ranked house use.
enum Campaign {
    static let stages: [CampaignStage] = CampaignRegion.allCases.flatMap(\.stages)

    static func stage(_ id: String) -> CampaignStage? { stages.first { $0.id == id } }

    /// Counted from one, as the map prints it.
    static func stage(number: Int) -> CampaignStage? { stages[safe: number - 1] }

    /// The table after the furthest one won, the first when none is, the last once it is won.
    /// A region put in ahead of won tables leaves a gap, and this still stands past it.
    static func frontier(won: (CampaignStage) -> Bool) -> CampaignStage {
        guard let furthest = stages.last(where: won) else { return stages[0] }
        return stage(number: furthest.number + 1) ?? furthest
    }
}

/// One stretch of the road, with its own ground on the map and its own prize at the end.
enum CampaignRegion: String, CaseIterable, Identifiable {
    // Shown in this order. Stars are kept by stage id, so a region can be put in anywhere.
    case liguria, piemonte, napoli, sicilia, venezia, roma

    var id: String { rawValue }

    /// The same word in every language.
    var title: String {
        switch self {
        case .liguria: "Liguria"
        case .piemonte: "Piemonte"
        case .napoli: "Napoli"
        case .sicilia: "Sicilia"
        case .venezia: "Venezia"
        case .roma: "Roma"
        }
    }

    var numeral: String { ["I", "II", "III", "IV", "V", "VI"][index] }

    var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    var tagline: LocalizedStringKey {
        switch self {
        case .liguria: "Lemon terraces and harbour cafés"
        case .piemonte: "Fog on the Po and chocolate in the cup"
        case .napoli: "Coffee, noise and quick hands"
        case .sicilia: "Sun, salt and long games"
        case .venezia: "Lamplight on the canals"
        case .roma: "Where every road ends"
        }
    }

    /// The house rule the region teaches. Liguria and Piemonte play the classic game, so
    /// nobody is lost.
    var rule: HouseRule? {
        switch self {
        case .liguria, .piemonte: nil
        case .napoli: .napola
        case .sicilia: .assoPigliaTutto
        case .venezia: .reBello
        case .roma: .scopone
        }
    }

    /// The ground the region is drawn on, lightest first.
    var ground: (light: Color, deep: Color) {
        switch self {
        case .liguria: (Color(red: 0.20, green: 0.42, blue: 0.47), Color(red: 0.08, green: 0.25, blue: 0.30))
        case .piemonte: (Color(red: 0.40, green: 0.20, blue: 0.29), Color(red: 0.21, green: 0.08, blue: 0.15))
        case .napoli: (Color(red: 0.47, green: 0.27, blue: 0.20), Color(red: 0.27, green: 0.13, blue: 0.10))
        case .sicilia: (Color(red: 0.55, green: 0.40, blue: 0.16), Color(red: 0.33, green: 0.21, blue: 0.07))
        case .venezia: (Color(red: 0.19, green: 0.21, blue: 0.38), Color(red: 0.08, green: 0.09, blue: 0.20))
        case .roma: (Color(red: 0.45, green: 0.36, blue: 0.27), Color(red: 0.24, green: 0.18, blue: 0.13))
        }
    }

    /// The pack waiting in the album once the region's last table is won.
    var pack: PackTier {
        switch self {
        case .liguria, .piemonte, .napoli: .bottega
        case .sicilia, .venezia: .velluto
        case .roma: .reliquia
        }
    }

    /// What winning the region's last table hands over, off the shop's own shelves.
    enum Prize {
        case mark(SeatMark)
        case cornice(Cornice)
        case tapis(Tapis)
    }

    var prize: Prize {
        switch self {
        case .liguria: .mark(.sail)
        case .piemonte: .mark(.wine)
        case .napoli: .mark(.espresso)
        case .sicilia: .tapis(.maiolica)
        case .venezia: .cornice(.onde)
        case .roma: .tapis(.velluto)
        }
    }

    var prizeItem: ShopItem? {
        switch prize {
        case .mark(let mark): Cosmetics.item(for: mark)
        case .cornice(let cornice): Cosmetics.item(for: cornice)
        case .tapis(let tapis): Cosmetics.item(for: tapis)
        }
    }

    var prizeTitle: String { prizeItem?.title ?? "" }

    var stages: [CampaignStage] {
        Self.plan[index].enumerated().map { offset, plan in
            CampaignStage(plan: plan, region: self, number: index * Self.perRegion + offset + 1,
                          isFinale: offset == Self.perRegion - 1)
        }
    }

    static let perRegion = 6
}

/// One table on the road.
struct CampaignStage: Identifiable, Hashable {
    /// How the chairs are filled.
    enum Seating: Hashable {
        case duel, three, four
        /// You and Hugo against two.
        case teams
    }

    struct Plan {
        let id: String
        let place: String
        let opponent: String
        let difficulty: Int
        let target: Int
        var seating: Seating = .duel
        var clock: TurnClock = .off
        var primiera: PrimieraRule = .mostSevens
        var house: Set<HouseRule> = []
    }

    let plan: Plan
    let region: CampaignRegion
    /// Counted from one across the whole road.
    let number: Int
    let isFinale: Bool

    var id: String { plan.id }
    var place: String { plan.place }
    var opponent: String { plan.opponent }
    /// One to five pips.
    var difficulty: Int { plan.difficulty }
    var target: Int { plan.target }
    var seating: Seating { plan.seating }
    var clock: TurnClock { plan.clock }
    var primiera: PrimieraRule { plan.primiera }
    var house: Set<HouseRule> { plan.house }

    static func == (a: Self, b: Self) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Playing it

extension CampaignStage {
    /// Your partner on a teams table. Never the stage's own opponent.
    static let partner = BotNames.dealer

    var teams: Bool { seating == .teams }

    /// Every chair, yours first. Partners sit opposite, as `QuickTable` seats them.
    func seats(you: String) -> [LocalSeat] {
        let others = BotNames.table.filter { $0 != opponent }
        let shift = number % others.count
        let rest = Array(others[shift...] + others[..<shift])
        let names: [String] = switch seating {
        case .duel: [opponent]
        case .three: [opponent, rest[0]]
        case .four: [opponent, rest[0], rest[1]]
        case .teams: [opponent, Self.partner, rest[0]]
        }
        return [.person(name: you)] + names.map { .bot(name: $0) }
    }

    /// The two dials behind the pips: the three settings levels, with a step between each.
    var strength: BotStrength {
        switch difficulty {
        case ...1: BotStrength(searches: false, follows: 0.5)
        case 2: BotLevel.easy.strength
        case 3: BotStrength(searches: false, follows: 0.8)
        case 4: BotLevel.normal.strength
        default: BotLevel.hard.strength
        }
    }

    /// The settings word the pips fall under.
    var level: BotLevel {
        switch difficulty {
        case ...2: .easy
        case 3, 4: .normal
        default: .hard
        }
    }
}

// MARK: - Stars and rewards

extension CampaignStage {
    /// The second star: a win by at least this many points.
    var marginGoal: Int { max(3, (target + 1) / 3) }

    /// The third star: at least this many scope over the game. A crowded table sweeps less.
    var scopeGoal: Int {
        let duel = max(1, (target + 1) / 5)
        return seating == .duel ? duel : max(1, duel - 1)
    }

    /// Stars for a finished game: one for the win, one for the margin, one for the sweeps.
    func stars(won: Bool, margin: Int, scope: Int) -> Int {
        guard won else { return 0 }
        return 1 + (margin >= marginGoal ? 1 : 0) + (scope >= scopeGoal ? 1 : 0)
    }

    /// Paid once, the first time the table is won.
    var denari: Denari {
        let base = Denari(20 + 3 * number)
        return isFinale ? base + base : base
    }

    /// Paid once, the first time the table is won with all three stars.
    static let threeStarBonus = Denari(15)
}
