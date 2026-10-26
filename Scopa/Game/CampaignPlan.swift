import ScopaCore

/// The road itself, region by region. Ids are written down against the stars, so a stage
/// keeps its id for good once shipped; places and names may change freely.
///
/// Difficulty climbs one pip about every six tables: Liguria teaches, Piemonte holds the
/// easy bot a little longer while the twists arrive, Napoli and Sicilia ask for the normal
/// bot's full attention, Venezia brings in the search, Roma never lets it go. The twists
/// are tables the engine already deals: three or four chairs, a partner, a clock, the
/// classic primiera, a longer game. Piemonte, put in after the rest had shipped, keeps the
/// classic rules; each region after it teaches one house rule of its own: the napola in
/// Napoli, asso piglia tutto in Sicilia, re bello in Venezia, and the scopone in Roma.
///
/// The games are short: six points for most tables, seven for a longer one, eight at most
/// for the last tables of the road. Eleven made a sitting of a single table. A game already
/// dealt keeps the target it was dealt with.
///
/// The second road, after Roma, has no stronger bot to climb to: it stays at the normal and
/// the hard ones and changes the game instead. Toscana starts you behind, Puglia plays a
/// single round, Sardegna deals every hand face up, and Lombardia sits you down three times
/// in a row. Each mode stays on the road once taught, mixed with the twists of the first.
/// A comeback is two points at every target: measured between level players, it leaves
/// the one behind about one game in three.
extension CampaignRegion {
    typealias Plan = CampaignStage.Plan
    typealias Rival = CampaignStage.Rival

    static let plan: [[Plan]] = [ligurian, piedmontese, neapolitan, sicilian, venetian, roman,
                                 tuscan, apulian, sardinian, lombard]

    private static let oneRound = CampaignStage.oneRound

    private static let ligurian: [Plan] = [
        Plan(id: "genova", place: "Genova", opponent: "Laurence", difficulty: 1, target: 5),
        Plan(id: "camogli", place: "Camogli", opponent: "Lucas", difficulty: 1, target: 6),
        Plan(id: "portofino", place: "Portofino", opponent: "Camille", difficulty: 2, target: 6),
        Plan(id: "vernazza", place: "Vernazza", opponent: "Alexis", difficulty: 2, target: 6, seating: .three),
        Plan(id: "sanremo", place: "Sanremo", opponent: "Arthur", difficulty: 2, target: 6, seating: .teams),
        Plan(id: "portovenere", place: "Portovenere", opponent: "Hugo", difficulty: 3, target: 7),
    ]

    // Turin and its hills: four chairs, a clock at the Palio town, the old count at Barolo.
    private static let piedmontese: [Plan] = [
        Plan(id: "torino", place: "Torino", opponent: "Arthur", difficulty: 2, target: 6),
        Plan(id: "langhe", place: "Langhe", opponent: "Timothée", difficulty: 2, target: 6, seating: .four),
        Plan(id: "asti", place: "Asti", opponent: "Camille", difficulty: 2, target: 6, clock: .relaxed),
        Plan(id: "barolo", place: "Barolo", opponent: "Loïc", difficulty: 3, target: 6, primiera: .classic),
        Plan(id: "murazzi", place: "Murazzi del Po", opponent: "Alexis", difficulty: 3, target: 6, seating: .teams),
        Plan(id: "mole", place: "Mole Antonelliana", opponent: "Hugo", difficulty: 3, target: 7),
    ]

    private static let neapolitan: [Plan] = [
        Plan(id: "pozzuoli", place: "Pozzuoli", opponent: "Loïc", difficulty: 2, target: 6),
        Plan(id: "spaccanapoli", place: "Spaccanapoli", opponent: "Timothée", difficulty: 3, target: 6,
             primiera: .classic),
        Plan(id: "posillipo", place: "Posillipo", opponent: "Laurence", difficulty: 3, target: 6, seating: .three,
             house: [.napola]),
        Plan(id: "sorrento", place: "Sorrento", opponent: "Camille", difficulty: 3, target: 6, seating: .teams),
        Plan(id: "capri", place: "Capri", opponent: "Lucas", difficulty: 3, target: 7, house: [.napola]),
        Plan(id: "vesuvio", place: "Vesuvio", opponent: "Hugo", difficulty: 4, target: 7, house: [.napola]),
    ]

    private static let sicilian: [Plan] = [
        Plan(id: "palermo", place: "Palermo", opponent: "Alexis", difficulty: 3, target: 6, clock: .relaxed),
        Plan(id: "cefalu", place: "Cefalù", opponent: "Arthur", difficulty: 3, target: 7, house: [.assoPigliaTutto]),
        Plan(id: "taormina", place: "Taormina", opponent: "Timothée", difficulty: 4, target: 6, seating: .four,
             house: [.assoPigliaTutto]),
        Plan(id: "siracusa", place: "Siracusa", opponent: "Loïc", difficulty: 4, target: 6, primiera: .classic),
        Plan(id: "agrigento", place: "Agrigento", opponent: "Laurence", difficulty: 4, target: 7, seating: .teams),
        Plan(id: "etna", place: "Etna", opponent: "Hugo", difficulty: 4, target: 8, house: [.assoPigliaTutto]),
    ]

    private static let venetian: [Plan] = [
        Plan(id: "murano", place: "Murano", opponent: "Camille", difficulty: 4, target: 6),
        Plan(id: "burano", place: "Burano", opponent: "Lucas", difficulty: 4, target: 6, clock: .brisk,
             house: [.reBello]),
        Plan(id: "rialto", place: "Rialto", opponent: "Arthur", difficulty: 4, target: 7, seating: .three,
             house: [.reBello]),
        Plan(id: "sanmarco", place: "San Marco", opponent: "Alexis", difficulty: 5, target: 6),
        Plan(id: "lido", place: "Lido", opponent: "Timothée", difficulty: 5, target: 7, seating: .teams),
        Plan(id: "canalgrande", place: "Canal Grande", opponent: "Hugo", difficulty: 5, target: 8, house: [.reBello]),
    ]

