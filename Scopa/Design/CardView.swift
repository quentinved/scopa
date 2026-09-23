import SwiftUI
import ScopaCore

/// One card face. Width drives every other measurement, so the same view serves the hand,
/// the table and the sheet.
struct CardView: View {
    let card: Card
    var width: CGFloat
    var highlighted = false
    var outlined = false

    @Environment(\.cardTheme) private var theme
    private var face: CardFace { theme.face }

    private var radius: CGFloat { width * 0.12 }
    private var isSettebello: Bool { card == .settebello }
    private var isCoins: Bool { card.suit == .coins }

    var body: some View {
        // The face is rasterised once and moved as one piece: live, a seven is seventy-odd
        // shapes and a full table runs to a thousand layers per frame. The border stays
        // outside the group because it changes while the card is on the table.
        CardArt(card: card, width: width)
            .drawingGroup()
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(borderColour, lineWidth: borderWidth)
            }
            .background { CardShadow(width: width, radius: radius, fill: face.stock) }
    }

    private var borderColour: Color {
        if highlighted { return Palette.terracotta }
        if outlined { return Palette.terracotta.opacity(0.55) }
        if isSettebello { return face.accent }
        // Coins score a point of their own, so they are edged in the settebello's gold a
        // shade down.
        return isCoins ? face.accent.opacity(0.7) : face.edge
    }

    private var borderWidth: CGFloat {
        if highlighted { return 2.5 }
        if outlined { return 2 }
        if isSettebello { return 2 }
        return isCoins ? 1.5 : 1
    }
}

/// Everything on the card that never changes once it is dealt.
///
/// Its own view, taking only the card and the width, so picking a card up rebuilds the
/// border and not the face. A court card is a couple of hundred shapes.
private struct CardArt: View {
    let card: Card
    let width: CGFloat

    @Environment(\.cardTheme) private var theme
    private var face: CardFace { theme.face }

    private var height: CGFloat { width * 1.5 }
    private var radius: CGFloat { width * 0.12 }
    private var isSettebello: Bool { card == .settebello }
    private var isCoins: Bool { card.suit == .coins }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius).fill(face.stock)
            coinGlow
            if isSettebello {
                Rays(count: 20).stroke(face.accent.opacity(0.35), lineWidth: max(0.6, width * 0.012))
                    .frame(width: width * 0.86, height: width * 0.86)
            }
            CardCentre(card: card,
                       area: CGSize(width: width * 0.60, height: width * (isSettebello ? 0.86 : 0.94)),
                       cardWidth: width)
        }
        .frame(width: width, height: height)
        .overlay(alignment: .topLeading) { index.padding(width * 0.08) }
        .overlay(alignment: .bottomTrailing) { index.rotationEffect(.degrees(180)).padding(width * 0.08) }
        .overlay(alignment: .bottom) { caption }
        .overlay { printedFrame }
    }

    /// Every coin carries the settebello's glow turned down, so the suit reads across a
    /// spread table without the seven losing its place.
    @ViewBuilder private var coinGlow: some View {
        if isCoins {
            RoundedRectangle(cornerRadius: radius)
                .fill(RadialGradient(colors: [face.accent.opacity(isSettebello ? 0.22 : 0.13), .clear],
                                     center: .center, startRadius: 0, endRadius: width * 0.75))
        }
    }

    @ViewBuilder private var caption: some View {
        if isSettebello && width >= 70 {
            Text("SETTEBELLO")
                .font(.system(size: width * 0.082, weight: .bold))
                .tracking(width * 0.012)
                .foregroundStyle(face.accent)
                .padding(.bottom, width * 0.07)
        }
    }

    /// The gold rule inside the card edge, dropped on small cards where it is only noise.
    @ViewBuilder private var printedFrame: some View {
        if width >= 56 {
            // A style may print its frame in its own colour, unless the colourway is dark,
            // which `CardTheme.rule` settles. A coin overrides both and prints gold.
            let rule = isCoins ? face.accent.opacity(0.75) : theme.rule
            switch theme.style.frame {
            case .none:
                EmptyView()
            case .single:
                RoundedRectangle(cornerRadius: radius * 0.66)
                    .strokeBorder(rule, lineWidth: max(0.7, width * 0.013))
                    .padding(width * 0.055)
            case .double:
                doubleFrame(rule)
            case .heavy:
                RoundedRectangle(cornerRadius: radius * 0.5)
                    .strokeBorder(rule, lineWidth: max(1, width * 0.028))
                    .padding(width * 0.05)
            }
        }
    }

    private func doubleFrame(_ rule: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius * 0.7)
                .strokeBorder(rule, lineWidth: max(0.7, width * 0.014))
                .padding(width * 0.045)
            RoundedRectangle(cornerRadius: radius * 0.55)
                .strokeBorder(rule.opacity(0.6), lineWidth: max(0.5, width * 0.008))
                .padding(width * 0.085)
        }
    }

    private var index: some View {
        VStack(spacing: width * 0.02) {
            Text(card.rank.label)
                .font(.display(width * 0.26))
                .foregroundStyle(face.ink)
            // A six and a nine read as each other upside down, so they get a rule under them.
            if card.rank == .six || card.rank == .knight {
                Rectangle()
                    .fill(face.ink)
                    .frame(width: width * 0.13, height: max(1, width * 0.018))
            }
        }
    }
}

