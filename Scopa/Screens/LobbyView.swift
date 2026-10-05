import SwiftUI
import ScopaCore
import ScopaRewards

/// The front door: who you are, what is on today, and the ways to sit down.
///
/// The identity row stays at the top and the rest scrolls. Under the goals, ranked and the
/// campaign take the width, and the quick game — or the game saved on this phone — shares
/// the row under them with friends.
struct LobbyView: View {
    @Bindable var store: TableStore
    let ads: AdsStore
    let purse: PurseStore
    let reminders: Reminders
    let account: AccountSync
    @State private var isEditingSettings = false
    @State private var showsFriends = false
    @State private var showsOnline = false
    @State private var showsWager = false
    @State private var showsShop = false
    /// The no-ads purchase, opened from its corner button.
    @State private var showsAdFree = DebugLaunch.showsAdFree
    @State private var showsRules = false
    @State private var showsLadder = false
    @State private var showsWeekly = false
    @State private var showsAlbum = false
    @State private var showsCampaign = false
    /// Asked once, after the rules on a first launch, if the name is still the stand-in.
    @State private var asksName = false
    /// The walkthrough ended on "deal me a hand". The table cannot be dealt from under the
    /// sheet that asked for it, so the offer is held until the sheets are out of the way.
    @State private var startsCoached = false
    /// Asked before throwing away a saved game with denari on it: the stake would go too.
    @State private var confirmsForget = false
    /// Which page the friends sheet opens on; the debug launch can ask for the second.
    @State private var friendsPath: [FriendsSheet.Page] = []
    /// A season that ended while the app was closed, held until it has been collected.
    @State private var finishedSeason: Ladder.RankAnswer.Finish?
    @State private var isCollectingSeason = false
    /// The rating ask, after a long sitting that ended in a win. See `ReviewPrompt`.
    @State private var asksReview = false
    /// The day's wheel, and whether its sheet is up. See `DailyWheel`.
    @State private var wheel = DailyWheel()
    @State private var showsWheel = false

