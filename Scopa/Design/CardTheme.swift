import SwiftUI
import ScopaCore

/// The look of a deck, in two independent parts: how it is drawn (`CardStyle`) and what
/// colour it is printed in (`CardSkin`).
///
/// Cosmetic and device-local. Nothing in the rules or on the wire knows a deck has a look,
/// so two players at one table can each use their own.
struct CardTheme: Equatable, Sendable, Codable {
    /// The hand it is drawn in.
    var style: CardStyle
    /// The colours it is printed in.
    var skin: CardSkin

    static let `default` = CardTheme(style: .moderna, skin: .riviera)

    var face: CardFace { skin.face }

    /// How solid the colour inside a drawn shape is.
    ///
    /// A washed fill lets pale stock lighten the colour, which is the woodcut's whole
    /// effect. On dark stock the same wash drags every fill towards black, so a dark skin
    /// keeps nearly all of the fill and leans on the outline instead.
    ///
    /// The style is a parameter because the caller is one drawn shape, which knows which
    /// hand it is being drawn in.
    func fillOpacity(for style: CardStyle) -> Double { skin.isDark ? 0.88 : style.fillOpacity }

    /// The rule printed inside the card edge.
    ///
    /// A style may print its frame in its own colour, but on a dark skin the colourway
    /// wins: only the skin knows what the paper is.
    var rule: Color {
        guard let own = style.ruleTint, !skin.isDark else { return face.rule }
        return own
    }

    /// Carries across a deck saved before the look was split into style and skin. The old
    /// names were regional decks, so each maps to that region's colours.
    static func migrated(from saved: String?) -> CardTheme {
        switch saved {
        case "napoletana": CardTheme(style: .classica, skin: .napoletana)
        case "piacentina": CardTheme(style: .classica, skin: .piacentina)
        case "bergamasca": CardTheme(style: .classica, skin: .bergamasca)
        case "antica": CardTheme(style: .antica, skin: .pergamena)
        default: .default
        }
    }
}

/// A colourway. Every skin works under every style.
enum CardSkin: String, CaseIterable, Codable, Sendable, Identifiable {
    /// The house colours: cream stock, bottle green back, gold hairlines.
    case riviera
    /// Naples: warm cream, red back, deep gold.
    case napoletana
    /// Piacenza: cool paper, navy back, steel blue.
    case piacentina
    /// Bergamo: bright, with a cobalt back.
    case bergamasca
    /// Aged paper and brown ink.
    case pergamena
    /// Night: the deck printed in reverse, bone and gold on near-black stock.
    case notturna

    static let `default` = CardSkin.riviera

    var id: String { rawValue }

    /// Whether the stock is darker than the ink printed on it. Every other colourway is
    /// dark ink on pale paper, which parts of the drawing assume.
    var isDark: Bool { self == .notturna }

    var title: String {
        switch self {
        case .riviera: "Riviera"
        case .napoletana: "Napoli"
        case .piacentina: "Piacenza"
        case .bergamasca: "Bergamo"
        case .pergamena: "Pergamena"
        case .notturna: "Notturna"
        }
    }

    /// Written into the ledger with a purchase, so it stays in one language.
    var detail: String {
        switch self {
        case .riviera: "Cream and bottle green, the house colours"
        case .napoletana: "Warm cream on red"
        case .piacentina: "Cool paper on navy"
        case .bergamasca: "Bright, on cobalt"
        case .pergamena: "Aged paper and brown ink"
        case .notturna: "Bone and gold on black, printed in reverse"
        }
    }

    var face: CardFace {
        switch self {
        case .riviera: Self.rivieraFace
        case .napoletana: Self.napoletanaFace
        case .piacentina: Self.piacentinaFace
        case .bergamasca: Self.bergamascaFace
        case .notturna: Self.notturnaFace
        case .pergamena: Self.pergamenaFace
        }
    }

