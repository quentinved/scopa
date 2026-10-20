import SwiftUI
import ScopaCore

/// One suit sign painted in glaze: a saffron coin ringed in cobalt, an iron-orange goblet,
/// a cobalt sword with a saffron guard, a lopped copper-green cudgel in leaf.
struct MaiolicaSuit: View {
    let suit: Suit
    let size: CGFloat
    /// The card width. The brush is the same brush on a pip as on a king.
    let unit: CGFloat
    var seed = 0

    var body: some View {
        ZStack {
            switch suit {
            case .coins: coin
            case .cups: cup
            case .swords: sword
            case .clubs: club
            }
        }
        .frame(width: size, height: size)
    }

    private var s: CGFloat { size }
    /// Petals, milling and sprouting leaves: below this they are only noise.
    private var fine: Bool { size >= 13 }

    private func glazed<S: Shape>(_ shape: S, _ tint: MaiolicaTint, _ pw: CGFloat, _ ph: CGFloat,
                                  x: CGFloat = 0, y: CGFloat = 0,
                                  line: Color? = MaiolicaPaint.manganese) -> some View {
        MaiolicaGlazed(shape: shape, tint: tint, unit: unit, line: line,
                       seed: seed &+ Int(pw * 97 + ph * 31 + y * 13))
            .frame(width: s * pw, height: s * ph)
            .offset(x: s * x, y: s * y)
    }

    // MARK: Denari

    private var coin: some View {
        ZStack {
            glazed(Circle(), .saffron, 0.90, 0.90, line: MaiolicaPaint.cobalt)
            if fine {
                MaiolicaRingDots(count: 10, radius: 0.37, dot: 0.075)
                    .fill(MaiolicaPaint.ochre.opacity(0.85))
                    .frame(width: s, height: s)
            }
            MaiolicaBrushed(shape: Circle(), wander: unit * 0.004, seed: seed &+ 3)
                .stroke(MaiolicaPaint.cobalt, lineWidth: max(0.6, s * 0.05))
                .frame(width: s * 0.56, height: s * 0.56)
            MaiolicaPetals(count: 4, turn: .pi / 4, breadth: 0.62)
                .fill(MaiolicaPaint.cobalt)
                .frame(width: s * 0.44, height: s * 0.44)
            Circle().fill(MaiolicaPaint.ferraccia).frame(width: s * 0.12, height: s * 0.12)
        }
    }

    // MARK: Coppe

    private var cup: some View {
        ZStack {
            glazed(Trapezoid(topRatio: 0.30), .ferraccia, 0.54, 0.12, y: 0.37)
            glazed(Rectangle(), .saffron, 0.10, 0.15, y: 0.25)
            glazed(Ellipse(), .saffron, 0.22, 0.10, y: 0.17)
            glazed(Bowl(roundness: 0.95), .ferraccia, 0.72, 0.46, y: -0.10)
            if fine { bowlSprig }
            glazed(Capsule(), .cobalt, 0.80, 0.11, y: -0.33)
        }
    }

    /// Two copper leaves and a cobalt berry painted on the belly of the cup.
    private var bowlSprig: some View {
        ZStack {
            Leaf().fill(MaiolicaPaint.copper)
                .frame(width: s * 0.09, height: s * 0.18)
                .rotationEffect(.degrees(-58))
                .offset(x: -s * 0.09, y: -s * 0.08)
            Leaf().fill(MaiolicaPaint.copper)
                .frame(width: s * 0.09, height: s * 0.18)
                .rotationEffect(.degrees(58))
                .offset(x: s * 0.09, y: -s * 0.08)
            Circle().fill(MaiolicaPaint.cobalt)
                .frame(width: s * 0.09, height: s * 0.09)
                .offset(y: -s * 0.04)
        }
    }

    // MARK: Spade

    private var sword: some View {
        ZStack {
            glazed(SwordBlade(), .cobalt, 0.21, 0.66, y: -0.17)
            Capsule().fill(MaiolicaPaint.cobaltWash.opacity(0.9))
                .frame(width: s * 0.045, height: s * 0.48)
                .offset(x: -s * 0.02, y: -s * 0.12)
            glazed(Rectangle(), .manganese, 0.10, 0.15, y: 0.30)
            glazed(Capsule(), .saffron, 0.70, 0.10, y: 0.18)
            glazed(Circle(), .saffron, 0.16, 0.16, y: 0.42)
        }
    }

    // MARK: Bastoni

    private var club: some View {
        ZStack {
            if fine {
                sprout(angle: -52, x: -0.17, y: 0.08)
                sprout(angle: 48, x: 0.16, y: -0.15)
            }
            stub(angle: -35, x: -0.12, y: 0.12)
            stub(angle: 35, x: 0.13, y: -0.08)
            glazed(Cudgel(), .copper, 0.34, 0.94)
            glazed(Capsule(), .saffron, 0.21, 0.07, y: 0.31)
            Ellipse().fill(MaiolicaPaint.copperDeep)
                .frame(width: s * 0.07, height: s * 0.045)
                .offset(x: s * 0.05, y: -s * 0.22)
            Ellipse().fill(MaiolicaPaint.copperDeep)
                .frame(width: s * 0.06, height: s * 0.04)
                .offset(x: -s * 0.03, y: s * 0.03)
        }
        .rotationEffect(.degrees(-14))
    }

    /// The stump of a lopped branch, poking out of the shaft.
    private func stub(angle: Double, x: CGFloat, y: CGFloat) -> some View {
        glazed(Capsule(), .copper, 0.13, 0.065)
            .rotationEffect(.degrees(angle))
            .offset(x: s * x, y: s * y)
    }

    private func sprout(angle: Double, x: CGFloat, y: CGFloat) -> some View {
        glazed(Leaf(), .copper, 0.14, 0.25, line: MaiolicaPaint.copperDeep)
            .rotationEffect(.degrees(angle))
            .offset(x: s * x, y: s * y)
    }
}

/// Pips in the rows every deck in the app uses: seven is two, three, two.
struct MaiolicaPips: View {
    let suit: Suit
    let count: Int
    let area: CGSize
    let unit: CGFloat

    private static let rows: [Int: [Int]] = [
        1: [1], 2: [1, 1], 3: [1, 1, 1], 4: [2, 2], 5: [2, 1, 2], 6: [2, 2, 2], 7: [2, 3, 2],
    ]

    var body: some View {
        let rows = Self.rows[count] ?? [count]
        let widest = CGFloat(rows.max() ?? 1)
        let lines = CGFloat(rows.count)
        let pip = min(area.width / (widest + (widest - 1) * 0.28),
                      area.height / (lines + (lines - 1) * 0.22))
        VStack(spacing: pip * 0.22) {
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: pip * 0.28) {
                    ForEach(0..<rows[row], id: \.self) { column in
                        MaiolicaSuit(suit: suit, size: pip, unit: unit, seed: row * 7 + column * 3)
                    }
                }
            }
        }
        .frame(width: area.width, height: area.height)
    }
}
