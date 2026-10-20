import SwiftUI
import ScopaCore

/// One Carnevale suit sign, outlined in ink like an engraved plate: a gold coin with a lace
/// rim, a red goblet on a gold stem, a teal blade with gold quillons, a lacquered baton
/// bound in gold.
struct CarnevalePip: View {
    let suit: Suit
    let size: CGFloat

    private var s: CGFloat { size }
    private var line: CGFloat { max(0.5, size * 0.045) }

    var body: some View {
        ZStack {
            switch suit {
            case .coins: coin
            case .cups: cup
            case .swords: sword
            case .clubs: baton
            }
        }
        .frame(width: size, height: size)
    }

    private func inked<S: Shape>(_ shape: S, _ tint: Color, _ w: CGFloat, _ h: CGFloat,
                                 x: CGFloat = 0, y: CGFloat = 0) -> some View {
        shape.fill(tint)
            .overlay { shape.stroke(Carnevale.ink, lineWidth: line) }
            .frame(width: s * w, height: s * h)
            .offset(x: s * x, y: s * y)
    }

    private var coin: some View {
        ZStack {
            inked(Carnevale.Scalloped(count: 16, depth: 0.10), Carnevale.gold, 0.94, 0.94)
            inked(Circle(), Carnevale.paleGold, 0.60, 0.60)
            Circle().stroke(Carnevale.ochre, lineWidth: line * 0.6).frame(width: s * 0.47, height: s * 0.47)
            inked(Carnevale.Lozenge(), Carnevale.red, 0.22, 0.32)
        }
    }

    private var cup: some View {
        ZStack {
            inked(Trapezoid(topRatio: 0.30), Carnevale.gold, 0.50, 0.13, y: 0.385)
            inked(Rectangle(), Carnevale.gold, 0.09, 0.20, y: 0.235)
            inked(Circle(), Carnevale.gold, 0.16, 0.16, y: 0.20)
            inked(Bowl(roundness: 0.92), Carnevale.red, 0.70, 0.46, y: -0.04)
            Carnevale.Swag()
                .stroke(Carnevale.paleGold, lineWidth: line * 1.2)
                .frame(width: s * 0.44, height: s * 0.10)
                .offset(y: -s * 0.12)
            inked(Capsule(), Carnevale.gold, 0.78, 0.09, y: -0.27)
        }
    }

    private var sword: some View {
        ZStack {
            inked(SwordBlade(), Carnevale.teal, 0.22, 0.62, y: -0.16)
            Rectangle()
                .fill(Carnevale.white.opacity(0.55))
                .frame(width: max(0.5, s * 0.035), height: s * 0.44)
                .offset(y: -s * 0.10)
            inked(Capsule(), Carnevale.ink, 0.11, 0.21, y: 0.26)
            inked(Circle(), Carnevale.gold, 0.13, 0.13, x: -0.34, y: 0.10)
            inked(Circle(), Carnevale.gold, 0.13, 0.13, x: 0.34, y: 0.10)
            inked(Capsule(), Carnevale.gold, 0.66, 0.085, y: 0.15)
            inked(Circle(), Carnevale.gold, 0.15, 0.15, y: 0.40)
        }
    }

    private var baton: some View {
        ZStack {
            inked(Cudgel(), Carnevale.lacquer, 0.36, 0.94)
            Capsule()
                .fill(Carnevale.white.opacity(0.35))
                .frame(width: max(0.5, s * 0.035), height: s * 0.30)
                .offset(x: -s * 0.075, y: -s * 0.20)
            inked(Capsule(), Carnevale.gold, 0.36, 0.085, y: -0.12)
            inked(Capsule(), Carnevale.gold, 0.27, 0.080, y: 0.10)
            inked(Capsule(), Carnevale.gold, 0.20, 0.075, y: 0.30)
            inked(Circle(), Carnevale.gold, 0.15, 0.15, y: -0.44)
        }
        .rotationEffect(.degrees(-14))
    }
}

/// Pips in rows that stay symmetric as the rank climbs, the same layout as every other deck.
struct CarnevalePipField: View {
    let suit: Suit
    let count: Int
    let area: CGSize

    /// Rows of pips per rank. Seven reads as two, three, two.
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
                    ForEach(0..<rows[row], id: \.self) { _ in
                        CarnevalePip(suit: suit, size: pip)
                    }
                }
            }
        }
        .frame(width: area.width, height: area.height)
    }
}
