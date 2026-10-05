import ScopaRewards
import SwiftUI

/// How the shop works, in four lines, for someone opening it for the first time. Folds to
/// its heading once they have bought something, and opens again on a tap.
struct ShopGuide: View {
    @Binding var isOpen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { isOpen.toggle() } label: { heading }
                .buttonStyle(.plain)
            if isOpen {
                VStack(alignment: .leading, spacing: 11) {
                    line("hand.tap.fill", "Tap anything to buy it. It is yours for good and goes on your table straight away.")
                    line("checkmark.circle.fill", "Tap anything you own to switch to it.")
                    line("lock.fill", "A few things are never sold: you earn them by playing, and the tile says how.")
                    rarity
                }
                .padding(16)
                .glassPanel(radius: GlassRadius.control)
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            }
        }
        .animation(.snappy, value: isOpen)
    }

    private var heading: some View {
        HStack(spacing: 8) {
            Caption(text: "How it works")
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.onTableSoft)
                .rotationEffect(.degrees(isOpen ? 0 : -90))
            Spacer(minLength: 0)
        }
        .contentShape(.rect)
    }

    private func line(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.goldLight)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Palette.onTable)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The four grades in order, so a tag on a tile means something before anything is bought.
    private var rarity: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                ForEach(Grade.allCases, id: \.self) { grade in
                    RarityTag(grade, size: 8.5)
                }
            }
            Text("How rare a thing is, from everyday to one of a kind. Rarer things turn up less often in packs.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 28)
    }
}
