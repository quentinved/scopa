import SwiftUI
import ScopaCore
import ScopaRewards

struct ContentView: View {
    @State private var store = TableStore()
    @State private var ads = AdsStore()
    @State private var purse = PurseStore()
    @State private var reminders = Reminders()
    @State private var account = AccountSync()
    @State private var toaster = Toaster()
    @State private var friendsOnline = FriendsOnline()
    @State private var bannerCovers = BannerCovers()
    /// The screen the whole app is being drawn in. See `Stage`.
    @State private var screenSize: CGSize = .zero
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        startupTasks(audioReactions(purseReactions(screen)))
    }

    private var screen: some View {
        Group {
            if DebugLaunch.showsVerdict {
                RankedVerdictSheet()
            } else if DebugLaunch.showsCardSheet {
                CardSheetView()
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
        // Measured once here and handed down: every screen that folds sideways needs to
        // know whether it is being held that way, and on an iPad the size classes cannot
        // say — it is `.regular` both ways round. Nothing inside settles this size, so
        // writing it back cannot chase its own tail.
        .onGeometryChange(for: CGSize.self) { $0.size } action: { screenSize = $0 }
        .environment(\.screenSize, screenSize)
        .environment(\.cardTheme, store.cardTheme)
        .environment(\.cardBack, store.cardBack)
        .environment(\.locale, store.language.locale ?? .autoupdatingCurrent)
        .environment(\.tableFelt, store.tableFelt)
        .environment(\.tapis, store.tapis)
        .environment(toaster)
        .environment(\.bannerCovers, bannerCovers)
        .environment(ads)
        .environment(friendsOnline)
        // For screens opened without arguments, such as `CampaignView`.
        .environment(store)
        .environment(purse)
        .tint(Palette.terracotta)
        .overlay(alignment: .top) { NoticeBar(store: store) }
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
            .task(id: wheelSpentToday) { await refreshReminders() }
            // A turn just taken goes up now rather than on the next launch, so it is on
            // everyone else's strip under the wheel while it is still news.
            .onChange(of: wheelSpentToday) { was, now in
                if was == false, now == true { Task { await syncAccount() } }
            }
            // Consent first, then the SDK: `ads.isReady` stays false until both are done.
            .task { await ads.start() }
            // Settles the no-ads pass, then follows the App Store for the life of the app.
            .task { await ads.pass.watch() }
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

    /// Only while somebody could see the answer: signed in, switched on, and in front.
    private var beatsForFriends: Bool {
        store.isSignedIn && friendsOnline.isOn && scenePhase == .active
    }

    private func beatForFriends() async {
        guard beatsForFriends else { return }
        while !Task.isCancelled {
            let wait = await friendsOnline.beat()
            if store.route != .table { announceFriends() }
            try? await Task.sleep(for: wait)
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
            ? String(localized: "Ask them to a table from With friends", locale: locale)
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

    private func refreshReminders() async {
        guard let spent = wheelSpentToday else { return }
        await reminders.refresh(store.dailyBook, wheelSpentToday: spent)
    }

    private func syncAccount() async {
        guard canSyncAccount else { return }
        await account.sync(store, purse: purse, ads: ads, reminders: reminders)
    }

    /// Reminders are replanned on every return to the front, so the planned week always starts
    /// from today. The account is merged on the way back too: the other device has had
    /// the whole time the app was away to change something.
    private func handleScenePhase(_ phase: ScenePhase) {
        if phase == .active { Audio.shared.resume() } else { Audio.shared.pause() }
        if phase == .active { Task { await refreshReminders() } }
        if phase == .active { Task { await syncAccount() } }
        if phase == .active { Task { await friendsOnline.refreshAccess() } }
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
            case .playerLeft, .joinRefused: .notice
            default: nil
            }
        }
    }

    private func capsule(_ text: String) -> some View {
        Text(LocalizedStringKey(text))
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

    /// The deal and the scopa are shown as banners by the table, not here.
    private var message: String? {
        switch store.notice {
        case .rejected(let text): text
        case .playerLeft(let name): "\(name) left the table"
        case .joinRefused: "That table is full"
        case .dealt, .scopa, .none: nil
        }
    }
}

#Preview {
    ContentView()
}
