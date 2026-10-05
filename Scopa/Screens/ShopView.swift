import SwiftUI
import ScopaCore
import ScopaRewards

/// Where denari are spent. Everything for sale is cosmetic, and buying equips straight away.
struct ShopView: View {
    @Bindable var store: TableStore
    let purse: PurseStore
    let ads: AdsStore

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ShopContent(store: store, purse: purse, ads: ads)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .tint(Palette.goldLight)
                    }
                }
        }
    }
}

/// The shelves without the sheet around them, so the settings can push the same page.
struct ShopContent: View {
    @Bindable var store: TableStore
    let purse: PurseStore
    let ads: AdsStore

    @Environment(\.locale) private var locale
    @State private var isWatching = false
    /// The last tap on the opt-in ad found no video to show.
    @State private var noVideo = false
    /// The purchase waiting on a yes and the last thing bought, shared by every shelf.
    @State private var counter: ShopCounter
    /// Buying a pack, opening it, and paying out what it turned up. The album keeps one
    /// too, for the shelf of packs made of cards.
    @State private var till = PackTill()
    /// The sections whose tops have scrolled up under the jump bar.
    @State private var passed: Set<ShopJump> = []
    /// Open until the first purchase: by then the shop has explained itself.
    @AppStorage("shop.guideOpen") private var guideOpen = true

    init(store: TableStore, purse: PurseStore, ads: AdsStore) {
        self.store = store
        self.purse = purse
        self.ads = ads
        _counter = State(initialValue: ShopCounter(purse: purse))
    }

    var body: some View {
        ScrollViewReader { reader in
            shelves.shopJumpBar(ShopJumpBar(current: section) { jump in
                withAnimation(.snappy) { reader.scrollTo(jump.rawValue, anchor: .top) }
            })
        }
        .background(TableGround())
        .packTill(till, book: store.albumBook, purse: purse, name: store.playerName)
        .task { ads.prepareReward() }
        .task { await askForDebugging() }
        .sensoryFeedback(.success, trigger: counter.bought)
        .onChange(of: counter.bought) { guideOpen = false }
        .confirmation(isPresented: $counter.confirmsPurchase) {
            guard let pending = counter.pending else { return nil }
            return Confirmation(Text("Buy \(pending.item.title)?"),
                                message: Text("Leaves you \((purse.balance - pending.item.price).coins) denari."),
                                actions: [
                .init(title: Text("Buy for \(pending.item.price.coins) denari")) { counter.pay(for: pending) },
                .init(title: Text("Not now"), role: .cancel),
            ])
        }
        .navigationTitle("Shop")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The last section to have gone under the bar, which is the one being looked at.
    private var section: ShopJump? { ShopJump.allCases.last(where: passed.contains) }

    private var shelves: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                balance
                // Packs handed over rather than bought, torn here where they are sold.
                ShopWaitingPacks(book: store.albumBook, purse: purse, till: till)
                // Next to the balance it tops up, above the fold: further down, players
                // did not know it was there.
                watchForDenari
                AdFreeShopRow(ads: ads)
                hero
                ShopGuide(isOpen: $guideOpen).id("guide")
                packs.passesUnderShopBar(.packs, into: $passed)
                ShopDeck(store: store, purse: purse, counter: counter).passesUnderShopBar(.cards, into: $passed)
                ShopTable(store: store, purse: purse, counter: counter).passesUnderShopBar(.table, into: $passed)
                ShopSongs(purse: purse, counter: counter).passesUnderShopBar(.songs, into: $passed)
                ShopSeat(store: store, purse: purse, counter: counter).passesUnderShopBar(.you, into: $passed)
                ShopSweeps(store: store, purse: purse, counter: counter).passesUnderShopBar(.sweeps, into: $passed)
                earning
                PromoCodeRow(purse: purse, book: store.albumBook)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .defaultScrollAnchor(DebugLaunch.promoCode == nil ? nil : .bottom)
        .scrollsToDebugShelf()
        .softScrollEdge(.top)
    }

    /// `-confirmBuy` puts the purchase question up for the first thing not owned yet, once
    /// the purse is read and the sheet has finished rising, as a tap would.
    private func askForDebugging() async {
        #if DEBUG
        guard DebugLaunch.confirmsPurchase else { return }
        while !purse.isReady { try? await Task.sleep(for: .milliseconds(100)) }
        try? await Task.sleep(for: .seconds(1))
        guard let item = Cosmetics.catalogue.items.first(where: { $0.price > .zero && !purse.owns($0) })
        else { return }
        counter.ask(for: item) {}
        #endif
    }

    // MARK: The purse

