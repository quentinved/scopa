import ScopaCore
import SwiftUI

/// What is drawn around a seat mark. It travels on the wire beside `mark` and `honour`,
/// because the table can see it.
///
/// No cornice is ever metal: metal is `Prestige`, which is earned by winning. A bought
/// cornice is made of rope, flowers, ribbon or paint instead.
enum Cornice: String, CaseIterable, Codable, Sendable, Identifiable {
    /// A bare mark, which is what everybody starts with.
    case none
    /// Braided cord, the kind round a curtain.
    case corda
    /// A ring of small flowers.
    case fiori
    /// A ribbon, tied at the bottom.
    case nastro
    /// A painted wave border, off a plate.
    case onde

    var id: String { rawValue }

    /// The ones the shop sells. `none` is not among them: it is never locked.
    static let forSale: [Cornice] = [.corda, .fiori, .nastro, .onde]

    /// Where the phone keeps its owner's choice.
    static let stored = "cornice"

    /// What goes on the wire. Nothing for the bare mark, so a build that knows no such
    /// field reads a player exactly as before.
    var wireValue: String? { self == .none ? nil : rawValue }

    init(_ player: Player) {
        self = player.cornice.flatMap(Cornice.init(rawValue:)) ?? .none
    }

    var title: String {
        switch self {
        case .none: "Bare"
        case .corda: "Corda"
        case .fiori: "Fiori"
        case .nastro: "Nastro"
        case .onde: "Onde"
        }
    }

    /// Written into the ledger with a purchase, so it stays in one language.
    var detail: String {
        switch self {
        case .none: "Nothing round the mark"
        case .corda: "Braided cord"
        case .fiori: "A ring of small flowers"
        case .nastro: "A ribbon, tied at the bottom"
        case .onde: "A painted wave border"
        }
    }

    /// The line under the swatch in the shop.
    var explanation: LocalizedStringKey {
        switch self {
        case .none: "The mark on its own"
        case .corda: "Twisted, like a curtain rope"
        case .fiori: "Six of them, in gold"
        case .nastro: "Tied under your name"
        case .onde: "Off a Ligurian plate"
        }
    }

    /// How far past the circle it reaches, as a multiple of the badge size. Same contract
    /// as `Prestige.reach`.
    var reach: CGFloat {
        switch self {
        case .none: 1.00
        case .corda, .onde: 1.22
        case .fiori: 1.28
        case .nastro: 1.34
        }
    }

    /// How wide the ring is drawn, as a multiple of the circle it is set outside — the
    /// `ring` each style below is measured against, not the badge. A caller with a slot
    /// to fill multiplies the two: a ring set outside a laurel is half as wide again as
    /// the badge under it.
    var spread: CGFloat {
        switch self {
        case .none: 1.00
        case .corda: 1.24
        case .fiori: 1.30
        case .nastro, .onde: 1.32
        }
    }
}

/// The ring itself, drawn outside a badge.
///
/// Like `PrestigePlate` it takes no layout with it, so a badge can wear a cornice, its
/// metal and this week's laurel at once and still measure the same.
struct CorniceRing: View {
    var cornice: Cornice
    var size: CGFloat
    /// How far out to start, as a multiple of the badge, to clear whatever the badge is
    /// already wearing. Armour reaches 1.52, and a ring drawn inside that is swallowed.
    var outset: CGFloat = 1

    /// Everything is drawn against this rather than `size`, so one number moves the ring.
    private var ring: CGFloat { size * outset }

    var body: some View {
        switch cornice {
        case .none: EmptyView()
        case .corda: corda
        case .fiori: fiori
        case .nastro: nastro
        case .onde: onde
        }
    }

    // MARK: Corda

    /// Twenty short strands laid end to end round the circle.
    ///
    /// The lean is measured off the tangent rather than the radius: strands pointing away
    /// from the circle read as a sunburst of spikes instead of a twist.
    private var corda: some View {
        let radius = ring * 0.58
        return ZStack {
            ForEach(0..<20, id: \.self) { index in
                let angle = Double(index) / 20 * 360
                Capsule()
                    .fill(index.isMultiple(of: 2) ? Palette.linen : Palette.linenDeep)
                    .frame(width: size * 0.05, height: size * 0.19)
                    .rotationEffect(.degrees(66))
                    .offset(y: -radius)
                    .rotationEffect(.degrees(angle))
            }
        }
        .frame(width: ring * 1.24, height: ring * 1.24)
        .shadow(color: .black.opacity(0.3), radius: size * 0.02, y: size * 0.01)
    }

