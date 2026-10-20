import ScopaCore
import ScopaRewards
import SwiftUI

/// Oro on the album's page: how many foils are in, what filling it pays, the odds it is
/// filled at, and the forty places, each a foil or the gap where one goes.
///
/// There are no packs here. Every pack opened on the volume's page is also a pack for Oro,
/// so the page only shows what they turned up.
struct OroPage: View {
    let book: AlbumBook
    let purse: PurseStore

    @Environment(\.locale) private var locale
    @Environment(\.tableFelt) private var felt

    private var oro: Album { book.oro }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            found
            OroPrize(oro: oro, purse: purse)
            OroOdds()
            ForEach(Suit.allCases, id: \.self) { suit in
                suitSection(suit)
            }
            // Printed in the first volume's deck, whose cream paper takes the foil best.
            .environment(\.cardTheme, Volume.riviera.theme)
        }
    }

    // MARK: How far along

    private var found: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(oro.found) of \(Album.size)")
                    .font(.display(30))
                    .foregroundStyle(Palette.onTable)
                    .monospacedDigit()
                Spacer(minLength: 0)
                if oro.isComplete {
                    Text("Complete")
                        .textCase(.uppercase)
                        .font(.system(size: 12.5, weight: .heavy))
                        .tracking(1.4)
                        .foregroundStyle(Palette.goldLight)
                }
            }
            bar
            HStack(spacing: 6) {
                ForEach(Rarity.allCases, id: \.self) { rarity in rarityCount(rarity) }
            }
            Text("Every foil still counts for its volume. Oro fills beside them, from any pack.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassPanel(radius: GlassRadius.panel)
    }

    /// How far in, in gold leaf.
    private var bar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(felt.shade(0.5))
                Capsule()
                    .fill(GoldLeaf.board)
                    .frame(width: max(geometry.size.width * oro.fraction, oro.found > 0 ? 6 : 0))
            }
        }
        .frame(height: 6)
    }

    private func rarityCount(_ rarity: Rarity) -> some View {
        let all = Deck.standard.filter { $0.rarity == rarity }
        let have = all.count { oro.has($0) }
        return VStack(spacing: 4) {
            RarityTag(rarity, locale: locale, size: 8.5)
            Text(verbatim: "\(have)/\(all.count)")
                .font(.system(size: 12, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(have == all.count ? Palette.goldLight : Palette.onTable)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: One suit

    private func suitSection(_ suit: Suit) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(OroSuit.name(suit, locale: locale))
                    .textCase(.uppercase)
                    .font(.system(size: 12.5, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(Palette.onTable)
                if oro.isComplete(suit) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.goldLight)
                }
                Spacer(minLength: 0)
                Text(verbatim: "\(10 - oro.missing(in: suit).count)/10")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Palette.onTableSoft)
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Rank.allCases, id: \.self) { rank in
                    OroSlot(card: Card(rank, of: suit), count: oro.count(of: Card(rank, of: suit)))
                }
            }
        }
    }
}

/// One place in Oro: the foil, which catches the light once as it comes into view, or the
/// gap it goes in, ruled in gold.
struct OroSlot: View {
    let card: Card
    let count: Int

    private static let width: CGFloat = 58
    private var radius: CGFloat { Self.width * 0.12 }

    var body: some View {
        Group {
            if count > 0 {
                CardView(card: card, width: Self.width)
                    .foil(true)
                    .overlay { FoilGlare(fanfare: .grand, tint: Palette.goldLight, glance: 0, radius: radius) }
            } else {
                MissingCard(card: card, width: Self.width, ghost: 0.1)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius)
                            .strokeBorder(Palette.goldLight.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
            }
        }
        .overlay(alignment: .bottomTrailing) { if count > 1 { spares } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(card.rank.italianName) of \(Text(card.suit.name))"))
        .accessibilityValue(count > 0
                            ? Text("Found", comment: "A card that is in the album")
                            : Text("Missing", comment: "A card that is not in the album yet"))
    }

    private var spares: some View {
        Text(verbatim: "×\(count)")
            .font(.system(size: 10, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background { Capsule().fill(GoldLeaf.board) }
            .offset(x: 4, y: 4)
    }
}
