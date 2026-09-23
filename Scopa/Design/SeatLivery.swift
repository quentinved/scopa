import ScopaCore
import ScopaRewards
import SwiftUI

/// The colour a seat mark is struck in: your icon, and the first thing anybody across the
/// table sees of you.
///
/// It travels on the wire beside `mark` and `cornice`, because a colour nobody else can
/// see is a colour nobody would buy. `tavolo` is what everyone starts on — the seat colour
/// the table itself hands out, which is why a livery is drawn against a seat tint rather
/// than instead of one.
///
/// The cheap liveries are flat paint. The dear ones are not paint at all: gold is a struck
/// sheen, night is steel with a hairline of gold cut round it, and iride moves through four
/// colours across the circle. That is the whole difference between a `comune` and a
/// `leggendario` here, and it is meant to be visible at 26 points in a lobby chip.
enum SeatLivery: String, CaseIterable, Codable, Sendable, Identifiable {
    /// The seat colour the table deals you, which changes chair to chair. Free, and what a
    /// player who has never opened the shop is wearing.
    case tavolo
    case terracotta
    case lavanda
    case oliva
    case mare
    case rubino
    /// Struck gold, not painted yellow.
    case oro
    /// Steel gone almost to black, with a gold hairline.
    case notte
    /// Four colours across one circle.
    case iride

    var id: String { rawValue }

    /// Where the phone keeps its owner's choice.
    static let stored = "livery"

    /// The ones the shop sells. `tavolo` is not among them: it is never locked.
    static let forSale: [SeatLivery] = allCases.filter { $0 != .tavolo }

    /// What goes on the wire. Nothing for the table's own colour, so a build that knows no
    /// such field reads a player exactly as before.
    var wireValue: String? { self == .tavolo ? nil : rawValue }

    init(_ player: Player) {
        self = player.livery.flatMap(SeatLivery.init(rawValue:)) ?? .tavolo
    }

    /// A name, and the same word in every language.
    var title: String {
        switch self {
        case .tavolo: "Tavolo"
        case .terracotta: "Terracotta"
        case .lavanda: "Lavanda"
        case .oliva: "Oliva"
        case .mare: "Mare"
        case .rubino: "Rubino"
        case .oro: "Oro"
        case .notte: "Notte"
        case .iride: "Iride"
        }
    }

    /// Written into the ledger with a purchase, so it stays in one language.
    var detail: String {
        switch self {
        case .tavolo: "The colour of the chair you sat in"
        case .terracotta: "Fired clay"
        case .lavanda: "Lavender"
        case .oliva: "Olive"
        case .mare: "Adriatic blue"
        case .rubino: "Deep ruby"
        case .oro: "Struck gold"
        case .notte: "Steel at night, edged in gold"
        case .iride: "Four colours across one circle"
        }
    }

    /// The line under the swatch in the shop.
    var explanation: LocalizedStringKey {
        switch self {
        case .tavolo: "Whatever chair you get"
        case .terracotta: "Fired clay"
        case .lavanda: "Lavender"
        case .oliva: "Olive"
        case .mare: "Adriatic blue"
        case .rubino: "Deep ruby"
        case .oro: "Struck, not painted"
        case .notte: "Steel, edged in gold"
        case .iride: "It moves as it turns"
        }
    }

    /// The flat colour, which is what a tiny swatch or a text tint needs. The dear liveries
    /// answer with the nearest single colour they have.
    func plain(seat: Color) -> Color {
        switch self {
        case .tavolo: seat
        case .terracotta: Palette.terracotta
        case .lavanda: Color(red: 0.522, green: 0.435, blue: 0.639)
        case .oliva: Color(red: 0.400, green: 0.451, blue: 0.239)
        case .mare: Palette.seaGlaze
        case .rubino: Color(red: 0.549, green: 0.145, blue: 0.220)
        case .oro: Palette.gold
        case .notte: Palette.steel
        case .iride: Color(red: 0.400, green: 0.435, blue: 0.702)
        }
    }

    /// How the circle is actually filled. Flat paint for the cheap ones; for the rest, the
    /// thing you paid for.
    func style(seat: Color) -> AnyShapeStyle {
        switch self {
        case .oro:
            AnyShapeStyle(LinearGradient(
                colors: [Palette.goldLight, Palette.gold, Palette.goldDeep, Palette.gold],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .notte:
            AnyShapeStyle(LinearGradient(
                colors: [Color(red: 0.278, green: 0.310, blue: 0.345),
                         Color(red: 0.137, green: 0.153, blue: 0.180),
                         Color(red: 0.055, green: 0.063, blue: 0.078)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .iride:
            AnyShapeStyle(AngularGradient(
                colors: [Color(red: 0.376, green: 0.471, blue: 0.831),
                         Color(red: 0.706, green: 0.400, blue: 0.741),
                         Color(red: 0.918, green: 0.482, blue: 0.435),
                         Color(red: 0.400, green: 0.749, blue: 0.702),
                         Color(red: 0.376, green: 0.471, blue: 0.831)],
                center: .center))
        default:
            AnyShapeStyle(plain(seat: seat))
        }
    }

    /// An extra line cut round the circle, over the cream hairline every badge wears. Only
    /// the dear ones have one, and it is most of why they read as metal.
    @ViewBuilder func edge(size: CGFloat) -> some View {
        switch self {
        case .oro:
            Circle().strokeBorder(Palette.goldDeep.opacity(0.85), lineWidth: size * 0.035)
        case .notte:
            Circle().strokeBorder(Palette.goldLight.opacity(0.9), lineWidth: size * 0.035)
        case .iride:
            Circle().strokeBorder(.white.opacity(0.65), lineWidth: size * 0.03)
        default:
            EmptyView()
        }
    }

    /// The emblem's own colour. Cream on everything except gold, where cream on gold is a
    /// smudge at lobby size and the ink the cards are printed in is not.
    var emblem: Color {
        self == .oro ? Palette.ink : Palette.cream
    }

    /// How rare it is. The three that are not flat paint are the three worth grading up.
    var grade: Grade {
        switch self {
        case .tavolo: .comune
        case .terracotta, .lavanda, .oliva, .mare: .comune
        case .rubino: .raro
        case .oro, .notte: .prezioso
        case .iride: .leggendario
        }
    }
}
