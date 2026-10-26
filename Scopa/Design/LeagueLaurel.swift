import SwiftUI

/// Gran Maestro's laurel: two sprigs of leaves round the medal, open at the top where
/// Maestro's rays still come through, and tied at the foot.
///
/// Enamelled in the stone's emerald and set in gold, since gold leaves on Maestro's gold
/// vanished into it; that also keeps this laurel apart from the week's, which is plain gold
/// and goes round the seat. It lies on the face, round the stone's halo, the way a wreath is
/// struck on a medal, and inside the medal's own edge, so Gran Maestro takes no more room than
/// Maestro and a seat wearing it sits with its neighbours. The leaf is `Leaf`, the one the
/// week's laurel and the batons suit are cut from.
struct MedalLaurel: View {
    let size: CGFloat
    let metal: LeagueMetal

    /// The room the leaves are laid out in, as a multiple of `size`: within Maestro's rays.
    static let reach: CGFloat = 1.44

    var body: some View {
        ZStack {
            sprig.scaleEffect(x: -1)
            sprig
            knot
        }
        .frame(width: size * Self.reach, height: size * Self.reach)
        .allowsHitTesting(false)
    }

    /// One side: six leaves from the knot round to the shoulder, smallest at the top.
    private var sprig: some View {
        let leaves = 6
        return ZStack {
            ForEach(0..<leaves, id: \.self) { index in
                let t = Double(index) / Double(leaves - 1)
                Leaf()
                    .fill(metal.stone)
                    .overlay { Leaf().fill(shading) }
                    .overlay { Leaf().stroke(metal.light, lineWidth: max(size * 0.014, 0.5)) }
                    .frame(width: size * (0.15 - t * 0.04), height: size * (0.28 - t * 0.08))
                    // Swept along the arc, as on the week's laurel: on the radius they read as rays.
                    .rotationEffect(.degrees(-58))
                    .offset(y: -size * 0.6)
                    .rotationEffect(.degrees(166 - t * 116))
            }
        }
    }

    /// Light from the top left over the enamel, as over the metal it is set in.
    private var shading: LinearGradient {
        LinearGradient(colors: [.white.opacity(0.4), .clear, .black.opacity(0.35)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Where the two sprigs meet: a gold ribbon, tied over the foot of the medal.
    private var knot: some View {
        let ribbon = metal.sheen
        return ZStack {
            ForEach([-1.0, 1.0], id: \.self) { side in
                Capsule()
                    .fill(ribbon)
                    .overlay { Capsule().strokeBorder(metal.dark.opacity(0.6), lineWidth: max(size * 0.01, 0.4)) }
                    .frame(width: size * 0.15, height: size * 0.075)
                    .rotationEffect(.degrees(side * 24))
                    .offset(x: side * size * 0.065)
            }
            Circle()
                .fill(ribbon)
                .overlay { Circle().strokeBorder(metal.dark.opacity(0.6), lineWidth: max(size * 0.01, 0.4)) }
                .frame(width: size * 0.075, height: size * 0.075)
        }
        .offset(y: size * 0.6)
    }
}

#Preview("Maestro, then Gran Maestro") {
    HStack(spacing: 30) {
        ForEach([5, 6], id: \.self) { league in
            VStack(spacing: 24) {
                LeagueMedal(league: league, size: 15)
                LeagueMedal(league: league, size: 30)
                LeagueMedal(league: league, size: 46)
                LeagueMedal(league: league, size: 132)
            }
        }
    }
    .padding(60)
    .background { TableGround() }
}
