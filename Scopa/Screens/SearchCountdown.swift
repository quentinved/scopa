import SwiftUI

/// The line under a ranked search, alone or as a duo: gold that runs out over exactly the
/// seconds the search has, and one line saying who is there if nobody comes.
///
/// Drawn from the clock rather than animated from a stored fraction, so a sheet redrawn
/// mid-search picks the line up where it actually is instead of starting it over.
struct SearchCountdown: View {
    let startedAt: Date
    let length: TimeInterval
    let note: LocalizedStringKey

    /// The cloth under it, so the glass is tinted with the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            // Thirty a second, not every frame the display can draw: a line this short moves
            // a pixel or two between ticks, and the panel sits over a lobby of glass that has
            // to be recomposited for each one.
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                track(left: timeLeft(at: timeline.date))
            }
            // The line is the sentence drawn; VoiceOver reads the sentence.
            .accessibilityHidden(true)
            Text(note)
                .font(.system(size: 11))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// How much of the search is still to come, 1 at the start and 0 at the end.
    private func timeLeft(at now: Date) -> Double {
        guard length > 0 else { return 0 }
        let gone = now.timeIntervalSince(startedAt) / length
        return min(max(1 - gone, 0), 1)
    }

    private func track(left: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(felt.shade(0.6))
                Capsule()
                    .fill(Palette.goldSheen)
                    .frame(width: max(geometry.size.width * left, 0))
            }
        }
        .frame(height: 6)
    }
}
