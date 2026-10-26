import SwiftUI
import ScopaCore
import ScopaRewards

struct ContentView: View {
    @State private var store = TableStore()
    @State private var ads = AdsStore()
    @State private var purse = PurseStore()
    @State private var sale = DenariSale()
    @State private var reminders = Reminders()
    @State private var account = AccountSync()
    @State private var toaster = Toaster()
    @State private var friendsOnline = FriendsOnline()
    @State private var bannerCovers = BannerCovers()
    @State private var gifts = CardGifts()
    /// The screen the whole app is being drawn in. See `Stage`.
    @State private var screenSize: CGSize = .zero
    @Environment(\.scenePhase) private var scenePhase
    /// Set when the app goes to the background, so only a real return refetches anything.
    @State private var wasAway = false
    @AppStorage(CardEdge.stored) private var cardEdge: CardEdge = .plain

    var body: some View {
        startupTasks(audioReactions(purseReactions(screen)))
    }

    private var screen: some View {
        Group {
            if DebugLaunch.showsVerdict {
                RankedVerdictSheet()
            } else if let run = DebugLaunch.keepRun {
                #if DEBUG
                KeepRunRehearsal(run: run)
                #endif
            } else if DebugLaunch.showsRecordLine {
                #if DEBUG
                RecordLineRehearsal()
                #endif
            } else if DebugLaunch.showsCardSheet {
                CardSheetView()
            } else if let draft = DebugLaunch.deckDraft {
                DeckDraftSheet(draft: draft.draft, page: draft.page)
            } else if let gift = DebugLaunch.dailyGift {
                DailyCardReveal(gift: gift, name: store.playerName) {}
            } else {
                routes
            }
        }
        // The banner is only shown under the lobby, never under a hand of cards. A sheet
        // over the lobby carries it instead, see `coversBanner`.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BannerSlot(ads: ads, isVisible: ads.showsBanner(on: store.route) && !bannerCovers.isCovered)
        }
        .animation(.easeInOut(duration: 0.25), value: store.route)
        // Over every screen, under the notices, the toasts and a full screen ad, and inside
        // the environment below so it is drawn in the player's language and cloth.
        .ladderCeremony(store: store)
        .matchFoundMoment(store: store)
        .cardGifts(gifts, store: store, purse: purse, toaster: toaster)
        // Measured once here and handed down: every screen that folds sideways needs to
        // know whether it is being held that way, and on an iPad the size classes cannot
        // say — it is `.regular` both ways round. Nothing inside settles this size, so
        // writing it back cannot chase its own tail.
        .onGeometryChange(for: CGSize.self) { $0.size } action: { screenSize = $0 }
        .environment(\.screenSize, screenSize)
        // A deck or a cloth tried for a game is worn over the one owned, the lobby included.
        .environment(\.cardTheme, store.tryOn.theme(over: store.cardTheme))
        .environment(\.cardBack, store.tryOn.back(over: store.cardBack))
        // Worn only while owned, so an edge chosen on the other phone waits for the ledger.
        .environment(\.cardEdge, DebugLaunch.wornEdge ?? (purse.owns(cardEdge.shopItem) ? cardEdge : .plain))
        .environment(\.locale, store.language.locale ?? .autoupdatingCurrent)
        .environment(\.tableFelt, store.tryOn.felt(over: store.tableFelt))
        .environment(\.tapis, store.tryOn.tapis(over: store.tapis))
        .environment(toaster)
        .environment(\.bannerCovers, bannerCovers)
        .environment(ads)
        .environment(friendsOnline)
        // For screens opened without arguments, such as `CampaignView`.
        .environment(store)
        .environment(purse)
        .environment(sale)
        .tint(Palette.terracotta)
        .overlay(alignment: .top) { NoticeBar(store: store) }
        // Over the table and its notices: a line in trouble wants an answer before another card.
        .overlay { ReconnectBanner(store: store) }
        // Its own layer: news outlives the screen it was posted from.
        .overlay(alignment: .top) { ToastBar(toaster: toaster) }
        // Above the banner and the notices: a full screen ad covers everything.
        .overlay { ads.gateway.overlayBody() }
    }

    @ViewBuilder private var routes: some View {
        Group {
            switch store.route {
            case .lobby: LobbyView(store: store, ads: ads, purse: purse, reminders: reminders, account: account)
            case .waiting: WaitingRoomView(store: store)
            case .table: TableScreen(store: store, ads: ads, purse: purse)
            }
        }
        // The campaign's map, shown again on the walk back from one of its tables.
        .campaignCover(store)
    }

    // MARK: Reactions

    /// The purse follows the passphrase, which pays its denari wherever it was said, and a
    /// stake that found no table comes back.
    private func purseReactions(_ content: some View) -> some View {
        content
            .onChange(of: ads.isSwept) { _, swept in
                guard swept else { return }
                Task { await purse.grantSweepGift() }
            }
            .task { await loadPurse() }
            .task(id: store.refusedStake?.id) { await refundRefusedStake() }
            .onChange(of: store.rank?.rating) { Task { await giveDivisionPacks() } }
    }

    /// An owner from before 1.4 is handed only what the pass has gained since, so the toast
    /// says what landed rather than the whole gift. An owner who had all of it already is
    /// handed 1.4's thank-you, and told so in a toast of its own.
    private func givePassGift() async {
        guard ads.pass.isOwned, purse.isReady, let gift = await purse.grantPassGift() else { return }
        if gift.pack { store.albumBook.give(Boost.passPack) }
        let locale = store.language.locale ?? .autoupdatingCurrent
        if gift.thanksAlone {
            return toaster.post(Toast(symbol: "gift.fill", tint: Palette.gold,
                                      title: String(localized: "A thank-you from the house", locale: locale),
                                      detail: String(localized: "\(gift.denari.coins) denari, a thank-you for going ad free",
                                                     locale: locale)))
        }
        let detail = gift.pack
            ? String(localized: "\(gift.denari.coins) denari, and a \(Boost.passPack.title) pack in the album", locale: locale)
            : String(localized: "\(gift.denari.coins) denari, straight into your purse", locale: locale)
        toaster.post(Toast(symbol: "gift.fill", tint: Palette.gold,
                           title: String(localized: "Thank you for going ad free", locale: locale), detail: detail))
    }

    /// A bag that landed with nobody watching for it, such as an Ask to Buy approved later.
    private func tellArrival(_ bag: DenariBag) {
        let locale = store.language.locale ?? .autoupdatingCurrent
        toaster.post(Toast(symbol: "gift.fill", tint: Palette.gold,
                           title: String(localized: "Your denari are here", locale: locale),
                           detail: String(localized: "\(bag.denari.coins) denari, straight into your purse", locale: locale)))
    }

    /// What the stops of the ranked road just passed pay, told in one toast. Never over a
    /// result still being told: at the table it waits for the verdict, or for the way out.
    private func giveDivisionPacks() async {
        guard let rank = store.rank else { return }
        let locale = store.language.locale ?? .autoupdatingCurrent
        guard let toast = await DivisionPayout.settle(rank, store: store, purse: purse, locale: locale) else { return }
        if store.route == .table { toaster.hold(toast) } else { toaster.post(toast) }
    }

    private func audioReactions(_ content: some View) -> some View {
        content
            // Asking for the loop already playing is a no-op.
            .task(id: store.route) { playRouteMusic() }
            .onChange(of: Audio.shared.tableSong) { _, _ in playRouteMusic() }
            .task { Audio.shared.warmUp() }
            .onChange(of: scenePhase) { _, phase in handleScenePhase(phase) }
    }

    /// The lobby keeps its own loop; the table plays the song picked in the shop.
    private func playRouteMusic() {
        Audio.shared.music(store.route == .table ? Audio.shared.tableSong.track : .lungomare)
    }

    private func startupTasks(_ content: some View) -> some View {
        content
            .task { DebugLaunch.applyIfRequested(to: store) }
            // Before anything reads a level: what was played before experience existed
            // still counts towards it.
            .task { Experience.seedFromWhatWasPlayed() }
            .onOpenURL { url in store.open(url) }
            // Planned again whenever what the reminders would say changes: the wheel turned,
            // the deal played, a task moved, a pack opened, the language switched.
            .task(id: reminderInputs) { await refreshReminders() }
            // A turn just taken goes up now rather than on the next launch, so it is on
            // everyone else's strip under the wheel while it is still news.
            .onChange(of: wheelSpentToday) { was, now in
                if was == false, now == true { Task { await syncAccount() } }
            }
            // Consent first, then the SDK: `ads.isReady` stays false until both are done.
            .task { await ads.start() }
            // Settles the no-ads pass, then follows the App Store for the life of the app.
            .task { await ads.pass.watch() }
            // The pass's denari and pack, once per account, as soon as it is owned and the
            // purse read.
            .task(id: ads.pass.isOwned && purse.isReady) { await givePassGift() }
            // The ledger vouches for a purchase StoreKit has gone quiet about.
            .task(id: purse.isReady && purse.purse.hasHadPass) {
                await ads.pass.believeLedger(purse.isReady && purse.purse.hasHadPass)
            }
            // Bags of denari pay into the purse, so the App Store is only followed once it is read.
            .task(id: purse.isReady) {
                guard purse.isReady else { return }
                await sale.watch(crediting: purse)
            }
            .onChange(of: sale.arrival) { _, arrival in
                if let arrival { tellArrival(arrival.bag) }
            }
            .task { store.listenForInvites() }
            .task { await showDebugAdIfAsked() }
            // The account waits for both: Game Center to say who this is, and the ledger to
            // have been read off the disk. Syncing before the purse is loaded would hand the
            // Worker an empty one and call it this device's copy.
            .task(id: canSyncAccount) { await syncAccount() }
            .task(id: store.isSignedIn) { await friendsOnline.refreshAccess() }
            .task(id: beatsForFriends) { await beatForFriends() }
            // Held while a hand is being played; told on the way back out.
            .onChange(of: store.route) { _, route in
                guard route != .table else { return }
                announceFriends()
                toaster.releaseHeld()
            }
    }

    // MARK: Handlers

    private func loadPurse() async {
        await purse.load()
        // Whatever was in use before the shop existed stays owned.
        await purse.grandfather([Cosmetics.item(for: store.cardTheme.style),
                                 Cosmetics.item(for: store.cardTheme.skin),
                                 Cosmetics.item(for: store.tableFelt)])
        if ads.isSwept { await purse.grantSweepGift() }
        #if DEBUG
        if let denari = DebugLaunch.grantedDenari { await purse.grantForDebugging(denari) }
        // Before `-purse`, which then evens out what setting the run moved.
        if let left = DebugLaunch.boostLeft { await purse.setBoostForDebugging(left: left) }
        // After the grant, so the two together land on the figure `-purse` asked for.
        if let total = DebugLaunch.exactPurse { await purse.setForDebugging(total) }
        if let stake = DebugLaunch.wager {
            let game = UUID()
            if await purse.stake(stake, gameID: game) { store.playForStake(stake, gameID: game) }
        }
        #endif
    }

    /// The stake went down before the table existed, so it comes straight back.
    private func refundRefusedStake() async {
        guard let refused = store.refusedStake else { return }
        await purse.refund(refused.stake, gameID: refused.gameID)
        store.clearRefusedStake()
    }

    private var canSyncAccount: Bool { store.isSignedIn && purse.isReady }

    /// Only while somebody could see the answer: signed in, switched on, and in front. Not
    /// `== .active`: Control Center pulled down would restart the loop and beat at once.
    private var beatsForFriends: Bool {
        store.isSignedIn && friendsOnline.isOn && scenePhase != .background
    }

    /// Still inside the Worker's 150 second window, so the player stays seen while playing.
    private static let tableBeat: Duration = .seconds(110)

    /// Beats half as often at the table, where the news waits for the hand to end anyway.
    /// Each beat wakes the phone's radio for several seconds.
    private func beatForFriends() async {
        guard beatsForFriends else { return }
        while !Task.isCancelled {
            let wait = await friendsOnline.beat()
            if store.route != .table { announceFriends() }
            try? await Task.sleep(for: store.route == .table ? max(wait, Self.tableBeat) : wait)
        }
    }

    /// A friend who has just arrived, as a toast. Never in the middle of a hand: that news
    /// waits for the table to be left, and is still news if they are still here.
    private func announceFriends() {
        let news = friendsOnline.takeNews()
        guard let first = news.first else { return }
        let locale = store.language.locale ?? .autoupdatingCurrent
        let title = news.count == 1
            ? String(localized: "\(first.name) is on Scopa", locale: locale)
            : String(localized: "^[\(news.count) friends](inflect: true) are on Scopa", locale: locale)
        let detail = news.count == 1
            ? String(localized: "Ask them to a table from Friends & bots", locale: locale)
            : news.map(\.name).formatted(.list(type: .and).locale(locale))
        toaster.post(Toast(symbol: "person.2.fill", tint: Palette.live, title: title, detail: detail))
    }

    /// Merges this device with the player's other ones: the preferences, the album, the
    /// counters and the purse. Quiet on every failure — an account that could not be
    /// reached changes nothing about the game in front of the player.
    /// Whether today's free turn of the wheel is gone, read off the ledger so a turn taken on
    /// the other device counts. Nil until the purse has been read.
    private var wheelSpentToday: Bool? {
        guard purse.isReady else { return nil }
        return purse.purse.keys.contains(DailyWheel.Ticket.free.key(on: store.today))
    }

    /// What the reminders are planned from. Nil until the ledger and the daily book are read.
    private var reminderInputs: Reminders.Inputs? { Reminders.inputs(store, purse: purse) }

    private func refreshReminders() async {
        guard let inputs = reminderInputs else { return }
        await reminders.refresh(inputs)
    }

    private func syncAccount() async {
        guard canSyncAccount else { return }
        await account.sync(store, purse: purse, ads: ads, reminders: reminders)
    }

    /// The account is not merged again this soon after the last time.
    private static let resyncGap: TimeInterval = 120

    /// Only a real trip away counts. `.inactive` is Control Center, a notification or a
    /// purchase sheet over the game: the music plays on and nothing is fetched again.
    ///
    /// Reminders are replanned on every return, so the planned week always starts from today
    /// and the comebacks count from this visit. The account is merged on the way back too:
    /// the other device has had the whole time the app was away to change something.
    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            wasAway = true
            Audio.shared.pause()
        case .active:
            // Also where music handed back by a call while not in front comes back.
            Audio.shared.resume()
            guard wasAway else { return }
            wasAway = false
            Task { await refreshReminders() }
            if account.syncedAt.map({ Date.now.timeIntervalSince($0) > Self.resyncGap }) ?? true {
                Task { await syncAccount() }
            }
            Task { await friendsOnline.refreshAccess() }
        default:
            break
        }
    }

    private func showDebugAdIfAsked() async {
        #if DEBUG
        guard DebugLaunch.showsAd else { return }
        await ads.showInterstitialForDebugging()
        #endif
    }
}