    private var balance: some View {
        HStack(spacing: 14) {
            DenariMark(size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(purse.balance.coins) denari")
                    .font(.display(28))
                    .foregroundStyle(Palette.onTable)
                    .contentTransition(.numericText())
                Text(purse.problem ?? (purse.ownsEverything
                    ? LocalizedStringKey("Tutto pulito — the whole shop is yours")
                    : LocalizedStringKey("Won at the table. Spend wisely, or don't")))
                    .font(.system(size: 13))
                    .foregroundStyle(purse.problem == nil ? Palette.onTableSoft : Palette.terracotta)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .glassPanel(radius: GlassRadius.control)
        .animation(.snappy, value: purse.balance)
    }

    // MARK: Your table

    /// The real table, dressed as it currently is, changing under every tap below.
    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption(text: "Your table")
            TableHero(theme: store.cardTheme, felt: store.tableFelt, tapis: store.tapis,
                      back: store.cardBack, name: store.playerName, mark: store.seatMark,
                      cornice: store.cornice, livery: store.livery, companion: store.companion)
                .animation(.spring(duration: 0.4, bounce: 0.18), value: store.cardTheme)
                .animation(.spring(duration: 0.4, bounce: 0.18), value: store.tableFelt)
                .animation(.spring(duration: 0.4, bounce: 0.18), value: store.tapis)
                .animation(.spring(duration: 0.4, bounce: 0.18), value: store.seatMark)
                .animation(.spring(duration: 0.4, bounce: 0.18), value: store.cornice)
                .animation(.spring(duration: 0.4, bounce: 0.18), value: store.cardBack)
                .animation(.spring(duration: 0.4, bounce: 0.18), value: store.companion)
                .animation(.spring(duration: 0.4, bounce: 0.18), value: store.livery)
        }
    }

    // MARK: Packs

    /// The shop's own packs: a handful of things off these shelves, sealed, for less than
    /// the same things cost one at a time. The album sells the other shelf, made of cards.
    private var packs: some View {
        VStack(alignment: .leading, spacing: 8) {
            PackShelf(shelf: .shop, title: "Packs", purse: purse, till: till, showsProblem: false)
            Text("A pack holds a few things picked at random from the shelves below, for less than buying them one by one. Never anything you already own. Odds shows the chances.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .id("packs")
    }

    // MARK: How it is earned

    private var earning: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption(text: "How you earn")
            VStack(spacing: 9) {
                ForEach(Earning.allCases, id: \.self) { earning in
                    HStack(spacing: 10) {
                        Text(earning.tally(count: 1, locale: locale))
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.onTable)
                        Spacer(minLength: 8)
                        DenariLabel(amount: earning.unitValue, size: 14, signed: true)
                    }
                }
            }
            .padding(16)
            .glassPanel(radius: GlassRadius.control)
            Text("Denari are never sold for money, and nothing here changes how the cards fall.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: The rewarded ad

    /// Stands whenever ads are on, so it is never taken for gone, and a tap with no video to
    /// hand says so. There is no daily allowance to spend.
    @ViewBuilder private var watchForDenari: some View {
        if ads.isReady {
            VStack(alignment: .leading, spacing: 10) {
                Caption(text: "Short of denari?")
                Button(action: watch) {
                    watchOffer
                        .padding(14)
                        .glassPanel(radius: GlassRadius.control, interactive: true)
                }
                .buttonStyle(.plain)
                .disabled(isWatching)
                if noVideo {
                    Text("No video to show right now. Try again in a little while.")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.onTableSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .animation(.easeInOut(duration: 0.2), value: noVideo)
        }
    }

    private var watchOffer: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 22))
                .foregroundStyle(Palette.goldLight)
            VStack(alignment: .leading, spacing: 3) {
                Text("Watch a short ad")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.onTable)
                Text("As often as you like")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.onTableSoft)
            }
            Spacer(minLength: 0)
            if isWatching {
                ProgressView().tint(Palette.goldLight)
            } else {
                DenariLabel(amount: ads.reward, size: 15, signed: true)
            }
        }
    }

    private func watch() {
        guard !isWatching else { return }
        isWatching = true
        noVideo = false
        Task {
            defer { isWatching = false }
            // Paid only on the network's word that the ad was watched to the end.
            switch await ads.watchRewarded() {
            case .watched:
                // The device as well as the count: the count is this phone's own, the ledger
                // the account's, so a bare count would collide with another device's watches.
                let key = "ad/\(Device.id)/\(ads.rewardsWatched)"
                if await purse.earnFromAd(ads.reward, key: key) { Audio.shared.play(.purchase) }
            case .unavailable:
                noVideo = true
            case .closedEarly:
                break
            }
        }
    }
}
