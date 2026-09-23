import ScopaRewards
import SwiftUI

/// A sealed pack, drawn at any size.
///
/// The cheap one is the player's own deck tied with a paper band, which is what a pack has
/// always looked like here and is deliberately modest. The bought ones are wrapped: foil in
/// the tier's colours, a seal, and — for the dear ones — the same plates and rays a seat
/// mark wears, because that language already means "this was not cheap" everywhere else in
/// the game and inventing a second one would be inventing a second one.
///
/// The two shelves are told apart by colour before they are read. The album's packs are
/// cool — blue, then violet, then gold — and the shop's are warm: a chest of tooled leather
/// and brass, and a strongbox of oxblood and gold. Somebody who has opened one of each
/// knows which page a pack came off without looking at the name on it.
///
/// Every wrapper has to stand off a green cloth, which is the one thing that rules colours
/// out here. Malachite was the obvious colour for a strongbox and it was unusable: the pack
/// and its rays both sank into the felt behind them.
///
/// Nothing is imported. The band, the foil and the seal are gradients and shapes, so a pack
/// can be drawn at 34 points in a lobby chip and at 240 in the middle of an opening.
struct PackArt: View {
    var tier: PackTier = .mazzetto
    var width: CGFloat
    /// The sheen slides across a wrapped pack while it waits to be torn. Off for the tiles
    /// in a list, where eight things catching the light is a list nobody can read.
    var alive = false

    @Environment(\.cardBack) private var back
    /// What the piece drops on the cloth, so the shadow is the table's own colour.
    @Environment(\.tableFelt) private var felt
    @State private var glint: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var height: CGFloat { width * 1.42 }

    /// How far down the pack the serrated line runs, as a fraction of its height. The
    /// opening tears along it, so the drawing and the tearing agree on one number.
    static let tearLine: CGFloat = 0.2

    /// The whole space a pack takes when laid out, padding for the rays included.
    static func footprint(_ tier: PackTier, width: CGFloat) -> CGSize {
        let pad = PackLook.hasRays(tier) ? width * 0.3 : 0
        return CGSize(width: width + pad * 2, height: width * 1.42 + pad * 2)
    }

    var body: some View {
        Group {
            if tier == .mazzetto { tiedDeck } else { wrapped }
        }
        .frame(width: width, height: height)
        // The rays on the two dear packs draw well outside the wrapper. Reserving the room
        // here rather than at each call site is what stops a `reliquia` throwing light
        // across the title next to it in a list.
        .padding(PackLook.hasRays(tier) ? width * 0.3 : 0)
        .frame(width: PackArt.footprint(tier, width: width).width,
               height: PackArt.footprint(tier, width: width).height)
        .onAppear {
            guard alive, !reduceMotion, tier != .mazzetto else { return }
            withAnimation(.linear(duration: 2.6).delay(0.5).repeatForever(autoreverses: false)) {
                glint = 1.6
            }
        }
    }

    // MARK: The earned pack

    /// Two of the player's own card backs, fanned and banded. Their deck, not a wrapper.
    private var tiedDeck: some View {
        ZStack {
            CardBack(width: width * 0.78).rotationEffect(.degrees(-11)).offset(x: -width * 0.11)
            CardBack(width: width * 0.78).rotationEffect(.degrees(6)).offset(x: width * 0.07)
            Capsule()
                .fill(Palette.goldSheen)
                .frame(width: width * 1.02, height: height * 0.14)
                .overlay {
                    Capsule().strokeBorder(Palette.goldDeep.opacity(0.6), lineWidth: width * 0.012)
                }
                .shadow(color: felt.shade(0.35), radius: width * 0.03, y: width * 0.02)
        }
    }

    // MARK: The bought packs

    private var wrapped: some View {
        ZStack {
            // Behind the foil, so what shows is the light coming out from behind the pack
            // rather than a wheel drawn across it. Over the top, the wrapper stopped
            // reading as a wrapper and the whole thing became a bright square.
            if PackLook.hasRays(tier) { rays }
            foil
            seal
        }
    }

