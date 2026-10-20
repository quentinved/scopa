import SwiftUI

/// What the shop's code panel says when the god mode's phrase is typed: on, or put away.
struct ScatouchAnswer: View {
    let isOn: Bool
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                SymbolCoin(symbol: isOn ? "hand.point.up.left.fill" : "hand.raised.slash.fill",
                           tint: isOn ? Palette.terracotta : Palette.steel, size: 36)
                Text(isOn ? "Scatouch!" : "Scatouch is off")
                    .font(.display(30))
                    .foregroundStyle(Palette.onTable)
            }
            Text(isOn
                 ? "Little finger up, and the cards obey. At a quick game every hand is face up, the deck is yours to pick from, and the bots can wait for you to make their moves."
                 : "The cards are face down again, and every game pays as it should. Type the code again to bring it back.")
                .font(.system(size: 15))
                .foregroundStyle(Palette.onTable)
                .fixedSize(horizontal: false, vertical: true)
            if isOn {
                Text("A game played like that pays nothing. Turn it off in Settings, under At the table, or type the code again.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.onTableSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button("Done", action: done)
                .buttonStyle(FilledButtonStyle())
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }
}