    private static let rivieraFace =
        CardFace(
            stock: Color(red: 0.976, green: 0.957, blue: 0.914),
            ink: Color(red: 0.118, green: 0.106, blue: 0.094),
            rule: Color(red: 0.792, green: 0.549, blue: 0.125).opacity(0.48),
            edge: Color(red: 0.118, green: 0.106, blue: 0.094).opacity(0.14),
            accent: Color(red: 0.792, green: 0.549, blue: 0.125),
            coins: Color(red: 0.792, green: 0.549, blue: 0.125),
            cups: Color(red: 0.808, green: 0.353, blue: 0.243),
            swords: Color(red: 0.259, green: 0.290, blue: 0.322),
            clubs: Color(red: 0.231, green: 0.357, blue: 0.247),
            backGround: Color(red: 0.153, green: 0.310, blue: 0.204),
            backPattern: Color(red: 0.976, green: 0.965, blue: 0.937).opacity(0.20),
            backTrim: Color(red: 0.941, green: 0.745, blue: 0.290),
            backEdge: Color(red: 0.988, green: 0.973, blue: 0.933)
        )

    private static let napoletanaFace =
        CardFace(
            stock: Color(red: 0.980, green: 0.949, blue: 0.878),
            ink: Color(red: 0.176, green: 0.122, blue: 0.090),
            rule: Color(red: 0.702, green: 0.220, blue: 0.176).opacity(0.30),
            edge: Color(red: 0.176, green: 0.122, blue: 0.090).opacity(0.16),
            accent: Color(red: 0.878, green: 0.694, blue: 0.243),
            coins: Color(red: 0.886, green: 0.671, blue: 0.204),
            cups: Color(red: 0.749, green: 0.184, blue: 0.161),
            swords: Color(red: 0.318, green: 0.376, blue: 0.435),
            clubs: Color(red: 0.443, green: 0.318, blue: 0.180),
            backGround: Color(red: 0.643, green: 0.157, blue: 0.149),
            backPattern: Color(red: 0.988, green: 0.937, blue: 0.867).opacity(0.26),
            backTrim: Color(red: 0.925, green: 0.784, blue: 0.400),
            backEdge: Color(red: 0.980, green: 0.949, blue: 0.878)
        )

    private static let piacentinaFace =
        CardFace(
            stock: Color(red: 0.965, green: 0.965, blue: 0.949),
            ink: Color(red: 0.129, green: 0.145, blue: 0.184),
            rule: Color(red: 0.176, green: 0.259, blue: 0.400).opacity(0.40),
            edge: Color(red: 0.129, green: 0.145, blue: 0.184).opacity(0.22),
            accent: Color(red: 0.784, green: 0.596, blue: 0.220),
            coins: Color(red: 0.800, green: 0.612, blue: 0.235),
            cups: Color(red: 0.694, green: 0.204, blue: 0.212),
            swords: Color(red: 0.220, green: 0.310, blue: 0.451),
            clubs: Color(red: 0.322, green: 0.400, blue: 0.298),
            backGround: Color(red: 0.157, green: 0.220, blue: 0.361),
            backPattern: Color(red: 0.949, green: 0.957, blue: 0.976).opacity(0.24),
            backTrim: Color(red: 0.831, green: 0.702, blue: 0.365),
            backEdge: Color(red: 0.965, green: 0.965, blue: 0.949)
        )

    private static let bergamascaFace =
        CardFace(
            stock: Color(red: 0.988, green: 0.973, blue: 0.945),
            ink: Color(red: 0.161, green: 0.145, blue: 0.129),
            rule: Color(red: 0.769, green: 0.184, blue: 0.180).opacity(0.28),
            edge: Color(red: 0.161, green: 0.145, blue: 0.129).opacity(0.18),
            accent: Color(red: 0.910, green: 0.729, blue: 0.216),
            coins: Color(red: 0.914, green: 0.741, blue: 0.216),
            cups: Color(red: 0.769, green: 0.184, blue: 0.180),
            swords: Color(red: 0.180, green: 0.373, blue: 0.612),
            clubs: Color(red: 0.286, green: 0.510, blue: 0.290),
            backGround: Color(red: 0.157, green: 0.322, blue: 0.545),
            backPattern: Color(red: 0.976, green: 0.965, blue: 0.937).opacity(0.26),
            backTrim: Color(red: 0.933, green: 0.780, blue: 0.310),
            backEdge: Color(red: 0.988, green: 0.973, blue: 0.945)
        )

