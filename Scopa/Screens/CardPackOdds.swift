import ScopaCore
import ScopaRewards
import SwiftUI

/// What it takes to find a card the album is still missing: its own chance in each pack the
/// album sells, the free one first. Under the card when it is lifted off the page.
struct CardPackOdds: View {
    let card: Card
    /// The volume packs are filling, whose scarcity holds the good cards back.
    let volume: Volume

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 10) {
            Caption(text: "Chance in one pack")
            HStack(alignment: .top, spacing: 0) {
                ForEach(PackTier.on(.album)) { column($0) }
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 10)
        .padding(.horizontal, 6)
        .frame(maxWidth: 340)
        .glassPanel(radius: GlassRadius.control)
        .accessibilityElement(children: .combine)
    }

    private func column(_ tier: PackTier) -> some View {
        VStack(spacing: 4) {
            // A fixed slot, so the packs whose rays reach past them sit level with the rest.
            PackArt(tier: tier, width: 24)
                .frame(width: 40, height: 24 * 1.42)
            Text(verbatim: Odds.percent(Pack.packChance(finding: card, in: tier, volume: volume), locale: locale))
                .font(.system(size: 15, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(tier == .mazzetto ? Palette.onTable : Palette.goldLight)
            Text(verbatim: tier.title)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Palette.onTableSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

/// A chance, said as a share with as many places as it takes not to read as nothing:
/// "38%", "4.2%", "0.47%". Every odds figure on the album's pages is said this one way.
enum Odds {
    static func percent(_ chance: Double, locale: Locale) -> String {
        // Never "100%" for something that can still miss.
        let share = min(max(chance, 0.0001), 0.99)
        let precision: NumberFormatStyleConfiguration.Precision = switch share {
        case 0.1...: .fractionLength(0)
        case 0.01...: .fractionLength(1)
        default: .significantDigits(2)
        }
        return share.formatted(.percent.precision(precision).locale(locale))
    }
}