    @Environment(\.verticalSizeClass) private var heightClass
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.locale) private var locale
    @Environment(\.screenSize) private var screenSize
    private var stage: Stage { Stage(heightClass, size: screenSize) }
    /// One factor over every point size in the lobby: 1 on a phone, more on an iPad.
    private var lift: CGFloat { Stage.lift(widthClass, heightClass) }

    var body: some View {
        lobbySheets(layout)
            .onAppear(perform: handleAppear)
            .onChange(of: store.route) { _, route in closePlaySheets(for: route) }
            // The day's result is news once: leaving the lobby spends it.
            .onDisappear { store.clearFreshDaily() }
            .releaseMoment(store: store, purse: purse, isClear: isClearForNews) { shelf in
                if shelf == .shop { showsShop = true } else { showsAlbum = true }
            }
    }

    /// Nothing else on screen asking to be looked at, so a gift or a version's news can
    /// have its turn: the first launch's walkthrough is done, and no card or sheet is up.
    private var isClearForNews: Bool {
        let sheets = [isEditingSettings, showsFriends, showsOnline, showsWager, showsShop, showsRules,
                      showsLadder, showsWeekly, showsAlbum, asksName, startsCoached, showsWheel]
        return store.hasSeenRules && finishedSeason == nil && store.finishedChallenge == nil
            && !sheets.contains(true)
    }

    private var layout: some View {
        Group {
            if stage.isWide { wideBody } else { tallBody }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.lift, lift)
        .background { TableGround() }
        .overlay { seasonOverlay }
        // The season outranks the week: both landing at once is rare, and the season is the
        // one that only comes round every few weeks.
        .overlay { if finishedSeason == nil { weekWonOverlay } }
        // Behind both: they are news, and the ask can wait for them to be taken.
        .overlay { if finishedSeason == nil, store.finishedChallenge == nil { reviewOverlay } }
        .animation(.spring(duration: 0.45, bounce: 0.2), value: asksReview)
        .animation(.spring(duration: 0.45, bounce: 0.2), value: finishedSeason)
        .animation(.spring(duration: 0.45, bounce: 0.2), value: store.finishedChallenge)
        .onChange(of: store.seasonFinish, initial: true) { _, finish in
            guard finishedSeason == nil else { return }
            finishedSeason = finish
        }
    }

    /// The week's laurel, landing on the walk back from the game that finished it. The store
    /// has held `finishedChallenge` since that game ended and nothing had ever shown it, so
    /// a week of play arrived as one line in a payout list and then an unchanged lobby.
    @ViewBuilder private var weekWonOverlay: some View {
        if let goals = store.finishedChallenge {
            ZStack {
                Palette.ink.opacity(0.62).ignoresSafeArea()
                WeekWonCard(goals: goals, name: store.playerName, mark: store.seatMark,
                            cornice: store.cornice) {
                    Audio.shared.play(.purchase)
                    store.clearFinishedChallenge()
                }
                .padding(20 * lift)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder private var reviewOverlay: some View {
        if asksReview {
            ZStack {
                Palette.ink.opacity(0.62).ignoresSafeArea()
                ReviewAskCard { asksReview = false }
                    .padding(20 * lift)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
    }

    /// A finished season takes the whole screen rather than a sheet: a reward that can be
    /// swiped away by accident is a support email.
    @ViewBuilder private var seasonOverlay: some View {
        if let finishedSeason {
            ZStack {
                Palette.ink.opacity(0.62).ignoresSafeArea()
                SeasonCard(finish: finishedSeason, isCollecting: isCollectingSeason) {
                    collectSeason(finishedSeason)
                }
                .padding(20 * lift)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
    }

    // MARK: Sheets

    private func lobbySheets(_ content: some View) -> some View {
        content
            .sheet(isPresented: $isEditingSettings) {
                SettingsSheet(store: store, ads: ads, purse: purse, reminders: reminders, account: account)
                    .coversBanner()
            }
            .sheet(isPresented: $showsShop) {
                ShopView(store: store, purse: purse, ads: ads)
                    .coversBanner()
            }
            .sheet(isPresented: $showsAdFree) {
                AdFreeSheet(pass: ads.pass)
                    .coversBanner()
            }
            .sheet(isPresented: $showsLadder) {
                LeaderboardView(store: store)
                    .coversBanner()
            }
            .sheet(isPresented: $showsWeekly) {
                WeeklySheet(store: store)
                    .coversBanner()
            }
            .sheet(isPresented: $showsAlbum) {
                NavigationStack { AlbumView(store: store, purse: purse) }
                    .coversBanner()
            }
            .sheet(isPresented: $showsWheel) {
                DailyWheelSheet(wheel: wheel, purse: purse, book: store.albumBook,
                                name: store.playerName, day: store.today)
                    .coversBanner()
            }
            .sheet(isPresented: $showsCampaign) {
                CampaignView().environment(store)
                    .coversBanner()
            }
            .sheet(isPresented: $showsRules, onDismiss: handleRulesDismissed) {
                // No coached hand over a game already under way: it would be saved over
                // the one waiting behind the Resume tile.
                RulesView(onFinish: store.savedGame == nil ? { startsCoached = true } : nil)
                    .coversBanner()
            }
            .sheet(isPresented: $asksName, onDismiss: dealCoachedHandIfAsked) {
                NameSheet(store: store)
                    .coversBanner()
            }
            .sheet(isPresented: $showsOnline, onDismiss: { if store.route == .lobby { store.cancelOnline() } }) {
                OnlineSheet(store: store)
                    .coversBanner()
            }
            .sheet(isPresented: $showsWager) {
                WagerSheet(store: store, purse: purse)
                    .coversBanner()
            }
            .sheet(isPresented: $showsFriends, onDismiss: handleFriendsDismissed) {
                FriendsSheet(store: store, path: $friendsPath)
                    .coversBanner()
            }
    }

    /// Reading the rules counts however the sheet is left. On a first launch the name
    /// comes next, and it is that sheet's closing that deals the coached hand.
    private func handleRulesDismissed() {
        if !store.hasSeenRules, store.playerName == TableStore.defaultName { asksName = true }
        store.hasSeenRules = true
        if !asksName { dealCoachedHandIfAsked() }
    }

    /// The friends sheet opens online tables too, so leaving it stops a search.
    private func handleFriendsDismissed() {
        if store.isBrowsing { store.stopBrowsing() }
        if store.route == .lobby { store.cancelOnline() }
    }

    private func handleAppear() {
        store.dailyBook.load()
        store.loadBestYesterday()
        store.loadSavedGame()
        store.refreshRank()
        applyDebugLaunch()
        if ReviewPrompt.take() || DebugLaunch.asksReview { askForReviewShortly() }
        // A first launch lands here, so this is where the rules introduce themselves.
        if DebugLaunch.showsRules || !store.hasSeenRules { showsRules = true }
    }

    /// A beat after the lobby is up, so the card lands in the room rather than with it.
    private func askForReviewShortly() {
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            asksReview = true
        }
    }

    private func applyDebugLaunch() {
        if DebugLaunch.showsSettings { isEditingSettings = true }
        if DebugLaunch.showsShop { showsShop = true }
        if DebugLaunch.showsAlbum { showsAlbum = true }
        if DebugLaunch.showsWheel { showsWheel = true }
        if DebugLaunch.showsLadder {
            // `-ladder week` opens the week's own room instead, which is where the week's
            // card goes and the one page two devices and a Worker are needed to see.
            if DebugLaunch.ladderOpensOnTheWeek { showsWeekly = true } else { showsLadder = true }
        }
        if DebugLaunch.showsFriends { showsFriends = true }
        if DebugLaunch.showsStakes { showsWager = true }
        if DebugLaunch.showsOnlineSheet || DebugLaunch.showsSeasonBoard { showsOnline = true }
        if DebugLaunch.showsRankedSearch {
            showsOnline = true
            #if DEBUG
            store.pretendSearching()
            #endif
        }
        if DebugLaunch.showsLocalTable {
            friendsPath = [.thisPhone]
            showsFriends = true
        }
        if DebugLaunch.showsJoinCode {
            friendsPath = [.joinByCode]
            showsFriends = true
        }
    }

    /// Seated, whichever way: the sheet that seated you has nothing left to say.
    private func closePlaySheets(for route: TableStore.Route) {
        guard route != .lobby else { return }
        showsOnline = false
        showsWager = false
        showsFriends = false
        showsCampaign = false
    }

    // MARK: Layouts

    /// Portrait. The scroll always bounces, even when the column fits, so the lobby does
    /// not read as a static picture.
    private var tallBody: some View {
        VStack(spacing: 0 * lift) {
            topRow
                .padding(.horizontal, 20 * lift)
                .frame(maxWidth: Stage.column(widthClass, heightClass))
            ScrollView {
                column
            }
            .scrollBounceBehavior(.always)
            .scrollIndicators(.hidden)
        }
    }

    private var column: some View {
        VStack(spacing: 0 * lift) {
            // The fan leans up out of the masthead's frame, so the top padding is its.
            masthead
                // The wheel and the no-ads button sit in the masthead's corner on a phone:
                // the top row has no room left for them without cutting the name short.
                .overlay(alignment: .topTrailing) {
                    VStack(spacing: 12 * lift) {
                        wheelChip
                        noAdsButton
                    }
                }
                .padding(.top, 28 * lift * crestScale)
            goals.padding(.top, 14 * lift)
            doors.padding(.top, 10 * lift)
            ladderPeek.padding(.top, 10 * lift)
            // Room to push the column past the banner strip.
            Spacer(minLength: 20 * lift)
        }
        .padding(.horizontal, 20 * lift)
        .padding(.bottom, 12 * lift)
        // An iPad gets the column at its own size, see `Stage.lift(_:_:)`.
        .frame(maxWidth: Stage.column(widthClass, heightClass))
        .frame(maxWidth: .infinity)
    }

    /// Landscape: the masthead keeps the left half and the doors take the right.
    private var wideBody: some View {
        VStack(spacing: 0 * lift) {
            topRow
            HStack(alignment: .center, spacing: 28 * lift) {
                masthead.frame(maxWidth: .infinity)
                ScrollView {
                    VStack(spacing: 12 * lift) {
                        goals
                        doors
                        ladderPeek
                    }
                    .padding(.vertical, 12 * lift)
                }
                .scrollBounceBehavior(.always)
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24 * lift)
    }

    // MARK: The corners

    private var topRow: some View {
        HStack(spacing: 10 * lift) {
            profileChip
            Spacer(minLength: 8 * lift)
            if stage.isWide { wheelChip }
            purseChip
            if stage.isWide { noAdsButton }
            RulesButton { showsRules = true }
        }
        .padding(.top, 8 * lift)
    }

    /// The way to the no-ads purchase, until it is owned.
    @ViewBuilder private var noAdsButton: some View {
        if ads.adsAreOn && !ads.pass.isOwned {
            NoAdsButton { showsAdFree = true }
        }
    }

    /// The day's wheel, with a dot while today's free turn is waiting.
    private var wheelChip: some View {
        WheelChip(isWaiting: purse.isReady && wheel.isAvailable(on: store.today, paid: purse.purse.keys)) {
            showsWheel = true
        }
    }

    private var profileChip: some View {
        Button { isEditingSettings = true } label: {
            HStack(spacing: 9 * lift) {
                // Struck to fit the pill: what is worn round the mark is drawn outside the
                // circle, and a bought ring on a laurelled seat reached through the glass.
                SeatBadge(name: store.playerName, tint: Palette.seat(0),
                          size: SeatBadge.fitted(26 * lift, mark: store.seatMark,
                                                 honoured: store.challenges.wearsHonour,
                                                 cornice: store.cornice),
                          mark: store.seatMark,
                          honoured: store.challenges.wearsHonour, cornice: store.cornice,
                          livery: store.livery)
                Text(verbatim: store.playerName)
                    .font(.system(size: 15 * lift, weight: .semibold))
                    .foregroundStyle(Palette.onTable)
                    .lineLimit(1)
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12 * lift, weight: .semibold))
                    .foregroundStyle(Palette.onTableSoft)
            }
            .padding(.leading, 7 * lift)
            .padding(.trailing, 13 * lift)
            .padding(.vertical, 6 * lift)
            .glassCapsule(interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
    }

    /// Hidden until the ledger has been read, so nobody is shown a zero for a frame.
    private var purseChip: some View {
        Button { showsShop = true } label: {
            HStack(spacing: 8 * lift) {
                DenariMark(size: 18 * lift)
                Text(verbatim: purse.balance.chipText)
                    .font(.system(size: 15 * lift, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.onTable)
                    .contentTransition(.numericText())
                    // A five figure balance was wrapping inside the capsule.
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Image(systemName: "bag.fill")
                    .font(.system(size: 12 * lift, weight: .semibold))
                    .foregroundStyle(Palette.onTableSoft)
                    .overlay(alignment: .topTrailing) { shopPackDot }
            }
            .padding(.horizontal, 13 * lift)
            .padding(.vertical, 9 * lift)
            .glassCapsule(interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Shop")
        .accessibilityValue(shopPacks > 0 ? Text("^[\(shopPacks) pack](inflect: true) to open") : Text(verbatim: ""))
        // The name truncates before the balance does.
        .layoutPriority(1)
        .opacity(purse.isReady ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: purse.isReady)
        .animation(.snappy, value: purse.balance)
    }

    private var shopPacks: Int { store.albumBook.waiting(on: .shop) }

    /// A shop pack waiting to be torn — the house's gift, the wheel's gran premio — marks
    /// the bag the way a card pack marks the album.
    @ViewBuilder private var shopPackDot: some View {
        if shopPacks > 0 {
            Circle()
                .fill(Palette.terracotta)
                .overlay { Circle().strokeBorder(Palette.cream.opacity(0.9), lineWidth: 1.2) }
                .frame(width: 9 * lift, height: 9 * lift)
                .offset(x: 4 * lift, y: -4 * lift)
                .accessibilityHidden(true)
        }
    }

    // MARK: The masthead

    /// The broom, the fan and the wordmark drawn smaller on a short phone, an SE, so the
    /// doors still clear the bottom of the screen with nothing scrolled.
    private var crestScale: CGFloat {
        !stage.isWide && screenSize.height > 0 && screenSize.height < 700 ? 0.6 : 1
    }

    /// The broom on its glass coin, with a fan of the deck in use behind it.
    private var masthead: some View {
        let crest = lift * crestScale
        return VStack(spacing: stage.pick(tall: 10, wide: 8) * lift) {
            ZStack {
                MastheadFan(width: stage.pick(tall: 46, wide: 38) * crest)
                    .offset(y: stage.pick(tall: -24, wide: -20) * crest)
                BroomMark(size: stage.pick(tall: 38, wide: 34) * crest, tint: Palette.goldLight)
                    .padding(stage.pick(tall: 16, wide: 14) * crest)
                    .glass(.riviera(), in: .circle)
                    .offset(y: stage.pick(tall: 16, wide: 12) * crest)
            }
            .frame(height: stage.pick(tall: 94, wide: 92) * crest)
            Text(Brand.title)
                .font(.display(stage.pick(tall: 50, wide: 50) * crest))
                .foregroundStyle(Palette.onTable)
                .padding(.top, stage.pick(tall: 4, wide: 2) * lift)
            // The album rides under the wordmark: it is where you stand rather than a way to
            // play, and a pill here costs the column one line instead of a slab of its own.
            // The league's plate that sat over it is the ranked door now.
            albumStrip
        }
    }

    // MARK: The goals

    /// The day's deal and the week's challenge. They share a row except on the two days
    /// the deal has more to say: the first ever, and the walk back from a deal just played.
    private var goals: some View {
        VStack(spacing: 10 * lift) {
            if dealTakesTheRow {
                todaysDeal
                weeklyCard
            } else {
                HStack(alignment: .top, spacing: 10 * lift) {
                    todaysDeal
                    weeklyCard
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            if reminders.offerIsDue(store.dailyBook) {
                ReminderOffer(reminders: reminders, book: store.dailyBook)
                    .padding(.horizontal, 14 * lift)
                    .padding(.vertical, 10 * lift)
                    .glassPanel(radius: GlassRadius.control)
            }
        }
        .animation(.snappy, value: dealTakesTheRow)
    }

    /// The card answers the same question for itself, but the lobby needs it before
    /// laying out the row.
    private var dealTakesTheRow: Bool {
        TodaysDealCard.isFull(book: store.dailyBook, day: store.today,
                              fresh: store.freshDailyDay == store.today)
    }

    private var todaysDeal: some View {
        TodaysDealCard(book: store.dailyBook, day: store.today,
                       best: store.bestYesterday?.day == store.yesterday ? store.bestYesterday : nil,
                       fresh: store.freshDailyDay == store.today) { store.playTodaysDeal() }
    }

    private var weeklyCard: some View {
        WeeklyCard(book: store.challenges, narrow: !dealTakesTheRow, name: store.playerName,
                   mark: store.seatMark, cornice: store.cornice) { showsWeekly = true }
    }

    // MARK: The doors

    /// Ranked across the width, the campaign under it, and a row of the small doors.
    ///
    /// The quick game had the width once, as the door most people want most evenings. It
    /// still deals in one tap from half a row; the league and the campaign take the width
    /// because they are the doors with somewhere to go — a grade to climb, a road to walk —
    /// and the reasons to come back after the bots are beaten. A saved game no longer takes
    /// a row of its own either: it is the quick door's face until it is played out or
    /// thrown away.
    /// Where the road has reached, once a stage is won; until then the door sells the trip.
    private var campaignProgress: LocalizedStringKey? {
        let book = store.campaignBook
        guard book.totalStars > 0 else { return nil }
        let stage = book.current
        return "Stage \(stage.number) · \(stage.region.title)"
    }

    private var doors: some View {
        VStack(spacing: 10 * lift) {
            RankedHero(rank: store.rank) { showsOnline = true }
            CampaignDoor(progress: campaignProgress) { showsCampaign = true }
            HStack(spacing: 10 * lift) {
                quickDoor
                if Self.offersWagers { denariDoor }
                friendsDoor
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        // Only on the way open: read as one flag, the close of a sheet would tap too.
        .sound(trigger: showsWager || showsFriends || showsOnline || showsCampaign) { _, open in open ? .tap : nil }
        .animation(.spring(duration: 0.35, bounce: 0.15), value: store.savedGame == nil)
        .confirmation(isPresented: $confirmsForget) {
            Confirmation(Text("Forget this game?"),
                         message: Text("Your stake of \(store.savedGame?.stake?.amount.coins ?? 0) denari is on that table."),
                         actions: [
                .init(title: Text("Forget it, and lose the stake"), role: .destructive) { forgetSavedGame() },
                .init(title: Text("Keep it"), role: .cancel),
            ])
        }
    }

    /// Off: staking denari on a game is simulated gambling in App Store terms, and Apple
    /// reviews that only from an organisation account, which this app is not published
    /// under (rejected under 2.3.6, September 2026). The tables stay in the code; turning
    /// them back on also means answering `gamblingSimulated` in Tools/StoreMetadata again.
    static let offersWagers = false

    private var denariDoor: some View {
        ModeDoor(title: "For denari", compact: true) {
            DenariMark(size: 28 * lift)
        } action: {
            showsWager = true
        }
    }

    /// A fresh game against the bots, at whichever table the pills are set to, or the game
    /// saved on this phone while there is one. Nothing stands between the door and the cards.
    private var quickDoor: some View {
        QuickDoor(table: $store.quickTable, saved: store.savedGame) {
            store.playQuickGame()
        } resume: {
            store.resumeSavedGame()
        } forget: {
            if store.savedGame?.stake != nil { confirmsForget = true } else { forgetSavedGame() }
        }
    }

    private var friendsDoor: some View {
        ModeDoor(title: "With friends", detail: "This phone, a code, or Game Center") {
            Image(systemName: "person.2.fill")
                .font(.system(size: 24 * lift, weight: .semibold))
                .foregroundStyle(Palette.goldLight)
        } action: {
            friendsPath = []
            showsFriends = true
        }
    }

    /// The way into the album, on the lobby rather than three taps down a settings page.
    ///
    /// A pack used to arrive as a line of small print on the end-of-game summary and then
    /// wait, unmentioned, behind a row in Settings — so the one reward the game hands out
    /// for simply playing was the one nobody found. It is a door now, and it wears a count
    /// of what is unopened until the album has been looked at.
    private var albumStrip: some View {
        AlbumDoor(book: store.albumBook) { showsAlbum = true }
    }

    /// The top of today's board, in the strip that used to be a button promising it.
    private var ladderPeek: some View {
        LadderPeek(store: store, count: stage.pick(tall: 5, wide: 3)) { showsLadder = true }
    }

    // MARK: Actions

    /// The first hand, dealt once the walkthrough and the name are both out of the way.
    private func dealCoachedHandIfAsked() {
        guard startsCoached else { return }
        startsCoached = false
        store.playCoached()
    }

    private func forgetSavedGame() {
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) { store.forgetSavedGame() }
    }

    /// Pays a finished season into the purse, then tells the ladder. The card goes when
    /// the denari land, not when the Worker answers.
    private func collectSeason(_ finish: Ladder.RankAnswer.Finish) {
        guard !isCollectingSeason else { return }
        isCollectingSeason = true
        Task {
            let league = League(rawValue: finish.standing.league) ?? .bronze
            await purse.awardSeason(SeasonReward.denari(forLeague: league), season: finish.season)
            Audio.shared.play(.purchase)
            withAnimation(.spring(duration: 0.4, bounce: 0.2)) { finishedSeason = nil }
            isCollectingSeason = false
            await store.markSeasonClaimed(finish.season)
        }
    }
}

#Preview {
    LobbyView(store: TableStore(), ads: AdsStore(), purse: PurseStore(), reminders: Reminders(),
              account: AccountSync())
}
