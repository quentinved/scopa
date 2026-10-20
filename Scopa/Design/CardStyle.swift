import SwiftUI
import ScopaCore

/// The rule printed inside a card's edge.
enum CardFrame { case none, single, double, heavy }

/// How a deck is drawn, independent of its colourway (`CardSkin`).
///
/// The figures are laid out once in `CourtArt`. Each style decides how much detail goes in
/// and how it is finished (flat colour, colour under a fine line, or a wash under a heavy
/// woodcut outline). Nothing is traced from a published deck.
enum CardStyle: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Flat and geometric, matching the app icon. The house style.
    case moderna
    /// The traditional Italian court drawn out: articulated horse, faces, folds, southern pips.
    case classica
    /// The same figures as a woodcut: heavy outline, hatching, only a wash of colour.
    case antica
    /// A lithographed Piacentine sheet: polychrome on every card, sabres crossing through foliage.
    case litografia
    /// A painted tile from Vietri: tin glaze, a cobalt edge, a lemon garland, the figures in
    /// a loose brush. The album's fifth volume is printed in it.
    case maiolica
    /// A Ravenna mosaic: marble and lapis for the numerals, gold leaf behind the courts,
    /// every card set in tesserae. The album's sixth volume is printed in it.
    case mosaico
    /// An old Venetian printed deck: ivory inside a harlequin band, the court in masks.
    /// The album's seventh volume is printed in it.
    case carnevale
    /// Sorrento marquetry: every card laid in inlaid woods. The album's eighth volume is
    /// printed in it.
    case intarsio
    /// Burano needle lace: every card worked in thread. The album's ninth volume is
    /// printed in it. Its id is `deck.merletto`, apart from the old Merletto
    /// cloth's `tapis.merletto`, and the two are stored under different keys.
    case merletto
    /// A Visconti tarot: gold leaf, lapis and tooled frames. The album's tenth volume is
    /// printed in it.
    case tarocchi

    var id: String { rawValue }

    var title: String {
        switch self {
        case .moderna: "Moderna"
        case .classica: "Classica"
        case .antica: "Antica"
        case .litografia: "Litografia"
        case .maiolica: "Maiolica"
        case .mosaico: "Mosaico"
        case .carnevale: "Carnevale"
        case .intarsio: "Intarsio"
        case .merletto: "Merletto"
        case .tarocchi: "Tarocchi"
        }
    }

    /// Written into the ledger with a purchase, so it stays in one language.
    var detail: String {
        switch self {
        case .moderna: "Flat and geometric, the house hand"
        case .classica: "The court drawn out, in full"
        case .antica: "A woodcut: outline and hatching"
        case .litografia: "A lithographed sheet, in full colour"
        case .maiolica: "A painted tile: tin glaze, cobalt and lemons"
        case .mosaico: "Set in tesserae: marble, lapis and gold leaf"
        case .carnevale: "A Venetian print: a harlequin band, the court in masks"
        case .intarsio: "Sorrento marquetry, every card in inlaid wood"
        case .merletto: "Burano lace, every card in needlepoint"
        case .tarocchi: "A Visconti tarot: gold leaf, lapis and tooled frames"
        }
    }

    /// Whether the face is painted whole by the style's own view — ground, frame, index and
    /// colours — rather than assembled from the shared parts and tinted by the colourway.
    /// The colourway still dresses the back.
    var paintsItsOwnFace: Bool {
        switch self {
        case .maiolica, .mosaico, .carnevale, .intarsio, .merletto, .tarocchi: true
        case .moderna, .classica, .antica, .litografia: false
        }
    }

    // MARK: The hand

    /// Whether manes, folds, faces and hatching are drawn. Below the flat style they read as noise.
    var isDetailed: Bool { self != .moderna }

    /// How solid the colour is. The woodcut keeps only a wash under the ink.
    var fillOpacity: Double { self == .antica ? 0.62 : 1 }

    /// Whether the deck prints from a fixed set of stones rather than tinting a card by suit.
    var isPolychrome: Bool { self == .litografia }

    /// Whether the court fills the card (a printed sheet) rather than sitting in the middle of it.
    var fillsTheCard: Bool { self == .litografia }

    /// Whether swords and batons cross one another. Only legible with curved, thin blades.
    var interlacesPips: Bool { self == .litografia }

    /// A style that prints its frame in its own colour. Nil takes the rule from the colourway.
    var ruleTint: Color? { isPolychrome ? Pigment.cobalt.opacity(0.85) : nil }

    /// The line around a filled shape. Flat colour carries none.
    var outlineOpacity: Double {
        switch self {
        case .moderna: 0
        case .classica: 0.42
        case .antica: 0.92
        case .litografia: 0.85
        case .maiolica, .mosaico, .carnevale, .intarsio, .merletto, .tarocchi: 0.42
        }
    }

    /// The outline's weight, as a fraction of the figure's size.
    var outlineWeight: CGFloat {
        switch self {
        case .moderna: 0
        case .classica: 0.016
        case .antica: 0.030
        case .litografia: 0.020
        case .maiolica, .mosaico, .carnevale, .intarsio, .merletto, .tarocchi: 0.016
        }
    }

    var frame: CardFrame {
        switch self {
        case .moderna: .single
        case .classica: .double
        case .antica: .heavy
        case .litografia: .double
        // Painted on the card by its own face.
        case .maiolica, .mosaico, .carnevale, .intarsio, .merletto, .tarocchi: .none
        }
    }
}

/// The stones a lithographed sheet is printed from. Every card uses most of them, and the suit
/// only decides which one leads.
enum Pigment {
    static let cobalt = Color(red: 0.145, green: 0.298, blue: 0.596)
    static let sky = Color(red: 0.286, green: 0.463, blue: 0.741)
    static let leaf = Color(red: 0.235, green: 0.463, blue: 0.267)
    static let olive = Color(red: 0.494, green: 0.573, blue: 0.239)
    static let vermilion = Color(red: 0.784, green: 0.196, blue: 0.153)
    static let gold = Color(red: 0.918, green: 0.706, blue: 0.196)
    static let ochre = Color(red: 0.741, green: 0.494, blue: 0.145)
    static let plum = Color(red: 0.443, green: 0.235, blue: 0.427)
    static let ivory = Color(red: 0.976, green: 0.945, blue: 0.878)
    static let ink = Color(red: 0.145, green: 0.122, blue: 0.106)

    static func lead(_ suit: Suit) -> Color {
        switch suit {
        case .coins: gold
        case .cups: vermilion
        case .swords: sky
        case .clubs: olive
        }
    }
}