/// The shadow under a card, cast by its outline rather than by the card itself.
///
/// `.shadow` on the finished card re-renders the whole face off screen every time it
/// moves, and an opaque rounded rectangle casts the same shadow for far less. Cards under
/// 30 points cast none: the blur is under two points and invisible.
private struct CardShadow: View {
    let width: CGFloat
    let radius: CGFloat
    let fill: Color

    var body: some View {
        if width >= 30 {
            RoundedRectangle(cornerRadius: radius)
                .fill(fill)
                .shadow(color: Palette.ink.opacity(0.16), radius: width * 0.09, y: width * 0.05)
        }
    }
}

/// Rays behind the settebello.
private struct Rays: Shape {
    let count: Int

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let inner = min(rect.width, rect.height) * 0.38
        let outer = min(rect.width, rect.height) * 0.5
        var path = Path()
        for index in 0..<count {
            let angle = Double(index) / Double(count) * 2 * .pi
            path.move(to: CGPoint(x: centre.x + cos(angle) * inner, y: centre.y + sin(angle) * inner))
            path.addLine(to: CGPoint(x: centre.x + cos(angle) * outer, y: centre.y + sin(angle) * outer))
        }
        return path
    }
}

/// The back of a card: the chosen ruling on the deck's own ground, with a gold medallion
/// carrying the broom.
struct CardBack: View {
    var width: CGFloat

    @Environment(\.cardTheme) private var theme
    @Environment(\.cardBack) private var pattern
    private var face: CardFace { theme.face }

    private var height: CGFloat { width * 1.5 }
    private var radius: CGFloat { width * 0.12 }

    var body: some View {
        // Rasterised for the same reason as the face: a back is forty lattice lines plus
        // an eleven-slat broom, and a table shows a couple of dozen at once.
        ZStack {
            RoundedRectangle(cornerRadius: radius).fill(face.backGround)
            BackPattern(pattern: pattern, step: width * 0.22)
                .stroke(face.backPattern, lineWidth: max(0.6, width * 0.022))
            RoundedRectangle(cornerRadius: radius * 0.72)
                .strokeBorder(face.backTrim.opacity(0.65), lineWidth: max(0.8, width * 0.022))
                .padding(width * 0.10)
            if width >= 30 {
                Circle()
                    .fill(face.backGround)
                    .overlay { Circle().strokeBorder(face.backTrim.opacity(0.8), lineWidth: max(0.8, width * 0.022)) }
                    .frame(width: width * 0.46, height: width * 0.46)
                    .overlay { BroomMark(size: width * 0.26, tint: face.backTrim) }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius))
        .overlay { RoundedRectangle(cornerRadius: radius).strokeBorder(face.backEdge, lineWidth: max(1, width * 0.045)) }
        .frame(width: width, height: height)
        .drawingGroup()
        .background { CardShadow(width: width, radius: radius, fill: face.backGround) }
    }
}

/// A fanned stack of backs, for a hand you cannot see.
struct HiddenHand: View {
    var count: Int
    var width: CGFloat

    var body: some View {
        HStack(spacing: -width * 0.55) {
            ForEach(0..<max(count, 0), id: \.self) { index in
                CardBack(width: width)
                    .rotationEffect(.degrees(Double(index - count / 2) * 4))
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                        removal: .scale(scale: 0.3).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(duration: 0.38, bounce: 0.2), value: count)
    }
}

/// A card that flips from its back to its face, used when a played card lands on the table.
struct FlippingCard: View {
    let card: Card
    var width: CGFloat
    var faceUp: Bool

    var body: some View {
        ZStack {
            CardBack(width: width).opacity(faceUp ? 0 : 1)
            CardView(card: card, width: width)
                .opacity(faceUp ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(.degrees(faceUp ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .animation(.spring(duration: 0.45, bounce: 0.15), value: faceUp)
    }
}