/// Non-blocking feedback: a refused move, a player leaving, a table that would not take us.
private struct NoticeBar: View {
    let store: TableStore

    @Environment(\.verticalSizeClass) private var heightClass
    @Environment(\.screenSize) private var screenSize
    private var stage: Stage { Stage(heightClass, size: screenSize) }

    var body: some View {
        Group {
            if let text = message {
                capsule(text)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: message)
        .sound(trigger: store.notice) { _, notice in
            switch notice {
            case .rejected: .refused
            case .playerLeft, .playerBack, .calledOff, .joinRefused: .notice
            default: nil
            }
        }
    }

    private func capsule(_ text: String) -> some View {
        (named ?? Text(LocalizedStringKey(text)))
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Palette.cream)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .glassCapsule(tint: Palette.ink.opacity(0.85))
            // Clear of the score row pinned to the top of the table screen.
            .padding(.top, stage.pick(tall: 60, wide: 46))
            .transition(.move(edge: .top).combined(with: .opacity))
            .id(text)
            .task(id: text) {
                try? await Task.sleep(for: .seconds(2.2))
                guard !Task.isCancelled else { return }
                store.clearNotice()
            }
    }

    /// A notice with a name in it, said through the catalog's "%@" line rather than looked up
    /// with the name already in, which no catalog has.
    private var named: Text? {
        switch store.notice {
        case .playerLeft(let name): Text("\(name) left the table")
        case .playerBack(let name): Text("\(name) is back at the table")
        case .calledOff(let name?): Text("\(name) left early, so this game won't count")
        default: nil
        }
    }

    /// The deal and the scopa are shown as banners by the table, not here.
    private var message: String? {
        switch store.notice {
        case .rejected(let text): text
        case .playerLeft(let name): "\(name) left the table"
        case .playerBack(let name): "\(name) is back at the table"
        case .calledOff(let name?): "\(name) left early, so this game won't count"
        case .calledOff(nil): "You left early, so this game won't count"
        case .joinRefused: "That table is full"
        case .dealt, .scopa, .none: nil
        }
    }
}

#Preview {
    ContentView()
}
