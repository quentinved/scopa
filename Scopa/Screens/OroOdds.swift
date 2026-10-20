import ScopaCore
import ScopaRewards
import SwiftUI

/// Oro's odds, printed under the packs' own: how rare each card's gold is, the
/// thumb on the scale toward the foils still missing, and how long the whole of it takes.
/// Then Perla, the album after it: when it opens and what it pays.
struct OroOdds: View {
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            oro
            perla
        }
    }

    private var oro: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                OroTag(size: 9)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: "Oro")
                        .font(.display(19))
                        .foregroundStyle(Palette.onTable)
                    Text("Any card from any pack can come out foil")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.onTableSoft)
                }
            }
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Rarity.allCases, id: \.self) { rarity in
                    oddsLine(rarity)
                }
                Rule()
                Group {
                    Text("The rarer the card, the rarer its gold: the settebello is the hardest of all. A foil Oro already has turns into one of the same rarity that it is still missing, and the last card Oro is missing always comes out gold. Once a rarity is full, its foils pay five spares in denari.")
                    Text("About one card in \(perCard) comes out foil. At five games a day and today's card, Oro takes about \(months) months; dear packs hold better cards, and so more foils.")
                }
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(13)
            .glassPanel(radius: GlassRadius.control)
        }
    }

    /// Perla's terms. The odds are Oro's, so they are not printed twice.
    private var perla: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                OroTag(size: 9, album: .perla)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: FoilAlbum.perla.title)
                        .font(.display(19))
                        .foregroundStyle(Palette.onTable)
                    Text("Opens once Oro is full")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.onTableSoft)
                }
            }
            Text("Then every foil comes out in mother-of-pearl, at the same odds as Oro's gold. Each suit leaves a \(FoilAlbum.perla.suitPack.title) pack waiting, and the whole of Perla gives Madreperla: mother-of-pearl on every card you play. About \(inMonths(FoilAlbum.perla.typicalDays)) months more.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel(radius: GlassRadius.control)
        }
    }

    private var perCard: Int { Int((1 / Oro.chance(in: .mazzetto)).rounded()) }
    private var months: Int { inMonths(Oro.typicalDays) }

    private func inMonths(_ days: Int) -> Int { Int((Double(days) / 30.4).rounded()) }

    private func oddsLine(_ rarity: Rarity) -> some View {
        HStack(spacing: 8) {
            RarityTag(rarity, locale: locale, size: 8.5)
            Text("each card, in gold")
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
            Spacer(minLength: 6)
            Text("1 in \(Int((1 / Oro.cardChance(of: rarity, in: .mazzetto)).rounded())) packs")
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Palette.onTable)
        }
    }
}
