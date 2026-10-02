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
    /// The volume on the page. Nil follows the one being collected, so the pack that
    /// finishes a volume turns the page to the next.
    @State private var shown: Volume?
    /// The card lifted off the page to be looked at, if any.
    @State private var zoomed: Card?
    /// Where the slots and the lifted card find each other.
    @Namespace private var page

    private var book: AlbumBook { store.albumBook }
    private var volume: Volume { shown ?? book.openVolume }
    private var album: Album { book.album(volume) }
    /// Every volume before this one is full.
    private var isOpen: Bool { volume.isOpen(given: book.album(_:)) }
    /// This is the volume packs go into, so it is the page that opens and sells them.
    private var isCollecting: Bool { volume == book.openVolume }

    /// Five to a row: ten across is a thumbnail nobody can read, and five leaves a card
    /// wide enough for a court figure to still be a figure.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    /// The cloth under it, so the glass is tinted with the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VolumeShelf(book: book, shown: volume) { turned in
                    shown = turned == book.openVolume ? nil : turned
                }
                // The pack is wrapped in the backs of the deck it holds.
                if isCollecting { waiting.environment(\.cardTheme, volume.theme) }
                if isOpen { found }
                prizes
                if isCollecting { shelf }
                if isOpen {
                    ForEach(Suit.allCases, id: \.self) { suit in
                        suitSection(suit)
                    }
                    // Printed in the volume's own deck, whatever the table is dressed in.
                    .environment(\.cardTheme, volume.theme)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .defaultScrollAnchor(DebugLaunch.showsAlbumEnd ? .bottom : .top)
        .softScrollEdge(.top)
        .background(TableGround())
        .overlay { zoom }
        // The bar clears while a card is up, so the dimmed page is all there is behind it.
        .navigationTitle(zoomed == nil ? Text("The album") : Text(verbatim: ""))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(zoomed != nil)
        .interactiveDismissDisabled(zoomed != nil)
        .sensoryFeedback(Haptic.pick, trigger: zoomed)
        // Arriving here is being told: the red dot on the lobby has done its job. And any
        // volume full without its prize on the shelf — finished on the other phone, or on a
        // pack the app never got to pay out — is settled now.
        .task {
            book.markSeen()
            if let card = DebugLaunch.albumZoom { zoomed = card }
            for finished in book.finishedVolumes { await purse.award(finished) }
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

    /// The card packs, at the top and impossible to miss. The shop's own packs wait in the
    /// shop, where that shelf is sold.
    private var waiting: some View {
        WaitingPacks(book: book, shelf: .album) { openEarned() }
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

    // MARK: What it pays

    @ViewBuilder private var prizes: some View {
        if volume == .riviera {
            AlbumPrizes(album: album, name: store.playerName, livery: store.livery)
        } else {
            VolumePrize(volume: volume, album: album, isOpen: isOpen)
        }
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

    /// One place on the page. Tapping it lifts the card off the page to be looked at, a gap
    /// as much as a card: what a gap is waiting for is worth a closer look too.
    private func slot(for card: Card) -> some View {
        Button { zoomed = card } label: { cell(for: card) }
            .buttonStyle(.plain)
            // Lifted, the slot is empty: the card up in the middle is this one.
            .opacity(zoomed == card ? 0 : 1)
            .accessibilityLabel(Text("\(card.rank.italianName) of \(Text(card.suit.name))"))
            .accessibilityValue(album.has(card)
                                ? Text("Found", comment: "A card that is in the album")
                                : Text("Missing", comment: "A card that is not in the album yet"))
    }

    /// The card if it has been found, and the shape of it if not.
    ///
    /// Anything above a numeral wears a hairline of its rarity, found or missing, so the
    /// thirteen cards worth chasing are visible as a shape on the page before anything has
    /// been read.
    private func cell(for card: Card) -> some View {
        let spares = album.spares(of: card)
        let rarity = card.rarity
        return ZStack(alignment: .bottomTrailing) {
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
            .matchedGeometryEffect(id: AlbumSpot.slot(card), in: page)
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
    }

    // MARK: A card up close

    @ViewBuilder private var zoom: some View {
        if let zoomed {
            AlbumCardZoom(card: zoomed, volume: volume, album: album, page: page) {
                self.zoomed = nil
            }
            .environment(\.cardTheme, volume.theme)
        }
    }
}

/// The gap a card goes in: its own outline, and the faintest ghost of the card itself, so
/// a page of gaps still reads as a deck rather than as a grid of empty boxes.
struct MissingCard: View {
    let card: Card
    let width: CGFloat
    /// How much of the card shows through. Faint on the page; a shade more up close, where
    /// the ghost is the whole picture.
    var ghost: Double = 0.13

    /// The cloth under it, so the glass is tinted with the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        RoundedRectangle(cornerRadius: width * 0.12)
            .fill(felt.shade(0.35))
            .overlay {
                CardView(card: card, width: width)
                    .opacity(ghost)
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