    private static let roman: [Plan] = [
        Plan(id: "trastevere", place: "Trastevere", opponent: "Loïc", difficulty: 5, target: 6),
        Plan(id: "testaccio", place: "Testaccio", opponent: "Laurence", difficulty: 5, target: 7, primiera: .classic),
        Plan(id: "campodefiori", place: "Campo de' Fiori", opponent: "Camille", difficulty: 5, target: 7,
             seating: .four),
        Plan(id: "pantheon", place: "Pantheon", opponent: "Arthur", difficulty: 5, target: 7, clock: .relaxed),
        Plan(id: "colosseo", place: "Colosseo", opponent: "Lucas", difficulty: 5, target: 7, seating: .teams,
             house: [.scopone]),
        // The first road's last table: every rule its regions taught, at once.
        Plan(id: "trevi", place: "Fontana di Trevi", opponent: "Hugo", difficulty: 5, target: 8,
             house: [.napola, .assoPigliaTutto, .reBello]),
    ]

    // A start behind, from the first table: the normal bot, then the hard one by the bridge.
    private static let tuscan: [Plan] = [
        Plan(id: "firenze", place: "Firenze", opponent: "Arthur", difficulty: 4, target: 6, deficit: 2),
        Plan(id: "siena", place: "Siena", opponent: "Camille", difficulty: 5, target: 6, clock: .brisk),
        Plan(id: "pisa", place: "Pisa", opponent: "Lucas", difficulty: 4, target: 7, seating: .teams, deficit: 2),
        Plan(id: "sangimignano", place: "San Gimignano", opponent: "Laurence", difficulty: 5, target: 7,
             primiera: .classic),
        Plan(id: "montalcino", place: "Montalcino", opponent: "Loïc", difficulty: 5, target: 7, seating: .four,
             house: [.reBello]),
        Plan(id: "pontevecchio", place: "Ponte Vecchio", opponent: "Hugo", difficulty: 5, target: 8, deficit: 2),
    ]

    // One round decides. Castel del Monte's re bello puts five points on the cloth, so a
    // level round is rarer there.
    private static let apulian: [Plan] = [
        Plan(id: "bari", place: "Bari", opponent: "Alexis", difficulty: 4, target: oneRound),
        Plan(id: "alberobello", place: "Alberobello", opponent: "Timothée", difficulty: 5, target: 7,
             seating: .four, house: [.assoPigliaTutto]),
        Plan(id: "polignano", place: "Polignano a Mare", opponent: "Lucas", difficulty: 4, target: oneRound,
             seating: .three),
        Plan(id: "lecce", place: "Lecce", opponent: "Loïc", difficulty: 5, target: 7, primiera: .classic,
             deficit: 2),
        Plan(id: "ostuni", place: "Ostuni", opponent: "Camille", difficulty: 5, target: oneRound,
             house: [.napola, .reBello]),
        Plan(id: "casteldelmonte", place: "Castel del Monte", opponent: "Hugo", difficulty: 5, target: oneRound,
             house: [.reBello]),
    ]

    // Every hand face up. The search then sees yours as you see its, and only the stock is
    // left to guess, so the first face-up tables are the normal bot's.
    private static let sardinian: [Plan] = [
        Plan(id: "cagliari", place: "Cagliari", opponent: "Laurence", difficulty: 4, target: 6, openHands: true),
        Plan(id: "alghero", place: "Alghero", opponent: "Arthur", difficulty: 5, target: 7, clock: .brisk,
             house: [.napola]),
        Plan(id: "costasmeralda", place: "Costa Smeralda", opponent: "Camille", difficulty: 4, target: 6,
             seating: .three, openHands: true),
        Plan(id: "nuoro", place: "Nuoro", opponent: "Lucas", difficulty: 5, target: 7, deficit: 2),
        Plan(id: "maddalena", place: "La Maddalena", opponent: "Timothée", difficulty: 5, target: oneRound,
             openHands: true),
        Plan(id: "nuraxi", place: "Su Nuraxi", opponent: "Hugo", difficulty: 5, target: 7, openHands: true),
    ]

    // Three games in a row, short ones. The last table is the whole road's: three players,
    // the hard bot last.
    private static let lombard: [Plan] = [
        Plan(id: "bergamo", place: "Bergamo", opponent: "Alexis", difficulty: 5, target: 7, seating: .four,
             clock: .relaxed),
        Plan(id: "como", place: "Lago di Como", opponent: "Arthur", difficulty: 5, target: 4,
             rivals: [Rival(opponent: "Lucas", difficulty: 4), Rival(opponent: "Laurence", difficulty: 4)]),
        Plan(id: "mantova", place: "Mantova", opponent: "Loïc", difficulty: 5, target: 7, deficit: 2,
             openHands: true),
        Plan(id: "navigli", place: "Navigli", opponent: "Timothée", difficulty: 5, target: oneRound,
             seating: .teams, house: [.scopone]),
        Plan(id: "scala", place: "La Scala", opponent: "Camille", difficulty: 5, target: 7,
             house: [.napola, .reBello], openHands: true),
        Plan(id: "duomo", place: "Duomo di Milano", opponent: "Hugo", difficulty: 5, target: 5,
             rivals: [Rival(opponent: "Laurence", difficulty: 4), Rival(opponent: "Loïc", difficulty: 5)]),
    ]
}