    private static let notturnaFace =
        CardFace(
            // Near-black with a blue cast: a true black next to the felt reads as a hole.
            stock: Color(red: 0.086, green: 0.098, blue: 0.125),
            // Bone. Indices and every figure outline come off this one colour.
            ink: Color(red: 0.925, green: 0.906, blue: 0.855),
            rule: Color(red: 0.847, green: 0.706, blue: 0.373).opacity(0.55),
            // Brighter than the other skins: on a dark felt this line and its shadow
            // are all that say where the card ends.
            edge: Color(red: 0.804, green: 0.796, blue: 0.765).opacity(0.45),
            accent: Color(red: 0.878, green: 0.729, blue: 0.400),
            // The suits sit lighter than on paper: Napoli's red would be a hole here.
            coins: Color(red: 0.918, green: 0.761, blue: 0.353),
            cups: Color(red: 0.843, green: 0.384, blue: 0.341),
            swords: Color(red: 0.580, green: 0.678, blue: 0.796),
            clubs: Color(red: 0.486, green: 0.682, blue: 0.490),
            backGround: Color(red: 0.067, green: 0.082, blue: 0.118),
            backPattern: Color(red: 0.925, green: 0.906, blue: 0.855).opacity(0.16),
            backTrim: Color(red: 0.847, green: 0.706, blue: 0.373),
            // No white to make the pale margin the other skins have, so the gold trim
            // ring carries it and the stock runs to the edge.
            backEdge: Color(red: 0.086, green: 0.098, blue: 0.125)
        )

    private static let pergamenaFace =
        CardFace(
            stock: Color(red: 0.925, green: 0.882, blue: 0.796),
            ink: Color(red: 0.243, green: 0.176, blue: 0.114),
            rule: Color(red: 0.396, green: 0.298, blue: 0.204).opacity(0.45),
            edge: Color(red: 0.243, green: 0.176, blue: 0.114).opacity(0.32),
            accent: Color(red: 0.545, green: 0.400, blue: 0.235),
            coins: Color(red: 0.702, green: 0.545, blue: 0.294),
            cups: Color(red: 0.616, green: 0.294, blue: 0.220),
            swords: Color(red: 0.396, green: 0.376, blue: 0.337),
            clubs: Color(red: 0.451, green: 0.361, blue: 0.243),
            backGround: Color(red: 0.365, green: 0.278, blue: 0.192),
            backPattern: Color(red: 0.925, green: 0.882, blue: 0.796).opacity(0.28),
            backTrim: Color(red: 0.741, green: 0.620, blue: 0.435),
            backEdge: Color(red: 0.925, green: 0.882, blue: 0.796)
        )
}

/// Every colour one deck needs. Faces and backs travel together so a skin cannot be half
/// applied.
struct CardFace {
    var stock: Color
    var ink: Color
    /// The hairline rule inside the card edge.
    var rule: Color
    /// The card's outer border when it is neither picked nor outlined.
    var edge: Color
    /// Crowns, sword hilts, harness, and the settebello's rays.
    var accent: Color
    var coins: Color
    var cups: Color
    var swords: Color
    var clubs: Color
    var backGround: Color
    var backPattern: Color
    var backTrim: Color
    var backEdge: Color

    func colour(of suit: Suit) -> Color {
        switch suit {
        case .coins: coins
        case .cups: cups
        case .swords: swords
        case .clubs: clubs
        }
    }
}

extension EnvironmentValues {
    /// Read by the card views, so nothing in between has to carry it.
    @Entry var cardTheme: CardTheme = .default
}
