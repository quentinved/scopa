import SwiftUI
import ScopaCore

/// One suit, drawn the way its style draws it. The flat style keeps the icon's geometry,
/// the other two follow the southern pattern: rosette coins, bellied cups, short straight
/// swords and knobbly cudgels, with the woodcut hatching its own.
struct SuitArt: View {
    let style: CardStyle
    let suit: Suit
    let size: CGFloat
    let colour: Color
    let accent: Color
    let ink: Color

    var body: some View {
        ZStack {
            switch suit {
            case .coins: coins
            case .cups: cups
            case .swords: swords
            case .clubs: batons
            }
        }
        .frame(width: size, height: size)
    }

    private var s: CGFloat { size }
    private var line: CGFloat { max(0.8, size * 0.055) }

    private var pen: Color { style.isPolychrome ? Pigment.ink : ink }
    private var lead: Color { style.isPolychrome ? Pigment.lead(suit) : colour }

    private func drawn<S: Shape>(_ shape: S, _ tint: Color) -> Drawn<S> {
        Drawn(shape, style: style, colour: tint, ink: pen, unit: size)
    }

    /// A sprig of foliage. On a Piacentine sheet the leaves are what fill the space the
    /// crossed blades leave behind, and without them a trellis is just a pile of swords.
    private func sprig(_ tint: Color, width: CGFloat, height: CGFloat,
                       angle: Double, x: CGFloat, y: CGFloat) -> some View {
        drawn(Leaf(), tint)
            .frame(width: s * width, height: s * height)
            .rotationEffect(.degrees(angle))
            .offset(x: s * x, y: s * y)
    }

