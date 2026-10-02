import ScopaCore

/// The road itself, region by region. Ids are written down against the stars, so a stage
/// keeps its id for good once shipped; places and names may change freely.
///
/// Difficulty climbs one pip about every six tables: Liguria teaches, Napoli and Sicilia
/// ask for the normal bot's full attention, Venezia brings in the search, Roma never lets
/// it go. The twists are tables the engine already deals — three or four chairs, a
/// partner, a clock, the classic primiera, a longer game.
extension CampaignRegion {
    typealias Plan = CampaignStage.Plan

    static let plan: [[Plan]] = [ligurian, neapolitan, sicilian, venetian, roman]

    private static let ligurian: [Plan] = [
        Plan(id: "genova", place: "Genova", opponent: "Laurence", difficulty: 1, target: 7),
        Plan(id: "camogli", place: "Camogli", opponent: "Lucas", difficulty: 1, target: 11),
        Plan(id: "portofino", place: "Portofino", opponent: "Camille", difficulty: 2, target: 11),
        Plan(id: "vernazza", place: "Vernazza", opponent: "Alexis", difficulty: 2, target: 11, seating: .three),
        Plan(id: "sanremo", place: "Sanremo", opponent: "Arthur", difficulty: 2, target: 11, seating: .teams),
        Plan(id: "portovenere", place: "Portovenere", opponent: "Hugo", difficulty: 3, target: 16),
    ]

    private static let neapolitan: [Plan] = [
        Plan(id: "pozzuoli", place: "Pozzuoli", opponent: "Loïc", difficulty: 2, target: 11),
        Plan(id: "spaccanapoli", place: "Spaccanapoli", opponent: "Timothée", difficulty: 3, target: 11,
             primiera: .classic),
        Plan(id: "posillipo", place: "Posillipo", opponent: "Laurence", difficulty: 3, target: 11, seating: .three),
        Plan(id: "sorrento", place: "Sorrento", opponent: "Camille", difficulty: 3, target: 11, seating: .teams),
        Plan(id: "capri", place: "Capri", opponent: "Lucas", difficulty: 3, target: 16),
        Plan(id: "vesuvio", place: "Vesuvio", opponent: "Hugo", difficulty: 4, target: 16),
    ]

    private static let sicilian: [Plan] = [
        Plan(id: "palermo", place: "Palermo", opponent: "Alexis", difficulty: 3, target: 11, clock: .relaxed),
        Plan(id: "cefalu", place: "Cefalù", opponent: "Arthur", difficulty: 3, target: 16),
        Plan(id: "taormina", place: "Taormina", opponent: "Timothée", difficulty: 4, target: 11, seating: .four),
        Plan(id: "siracusa", place: "Siracusa", opponent: "Loïc", difficulty: 4, target: 11, primiera: .classic),
        Plan(id: "agrigento", place: "Agrigento", opponent: "Laurence", difficulty: 4, target: 16, seating: .teams),
        Plan(id: "etna", place: "Etna", opponent: "Hugo", difficulty: 4, target: 21),
    ]

    private static let venetian: [Plan] = [
        Plan(id: "murano", place: "Murano", opponent: "Camille", difficulty: 4, target: 11),
        Plan(id: "burano", place: "Burano", opponent: "Lucas", difficulty: 4, target: 11, clock: .brisk),
        Plan(id: "rialto", place: "Rialto", opponent: "Arthur", difficulty: 4, target: 16, seating: .three),
        Plan(id: "sanmarco", place: "San Marco", opponent: "Alexis", difficulty: 5, target: 11),
        Plan(id: "lido", place: "Lido", opponent: "Timothée", difficulty: 5, target: 16, seating: .teams),
        Plan(id: "canalgrande", place: "Canal Grande", opponent: "Hugo", difficulty: 5, target: 21),
    ]

    private static let roman: [Plan] = [
        Plan(id: "trastevere", place: "Trastevere", opponent: "Loïc", difficulty: 5, target: 11),
        Plan(id: "testaccio", place: "Testaccio", opponent: "Laurence", difficulty: 5, target: 16, primiera: .classic),
        Plan(id: "campodefiori", place: "Campo de' Fiori", opponent: "Camille", difficulty: 5, target: 16,
             seating: .four),
        Plan(id: "pantheon", place: "Pantheon", opponent: "Arthur", difficulty: 5, target: 21, clock: .relaxed),
        Plan(id: "colosseo", place: "Colosseo", opponent: "Lucas", difficulty: 5, target: 21, seating: .teams),
        Plan(id: "trevi", place: "Fontana di Trevi", opponent: "Hugo", difficulty: 5, target: 21),
    ]
}
