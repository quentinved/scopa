import ScopaCore
import SwiftUI

/// The spare leaving: a small copy of the card lifts off and is gone, and the house says
/// thank you. Once, as the Worker says yes; the count under the card has already dropped.
struct GiftThanks: View {
    let card: Card
    let friend: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tableFelt) private var felt
    @State private var gone = false

    var body: some View {
        VStack(spacing: 4) {
            Text("Grazie!")
                .font(.display(24))
                .foregroundStyle(Palette.goldLight)
            Text("Your \(card.rank.italianName) of \(Text(card.suit.name)) is on its way to \(friend)")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(Palette.onTableSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .overlay(alignment: .top) { flight }
        .accessibilityElement(children: .combine)
        .sensoryFeedback(Haptic.prize, trigger: gone) { _, now in now }
        .task { await leave() }
    }

    /// The spare, from where the button was, up and away past the card it was a copy of.
    private var flight: some View {
        CardView(card: card, width: 54)
            .shadow(color: felt.shade(0.5), radius: 10, y: 6)
            .rotationEffect(.degrees(gone && !reduceMotion ? 16 : 0))
            .scaleEffect(gone ? 0.7 : 1)
            .offset(x: gone && !reduceMotion ? 80 : 0, y: gone && !reduceMotion ? -300 : -36)
            .opacity(gone ? 0 : 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// A beat after it lands, in a transaction of its own rather than the one that put it here.
    private func leave() async {
        try? await Task.sleep(for: .milliseconds(250))
        Audio.shared.play(.play)
        withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .easeIn(duration: 0.9)) { gone = true }
    }
}
