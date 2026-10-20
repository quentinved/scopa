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
    @Environment(DenariSale.self) private var sale
    @Environment(Toaster.self) private var toaster
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
    /// The gold page an owner of the no-ads purchase gets instead of its price.
    @State private var showsPatron = false
    /// The no-ads purchase, for everyone else.
    @State private var showsAdFree = false

    /// Owns the no-ads purchase, so the shop is dressed for a patron. See `patronDress`.
    private var isPatron: Bool { ads.pass.isOwned }

    init(store: TableStore, purse: PurseStore, ads: AdsStore) {
        self.store = store
        self.purse = purse
        self.ads = ads
        _counter = State(initialValue: ShopCounter(purse: purse, ads: ads))
    }

    var body: some View {
        ScrollViewReader { reader in
            shelves.shopJumpBar(ShopJumpBar(current: section) { jump in
                withAnimation(.snappy) { reader.scrollTo(jump.rawValue, anchor: .top) }
            })
        }
        .patronDress(isPatron)
        .packTill(till, book: store.albumBook, purse: purse, name: store.playerName)
        .fullScreenCover(isPresented: $showsPatron) { PatronSheet() }
        .sheet(isPresented: $showsAdFree) { AdFreeSheet(pass: ads.pass).coversBanner(carries: false) }
        .task { await showPatronForDebugging() }
        .task { ads.prepareReward() }
        // Here rather than on the bags' row, which is not drawn until they are priced.
        .task { await sale.loadProducts() }
        .task { await askForDebugging() }
        // Here rather than on the songs, which the lazy page puts away as it scrolls on.
        .onDisappear { Audio.shared.audition(nil) }
        .sensoryFeedback(.success, trigger: counter.bought)
        .onChange(of: counter.bought) { guideOpen = false }
        .confirmation(isPresented: $counter.confirmsPurchase) {
            counter.pending.map(purchaseQuestion)
        }
        .navigationTitle("Shop")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Buy it, or wear it for a game for a video first. A purse too light for it only gets
    /// the second, which is the one place a trial can turn into a sale.
    private func purchaseQuestion(_ pending: ShopCounter.Pending) -> Confirmation {
        let item = pending.item
        let affordable = purse.canAfford(item)
        let tries = counter.offersTrial(item)
        var actions: [Confirmation.Action] = []
        if affordable {
            actions.append(.init(title: Text("Buy for \(item.price.coins) denari")) { counter.pay(for: pending) })
        }
        if tries {
            actions.append(.init(title: Text("Watch an ad, wear it for a game"), role: affordable ? .plain : .primary) {
                tryOn(item)
            })
        }
        actions.append(.init(title: Text("Not now"), role: .cancel))
        guard affordable else {
            return Confirmation(Text("\(item.title) costs \(item.price.coins) denari"),
                                message: Text("You are \((item.price - purse.balance).coins) denari short. Take it for a spin in the meantime."),
                                actions: actions)
        }
        let leaves = Text("Leaves you \((purse.balance - item.price).coins) denari.")
        return Confirmation(Text("Buy \(item.title)?"),
                            message: tries ? Text("\(leaves) Or try it for one game first.") : leaves,
                            actions: actions)
    }

    /// Puts it on for the next game once the video has been watched to the end.
    private func tryOn(_ item: ShopItem) {
        Task {
            switch await ads.watchRewarded(.tryOn) {
            case .watched:
                store.tryOn.start(item)
                Audio.shared.play(.purchase)
                toaster.post(Toast(symbol: "sparkles", tint: Palette.gold,
                                   title: String(localized: "\(item.title) is yours for a game", locale: locale),
                                   detail: String(localized: "It goes back once your next game is over", locale: locale)))
            case .unavailable:
                toaster.post(Toast(symbol: "play.slash", tint: Palette.terracotta,
                                   title: String(localized: "No video to show right now", locale: locale),
                                   detail: String(localized: "Try again in a little while.", locale: locale)))
            case .closedEarly:
                break
            }
        }
    }

    /// The last section to have gone under the bar, which is the one being looked at.
    private var section: ShopJump? { ShopJump.allCases.last(where: passed.contains) }

    private var shelves: some View {
        ScrollView {
            // Lazy, so only the sections near the screen are built and kept up to date:
            // every frame of a scroll used to walk all five screens of the page.
            LazyVStack(alignment: .leading, spacing: 30) {
                balance
                // Packs handed over rather than bought, torn here where they are sold.
                ShopWaitingPacks(book: store.albumBook, purse: purse, till: till)
                // Next to the balance it tops up, above the fold: further down, players
                // did not know it was there.
                watchForDenari
                // Above the fold too, ahead of what costs real money: under those it went unseen.
                BoostShopRow(purse: purse)
                DenariShopRow(purse: purse)
                AdFreeShopRow(ads: ads, showOffer: { showsAdFree = true }, showPatron: { showsPatron = true })
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
        .toursShopForDebugging()
        .softScrollEdge(.top)
    }

    /// `-patron` puts the gold page up once the sheet has finished rising, as a tap would.
    private func showPatronForDebugging() async {
        #if DEBUG
        guard DebugLaunch.showsPatron else { return }
        try? await Task.sleep(for: .seconds(1))
        showsPatron = true
        #endif
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
                Text(purse.problem ?? purseLine)
                    .font(.system(size: 13))
                    .foregroundStyle(purse.problem == nil ? Palette.onTableSoft : Palette.terracotta)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if isPatron {
                // The patron's crest, worn by the purse. A tap shows what it stands for.
                Button { showsPatron = true } label: { PatronCrest(size: 46) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Patron of the house")
            }
        }
        .padding(16)
        .glassPanel(radius: GlassRadius.control)
        .animation(.snappy, value: purse.balance)
    }

    private var purseLine: LocalizedStringKey {
        if purse.ownsEverything { return "Tutto pulito — the whole shop is yours" }
        return isPatron ? "Half again on every game. Spend like a patron" : "Won at the table. Spend wisely, or don't"
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
            Text("Nothing here changes how the cards fall.")
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
                        .glassPanel(radius: GlassRadius.control)
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