    @ViewBuilder private var coins: some View {
        switch style {
        case .moderna:
            ZStack {
                Circle().fill(colour).frame(width: s * 0.82)
                Circle().stroke(ink.opacity(0.55), lineWidth: max(0.8, s * 0.05)).frame(width: s * 0.50)
                Circle().fill(ink.opacity(0.55)).frame(width: s * 0.14)
            }
        case .classica:
            // A rosette: eight petals around a bezel, the way southern coins are cut.
            ZStack {
                drawn(Circle(), colour).frame(width: s * 0.88)
                ForEach(0..<8, id: \.self) { index in
                    Capsule()
                        .fill(ink.opacity(0.30))
                        .frame(width: s * 0.10, height: s * 0.26)
                        .offset(y: -s * 0.20)
                        .rotationEffect(.degrees(Double(index) * 45))
                }
                Circle().fill(accent).frame(width: s * 0.25)
                Circle().strokeBorder(ink.opacity(0.45), lineWidth: line * 0.6).frame(width: s * 0.25)
                Circle().strokeBorder(ink.opacity(0.30), lineWidth: line * 0.4).frame(width: s * 0.78)
            }
        case .litografia:
            // A struck coin rather than a disc: a milled gold rim, a ring of petals, a
            // cobalt field and a vermilion boss.
            ZStack {
                drawn(Circle(), Pigment.gold).frame(width: s * 0.94)
                ForEach(0..<12, id: \.self) { index in
                    Capsule()
                        .fill(Pigment.ochre)
                        .frame(width: s * 0.058, height: s * 0.17)
                        .offset(y: -s * 0.30)
                        .rotationEffect(.degrees(Double(index) * 30))
                }
                Circle().fill(Pigment.cobalt).frame(width: s * 0.50)
                Circle().strokeBorder(Pigment.gold, lineWidth: line * 0.55).frame(width: s * 0.50)
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(Pigment.gold)
                        .frame(width: s * 0.048)
                        .offset(y: -s * 0.175)
                        .rotationEffect(.degrees(Double(index) * 60))
                }
                Circle().fill(Pigment.vermilion).frame(width: s * 0.22)
                Circle().strokeBorder(Pigment.ink.opacity(0.8), lineWidth: line * 0.4).frame(width: s * 0.22)
            }
        case .antica:
            ZStack {
                drawn(Circle(), colour).frame(width: s * 0.86)
                Circle().strokeBorder(ink.opacity(0.9), lineWidth: line * 0.7).frame(width: s * 0.54)
                Star(points: 6).stroke(ink.opacity(0.75), lineWidth: line * 0.5).frame(width: s * 0.44)
                Hatching(count: 4)
                    .stroke(ink.opacity(0.45), lineWidth: line * 0.4)
                    .frame(width: s * 0.40, height: s * 0.40)
            }
        }
    }

    @ViewBuilder private var cups: some View {
        switch style {
        case .moderna:
            VStack(spacing: 0) {
                UnevenRoundedRectangle(bottomLeadingRadius: s * 0.26, bottomTrailingRadius: s * 0.26)
                    .fill(colour).frame(width: s * 0.60, height: s * 0.44)
                Rectangle().fill(colour).frame(width: s * 0.11, height: s * 0.16)
                Capsule().fill(colour).frame(width: s * 0.48, height: s * 0.10)
            }
        case .classica:
            // Round and bellied, with a lid knop on top and a turned foot.
            VStack(spacing: 0) {
                Circle().fill(accent).frame(width: s * 0.14).offset(y: s * 0.04)
                drawn(Bowl(roundness: 0.95), colour).frame(width: s * 0.62, height: s * 0.40)
                drawn(Rectangle(), colour).frame(width: s * 0.12, height: s * 0.11)
                drawn(Ellipse(), colour).frame(width: s * 0.50, height: s * 0.13)
            }
        case .litografia:
            // A standing cup: gold lid knop, vermilion bowl under a gold rim, a plum stem
            // through a gold knop, on a spread gold foot.
            ZStack {
                VStack(spacing: 0) {
                    drawn(Bowl(roundness: 0.95), Pigment.vermilion)
                        .frame(width: s * 0.64, height: s * 0.38)
                    drawn(Rectangle(), Pigment.plum).frame(width: s * 0.09, height: s * 0.10)
                    drawn(Trapezoid(topRatio: 0.30), Pigment.gold)
                        .frame(width: s * 0.54, height: s * 0.13)
                }
                .offset(y: s * 0.08)
                Capsule().fill(Pigment.gold)
                    .frame(width: s * 0.68, height: s * 0.075)
                    .offset(y: -s * 0.115)
                Circle().fill(Pigment.gold).frame(width: s * 0.135).offset(y: -s * 0.245)
                Circle().fill(Pigment.gold).frame(width: s * 0.125).offset(y: s * 0.275)
                Capsule().fill(Pigment.gold.opacity(0.85))
                    .frame(width: s * 0.30, height: s * 0.045)
                    .offset(y: s * 0.045)
            }
        case .antica:
            VStack(spacing: 0) {
                drawn(Bowl(roundness: 0.75), colour)
                    .frame(width: s * 0.60, height: s * 0.40)
                    .overlay {
                        Hatching(count: 3)
                            .stroke(ink.opacity(0.45), lineWidth: line * 0.4)
                            .frame(width: s * 0.34, height: s * 0.20)
                    }
                drawn(Rectangle(), colour).frame(width: s * 0.10, height: s * 0.14)
                drawn(Trapezoid(topRatio: 0.34), colour).frame(width: s * 0.50, height: s * 0.13)
            }
        }
    }

    @ViewBuilder private var swords: some View {
        switch style {
        case .moderna:
            VStack(spacing: 0) {
                SwordBlade().fill(colour).frame(width: s * 0.28, height: s * 0.60)
                Capsule().fill(accent).frame(width: s * 0.70, height: s * 0.09)
                Rectangle().fill(colour).frame(width: s * 0.10, height: s * 0.14)
                Circle().fill(accent).frame(width: s * 0.15)
            }
        case .classica:
            // Short, straight and blunt-shouldered, with a broad guard: the southern sword.
            VStack(spacing: 0) {
                drawn(SwordBlade(), colour).frame(width: s * 0.30, height: s * 0.48)
                drawn(Rectangle(), accent).frame(width: s * 0.76, height: s * 0.10)
                drawn(Rectangle(), colour).frame(width: s * 0.13, height: s * 0.17)
                drawn(Capsule(), accent).frame(width: s * 0.26, height: s * 0.10)
            }
        case .litografia:
            // A curved sabre through foliage, hilt down and to the left, so that a column of
            // them crosses cleanly.
            ZStack {
                sprig(Pigment.leaf, width: 0.17, height: 0.27, angle: -58, x: -0.27, y: 0.16)
                sprig(Pigment.olive, width: 0.15, height: 0.24, angle: 46, x: 0.26, y: -0.14)
                drawn(Sabre(), Pigment.sky).frame(width: s * 0.88, height: s * 0.90)
                Sabre()
                    .fill(Pigment.ivory.opacity(0.45))
                    .frame(width: s * 0.88, height: s * 0.90)
                    .scaleEffect(x: 0.46, y: 0.92, anchor: .bottomTrailing)
                Group {
                    Capsule().fill(Pigment.gold)
                        .frame(width: s * 0.44, height: s * 0.10)
                    Capsule().fill(Pigment.ochre)
                        .frame(width: s * 0.10, height: s * 0.24)
                        .offset(x: -s * 0.100, y: s * 0.105)
                    Circle().fill(Pigment.gold).frame(width: s * 0.13)
                        .offset(x: -s * 0.170, y: s * 0.200)
                }
                .rotationEffect(.degrees(-32))
                .offset(x: -s * 0.24, y: s * 0.34)
            }
        case .antica:
            VStack(spacing: 0) {
                drawn(SwordBlade(), colour)
                    .frame(width: s * 0.26, height: s * 0.54)
                    .overlay {
                        Rectangle().fill(ink.opacity(0.35))
                            .frame(width: line * 0.4, height: s * 0.42)
                    }
                drawn(Rectangle(), accent).frame(width: s * 0.68, height: s * 0.09)
                drawn(Rectangle(), colour).frame(width: s * 0.10, height: s * 0.18)
            }
        }
    }

    @ViewBuilder private var batons: some View {
        switch style {
        case .moderna:
            ZStack {
                Capsule().fill(colour).frame(width: s * 0.17, height: s * 0.92)
                Capsule().fill(colour)
                    .frame(width: s * 0.23, height: s * 0.085)
                    .rotationEffect(.degrees(-42))
                    .offset(x: -s * 0.14, y: s * 0.07)
                Capsule().fill(colour)
                    .frame(width: s * 0.20, height: s * 0.08)
                    .rotationEffect(.degrees(42))
                    .offset(x: s * 0.13, y: -s * 0.19)
            }
            .rotationEffect(.degrees(-26))
        case .classica:
            // A knobbly cudgel: thicker at the head, lumpy down the shaft.
            ZStack {
                drawn(Cudgel(), colour).frame(width: s * 0.34, height: s * 0.94)
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(ink.opacity(0.16))
                        .frame(width: s * 0.11)
                        .offset(x: index.isMultiple(of: 2) ? s * 0.07 : -s * 0.07,
                                y: s * (0.10 - Double(index) * 0.20))
                }
            }
            .rotationEffect(.degrees(-14))
        case .litografia:
            // A ceremonial baton, turned and gold-banded, sprouting leaves.
            ZStack {
                sprig(Pigment.leaf, width: 0.18, height: 0.26, angle: -60, x: -0.22, y: -0.06)
                sprig(Pigment.leaf, width: 0.16, height: 0.23, angle: 54, x: 0.21, y: 0.16)
                drawn(Cudgel(), Pigment.ochre).frame(width: s * 0.38, height: s * 0.94)
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(Pigment.gold)
                        .frame(width: s * 0.34, height: s * 0.060)
                        .offset(y: s * (0.20 - Double(index) * 0.22))
                }
                Circle().fill(Pigment.vermilion).frame(width: s * 0.15).offset(y: -s * 0.34)
            }
            .rotationEffect(.degrees(-14))
        case .antica:
            ZStack {
                drawn(Cudgel(), colour).frame(width: s * 0.30, height: s * 0.90)
                Hatching(count: 4)
                    .stroke(ink.opacity(0.55), lineWidth: line * 0.4)
                    .frame(width: s * 0.20, height: s * 0.48)
            }
            .rotationEffect(.degrees(-14))
        }
    }
}
