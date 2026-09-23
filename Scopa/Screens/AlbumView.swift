import ScopaCore
import ScopaRewards
import SwiftUI

/// The album: the forty cards of the deck, the ones found and the gaps where the rest go —
/// and the packs, which is what the page is opened for.
///
/// What is collected is the deck the game is played with, in the art it is played in — so
/// the page is the game's own cards rather than a second set of pictures nobody has seen
/// before, and the card everybody who plays scopa already wants is the one hardest to find.
///
/// The packs come first and the deck second. Somebody arriving here with one waiting is
/// arriving to open it, and a page that made them scroll past their own cards to reach it
/// would be a page organised around its nouns rather than around what is being done.
struct AlbumView: View {
    @Bindable var store: TableStore
    let purse: PurseStore

    @Environment(\.locale) private var locale
    /// Buying a pack, opening it, and paying out what it turned up. Shared with the shop,
    /// which sells the other shelf of them.
    @State private var till = PackTill()

    private var book: AlbumBook { store.albumBook }
    private var album: Album { book.album }

    /// Five to a row: ten across is a thumbnail nobody can read, and five leaves a card
    /// wide enough for a court figure to still be a figure.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    /// The cloth under it, so the glass is tinted with the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                waiting
                found
                AlbumPrizes(album: album, name: store.playerName, livery: store.livery)
                shelf
                ForEach(Suit.allCases, id: \.self) { suit in
                    suitSection(suit)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .softScrollEdge(.top)
        .background(TableGround())
        .navigationTitle("The album")
        .navigationBarTitleDisplayMode(.inline)
        // Arriving here is being told: the red dot on the lobby has done its job.
        .task {
            book.markSeen()
            if DebugLaunch.opensPack {
                if let tier = DebugLaunch.packTier {
                    till.show(book.openBought(tier, owned: purse.purse.owned), purse: purse)
                } else {
                    openEarned()
                }
            }
        }
        .packTill(till, book: book, purse: purse, name: store.playerName)
    }

    // MARK: What is waiting

    /// The earned packs, at the top and impossible to miss. Absent rather than greyed out
    /// when there are none: a disabled button for a thing you cannot do yet is furniture.
    @ViewBuilder private var waiting: some View {
        if book.waiting > 0 {
            Button { openEarned() } label: {
                HStack(spacing: 16) {
                    PackArt(tier: book.nextTier, width: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("^[\(book.waiting) pack](inflect: true) waiting")
                            .font(.display(24))
                            .foregroundStyle(Palette.ink)
                        Text(book.nextTier == .mazzetto
                             ? "Three cards, whatever the deck gives you"
                             : "\(book.nextTier.title) first · a level reward")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Palette.ink.opacity(0.72))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.ink.opacity(0.7))
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: GlassRadius.panel).fill(Palette.goldSheen)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: How far along

    private var found: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(album.found) of \(Album.size)")
                    .font(.display(30))
                    .foregroundStyle(Palette.onTable)
                    .monospacedDigit()
                Spacer(minLength: 0)
                if album.isComplete {
                    Text("Complete")
                        .textCase(.uppercase)
                        .font(.system(size: 12.5, weight: .heavy))
                        .tracking(1.4)
                        .foregroundStyle(Palette.goldLight)
                }
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(felt.shade(0.5))
                    Capsule()
                        .fill(Palette.goldSheen)
                        .frame(width: max(geometry.size.width * album.fraction, album.found > 0 ? 6 : 0))
                }
            }
            .frame(height: 6)
            // One line per rarity, which is where the album says what it is short of. The
            // settebello reads as 0/1 or 1/1 and nothing else in the game does.
            HStack(spacing: 6) {
                ForEach(Rarity.allCases, id: \.self) { rarity in
                    rarityCount(rarity)
                }
            }
            Text("A card already in the album is paid for in denari instead, so no pack is ever wasted.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassPanel(radius: GlassRadius.panel)
    }

    /// How many of one rarity are in, out of how many there are.
    private func rarityCount(_ rarity: Rarity) -> some View {
        let all = Deck.standard.filter { $0.rarity == rarity }
        let have = all.count { album.has($0) }
        return VStack(spacing: 4) {
            RarityTag(rarity, locale: locale, size: 8.5)
            Text(verbatim: "\(have)/\(all.count)")
                .font(.system(size: 12, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(have == all.count ? Palette.goldLight : Palette.onTable)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: The shelf

    /// The packs made of cards, bought rather than played for, dearest last. The shop
    /// keeps the other shelf: the packs made of what is on its own shelves.
    private var shelf: some View {
        PackShelf(shelf: .album, title: "Packs", purse: purse, till: till)
    }

    // MARK: Opening

    private func openEarned() {
        guard let opened = book.openOne(owned: purse.purse.owned) else { return }
        till.show(opened, purse: purse)
    }

    // MARK: One suit

    private func suitSection(_ suit: Suit) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title(of: suit))
                    .textCase(.uppercase)
                    .font(.system(size: 12.5, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(Palette.onTable)
                if album.isComplete(suit) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.goldLight)
                }
                Spacer(minLength: 0)
                Text(verbatim: "\(10 - album.missing(in: suit).count)/10")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Palette.onTableSoft)
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Rank.allCases, id: \.self) { rank in
                    slot(for: Card(rank, of: suit))
                }
            }
        }
    }

    private func title(of suit: Suit) -> String {
        switch suit {
        case .coins: String(localized: "Coins", locale: locale)
        case .cups: String(localized: "Cups", locale: locale)
        case .swords: String(localized: "Swords", locale: locale)
        case .clubs: String(localized: "Clubs", locale: locale)
        }
    }

    /// One place on the page: the card if it has been found, and the shape of it if not.
    ///
    /// Anything above a numeral wears a hairline of its rarity, found or missing, so the
    /// thirteen cards worth chasing are visible as a shape on the page before anything has
    /// been read.
    @ViewBuilder private func slot(for card: Card) -> some View {
        let spares = album.spares(of: card)
        let rarity = card.rarity
        ZStack(alignment: .bottomTrailing) {
            Group {
                if album.has(card) {
                    CardView(card: card, width: 58)
                } else {
                    MissingCard(card: card, width: 58)
                }
            }
            .overlay {
                if rarity > .plain {
                    RoundedRectangle(cornerRadius: 58 * 0.12)
                        .strokeBorder(Rarities.tint(rarity).opacity(album.has(card) ? 0.95 : 0.45),
                                      lineWidth: rarity == .settebello ? 2 : 1.4)
                }
            }
            if spares > 0 {
                Text(verbatim: "×\(spares + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background { Capsule().fill(Palette.goldSheen) }
                    .offset(x: 4, y: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: card.description))
        .accessibilityValue(album.has(card)
                            ? Text("Found", comment: "A card that is in the album")
                            : Text("Missing", comment: "A card that is not in the album yet"))
    }
}

/// The gap a card goes in: its own outline, and the faintest ghost of the card itself, so
/// a page of gaps still reads as a deck rather than as a grid of empty boxes.
private struct MissingCard: View {
    let card: Card
    let width: CGFloat

    /// The cloth under it, so the glass is tinted with the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        RoundedRectangle(cornerRadius: width * 0.12)
            .fill(felt.shade(0.35))
            .overlay {
                CardView(card: card, width: width)
                    .opacity(0.13)
                    .grayscale(1)
                    .clipShape(RoundedRectangle(cornerRadius: width * 0.12))
            }
            .overlay {
                RoundedRectangle(cornerRadius: width * 0.12)
                    .strokeBorder(Palette.onTableSoft.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            .frame(width: width, height: width * 1.5)
    }
}