    // MARK: Fiori

    /// Six flowers round the circle, five petals each. Flat gold with no rim or sheen, so
    /// they never read as prestige metal.
    private var fiori: some View {
        let radius = ring * 0.58
        return ZStack {
            ForEach(0..<6, id: \.self) { index in
                let angle = Double(index) / 6 * 2 * .pi - .pi / 2
                flower
                    .offset(x: cos(angle) * radius, y: sin(angle) * radius)
            }
        }
        .frame(width: ring * 1.26, height: ring * 1.26)
    }

    private var flower: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { petal in
                Circle()
                    .fill(Palette.goldLight)
                    .frame(width: size * 0.075, height: size * 0.075)
                    .offset(y: -size * 0.055)
                    .rotationEffect(.degrees(Double(petal) / 5 * 360))
            }
            Circle()
                .fill(Palette.terracotta)
                .frame(width: size * 0.055, height: size * 0.055)
        }
    }

    // MARK: Nastro

    /// A ribbon round the circle, tied in a bow at the bottom.
    ///
    /// Cream rather than terracotta, which is the first seat's colour and vanishes on it.
    /// A bow rather than two hanging tails, which read as a hand mirror.
    private var nastro: some View {
        let band = ring * 1.14
        return ZStack {
            Circle()
                .strokeBorder(Palette.linen, lineWidth: size * 0.085)
                .frame(width: band, height: band)
            Circle()
                .strokeBorder(Palette.terracotta.opacity(0.8), lineWidth: size * 0.02)
                .frame(width: band - size * 0.072, height: band - size * 0.072)
            Circle()
                .strokeBorder(Palette.terracotta.opacity(0.8), lineWidth: size * 0.02)
                .frame(width: band + size * 0.072, height: band + size * 0.072)
            bow.offset(y: band * 0.5)
        }
        .shadow(color: .black.opacity(0.28), radius: size * 0.025, y: size * 0.012)
    }

    /// Two loops, two short ends and a knot over the join.
    private var bow: some View {
        ZStack {
            loop(leaning: -34)
            loop(leaning: 34)
            tail(leaning: -26)
            tail(leaning: 26)
            Circle()
                .fill(Palette.linen)
                .frame(width: size * 0.15, height: size * 0.15)
                .overlay {
                    Circle().strokeBorder(Palette.terracotta.opacity(0.8), lineWidth: size * 0.02)
                }
        }
    }

    private func loop(leaning: Double) -> some View {
        Ellipse()
            .fill(Palette.linen)
            .frame(width: size * 0.20, height: size * 0.13)
            .overlay {
                Ellipse().strokeBorder(Palette.terracotta.opacity(0.55), lineWidth: size * 0.016)
            }
            .offset(x: leaning < 0 ? -size * 0.11 : size * 0.11)
            .rotationEffect(.degrees(leaning))
    }

    private func tail(leaning: Double) -> some View {
        Capsule()
            .fill(Palette.linen)
            .frame(width: size * 0.065, height: size * 0.15)
            .rotationEffect(.degrees(leaning), anchor: .top)
            .offset(y: size * 0.05)
    }

    // MARK: Onde

    /// Sixteen small arcs round the rim: glaze white over a blue line, since a green
    /// scallop on a green table cannot be seen.
    private var onde: some View {
        let radius = ring * 0.585
        return ZStack {
            Circle()
                .strokeBorder(Palette.seaGlaze, lineWidth: size * 0.035)
                .frame(width: ring * 1.06, height: ring * 1.06)
            ForEach(0..<16, id: \.self) { index in
                let angle = Double(index) / 16 * 2 * .pi - .pi / 2
                Circle()
                    .trim(from: 0.5, to: 1)
                    .stroke(Palette.linen, style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round))
                    .frame(width: size * 0.17, height: size * 0.17)
                    .rotationEffect(.degrees(Double(index) / 16 * 360))
                    .offset(x: cos(angle) * radius, y: sin(angle) * radius)
            }
        }
        .frame(width: ring * 1.2, height: ring * 1.2)
        .shadow(color: .black.opacity(0.3), radius: size * 0.025, y: size * 0.012)
    }
}
