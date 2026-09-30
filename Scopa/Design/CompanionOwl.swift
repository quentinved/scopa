import SwiftUI

/// A plush little owl, the Notturna album's companion.
///
/// A civetta rather than a storybook owl: no ear tufts, a round flat head as wide as her
/// body, white brows meeting in a frown, a crown freckled white and the two yellow eyes that
/// are most of her face. She naps between turns, looks up when it is yours, and a poke tips
/// her head right over, which is the one thing everybody knows an owl can do.
struct OwlArt: View {
    let pose: AnimalPose

    /// Plush brown and cream. Kept here rather than in `Palette`: this is one toy's
    /// colouring, not a colour the table uses.
    private static let down = Color(red: 0.549, green: 0.416, blue: 0.306)
    private static let downDeep = Color(red: 0.431, green: 0.318, blue: 0.224)
    private static let freckle = Color(red: 0.937, green: 0.890, blue: 0.812)
    private static let breast = Color(red: 0.804, green: 0.698, blue: 0.584)
    private static let iris = Color(red: 0.937, green: 0.765, blue: 0.255)
    private static let beak = Color(red: 0.788, green: 0.702, blue: 0.431)

    private var size: CGFloat { pose.size }
    private var isPoked: Bool { pose.isPoked }
    private var stirs: Bool { pose.stirs }
    private var isAwake: Bool { pose.isAwake }

    var body: some View {
        ZStack {
            feet
            wing(at: -1)
            wing(at: 1)
            torso
            head
        }
        .animation(.spring(duration: 0.45, bounce: 0.4), value: isAwake)
    }

    /// Round and sat down, a little wider at the bottom.
    private var torso: some View {
        ZStack {
            Ellipse()
                .fill(Self.down)
                .frame(width: size * 0.62, height: size * 0.56)
            Ellipse()
                .fill(Self.breast)
                .frame(width: size * 0.38, height: size * 0.38)
                .offset(y: size * 0.04)
            streaks.offset(y: size * 0.04)
        }
        .offset(y: size * 0.15)
    }

    /// The breast's markings, three short rows of them.
    private var streaks: some View {
        VStack(spacing: size * 0.045) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: size * 0.05) {
                    ForEach(0..<(row == 1 ? 3 : 2), id: \.self) { _ in
                        Capsule()
                            .fill(Self.down.opacity(0.75))
                            .frame(width: size * 0.035, height: size * 0.065)
                    }
                }
            }
        }
    }

    /// Folded against her sides, and lifted a little when her head goes over.
    private func wing(at side: CGFloat) -> some View {
        Ellipse()
            .fill(Self.downDeep)
            .frame(width: size * 0.19, height: size * 0.38)
            .rotationEffect(.degrees(Double(side) * (isPoked ? 34 : stirs ? 14 : 8)), anchor: .top)
            .offset(x: side * size * 0.27, y: size * 0.13)
    }

    /// The head, as wide as she is, tipped right over on a poke and a little aside on a stir.
    private var head: some View {
        ZStack {
            Circle()
                .fill(Self.down)
                .frame(width: size * 0.56, height: size * 0.56)
            crown
            face
        }
        .rotationEffect(.degrees(isPoked ? -44 : stirs ? 11 : 0), anchor: .bottom)
        .offset(y: -size * headLift)
    }

    /// The white freckles across the top of the head.
    private var crown: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { index in
                let angle = Double(index) / 6 * 120 - 150
                Circle()
                    .fill(Self.freckle)
                    .frame(width: size * 0.035, height: size * 0.035)
                    .offset(x: cos(angle * .pi / 180) * size * 0.2,
                            y: sin(angle * .pi / 180) * size * 0.2)
            }
        }
    }

    /// Two pale discs round the eyes, the brows over them, and the beak between.
    private var face: some View {
        ZStack {
            HStack(spacing: -size * 0.03) {
                Circle().fill(Self.breast).frame(width: size * 0.25, height: size * 0.25)
                Circle().fill(Self.breast).frame(width: size * 0.25, height: size * 0.25)
            }
            HStack(spacing: size * 0.06) {
                eye
                eye
            }
            brows
            Triangle()
                .fill(Self.beak)
                .frame(width: size * 0.07, height: size * 0.07)
                .rotationEffect(.degrees(180))
                .offset(y: size * 0.1)
        }
        .offset(y: size * 0.03)
    }

    /// Yellow and round when she is watching, all pupil on a poke, and a shut lid in between.
    @ViewBuilder private var eye: some View {
        if isAwake || isPoked {
            ZStack {
                Circle().fill(Self.iris).frame(width: size * 0.16, height: size * 0.16)
                Circle().fill(Palette.ink)
                    .frame(width: size * (isPoked ? 0.11 : 0.075), height: size * (isPoked ? 0.11 : 0.075))
            }
        } else {
            Capsule()
                .fill(Self.downDeep)
                .frame(width: size * 0.13, height: size * 0.03)
                .frame(width: size * 0.16, height: size * 0.16)
        }
    }

    /// Two white strokes meeting over the beak, which is what gives a little owl her frown.
    private var brows: some View {
        HStack(spacing: size * 0.02) {
            Capsule().fill(Self.freckle)
                .frame(width: size * 0.15, height: size * 0.03)
                .rotationEffect(.degrees(14))
            Capsule().fill(Self.freckle)
                .frame(width: size * 0.15, height: size * 0.03)
                .rotationEffect(.degrees(-14))
        }
        .offset(y: -size * 0.1)
    }

    /// Two pale feet with the toes showing under her.
    private var feet: some View {
        HStack(spacing: size * 0.1) {
            Ellipse().fill(Self.beak).frame(width: size * 0.13, height: size * 0.08)
            Ellipse().fill(Self.beak).frame(width: size * 0.13, height: size * 0.08)
        }
        .offset(y: size * 0.42)
    }

    /// Sunk into her shoulders while she naps, and up when it is your turn.
    private var headLift: CGFloat {
        if isPoked { return 0.2 }
        if isAwake { return 0.18 }
        return stirs ? 0.15 : 0.13
    }
}

/// A plain triangle pointing up.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview("Civetta") {
    HStack(spacing: 30) {
        CompanionView(companion: .civetta, size: 80, mood: .resting)
        CompanionView(companion: .civetta, size: 80, mood: .watching)
    }
    .padding(40)
    .background(TableGround())
}
