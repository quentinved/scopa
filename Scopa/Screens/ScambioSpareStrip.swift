import ScopaRewards
import SwiftUI

/// The spares a trade took, small and in a row, each with how many of it went. They fade
/// back once the card they paid for has turned over.
struct ScambioSpareStrip: View {
    let offer: Scambio.Offer
    /// The card they paid for is up.
    var spent: Bool

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: -8) {
                ForEach(offer.sparesInOrder, id: \.self) { card in
                    CardView(card: card, width: 34)
                        .overlay(alignment: .bottomTrailing) {
                            if let copies = offer.spares[card], copies > 1 { count(copies) }
                        }
                }
            }
            Text(verbatim: offer.cost(locale: locale))
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Palette.onTableSoft)
        }
        .opacity(spent ? 0.4 : 1)
        .scaleEffect(spent ? 0.92 : 1)
        .animation(.easeOut(duration: 0.5), value: spent)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: offer.cost(locale: locale)))
    }

    private func count(_ count: Int) -> some View {
        Text(verbatim: "×\(count)")
            .font(.system(size: 9, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 4)
            .padding(.vertical, 1.5)
            .background { Capsule().fill(Palette.goldSheen) }
            .offset(x: 3, y: 3)
    }
}
