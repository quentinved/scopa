import SwiftUI
import ScopaCore

/// What an opponent is holding, over their seat: the backs, or under Scatouch the faces.
struct SeatHand: View {
    let count: Int
    /// The cards themselves, once Scatouch has turned them over.
    let cards: [Card]?
    let width: CGFloat

    var body: some View {
        if let cards {
            RevealedHand(cards: cards, width: width)
        } else {
            HiddenHand(count: count, width: width)
        }
    }
}

/// An opponent's hand face up, fanned like the backs it stands in for but opened a little
/// wider, so every corner index can be read.
private struct RevealedHand: View {
    let cards: [Card]
    let width: CGFloat

    var body: some View {
        // Scopone's ten are held tighter, as the backs are.
        let tight = cards.count > 3
        HStack(spacing: -width * (tight ? 0.72 : 0.45)) {
            ForEach(Array(cards.enumerated()), id: \.element) { index, card in
                CardView(card: card, width: width)
                    .rotationEffect(.degrees(Double(index - cards.count / 2) * (tight ? 1.6 : 4)))
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                        removal: .scale(scale: 0.3).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(duration: 0.38, bounce: 0.2), value: cards)
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: cards.map(\.spoken).joined(separator: ", ")))
    }
}
