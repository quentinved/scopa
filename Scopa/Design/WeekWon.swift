import SwiftUI
import ScopaRewards

/// The week-is-yours card: the laurel, the tasks it was won for, and the bonus it paid.
///
/// Finishing a week used to be one line in the payout list on the round summary — "The
/// week's challenge  +300" — and then the lobby, unchanged. A whole week of play is the
/// longest thing the game asks for, so it gets the same treatment a finished season does:
/// the screen stops, the laurel lands, and it is taken deliberately.
struct WeekWonCard: View {
    let goals: [WeeklyChallenge.Goal]
    /// The badge as this player wears it, so the laurel is seen landing on their own seat
    /// rather than on a stand-in.
    let name: String
    let mark: SeatMark
    let cornice: Cornice
    let take: () -> Void

    /// The plate is cut from the cloth, so it changes with the felt.
    @Environment(\.tableFelt) private var felt

    /// Set a beat after the card arrives, so the laurel is caught landing.
    @State private var landed = false

    var body: some View {
        VStack(spacing: 0) {
            heading
            laurel
            words
            reward
                .padding(.bottom, 22)
            takeButton
            Text("The laurel stays on your seat until the week ends, wherever you play.")
                .font(.system(size: 12.5))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(26)
        .frame(maxWidth: 380)
        .background { cardBackground }
        .task {
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.spring(duration: 0.7, bounce: 0.42)) { landed = true }
            Audio.shared.play(.reveal)
        }
        .sensoryFeedback(trigger: landed) { _, on in on ? Haptic.reveal : nil }
    }

    private var heading: some View {
        Text("THE WEEK IS YOURS")
            .font(.system(size: 12, weight: .heavy))
            .tracking(2)
            .foregroundStyle(Palette.goldLight)
            .padding(.bottom, 18)
    }

    /// The badge at a size worth looking at, on a burst of its own light.
    private var laurel: some View {
        ZStack {
            Burst(spokes: 14)
                .fill(Palette.goldSheen)
                .frame(width: 190, height: 190)
                .opacity(landed ? 0.22 : 0)
                .rotationEffect(.degrees(landed ? 22 : 0))
                .scaleEffect(landed ? 1 : 0.6)
            SeatBadge(name: name, tint: Palette.seat(0), size: 96, mark: mark,
                      honoured: true, cornice: cornice)
                .scaleEffect(landed ? 1 : 0.7)
        }
        .frame(height: 150)
        .padding(.bottom, 10)
    }

    /// What was actually asked for. Without it the card celebrates a week nobody can name.
    private var words: some View {
        VStack(spacing: 4) {
            Text("You finished")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
            Text("All \(goals.count) tasks")
                .font(.display(34))
                .foregroundStyle(Palette.onTable)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 5) {
                ForEach(goals, id: \.self) { goal in
                    Label {
                        Text(goal.title)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Palette.goldLight)
                    }
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Palette.onTable)
                }
            }
            .padding(.bottom, 18)
        }
    }

    /// The bonus for the lot, in the same denari chip the season card uses. Each task's own
    /// reward was paid on the summary of the game that finished it.
    private var reward: some View {
        HStack(spacing: 10) {
            DenariMark(size: 26)
            Text(verbatim: "+\(WeeklyChallenge.allDoneBonus.coins)")
                .font(.display(30))
                .monospacedDigit()
                .foregroundStyle(Palette.goldSheen)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background { Capsule().fill(felt.shade(0.5)) }
        .overlay { Capsule().strokeBorder(Palette.gold.opacity(0.4), lineWidth: 1) }
    }

    private var takeButton: some View {
        Button(action: take) {
            Text("Wear it")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background { Capsule().fill(Palette.terracotta) }
        }
        .buttonStyle(.plain)
        .padding(.bottom, 14)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(felt.plate(from: .top, to: .bottom))
            .overlay {
                RoundedRectangle(cornerRadius: 28).strokeBorder(Palette.gold.opacity(0.5), lineWidth: 1.5)
            }
            .shadow(color: Palette.ink.opacity(0.4), radius: 30, y: 14)
    }
}

/// A ring of tapering spokes, for the light behind something earned. Its own shape because
/// a starburst drawn with rotated rectangles has square ends and reads as a cog.
struct Burst: Shape {
    var spokes: Int = 12
    /// How far down the spoke the taper starts, as a fraction of the radius.
    var waist: CGFloat = 0.34

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let step = .pi * 2 / CGFloat(max(spokes, 3))
        // Half the gap between spokes, so neighbours never touch at the waist.
        let half = step * 0.22
        var path = Path()
        for index in 0..<max(spokes, 3) {
            let angle = step * CGFloat(index)
            let tip = point(centre, angle, radius)
            let left = point(centre, angle - half, radius * waist)
            let right = point(centre, angle + half, radius * waist)
            path.move(to: left)
            path.addLine(to: tip)
            path.addLine(to: right)
            path.addQuadCurve(to: left, control: centre)
            path.closeSubpath()
        }
        return path
    }

    private func point(_ centre: CGPoint, _ angle: CGFloat, _ distance: CGFloat) -> CGPoint {
        CGPoint(x: centre.x + cos(angle) * distance, y: centre.y + sin(angle) * distance)
    }
}

#Preview("The week is yours") {
    ZStack {
        TableGround()
        WeekWonCard(goals: [.wins(12), .scope(40), .cappotti(3)], name: "Quentin", mark: .broom, cornice: .none) {}
            .padding(20)
    }
}
