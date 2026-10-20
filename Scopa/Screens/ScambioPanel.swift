import ScopaCore
import ScopaRewards
import SwiftUI

/// Spares for a card the open volume is missing: the rates, and the cards the spares could
/// bring in right now. A tap asks first, on the app's own card, saying what would go.
///
/// Spares were paid for in denari when they came in, so a trade only ever spends cards.
struct ScambioPanel: View {
    let book: AlbumBook
    let purse: PurseStore
    /// The player's own name, for the mark a finished suit hands over.
    let name: String
    /// True from the yes until the new card has been looked at.
    @Binding var isTrading: Bool

    @Environment(\.locale) private var locale
    @Environment(\.tableFelt) private var felt
    @State private var asking: Scambio.Offer?
    @State private var made: AlbumBook.Trade?
    @State private var isPaying = false

    private var album: Album { book.tradingAlbum }

    var body: some View {
        Group {
            if !book.openAlbum.isComplete { panel }
        }
        .confirmation(isPresented: Binding(get: { asking != nil }, set: { if !$0 { asking = nil } }), ask)
        .fullScreenCover(item: $made, onDismiss: { isTrading = false }) { trade in
            ScambioReveal(trade: trade, name: name) { made = nil }
                .environment(\.cardTheme, trade.opening.volume.theme)
                .coversBanner(carries: false)
        }
        .onChange(of: purse.purse.entries.count, initial: true) { book.noteDepartures(in: purse.purse) }
        .task { await debugTrade() }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "Scambio")
                    .textCase(.uppercase)
                    .font(.system(size: 12.5, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(Palette.onTable)
                Spacer(minLength: 0)
                Text("Spares: \(spares)")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.onTableSoft)
            }
            Text("Spares for a card this volume is missing")
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
            ScambioRates()
            ready
        }
        .padding(16)
        .glassPanel(radius: GlassRadius.panel)
    }

    /// Spares that can be traded: everything but a spare settebello.
    private var spares: Int {
        Rarity.allCases.filter { Scambio.worth(of: $0) != nil }.reduce(0) { $0 + album.spares(ofRarity: $1) }
    }

    // MARK: What the spares reach

    @ViewBuilder private var ready: some View {
        let offers = book.offers
        if !book.tradingIsOpen {
            locked
        } else if offers.isEmpty {
            Text("Not enough spares for any missing card yet")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Caption(text: "Ready to trade")
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(offers) { offer in
                            Button { asking = offer } label: { gap(offer.card) }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text("\(offer.card.rank.italianName) of \(Text(offer.card.suit.name))"))
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    /// Before a volume's hundredth pack: how far it has come, and nothing to tap.
    private var locked: some View {
        let done = min(book.packsTowardTrading, Scambio.packsBeforeTrading)
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.system(size: 11, weight: .semibold))
                Text("Trading opens after \(Scambio.packsBeforeTrading) packs in this volume")
            }
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(Palette.onTable)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(felt.shade(0.5))
                    Capsule().fill(Palette.goldSheen)
                        .frame(width: geometry.size.width * Double(done) / Double(Scambio.packsBeforeTrading))
                }
            }
            .frame(height: 5)
            Text("\(done) of \(Scambio.packsBeforeTrading) packs")
                .font(.system(size: 11.5))
                .monospacedDigit()
                .foregroundStyle(Palette.onTableSoft)
        }
    }

    /// The card's gap from the page, edged in its rarity, in the volume's own deck.
    private func gap(_ card: Card) -> some View {
        MissingCard(card: card, width: 46, ghost: 0.3)
            .overlay {
                RoundedRectangle(cornerRadius: 46 * 0.12)
                    .strokeBorder(Rarities.tint(card.rarity).opacity(card.rarity > .plain ? 0.95 : 0.5),
                                  lineWidth: 1.4)
            }
            .environment(\.cardTheme, book.openVolume.theme)
    }

    // MARK: Asking and making

    private func ask() -> Confirmation? {
        guard let offer = asking else { return nil }
        let card = offer.card
        return Confirmation(Text("\(card.rank.italianName) of \(Text(card.suit.name))"),
                            message: Text("For \(offer.cost(locale: locale)) from your spares. They paid their denari when they came in."),
                            actions: [
            .init(title: Text("Trade for it")) { make(offer) },
            .init(title: Text("Not now"), role: .cancel),
        ])
    }

    private func make(_ offer: Scambio.Offer) {
        guard !isPaying else { return }
        isPaying = true
        isTrading = true
        Task {
            defer { isPaying = false }
            guard let trade = await book.trade(for: offer.card, purse: purse) else {
                isTrading = false
                return
            }
            made = trade
        }
    }

    /// `-scambio`: plants spares when there are none, then asks, or with `now` trades.
    private func debugTrade() async {
        #if DEBUG
        guard let wanted = DebugLaunch.scambio else { return }
        DebugLaunch.plantSpares(in: book)
        guard let offer = wanted.card.flatMap(book.offer(for:)) ?? book.offers.first else { return }
        try? await Task.sleep(for: .milliseconds(600))
        if wanted.now { make(offer) } else { asking = offer }
        #endif
    }
}
