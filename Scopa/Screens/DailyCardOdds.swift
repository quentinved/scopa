import ScopaCore
import ScopaRewards
import SwiftUI

/// What today's deal puts in the album, printed under the packs' own odds: one card for
/// finishing it and better odds for a win, and the pack a run brings every seventh day.
struct DailyCardOdds: View {
    /// Where the day's card goes: a later volume holds its good cards back harder.
    var volume: Volume = .riviera

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                CardBack(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Today's deal")
                        .font(.display(19))
                        .foregroundStyle(Palette.onTable)
                    Text("One card for every deal you finish")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.onTableSoft)
                }
            }
            VStack(spacing: 7) {
                columns
                ForEach(Rarity.allCases.filter { $0 > .plain }, id: \.self) { rarity in
                    oddsLine(rarity)
                }
                Rule()
                Text(packLine)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.onTableSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(13)
            .glassPanel(radius: GlassRadius.control)
        }
    }

    private var packLine: LocalizedStringKey {
        let first = DailyCard.pack(onStreak: DailyCard.packEvery)?.title ?? ""
        let then = DailyCard.pack(onStreak: DailyCard.packEvery * 2)?.title ?? ""
        return "Every seventh day in a row brings a pack too: a \(first) the first week, a \(then) every week after."
    }

    private var columns: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            Text("Played out").frame(width: Self.column)
            Text("Beat Hugo").frame(width: Self.column)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Palette.onTableSoft)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private static let column: CGFloat = 68

    private func oddsLine(_ rarity: Rarity) -> some View {
        HStack(spacing: 8) {
            RarityTag(rarity, locale: locale, size: 8.5)
            Text("or better")
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
            Spacer(minLength: 6)
            ForEach([false, true], id: \.self) { won in
                Text(verbatim: percent(DailyCard.chance(ofAtLeast: rarity, won: won, volume: volume)))
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.onTable)
                    .frame(width: Self.column)
            }
        }
    }

    /// One decimal below ten per cent, as the packs print theirs.
    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(value < 0.1 ? 1 : 0)).locale(locale))
    }
}
