import SwiftUI

/// A round glass button with its name under it, in the house voice.
///
/// The lobby's corner coins were a "?" and a struck-through "AD" with nothing said about
/// them, so they were tapped by the players who already knew and missed by everyone else.
struct NamedCoin<Glyph: View>: View {
    @Environment(\.lift) private var lift
    let title: LocalizedStringKey
    @ViewBuilder var glyph: Glyph
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4 * lift) {
                glyph
                    .frame(width: 36 * lift, height: 36 * lift)
                    .glass(.riviera(), in: .circle)
                    .overlay { Circle().strokeBorder(Palette.gold.opacity(0.3), lineWidth: 1) }
                Text(title)
                    .textCase(.uppercase)
                    .font(.system(size: 12 * lift, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(Palette.onTable)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.onTable)
    }
}
