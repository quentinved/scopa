import SwiftUI
import ScopaCore

/// The app's colours: cream card stock on a lit bottle-green table, gold hairlines and
/// terracotta for anything that acts.
///
/// Two families that must not be mixed. `table`/`onTable` are the ground and the lettering
/// on it, `stock`/`ink` are paper. Ink on the table is unreadable, cream on a card worse.
///
/// `nonisolated` so lookups from outside the main actor stay plain lookups: the project
/// defaults to main-actor isolation.
nonisolated enum Palette {
    // Paper.
    static let cream = Color(red: 0.988, green: 0.973, blue: 0.933)
    static let stock = Color(red: 0.976, green: 0.957, blue: 0.914)
    static let linen = Color(red: 0.937, green: 0.906, blue: 0.827)
    static let linenDeep = Color(red: 0.851, green: 0.796, blue: 0.686)
    static let ink = Color(red: 0.118, green: 0.106, blue: 0.094)
    static let inkSoft = Color(red: 0.361, green: 0.333, blue: 0.298)

    // The table, lit from the top left exactly as the icon is. These three are the riviera
    // felt's own stops and nothing else: a view drawing on the cloth — a plate, a glass
    // tint, a shadow — reads `\.tableFelt` and asks it, or it stays green on a wine table.
    static let tableLight = Color(red: 0.278, green: 0.451, blue: 0.302)
    static let table = Color(red: 0.153, green: 0.310, blue: 0.204)
    static let tableDeep = Color(red: 0.055, green: 0.180, blue: 0.114)
    /// Lettering on the table, and the quieter grade under it.
    static let onTable = Color(red: 0.976, green: 0.965, blue: 0.937)
    static let onTableSoft = Color(red: 0.741, green: 0.788, blue: 0.741)

    // Accents, taken from the icon.
    static let terracotta = Color(red: 0.808, green: 0.353, blue: 0.243)
    static let green = Color(red: 0.231, green: 0.357, blue: 0.247)
    // Deep and warm rather than ochre, which reads as mustard against the green.
    static let gold = Color(red: 0.792, green: 0.549, blue: 0.125)
    static let goldLight = Color(red: 0.941, green: 0.745, blue: 0.290)
    static let goldDeep = Color(red: 0.580, green: 0.380, blue: 0.070)
    /// Lit gold, for anything larger than a hairline: a coin, a chip, a headline.
    static let goldSheen = LinearGradient(colors: [goldLight, gold, goldDeep],
                                          startPoint: .topLeading, endPoint: .bottomTrailing)
    static let steel = Color(red: 0.259, green: 0.290, blue: 0.322)

    /// Glazed ceramic blue, used only by the wave cornice.
    static let seaGlaze = Color(red: 0.243, green: 0.400, blue: 0.569)

    /// Riviera's lit green: the dot beside a count of who is playing, and what the green
    /// cloth answers `TableFelt.accent` with. Brighter than any green on the table so it
    /// reads as lit.
    static let live = Color(red: 0.404, green: 0.816, blue: 0.451)

    /// Seats get a stable colour so players recognise themselves across screens.
    static func seat(_ index: Int) -> Color {
        [terracotta, gold, seatBlue, seatPlum][index % 4]
    }

    /// The same chairs at a table played in teams, where the question a glance asks of a
    /// face is not who is sitting there but which side they play for.
    ///
    /// Partners share the hue and differ only in tone, so a side reads the same on a face,
    /// on a card in flight and on the pill that says who the table is waiting for. Four
    /// separate hues left a four-handed table looking like three against one: nothing on
    /// the cloth said which of the three strangers was yours.
    ///
    /// Telling partners apart matters far less than telling the sides apart — one of them
    /// is you — so the tone is the quiet half of the difference and the hue the loud one.
    ///
    /// Terracotta against blue, not the terracotta and gold a table for two uses: gold is
    /// already the turn highlight, the coin and every hairline on the cloth, so a gold side
    /// reads as the side whose turn it is. The pair also survives colour blindness, which
    /// warm against warm does not.
    static func seat(_ index: Int, teams: Bool) -> Color {
        guard teams else { return seat(index) }
        return [terracotta, seatBlue, terracottaLight, seatBlueLight][index % 4]
    }

    private static let terracottaLight = Color(red: 0.925, green: 0.588, blue: 0.478)
    private static let seatBlueLight = Color(red: 0.608, green: 0.765, blue: 0.847)
    private static let seatBlue = Color(red: 0.404, green: 0.573, blue: 0.667)
    private static let seatPlum = Color(red: 0.588, green: 0.400, blue: 0.573)
}

extension Font {
    /// Condensed and heavy, standing in for the Italian signage face in the mockups.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.condensed)
    }
}

extension Suit {
    var tint: Color {
        switch self {
        case .coins: Palette.gold
        case .cups: Palette.terracotta
        case .swords: Palette.steel
        case .clubs: Palette.green
        }
    }

    var italianName: String {
        switch self {
        case .coins: "Denari"
        case .cups: "Coppe"
        case .swords: "Spade"
        case .clubs: "Bastoni"
        }
    }
}

extension Rank {
    /// Numbers all the way up: the figure in the middle marks a court card.
    var label: String { String(rawValue) }

    var italianName: String {
        switch self {
        case .ace: "Asso"
        case .knave: "Fante"
        case .knight: "Cavallo"
        case .king: "Re"
        default: String(rawValue)
        }
    }
}

extension Collection where Element == Card {
    /// "3 + 4", for the capture hint above the hand. Always highest first, whatever order
    /// the cards were tapped in.
    var rankList: String { sorted { $0.rank.rawValue > $1.rank.rawValue }.map { $0.rank.label }.joined(separator: " + ") }
}
