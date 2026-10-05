import ScopaRewards
import SwiftUI

/// The song that plays under a game, picked in the shop.
///
/// The two loops the game shipped with are free. The rest are sold, graded like every other
/// shelf, and the dearer the song the more of the band plays it. All of them keep to the house
/// key, so a cheer or a win lands on any of them. `Tools/SoundForge/songs.py` composes them.
enum Song: String, CaseIterable, Codable, Sendable, Identifiable {
    /// The lobby's own loop, which can follow you to the table.
    case lungomare
    /// The table's loop, and the one every player starts with.
    case tavolo
    case pomeriggio
    case piazza
    case barcarola
    case serenata
    case tarantella
    case mergellina

    var id: String { rawValue }

    static let stored = "tableSong"

    /// The songs the shop sells. The two house loops are never locked.
    static let forSale: [Song] = allCases.filter { $0.price != nil }

    var track: Track {
        switch self {
        case .lungomare: .lungomare
        case .tavolo: .tavolo
        case .pomeriggio: .pomeriggio
        case .piazza: .piazza
        case .barcarola: .barcarola
        case .serenata: .serenata
        case .tarantella: .tarantella
        case .mergellina: .mergellina
        }
    }

    /// A name, and the same word in every language.
    var title: String { rawValue.capitalized }

    /// Written into the ledger with a purchase, so it stays in one language.
    var detail: String {
        switch self {
        case .lungomare: "The lobby band, with a vibraphone"
        case .tavolo: "The house band, quiet"
        case .pomeriggio: "A slow guitar waltz"
        case .piazza: "An accordion over the house band"
        case .barcarola: "A boat song with a wooden flute"
        case .serenata: "A mandolin serenade"
        case .tarantella: "A tarantella with tambourine"
        case .mergellina: "A Neapolitan song, the whole band"
        }
    }

    var explanation: LocalizedStringKey {
        switch self {
        case .lungomare: "The lobby tune followed you in"
        case .tavolo: "Soft guitar and bass. Thinking music"
        case .pomeriggio: "A slow guitar waltz, at siesta pace"
        case .piazza: "An accordion across the square, no hurry"
        case .barcarola: "A boat song and a wooden flute. Row gently"
        case .serenata: "A mandolin under a window. Fingers crossed"
        case .tarantella: "Tambourine, accordion, mandolin. Try sitting still"
        case .mergellina: "Naples, the whole band, full volume"
        }
    }

    var grade: Grade {
        switch self {
        case .lungomare, .tavolo, .pomeriggio, .piazza: .comune
        case .barcarola, .serenata: .raro
        case .tarantella: .prezioso
        case .mergellina: .leggendario
        }
    }

    /// Priced just under what a pack pays for a missing thing at the same grade.
    var price: Denari? {
        switch self {
        case .lungomare, .tavolo: nil
        case .pomeriggio, .piazza: 150
        case .barcarola, .serenata: 260
        case .tarantella: 500
        case .mergellina: 950
        }
    }
}
