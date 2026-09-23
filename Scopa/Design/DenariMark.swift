import SwiftUI
import ScopaRewards

/// The currency mark: the coins-suit rosette, reduced until it still reads at 15 points.
struct DenariMark: View {
    var size: CGFloat = 16

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Palette.goldLight, Palette.gold],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle()
                .strokeBorder(Palette.ink.opacity(0.28), lineWidth: size * 0.055)
            // Eight petals, the same rosette the coin cards are built from.
            ForEach(0..<8, id: \.self) { petal in
                Capsule()
                    .fill(Palette.ink.opacity(0.22))
                    .frame(width: size * 0.09, height: size * 0.30)
                    .offset(y: -size * 0.20)
                    .rotationEffect(.degrees(Double(petal) * 45))
            }
            Circle()
                .fill(Palette.ink.opacity(0.22))
                .frame(width: size * 0.16, height: size * 0.16)
        }
        .frame(width: size, height: size)
    }
}

/// A balance or a price: the coin, then the number.
struct DenariLabel: View {
    var amount: Denari
    var size: CGFloat = 15
    var weight: Font.Weight = .semibold
    var tint: Color = Palette.onTable
    /// Shows the sign, for a line in an end-of-game tally.
    var signed = false

    var body: some View {
        HStack(spacing: size * 0.30) {
            DenariMark(size: size * 1.05)
            Text(verbatim: signed && amount.isCredit ? "+\(amount)" : "\(amount)")
                .font(.system(size: size, weight: weight))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        DenariLabel(amount: 1_240)
        DenariLabel(amount: 25, tint: Palette.ink, signed: true)
        DenariMark(size: 48)
    }
    .padding(40)
    .background(TableGround())
}

extension Denari {
    /// The balance as a chip shows it. Full digits below 100k, then abbreviated, so the
    /// lobby's top row still fits a name and three buttons beside it.
    var chipText: String {
        let coins = magnitude.coins
        let sign = self.coins < 0 ? "-" : ""
        switch coins {
        case ..<100_000: return "\(self.coins)"
        case ..<1_000_000: return "\(sign)\(coins / 1_000)K"
        default: return "\(sign)\(String(format: "%.1f", Double(coins) / 1_000_000))M"
        }
    }
}
