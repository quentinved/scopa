/// How rare a thing in the shop is, and how rarely a pack hands one over.
///
/// The album already grades the deck — a numeral, a court, a seven, the settebello — and
/// this is the same idea for everything that is not a card. It exists because a price tag
/// is a poor way of saying "rare": four hundred denari reads as expensive, not as scarce,
/// and the thing a collector wants to know is how few people have it.
///
/// The words are Italian and stay Italian, like every other proper name in the shop. They
/// are not translated: a grade is a name, the way Napoli and Piacenza are.
public enum Grade: Int, CaseIterable, Codable, Sendable, Hashable, Comparable {
    /// On the shelves from the first day, and cheap.
    case comune
    /// Worth saving for.
    case raro
    /// Few of these, and every one of them does something the cheap ones do not.
    case prezioso
    /// The top of the shop. Never in the earned packs, and never cheap.
    case leggendario

    public static func < (a: Grade, b: Grade) -> Bool { a.rawValue < b.rawValue }

    public var title: String {
        switch self {
        case .comune: "Comune"
        case .raro: "Raro"
        case .prezioso: "Prezioso"
        case .leggendario: "Leggendario"
        }
    }

    /// How often a cosmetic slot lands on this grade, before a pack's own floor is applied.
    ///
    /// Weighed rather than fixed, so a tier that guarantees at least `prezioso` still hands
    /// over a `leggendario` sometimes — the reason to open the dear one twice.
    ///
    /// The numbers are set by what the *floored* packs print rather than by the bare
    /// ladder, because no pack with a cosmetic slot has a `comune` floor: what a player
    /// ever sees is a slot floored at `raro` or at `prezioso`. Raising a floor throws the
    /// weight it removes onto everything above it, so a top grade that looks scarce on the
    /// ladder can read as routine inside a `reliquia` — the reason `leggendario` sits
    /// nineteen to one under `prezioso`, which is what makes it one slot in twenty there
    /// rather than one in four.
    public var weight: Double {
        switch self {
        case .comune: 100
        case .raro: 50
        case .prezioso: 19
        case .leggendario: 1
        }
    }

    /// The grades this one may stand in for when the shop has nothing left at it. A pack
    /// that cannot pay in `leggendario` because the player owns them all falls to
    /// `prezioso` rather than paying nothing.
    public var orBelow: [Grade] {
        Grade.allCases.filter { $0 <= self }.reversed()
    }

    /// Picks one grade at or above `floor`.
    public static func draw(atLeast floor: Grade = .comune,
                            using generator: inout some RandomNumberGenerator) -> Grade {
        let eligible = allCases.filter { $0 >= floor }
        let total = eligible.reduce(0.0) { $0 + $1.weight }
        var roll = Double.random(in: 0..<total, using: &generator)
        for grade in eligible {
            roll -= grade.weight
            if roll < 0 { return grade }
        }
        return eligible.last ?? floor
    }

    /// What one thing at this grade is worth in denari.
    ///
    /// Two places need a grade priced rather than described. A pack that owed something at
    /// a grade and found the shop bare pays this instead, so opening the dear pack when
    /// you already own most of a shelf is never a loss you can feel. And the shop's own
    /// packs are priced off it: a pack that promises two `raro` asks what two `raro` are
    /// worth, and what you give up for the discount above the floor is the choosing.
    ///
    /// Set a little above what each grade's cheapest items cost, so the consolation is
    /// always enough to go and buy one of them.
    public static func denari(for grade: Grade) -> Denari {
        switch grade {
        case .comune: 150
        case .raro: 280
        case .prezioso: 520
        case .leggendario: 1000
        }
    }

    /// What share of cosmetic slots land on this grade in a pack with the given floor,
    /// which is what the shop prints under a pack so the odds are never a secret.
    public static func chance(of grade: Grade, atLeast floor: Grade) -> Double {
        guard grade >= floor else { return 0 }
        let eligible = allCases.filter { $0 >= floor }
        let total = eligible.reduce(0.0) { $0 + $1.weight }
        return grade.weight / total
    }
}
