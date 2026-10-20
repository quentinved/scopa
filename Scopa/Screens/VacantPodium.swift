import SwiftUI

/// The day's board before anybody is on it: an empty podium, what that means, and the way
/// onto it while the deal can still be played.
///
/// It was a walking figure over "Nobody has played today yet", which on a ladder this size
/// is most of most days, so the one screen the board showed most often was the bleakest.
struct VacantBoard: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    /// Deals today's hand. Nil once it is played, or on a day that is over.
    var play: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            VacantPodium().padding(.bottom, 14)
            Text(title)
                .font(.display(26))
                .foregroundStyle(Palette.onTable)
            Text(detail)
                .font(.system(size: 14))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
            if let play { playButton(play).padding(.top, 12) }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 36)
        .padding(.top, 34)
        .padding(.bottom, 40)
    }

    /// The lobby doors' gold pill, at a size a whole sheet can carry.
    private func playButton(_ play: @escaping () -> Void) -> some View {
        Button(action: play) {
            HStack(spacing: 7) {
                Image(systemName: "play.fill").font(.system(size: 12, weight: .bold))
                Text("Play today's deal").font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 22)
            .frame(height: 46)
            .background { Capsule().fill(Palette.goldSheen) }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}

/// Three glass steps with their medals and nobody standing on them, and a dashed seat over
/// first place: the board's own row badge, waiting for a name.
struct VacantPodium: View {
    var body: some View {
        VStack(spacing: 10) {
            seat
            HStack(alignment: .bottom, spacing: 3) {
                step(place: 2, league: 1, height: 74, medal: 28)
                step(place: 1, league: 2, height: 96, medal: 34)
                step(place: 3, league: 0, height: 60, medal: 26)
            }
        }
        .accessibilityHidden(true)
    }

    private var seat: some View {
        Circle()
            .strokeBorder(Palette.goldLight.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3.5]))
            .background { Circle().fill(Palette.gold.opacity(0.12)) }
            .frame(width: 46, height: 46)
    }

    /// A step, its medal set into the face and its place under it. First place is lit gold.
    private func step(place: Int, league: Int, height: CGFloat, medal: CGFloat) -> some View {
        VStack(spacing: 4) {
            LeagueMedal(league: league, size: medal)
            Text(verbatim: "\(place)")
                .font(.display(18))
                .foregroundStyle(Palette.onTableSoft)
        }
        .padding(.top, 9)
        .frame(width: 72, height: height, alignment: .top)
        .glassPanel(radius: 10, tint: league == 2 ? Palette.gold.opacity(0.22) : nil)
    }
}

#Preview {
    VacantBoard(title: "First place is free", detail: "Play today's deal and the ladder starts with you.") {}
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { TableGround() }
}
