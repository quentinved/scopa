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
    /// The last item bought, so its tile can show the gilding.
    @State private var bought: ShopItem.ID?
    /// Kept after the dialog closes so the dismissal animation still has a title to draw.
    @State private var pending: Pending?
    @State private var confirmsPurchase = false
    /// Buying a pack, opening it, and paying out what it turned up. The album keeps one
    /// too, for the shelf of packs made of cards.
    @State private var till = PackTill()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                balance
                hero
                packs
                watchForDenari
                drawings
                colours
                backs
                felts
                cloths
                companions
                marks
                liveries
                cornici
                flourishes
                cheers
                sayings
                earning
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .softScrollEdge(.top)
        .background(TableGround())
        .packTill(till, book: store.albumBook, purse: purse, name: store.playerName)
        .task { ads.prepareReward() }
        .sensoryFeedback(.success, trigger: bought)
        .confirmationDialog(Text("Buy \(pending?.item.title ?? "")?"),
                            isPresented: $confirmsPurchase, titleVisibility: .visible) {
            if let pending {
                Button("Buy for \(pending.item.price.coins) denari") { pay(for: pending) }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            if let pending {
                Text("Leaves you \((purse.balance - pending.item.price).coins) denari.")
            }
        }
        .navigationTitle("Shop")
        .navigationBarTitleDisplayMode(.inline)
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
                    : LocalizedStringKey("Earned at the table, spent here")))
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
    /// the same things cost one at a time. What is paid for is the chance of something
    /// above the floor, and what is given up is the choosing — which is the only trade a
    /// pack has ever offered. The album sells the other shelf, made of cards.
    private var packs: some View {
        VStack(alignment: .leading, spacing: 8) {
            PackShelf(shelf: .shop, title: "Packs", purse: purse, till: till, showsProblem: false)
            Text("A pack never hands you something you already have.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: The deck

    private var drawings: some View {
        shelf(.cardTheme, CardStyle.options)
    }

    private var colours: some View {
        shelf(.cardSkin, CardSkin.options)
    }

    /// One shelf per axis of the deck's look. The swatch swaps that axis into the equipped deck.
    private func shelf<Option: DeckOption>(_ kind: ShopItem.Kind, _ options: [Option]) -> some View {
        Shelf(title: Cosmetics.title(of: kind)) {
            ForEach(options) { option in
                let preview = option.applied(to: store.cardTheme)
                Button { pick(option) } label: {
                    Swatch(title: option.title, detail: option.explanation,
                           item: option.shopItem,
                           owned: purse.owns(option),
                           equipped: store.cardTheme == preview,
                           affordable: affordable(option.shopItem),
                           justBought: bought == option.shopItem?.id) {
                        HStack(spacing: -20) {
                            CardView(card: Card(.knight, of: .coins), width: 44)
                            CardBack(width: 44).rotationEffect(.degrees(7))
                        }
                        .environment(\.cardTheme, preview)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .reactsToPick(store.cardTheme)
    }

    /// The back is shown on a real card: the ruling, the deck's colours and the broom together.
    private var backs: some View {
        Shelf(title: Cosmetics.title(of: .cardBack)) {
            ForEach(CardBackPattern.allCases) { pattern in
                Button { pick(pattern) } label: {
                    Swatch(title: pattern.name, detail: pattern.explanation,
                           item: Cosmetics.item(for: pattern),
                           owned: purse.owns(pattern),
                           equipped: store.cardBack == pattern,
                           affordable: affordable(Cosmetics.item(for: pattern)),
                           justBought: bought == Cosmetics.item(for: pattern)?.id) {
                        CardBack(width: 52)
                            .environment(\.cardBack, pattern)
                            .environment(\.cardTheme, store.cardTheme)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .reactsToPick(store.cardBack)
    }

    // MARK: The table

    private var felts: some View {
        Shelf(title: Cosmetics.title(of: .felt)) {
            ForEach(TableFelt.allCases) { felt in
                Button { pick(felt) } label: {
                    Swatch(title: felt.title, detail: felt.explanation,
                           item: Cosmetics.item(for: felt),
                           owned: purse.owns(felt),
                           equipped: store.tableFelt == felt,
                           affordable: affordable(Cosmetics.item(for: felt)),
                           justBought: bought == Cosmetics.item(for: felt)?.id,
                           earnedBy: Streaks.milestone(for: felt).map { milestone -> LocalizedStringKey in
                               "\(milestone.days)-day streak"
                           }) {
                        FeltSwatch(felt: felt)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .reactsToPick(store.tableFelt)
    }

    /// Each cloth is previewed on the felt currently in use.
    private var cloths: some View {
        Shelf(title: Cosmetics.title(of: .tapis)) {
            ForEach(Tapis.allCases) { tapis in
                Button { pick(tapis) } label: {
                    Swatch(title: tapis.title, detail: tapis.explanation,
                           item: Cosmetics.item(for: tapis),
                           owned: purse.owns(tapis),
                           equipped: store.tapis == tapis,
                           affordable: affordable(Cosmetics.item(for: tapis)),
                           justBought: bought == Cosmetics.item(for: tapis)?.id) {
                        TapisSwatch(tapis: tapis, felt: store.tableFelt)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .reactsToPick(store.tapis)
    }

    // MARK: Who sits with you

    private var companions: some View {
        VStack(alignment: .leading, spacing: 8) {
            companionShelf
            Text("Everyone at the table sees who you brought.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var companionShelf: some View {
        Shelf(title: Cosmetics.title(of: .companion)) {
            ForEach(Companion.allCases) { companion in
                Button { pick(companion) } label: {
                    Swatch(title: companion.title, detail: companion.explanation,
                           item: Cosmetics.item(for: companion),
                           owned: purse.owns(companion),
                           equipped: store.companion == companion,
                           affordable: affordable(Cosmetics.item(for: companion)),
                           justBought: bought == Cosmetics.item(for: companion)?.id) {
                        CompanionSwatch(companion: companion, felt: store.tableFelt)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .reactsToPick(store.companion)
    }

    // MARK: The mark on your seat

    /// The marks for sale, then the earned ones as goals.
    private var marks: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption(text: Cosmetics.title(of: .mark))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    marksForSale
                    marksToEarn
                }
                .padding(.vertical, 4)
            }
            .scrollClipDisabled()
        }
        .reactsToPick(store.seatMark)
    }

    private var marksForSale: some View {
        ForEach(SeatMark.forSale) { mark in
            Button { pick(mark) } label: {
                Swatch(title: mark.name,
                       detail: mark.explanation,
                       item: Cosmetics.item(for: mark),
                       owned: purse.owns(mark),
                       equipped: store.seatMark == mark,
                       affordable: affordable(Cosmetics.item(for: mark)),
                       justBought: bought == Cosmetics.item(for: mark)?.id) {
                    SeatBadge(name: store.playerName, tint: Palette.seat(0), size: 46, mark: mark)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var marksToEarn: some View {
        ForEach(SeatMark.allCases.filter { $0.requirement != nil }) { mark in
            let earned = mark.isUnlocked(by: progress)
            Button {
                if earned { store.seatMark = mark; Audio.shared.play(.toggle) }
                else { Audio.shared.play(.refused) }
            } label: {
                Swatch(title: mark.name,
                       detail: mark.explanation,
                       item: nil,
                       owned: earned,
                       equipped: store.seatMark == mark,
                       affordable: true,
                       earnedBy: earned ? nil : mark.requirement?.label) {
                    SeatBadge(name: store.playerName, tint: Palette.seat(0), size: 46, mark: mark)
                        .saturation(earned ? 1 : 0)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var progress: MarkProgress {
        Achievements.markProgress(streak: store.dailyStreak, suits: store.albumBook.album.completedSuits,
                                  deck: store.albumBook.album.isComplete)
    }

    // MARK: The colour of your mark

    /// The badge in each colour, wearing the mark and the cornice already chosen, so the
    /// tile is the player's own icon rather than a colour chip.
    private var liveries: some View {
        VStack(alignment: .leading, spacing: 8) {
            liveryShelf
            Text("Everyone at the table sees the colour you play in.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var liveryShelf: some View {
        Shelf(title: Cosmetics.title(of: .livery)) {
            ForEach(SeatLivery.allCases) { livery in
                Button { pick(livery) } label: {
                    Swatch(title: livery.title, detail: livery.explanation,
                           item: Cosmetics.item(for: livery),
                           owned: purse.owns(livery),
                           equipped: store.livery == livery,
                           affordable: affordable(Cosmetics.item(for: livery)),
                           justBought: bought == Cosmetics.item(for: livery)?.id) {
                        SeatBadge(name: store.playerName, tint: Palette.seat(0), size: 46,
                                  mark: store.seatMark, cornice: store.cornice, livery: livery)
                            // Room for whatever metal the chosen mark already wears.
                            .frame(height: 68)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .reactsToPick(store.livery)
    }

    // MARK: What a sweep looks like

    /// Each flourish is previewed running, on a scrap of the cloth. A still picture of
    /// confetti is a picture of dots.
    private var flourishes: some View {
        Shelf(title: Cosmetics.title(of: .flourish)) {
            ForEach(Flourish.allCases) { flourish in
                Button { pick(flourish) } label: {
                    Swatch(title: flourish.title, detail: flourish.explanation,
                           item: Cosmetics.item(for: flourish),
                           owned: purse.owns(flourish),
                           equipped: store.flourish == flourish,
                           affordable: affordable(Cosmetics.item(for: flourish)),
                           justBought: bought == Cosmetics.item(for: flourish)?.id) {
                        FlourishSwatch(flourish: flourish, felt: store.tableFelt)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .reactsToPick(store.flourish)
    }

    // MARK: What a sweep sounds like

    /// The one shelf with nothing to show, so tapping a tile plays it. Picking a cheer and
    /// hearing it are the same gesture, which is the only honest way to sell a sound.
    private var cheers: some View {
        VStack(alignment: .leading, spacing: 8) {
            cheerShelf
            Text("Only you hear it. The table across from you keeps the house sweep.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var cheerShelf: some View {
        Shelf(title: Cosmetics.title(of: .cheer)) {
            ForEach(Cheer.allCases) { cheer in
                Button { pick(cheer) } label: {
                    Swatch(title: cheer.title, detail: cheer.explanation,
                           item: Cosmetics.item(for: cheer),
                           owned: purse.owns(cheer),
                           equipped: store.cheer == cheer,
                           affordable: affordable(Cosmetics.item(for: cheer)),
                           justBought: bought == Cosmetics.item(for: cheer)?.id) {
                        CheerSwatch(cheer: cheer, owned: purse.owns(cheer))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .reactsToPick(store.cheer)
    }

    // MARK: What goes round the mark

    /// Previewed on the mark the player is wearing, since that is where a cornice appears.
    private var cornici: some View {
        Shelf(title: Cosmetics.title(of: .cornice)) {
            ForEach(Cornice.allCases) { cornice in
                Button { pick(cornice) } label: {
                    Swatch(title: cornice.title, detail: cornice.explanation,
                           item: Cosmetics.item(for: cornice),
                           owned: purse.owns(cornice),
                           equipped: store.cornice == cornice,
                           affordable: affordable(Cosmetics.item(for: cornice)),
                           justBought: bought == Cosmetics.item(for: cornice)?.id) {
                        SeatBadge(name: store.playerName, tint: Palette.seat(0), size: 40,
                                  mark: store.seatMark, cornice: cornice)
                            // A badge draws outside its own size, so reserve room for the
                            // deepest ring and a crown's rays.
                            .frame(height: 68)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .reactsToPick(store.cornice)
    }

    // MARK: What you can say

    private var sayings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption(text: Cosmetics.title(of: .reactions))
            VStack(spacing: 10) {
                ForEach(Cosmetics.reactionPacks) { pack in
                    Button { buy(pack) } label: {
                        ReactionPackRow(pack: pack, owned: purse.owns(pack),
                                        affordable: purse.canAfford(pack.item),
                                        justBought: bought == pack.id)
                    }
                    .buttonStyle(.plain)
                    .disabled(purse.owns(pack))
                }
            }
        }
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
            Text("Nothing here can be bought with money, and nothing here changes how the cards fall.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: The rewarded ad

    /// Absent rather than greyed out when no ad is loaded or the day's allowance is spent.
    @ViewBuilder private var watchForDenari: some View {
        if ads.offersReward {
            VStack(alignment: .leading, spacing: 10) {
                Caption(text: "Short of denari?")
                Button(action: watch) {
                    watchOffer
                        .padding(14)
                        .glassPanel(radius: GlassRadius.control, interactive: true)
                }
                .buttonStyle(.plain)
                .disabled(isWatching)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .animation(.spring(duration: 0.4, bounce: 0.2), value: ads.rewardsLeftToday)
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
                Text("\(ads.rewardsLeftToday) left today")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.onTableSoft)
            }
            Spacer(minLength: 0)
            DenariLabel(amount: ads.reward, size: 15, signed: true)
        }
    }

    private func watch() {
        guard !isWatching else { return }
        isWatching = true
        Task {
            defer { isWatching = false }
            // Paid only on the network's word that the ad was watched to the end.
            guard await ads.watchRewarded() else { return }
            await purse.earnFromAd(ads.reward, key: "ad/\(ads.rewardsWatched)")
            Audio.shared.play(.purchase)
        }
    }

    // MARK: Picking

    private func affordable(_ item: ShopItem?) -> Bool {
        item.map(purse.canAfford) ?? true
    }

    private func pick(_ option: some DeckOption) {
        buyIfNeeded(option.shopItem) { store.cardTheme = option.applied(to: store.cardTheme) }
    }

    private func pick(_ felt: TableFelt) {
        // The streak felt is priced at zero but must not be sold: the streak is the only way in.
        if Streaks.milestone(for: felt) != nil, !purse.owns(felt) {
            Audio.shared.play(.refused)
            return
        }
        buyIfNeeded(Cosmetics.item(for: felt)) { store.tableFelt = felt }
    }

    private func pick(_ pattern: CardBackPattern) {
        buyIfNeeded(Cosmetics.item(for: pattern)) { store.cardBack = pattern }
    }

    private func pick(_ tapis: Tapis) {
        buyIfNeeded(Cosmetics.item(for: tapis)) { store.tapis = tapis }
    }

    private func pick(_ companion: Companion) {
        buyIfNeeded(Cosmetics.item(for: companion)) { store.companion = companion }
    }

    private func pick(_ cornice: Cornice) {
        buyIfNeeded(Cosmetics.item(for: cornice)) { store.cornice = cornice }
    }

    private func pick(_ mark: SeatMark) {
        buyIfNeeded(Cosmetics.item(for: mark)) { store.seatMark = mark }
    }

    private func pick(_ livery: SeatLivery) {
        buyIfNeeded(Cosmetics.item(for: livery)) { store.livery = livery }
    }

    private func pick(_ flourish: Flourish) {
        buyIfNeeded(Cosmetics.item(for: flourish)) { store.flourish = flourish }
    }

    /// A cheer equips and plays. It is the only thing in the shop that cannot be seen, so
    /// the tile has to say it out loud — and an owned one says it again on every tap, which
    /// is how anybody decides between two of them.
    private func pick(_ cheer: Cheer) {
        buyIfNeeded(Cosmetics.item(for: cheer)) {
            store.cheer = cheer
            Audio.shared.play(cheer.sound)
        }
    }

    /// A pack equips nothing: its reactions simply appear in the row at the table.
    private func buy(_ pack: Cosmetics.ReactionPack) {
        guard !purse.owns(pack) else { return }
        ask(for: pack.item) {}
    }

    private func buyIfNeeded(_ item: ShopItem?, then equip: @escaping () -> Void) {
        guard let item, !purse.owns(item) else {
            Audio.shared.play(.toggle)
            return equip()
        }
        ask(for: item, then: equip)
    }

    // MARK: Buying

    /// A purchase waiting on a yes.
    private struct Pending {
        let item: ShopItem
        let equip: () -> Void
    }

    /// Every shelf buys through here. A purse too light is refused on the spot rather than
    /// asked about, and the refusal writes the "N denari short" line under the balance.
    private func ask(for item: ShopItem, then equip: @escaping () -> Void) {
        let pending = Pending(item: item, equip: equip)
        self.pending = pending
        guard purse.canAfford(item) else { return pay(for: pending) }
        confirmsPurchase = true
    }

    private func pay(for pending: Pending) {
        Task {
            if await purse.buy(pending.item) {
                Audio.shared.play(.purchase)
                bought = pending.item.id
                pending.equip()
            } else {
                Audio.shared.play(.refused)
            }
        }
    }
}

private extension View {
    /// The spring and the click every shelf gives when its equipped item changes.
    func reactsToPick<Value: Equatable>(_ value: Value) -> some View {
        animation(.spring(duration: 0.35, bounce: 0.2), value: value)
            .sensoryFeedback(.selection, trigger: value)
    }
}

/// A titled row of swatches that scrolls sideways.
private struct Shelf<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption(text: title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) { content }
                    .padding(.vertical, 4)
            }
            .scrollClipDisabled()
        }
    }
}

/// A pack of reactions, with its four lines printed in the bubbles they arrive in.
private struct ReactionPackRow: View {
    let pack: Cosmetics.ReactionPack
    let owned: Bool
    let affordable: Bool
    let justBought: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: pack.title)
                        .font(.display(19))
                        .foregroundStyle(Palette.onTable)
                    Text(pack.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.onTableSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                price
            }
            lines
        }
        .padding(14)
        .glassPanel(radius: GlassRadius.control)
        .overlay { if justBought { Gilding().id(justBought) } }
        .opacity(owned || affordable ? 1 : 0.75)
        .contentShape(.rect(cornerRadius: GlassRadius.control))
    }

    @ViewBuilder private var price: some View {
        if owned {
            Text("Yours")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
        } else {
            DenariLabel(amount: pack.price, size: 15,
                        tint: affordable ? Palette.goldLight : Palette.onTableSoft)
        }
    }

    /// Two columns: a single row of four ran off the edge of a phone.
    private var lines: some View {
        let split = pack.reactions.count / 2 + pack.reactions.count % 2
        return HStack(alignment: .top, spacing: 8) {
            column(Array(pack.reactions.prefix(split)))
            column(Array(pack.reactions.dropFirst(split)))
        }
    }

    private func column(_ reactions: [Reaction]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(reactions, id: \.self) { reaction in
                SaidLine(reaction: reaction, size: 13, tint: Palette.cream)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.black.opacity(0.22)))
                    .overlay { Capsule().strokeBorder(Palette.gold.opacity(0.28)) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
