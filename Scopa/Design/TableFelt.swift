import SwiftUI

/// The colour of the cloth. Only the three greens change: the lighting, the gold burst
/// and the paper grain stay put.
///
/// Cosmetic and device-local like `CardTheme`. Nothing on the wire knows it exists, so
/// everyone at a table can be sitting at a different one.
enum TableFelt: String, CaseIterable, Codable, Sendable, Identifiable {
    /// The house table, straight off the icon.
    case riviera
    /// Deep blue.
    case notte
    /// Wine red.
    case vigna
    /// Grey stone.
    case pietra
    /// Deep teal. Not for sale: earned with seven daily deals in a row.
    case festa

    static let `default` = TableFelt.riviera

    var id: String { rawValue }

    var title: String {
        switch self {
        case .riviera: "Riviera"
        case .notte: "Notte"
        case .vigna: "Vigna"
        case .pietra: "Pietra"
        case .festa: "Festa"
        }
    }

    /// Written into the ledger with a purchase, so it stays in one language.
    var detail: String {
        switch self {
        case .riviera: "The house table, bottle green"
        case .notte: "Deep blue, after closing"
        case .vigna: "Wine, poured on the cloth"
        case .pietra: "Grey stone, for a quiet room"
        case .festa: "Deep teal, seven evenings in a row"
        }
    }

    /// The lit edge, top left.
    var light: Color {
        switch self {
        case .riviera: Palette.tableLight
        case .notte: Color(red: 0.239, green: 0.361, blue: 0.514)
        case .vigna: Color(red: 0.478, green: 0.263, blue: 0.310)
        case .pietra: Color(red: 0.400, green: 0.412, blue: 0.427)
        case .festa: Color(red: 0.231, green: 0.490, blue: 0.482)
        }
    }

    /// The body of the cloth.
    var base: Color {
        switch self {
        case .riviera: Palette.table
        case .notte: Color(red: 0.129, green: 0.231, blue: 0.365)
        case .vigna: Color(red: 0.337, green: 0.153, blue: 0.204)
        case .pietra: Color(red: 0.267, green: 0.278, blue: 0.298)
        case .festa: Color(red: 0.125, green: 0.349, blue: 0.353)
        }
    }

    /// The shadowed corner, bottom right.
    var deep: Color {
        switch self {
        case .riviera: Palette.tableDeep
        case .notte: Color(red: 0.047, green: 0.114, blue: 0.216)
        case .vigna: Color(red: 0.196, green: 0.063, blue: 0.098)
        case .pietra: Color(red: 0.137, green: 0.145, blue: 0.161)
        case .festa: Color(red: 0.047, green: 0.200, blue: 0.212)
        }
    }
}

extension TableFelt {
    /// The lit colour that goes with the cloth, for anything that has to read as itself
    /// rather than as the table: the turn clock while there is still time, a chip that is
    /// neither a warning nor a prize.
    ///
    /// Hand-picked rather than derived from `light`, which is the cloth's own lighting and
    /// disappears against it. All five stay clear of terracotta, which is what the same
    /// controls turn when something is going wrong.
    var accent: Color {
        switch self {
        case .riviera: Palette.live
        case .notte: Color(red: 0.376, green: 0.643, blue: 0.918)
        case .vigna: Color(red: 0.882, green: 0.435, blue: 0.576)
        case .pietra: Color(red: 0.741, green: 0.769, blue: 0.800)
        case .festa: Color(red: 0.310, green: 0.812, blue: 0.769)
        }
    }

    /// The cloth's own shadow, at the strength asked for. What glass over the table is
    /// tinted with, and what anything on it drops.
    func shade(_ opacity: Double) -> Color { deep.opacity(opacity) }

    /// A plate cut from the cloth, lit from the same corner the table is. The ends are
    /// given where a card is lit down the page rather than across it.
    func plate(from start: UnitPoint = .topLeading, to end: UnitPoint = .bottomTrailing) -> LinearGradient {
        LinearGradient(colors: [base, deep], startPoint: start, endPoint: end)
    }
}

extension EnvironmentValues {
    /// Read by `TableGround`, so nothing in between has to carry it.
    @Entry var tableFelt: TableFelt = .default
}