    private var foil: some View {
        RoundedRectangle(cornerRadius: width * 0.11)
            .fill(PackLook.wrapper(tier))
            // Stated rather than inherited: the rays behind it are a square wider than the
            // pack, and a flexible shape in that ZStack grows to them.
            .frame(width: width, height: height)
            .overlay {
                // A watermark of the broom, low enough that the seal still reads over it.
                BroomMark(size: width * 0.62, tint: .white.opacity(0.10))
                    .rotationEffect(.degrees(-18))
                    .offset(y: height * 0.14)
            }
            .overlay { crimp }
            .overlay { if alive { glintSweep } }
            .overlay {
                RoundedRectangle(cornerRadius: width * 0.11)
                    .strokeBorder(PackLook.edge(tier), lineWidth: width * 0.022)
            }
            .clipShape(RoundedRectangle(cornerRadius: width * 0.11))
            .shadow(color: felt.shade(0.45), radius: width * 0.07, y: width * 0.04)
    }

    /// The serrated line a pack is torn along, near the top. It is the thing that says
    /// "this opens" before anybody has touched it.
    private var crimp: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: height * PackArt.tearLine - width * 0.025)
            ZigZag(teeth: 14)
                .stroke(.white.opacity(0.4),
                        style: StrokeStyle(lineWidth: width * 0.016, dash: [width * 0.05, width * 0.04]))
                .frame(height: width * 0.05)
            Spacer(minLength: 0)
        }
        .frame(width: width, height: height)
    }

    private var glintSweep: some View {
        LinearGradient(stops: [
            .init(color: .clear, location: 0.0),
            .init(color: .white.opacity(0.42), location: 0.46),
            .init(color: .white.opacity(0.72), location: 0.5),
            .init(color: .white.opacity(0.42), location: 0.54),
            .init(color: .clear, location: 1.0),
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
        .frame(width: width * 0.65)
        .offset(x: glint * width * 1.5)
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }

    /// The rays behind the dear packs, the same wheel a sovereign seat mark wears.
    private var rays: some View {
        RarityBurst(count: PackLook.rays(tier),
                    tint: PackLook.accent(tier), size: width * 1.6)
            .opacity(0.55)
    }

    /// The wax seal in the middle, wearing the tier's metal.
    private var seal: some View {
        ZStack {
            PrestigePlate(tier: PackLook.prestige(tier), size: width * 0.34)
            Circle()
                .fill(PackLook.sealFace(tier))
                .frame(width: width * 0.34, height: width * 0.34)
            Circle()
                .strokeBorder(.white.opacity(0.4), lineWidth: width * 0.012)
                .frame(width: width * 0.34, height: width * 0.34)
            BroomMark(size: width * 0.19, tint: PackLook.sealInk(tier))
            PrestigeRim(tier: PackLook.prestige(tier), size: width * 0.34)
        }
        .shadow(color: felt.shade(0.4), radius: width * 0.03, y: width * 0.015)
    }
}

/// What each tier is made of. Kept apart from the view so the pack, its tile, the shop row
/// and the opening all dress the same tier the same way.
enum PackLook {
    static func wrapper(_ tier: PackTier) -> AnyShapeStyle {
        switch tier {
        case .mazzetto:
            AnyShapeStyle(Palette.goldSheen)
        case .bottega:
            AnyShapeStyle(LinearGradient(
                colors: [Color(red: 0.353, green: 0.478, blue: 0.639),
                         Color(red: 0.180, green: 0.290, blue: 0.435),
                         Color(red: 0.086, green: 0.157, blue: 0.267)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .velluto:
            AnyShapeStyle(LinearGradient(
                colors: [Color(red: 0.549, green: 0.310, blue: 0.639),
                         Color(red: 0.353, green: 0.165, blue: 0.443),
                         Color(red: 0.169, green: 0.063, blue: 0.239)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .reliquia:
            // The only wrapper that is not a single sweep: gold that turns as the pack does.
            AnyShapeStyle(AngularGradient(
                colors: [Palette.goldDeep, Palette.gold, Palette.goldLight, .white,
                         Palette.goldLight, Palette.gold, Palette.goldDeep],
                center: UnitPoint(x: 0.4, y: 0.3)))
        case .scrigno:
            // Tooled leather over brass: a box off a shelf rather than a packet of cards.
            AnyShapeStyle(LinearGradient(
                colors: [Color(red: 0.647, green: 0.443, blue: 0.263),
                         Color(red: 0.435, green: 0.271, blue: 0.157),
                         Color(red: 0.239, green: 0.141, blue: 0.078)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .forziere:
            AnyShapeStyle(LinearGradient(
                colors: [Color(red: 0.612, green: 0.208, blue: 0.220),
                         Color(red: 0.400, green: 0.098, blue: 0.133),
                         Color(red: 0.204, green: 0.043, blue: 0.071)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    static func accent(_ tier: PackTier) -> Color {
        switch tier {
        case .mazzetto: Palette.goldLight
        case .bottega: Color(red: 0.549, green: 0.714, blue: 0.867)
        case .velluto: Color(red: 0.776, green: 0.588, blue: 0.867)
        case .reliquia: Palette.goldLight
        case .scrigno: Color(red: 0.878, green: 0.706, blue: 0.443)
        // Gold rather than a lighter oxblood: the rays have only the cloth behind them,
        // and a red wheel on green reads as a smudge where a gold one reads as light.
        case .forziere: Palette.goldLight
        }
    }

    static func edge(_ tier: PackTier) -> Color {
        switch tier {
        case .mazzetto: Palette.goldDeep
        case .bottega, .velluto, .scrigno: accent(tier).opacity(0.7)
        case .reliquia, .forziere: Palette.goldDeep
        }
    }

    static func sealFace(_ tier: PackTier) -> AnyShapeStyle {
        switch tier {
        case .reliquia, .forziere: AnyShapeStyle(Palette.goldSheen)
        default: AnyShapeStyle(Palette.terracotta)
        }
    }

    static func sealInk(_ tier: PackTier) -> Color {
        switch tier {
        case .reliquia, .forziere: Palette.ink
        default: Palette.cream
        }
    }

    /// How much metal the seal wears, on the same scale a seat mark uses.
    static func prestige(_ tier: PackTier) -> Prestige {
        switch tier {
        case .mazzetto: .none
        case .bottega: .ring
        case .velluto, .scrigno: .bezel
        case .reliquia, .forziere: .royal
        }
    }

    static func hasRays(_ tier: PackTier) -> Bool {
        rays(tier) > 0
    }

    /// How many spokes go behind a pack, or none for the ones that get no wheel. Only the
    /// top of each shelf gets the full one, so "this is the dearest thing here" reads the
    /// same on both pages.
    static func rays(_ tier: PackTier) -> Int {
        switch tier {
        case .mazzetto, .bottega: 0
        case .velluto, .scrigno: 14
        case .reliquia, .forziere: 24
        }
    }

    /// The line under a pack's name on the shelf.
    static func explanation(_ tier: PackTier) -> LocalizedStringKey {
        switch tier {
        case .mazzetto: "Three cards, whatever the deck gives you"
        case .bottega: "Three cards, a court or better among them"
        case .velluto: "Four cards, a seven or better, and something off the shelves"
        case .reliquia: "Five cards, the best odds there are, nothing common with them"
        case .scrigno: "Two things off the shelves, nothing common among them"
        case .forziere: "Three things off the shelves, and nothing short of prezioso"
        }
    }

    /// The grade a tier reads as, for the ribbon on its tile. A pack is not owned, so it
    /// has no grade of its own — this is what it feels like.
    static func grade(_ tier: PackTier) -> Grade {
        switch tier {
        case .mazzetto: .comune
        case .bottega: .raro
        case .velluto: .prezioso
        case .reliquia, .forziere: .leggendario
        case .scrigno: .raro
        }
    }
}

/// A row of teeth, for the line a pack tears along.
struct ZigZag: Shape {
    var teeth: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step = rect.width / CGFloat(teeth)
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        for index in 0..<teeth {
            let x = rect.minX + CGFloat(index) * step
            path.addLine(to: CGPoint(x: x + step / 2, y: index.isMultiple(of: 2) ? rect.minY : rect.maxY))
            path.addLine(to: CGPoint(x: x + step, y: rect.midY))
        }
        return path
    }
}

#Preview("Packs") {
    ZStack {
        TableGround()
        VStack(spacing: 18) {
            ForEach(PackTier.Shelf.allCases) { shelf in
                HStack(spacing: 18) {
                    ForEach(PackTier.on(shelf)) { tier in
                        PackArt(tier: tier, width: 74, alive: true)
                    }
                }
            }
        }
    }
}
