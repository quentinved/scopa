import ScopaCore
import ScopaRewards
import SwiftUI

/// Perla on the album's page: Oro's page again, in mother-of-pearl. How many pearl foils are
/// in, what filling it pays, the odds, and the forty places.
///
/// Locked until Oro is full, when it shows only what it pays and how far Oro has to go.
struct PerlaPage: View {
    let book: AlbumBook
    let purse: PurseStore

    @Environment(\.locale) private var locale
    @Environment(\.tableFelt) private var felt

    private var perla: Album { book.perla }
    private var isOpen: Bool { book.oro.isComplete }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if isOpen { found } else { locked }
            OroPrize(oro: perla, purse: purse, album: .perla)
            OroOdds()
            if isOpen {
                ForEach(Suit.allCases, id: \.self) { suit in
                    suitSection(suit)
                }
                // Printed in the first volume's deck, whose cream paper takes the pearl best.
                .environment(\.cardTheme, Volume.riviera.theme)
            }
        }
    }

    // MARK: How far along

    private var found: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(perla.found) of \(Album.size)")
                    .font(.display(30))
                    .foregroundStyle(Palette.onTable)
                    .monospacedDigit()
                Spacer(minLength: 0)
                if perla.isComplete {
                    Text("Complete")
                        .textCase(.uppercase)
                        .font(.system(size: 12.5, weight: .heavy))
                        .tracking(1.4)
                        .foregroundStyle(Nacre.glow)
                }
            }
            PerlaBar(fraction: perla.fraction, started: perla.found > 0)
            HStack(spacing: 6) {
                ForEach(Rarity.allCases, id: \.self) { rarity in rarityCount(rarity) }
            }
            Text("Oro is full, so every foil now comes out in mother-of-pearl. Each still counts for its volume.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassPanel(radius: GlassRadius.panel)
        .overlay { pearlRule(GlassRadius.panel) }
    }

    /// Before Oro is full: what opens it, and how far Oro is from it.
    private var locked: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Nacre.glow)
                Text("Opens once Oro is full")
                    .font(.display(22))
                    .foregroundStyle(Palette.onTable)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: "Oro")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Palette.goldLight)
                Spacer(minLength: 0)
                Text(verbatim: "\(book.oro.found)/\(Album.size)")
                    .font(.system(size: 12.5, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.onTable)
            }
            GoldBar(fraction: book.oro.fraction, felt: felt)
            Text("Then every foil comes out in mother-of-pearl instead of gold, at the same odds.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassPanel(radius: GlassRadius.panel)
        .overlay { pearlRule(GlassRadius.panel) }
    }

    /// The finer rule Perla's panels wear: a hair of pearl inside the glass.
    private func pearlRule(_ radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius - 3)
            .strokeBorder(Nacre.shell, lineWidth: 0.8)
            .opacity(0.55)
            .padding(3)
            .allowsHitTesting(false)
    }

    private func rarityCount(_ rarity: Rarity) -> some View {
        let all = Deck.standard.filter { $0.rarity == rarity }
        let have = all.count { perla.has($0) }
        return VStack(spacing: 4) {
            RarityTag(rarity, locale: locale, size: 8.5)
            Text(verbatim: "\(have)/\(all.count)")
                .font(.system(size: 12, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(have == all.count ? Nacre.glow : Palette.onTable)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: One suit

    private func suitSection(_ suit: Suit) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Nacre.shell)
                    .overlay { Circle().strokeBorder(Nacre.silverDeep, lineWidth: 0.6) }
                    .frame(width: 7, height: 7)
                Text(OroSuit.name(suit, locale: locale))
                    .textCase(.uppercase)
                    .font(.system(size: 12.5, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(Palette.onTable)
                if perla.isComplete(suit) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Nacre.glow)
                }
                Spacer(minLength: 0)
                Text(verbatim: "\(10 - perla.missing(in: suit).count)/10")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Palette.onTableSoft)
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Rank.allCases, id: \.self) { rank in
                    PerlaSlot(card: Card(rank, of: suit), count: perla.count(of: Card(rank, of: suit)))
                }
            }
        }
    }
}

/// How far in, in mother-of-pearl, with a hair of silver round it.
private struct PerlaBar: View {
    let fraction: Double
    let started: Bool

    @Environment(\.tableFelt) private var felt

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(felt.shade(0.5))
                Capsule()
                    .fill(Nacre.board)
                    .overlay { Capsule().strokeBorder(Nacre.silverDeep.opacity(0.8), lineWidth: 0.6) }
                    .frame(width: max(geometry.size.width * fraction, started ? 6 : 0))
            }
        }
        .frame(height: 6)
    }
}

/// Oro's own bar, for the locked page's count of it.
private struct GoldBar: View {
    let fraction: Double
    let felt: TableFelt

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(felt.shade(0.5))
                Capsule()
                    .fill(GoldLeaf.board)
                    .frame(width: max(geometry.size.width * fraction, fraction > 0 ? 6 : 0))
            }
        }
        .frame(height: 6)
    }
}

/// One place in Perla: the pearl foil, which catches the light once as it comes into view,
/// or the gap it goes in, ruled in a hair of pearl with a line of seed dots inside it.
struct PerlaSlot: View {
    let card: Card
    let count: Int

    private static let width: CGFloat = 58
    private var radius: CGFloat { Self.width * 0.12 }

    var body: some View {
        Group {
            if count > 0 {
                CardView(card: card, width: Self.width)
                    .foil(true, in: .perla)
                    .overlay { FoilGlare(fanfare: .grand, tint: Nacre.glow, glance: 0, radius: radius) }
            } else {
                MissingCard(card: card, width: Self.width, ghost: 0.1)
                    .overlay { gap }
            }
        }
        .overlay(alignment: .bottomTrailing) { if count > 1 { spares } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(card.rank.italianName) of \(Text(card.suit.name))"))
        .accessibilityValue(count > 0
                            ? Text("Found", comment: "A card that is in the album")
                            : Text("Missing", comment: "A card that is not in the album yet"))
    }

    private var gap: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(Nacre.shell, lineWidth: 1)
                .opacity(0.5)
            RoundedRectangle(cornerRadius: radius - 3)
                .strokeBorder(Nacre.pearl.opacity(0.35),
                              style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [0.1, 3.4]))
                .padding(3)
        }
    }

    private var spares: some View {
        Text(verbatim: "×\(count)")
            .font(.system(size: 10, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(Nacre.graphite)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background {
                Capsule().fill(Nacre.board)
                    .overlay { Capsule().strokeBorder(Nacre.silverDeep, lineWidth: 0.6) }
            }
            .offset(x: 4, y: 4)
    }
}

/// Perla's cover: a board of mother-of-pearl, its rings showing, framed in a hair of silver,
/// a string of seed pearls down the spine, and its name struck in graphite.
struct PerlaCover: View {
    var width: CGFloat = 56

    private var height: CGFloat { width * 1.38 }

    var body: some View {
        let board = UnevenRoundedRectangle(topLeadingRadius: width * 0.05, bottomLeadingRadius: width * 0.05,
                                           bottomTrailingRadius: width * 0.11, topTrailingRadius: width * 0.11)
        ZStack(alignment: .leading) {
            board.fill(Nacre.pearl)
            board.fill(RadialGradient(stops: Nacre.bands(turns: 2, phase: 0.4), center: UnitPoint(x: 0.1, y: 1.1),
                                      startRadius: width * 0.1, endRadius: width * 1.9))
                .blendMode(.multiply)
                .opacity(0.6)
            board.fill(LinearGradient(colors: [.clear, .white.opacity(0.55), .clear],
                                      startPoint: .topTrailing, endPoint: .bottomLeading))
            spine
            title
        }
        .frame(width: width, height: height)
        .compositingGroup()
        .shadow(color: .black.opacity(0.35), radius: width * 0.1, y: width * 0.07)
    }

    private var spine: some View {
        Rectangle()
            .fill(LinearGradient(colors: [Nacre.silverDeep, Nacre.silver, Nacre.silverDeep],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(width: width * 0.11)
            .overlay {
                VStack(spacing: width * 0.05) {
                    ForEach(0..<5, id: \.self) { _ in
                        Circle()
                            .fill(RadialGradient(colors: [.white, Nacre.pearl, Nacre.silverDeep],
                                                 center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0,
                                                 endRadius: width * 0.04))
                            .frame(width: width * 0.055, height: width * 0.055)
                    }
                }
            }
    }

    private var title: some View {
        Text(verbatim: "PERLA")
            .font(.system(size: width * 0.165, weight: .bold, design: .serif))
            .tracking(width * 0.012)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(Nacre.graphite.opacity(0.85))
            .padding(.horizontal, width * 0.03)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                RoundedRectangle(cornerRadius: width * 0.04)
                    .strokeBorder(Nacre.silverDeep.opacity(0.85), lineWidth: max(1, width * 0.016))
            }
            .overlay {
                RoundedRectangle(cornerRadius: width * 0.025)
                    .strokeBorder(Nacre.silverDeep.opacity(0.45), lineWidth: max(0.5, width * 0.008))
                    .padding(width * 0.035)
            }
            .padding(.leading, width * 0.19)
            .padding([.top, .bottom, .trailing], width * 0.09)
    }
}
