import SwiftUI
import ScopaCore
import ScopaRelay
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
    /// The no-ads purchase, opened from its coin beside the wordmark.
    @State private var showsAdFree = DebugLaunch.showsAdFree
    /// What an owner opens from the same coin: the gold page saying it is theirs.
    @State private var showsPatron = false
    @State private var showsRules = false
    @State private var showsLadder = false
    @State private var showsWeekly = false
    @State private var showsAlbum = false
    @State private var showsCampaign = false
    /// Asked once, after the rules on a first launch, if the name is still the stand-in.
    @State private var asksName = false
    /// Asked once, after the name on a first launch: the coach, or a plain table.
    @State private var asksCoach = DebugLaunch.showsCoachChoice
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
    /// The card saying the App Store has a newer Scopa. See `StoreVersion`.
    @State private var showsUpdate = false
    /// The header's share of a portrait column, and the two heights it is worked out from.
    @State private var room = MastheadRoom()
    @State private var viewport: CGFloat = 0
    @State private var columnHeight: CGFloat = 0

    @Environment(\.verticalSizeClass) private var heightClass
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.locale) private var locale
    @Environment(\.screenSize) private var screenSize
    private var stage: Stage { Stage(heightClass, size: screenSize) }
    /// One factor over every point size in the lobby: 1 on a phone, more on an iPad.
    private var lift: CGFloat { Stage.lift(widthClass, heightClass) }

    var body: some View {
        // Set under the sheets rather than over them, so only the lobby behind holds still.
        lobbySheets(layout.environment(\.isUnderSheet, isUnderSheet))
            .onAppear(perform: handleAppear)
            .onChange(of: store.route) { _, route in closePlaySheets(for: route) }
            // Somebody found: the moment that says so is drawn over the lobby, not under a sheet.
            .onChange(of: store.matchFound != nil) { _, found in if found { closeSearchSheets() } }
            // The day's result is news once: leaving the lobby spends it.
            .onDisappear { store.clearFreshDaily() }
            .releaseMoment(store: store, purse: purse, isClear: isClearForNews) { shelf in
                if shelf == .shop { showsShop = true } else { showsAlbum = true }
            }
            // After the arrival moment, which it reads, and never over the rating ask.
            .storeUpdate(isPresented: $showsUpdate, isClear: isClearForNews && !asksReview)
    }

    /// A sheet hides the lobby, so its turning rims can stop until it comes down.
    private var isUnderSheet: Bool {
        [isEditingSettings, showsFriends, showsOnline, showsWager, showsShop, showsAdFree, showsRules,
         showsLadder, showsWeekly, showsAlbum, showsCampaign, asksName, asksCoach, showsWheel, showsPatron].contains(true)
    }

    /// Nothing else on screen asking to be looked at, so a gift or a version's news can
    /// have its turn: the first launch's walkthrough is done, and no card or sheet is up.
    private var isClearForNews: Bool {
        let sheets = [isEditingSettings, showsFriends, showsOnline, showsWager, showsShop, showsRules,
                      showsLadder, showsWeekly, showsAlbum, asksName, asksCoach, startsCoached, showsWheel,
                      showsUpdate]
        return store.hasSeenRules && finishedSeason == nil && store.finishedChallenge == nil
            && !sheets.contains(true) && store.onlineStatus == nil
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
                // No ad on the page that sells their removal.
                AdFreeSheet(pass: ads.pass)
                    .coversBanner(carries: false)
            }
            .fullScreenCover(isPresented: $showsPatron) { PatronSheet() }
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
                DailyWheelSheet(wheel: wheel, purse: purse, ads: ads, book: store.albumBook,
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
            .sheet(isPresented: $asksName, onDismiss: { asksCoach = true }) {
                NameSheet(store: store)
                    .coversBanner()
            }
            .sheet(isPresented: $asksCoach, onDismiss: dealFirstHandIfAsked) {
                // No strip under a first launch's question: it would crowd the two answers.
                CoachChoiceSheet(dealsNext: startsCoached) { store.assist = $0 }
                    .coversBanner(carries: false)
            }
            .sheet(isPresented: $showsOnline, onDismiss: {
                if store.route == .lobby, store.matchFound == nil { store.cancelOnline() }
            }) {
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
    /// comes next, then the coach question, and it is that sheet's closing that deals.
    private func handleRulesDismissed() {
        if !store.hasSeenRules {
            if store.playerName == TableStore.defaultName { asksName = true } else { asksCoach = true }
        }
        store.hasSeenRules = true
        if !asksName, !asksCoach { dealCoachedHandIfAsked() }
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
        if DebugLaunch.showsScorePad {
            friendsPath = [.scorePad]
            showsFriends = true
        }
    }

    /// Seated, whichever way: the sheet that seated you has nothing left to say.
    private func closePlaySheets(for route: TableStore.Route) {
        guard route != .lobby else { return }
        showsOnline = false
        showsLadder = false
        showsWager = false
        showsFriends = false
        showsCampaign = false
    }

    /// The sheets a search runs in, put away as soon as it finds somebody. The seating goes on.
    private func closeSearchSheets() {
        showsOnline = false
        showsWager = false
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
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                        columnHeight = $0
                        settleMasthead()
                    }
            }
            .scrollBounceBehavior(.always)
            .scrollIndicators(.hidden)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                viewport = $0
                settleMasthead()
            }
        }
    }

    private var column: some View {
        VStack(spacing: 0 * lift) {
            masthead.padding(.top, room.top(lift))
            goals.padding(.top, room.after(lift))
            doors.padding(.top, 10 * lift)
            ladderPeek.padding(.top, 10 * lift)
        }
        .padding(.horizontal, 20 * lift)
        .padding(.bottom, 10 * lift)
        // An iPad gets the column at its own size, see `Stage.lift(_:_:)`.
        .frame(maxWidth: Stage.column(widthClass, heightClass))
        .frame(maxWidth: .infinity)
    }

    /// Gives the header whatever the column leaves of the screen, within its two sizes. The
    /// first answer lands as it is; later ones, a saved game's door coming or going, ease.
    private func settleMasthead() {
        var next = room
        guard next.settle(column: columnHeight, viewport: viewport, lift: lift) else { return }
        withAnimation(room.isSettled ? .snappy : nil) { room = next }
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

    /// Who you are on the left, what you hold on the right. The wheel and the no-ads
    /// purchase sit down beside the wordmark, where each has room for its name.
    private var topRow: some View {
        HStack(spacing: 10 * lift) {
            profileChip
            Spacer(minLength: 8 * lift)
            purseChip
        }
        .padding(.top, 8 * lift)
    }

    /// The way to the no-ads purchase, until it is owned. It sits beside the wordmark rather
    /// than with the doors: the first place the eye lands, and it costs the column no height.
    /// Once owned, the patron's crest takes the same place, never a price.
    @ViewBuilder private var noAdsButton: some View {
        if ads.pass.isOwned {
            PatronCoin { showsPatron = true }
        } else if ads.adsAreOn {
            NoAdsButton { showsAdFree = true }
        } else {
            // Holds the place, so the lockup stays centred once the ads are gone.
            Color.clear.frame(width: 1, height: 1)
        }
    }

    /// The day's wheel, with a dot while today's free turn is waiting.
    private var wheelCoin: some View {
        WheelCoin(turn: wheelTurn) { showsWheel = true }
    }

    /// Nil until the ledger has been read, so the coin promises nothing it has to take back.
    private var wheelTurn: WheelCoin.Turn? {
        guard purse.isReady else { return nil }
        let paid = purse.purse.keys
        if wheel.isAvailable(on: store.today, paid: paid) { return .free }
        return ads.adsAreOn && wheel.isVideoAvailable(on: store.today, paid: paid) ? .video : .spent
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
                    // The badge is a fixed size, so a long name gives way and the laurel never does.
                    .layoutPriority(1)
                Text(verbatim: store.playerName)
                    .font(.system(size: 15 * lift, weight: .semibold))
                    .foregroundStyle(Palette.onTable)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12 * lift, weight: .semibold))
                    .foregroundStyle(Palette.onTableSoft)
            }
            .padding(.leading, 7 * lift)
            .padding(.trailing, 13 * lift)
            .padding(.vertical, 6 * lift)
            .glassCapsule()
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
                Rectangle()
                    .fill(Palette.onTableSoft.opacity(0.35))
                    .frame(width: 1, height: 16 * lift)
                // The bag alone read as a purse, so the chip says where it goes.
                HStack(spacing: 5 * lift) {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 12 * lift, weight: .semibold))
                        .foregroundStyle(Palette.goldLight)
                        .overlay(alignment: .topTrailing) { shopPackDot }
                    Text("Shop")
                        .textCase(.uppercase)
                        .font(.system(size: 12 * lift, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(Palette.onTable)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .padding(.horizontal, 13 * lift)
            .padding(.vertical, 9 * lift)
            .glassCapsule()
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

    /// The crest and the wordmark, with the wheel on one side and the no-ads purchase on the
    /// other, each under its own name. The rules are in Settings, and behind the table's "?".
    private var masthead: some View {
        VStack(spacing: stage.isWide ? 8 * lift : room.under(lift)) {
            HStack(spacing: stage.isWide ? 6 * lift : room.coinGap(lift)) {
                wheelCoin.frame(maxWidth: .infinity)
                BrandLockup(stacked: stage.isWide, growth: stage.isWide ? 0 : room.growth)
                noAdsButton.frame(maxWidth: .infinity)
            }
            // A grown lockup leaves the coins less of the row, so they move out into the margin.
            .padding(.horizontal, stage.isWide ? 0 : -room.bleed(lift))
            // The album rides under the wordmark: it is where you stand rather than a way to
            // play, and a pill here costs the column one line instead of a slab of its own.
            albumStrip
        }
    }

    // MARK: The goals

    /// Today in one row: the day's deal and the week's tasks. The deal takes a row of its
    /// own on the two days it has more to say, the first ever and the walk back from a deal
    /// just played, and the week has the row under it.
    private var goals: some View {
        VStack(spacing: 10 * lift) {
            if dealTakesTheRow { todaysDeal }
            HStack(alignment: .top, spacing: 8 * lift) {
                if !dealTakesTheRow { todaysDeal }
                weeklyCard
            }
            .fixedSize(horizontal: false, vertical: true)
            if reminders.offerIsDue(store.dailyBook) {
                ReminderOffer(reminders: reminders)
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
        WeeklyCard(book: store.challenges, name: store.playerName, mark: store.seatMark,
                   cornice: store.cornice) { showsWeekly = true }
    }

    // MARK: The doors

    /// Three ways to play, each across the width: the league, the road, and people you know.
    ///
    /// The quick game had a door of its own, and with the league, the campaign and friends
    /// beside it that was four answers to "what now?" before a card was dealt. It deals from
    /// the foot of the campaign now, against the same bots, so a player alone is sent down
    /// the road. A game saved on this phone goes over the three until it is played out or
    /// thrown away.
    private var doors: some View {
        VStack(spacing: 10 * lift) {
            comebackDoor
            RankedHero(rank: store.rank) { showsOnline = true }
            CampaignDoor(book: store.campaignBook) { showsCampaign = true }
            FriendsDoor {
                friendsPath = []
                showsFriends = true
            }
            if Self.offersWagers { denariDoor.fixedSize(horizontal: false, vertical: true) }
        }
        // Only on the way open: read as one flag, the close of a sheet would tap too.
        .sound(trigger: showsWager || showsFriends || showsOnline || showsCampaign) { _, open in open ? .tap : nil }
        .animation(.spring(duration: 0.35, bounce: 0.15), value: store.savedGame == nil)
        .animation(.spring(duration: 0.35, bounce: 0.15), value: store.connection.ticket)
        // A seat the room has since closed is not offered.
        .task { await store.connection.confirmTicket(with: Ladder.baseURL.map(Relay.init(baseURL:))) }
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
    /// And since denari are sold for money (`DenariBag`), a stake would be a real-money
    /// bet: never turn this on while they are.
    static let offersWagers = false

    private var denariDoor: some View {
        ModeDoor(title: "For denari", compact: true) {
            DenariMark(size: 28 * lift)
        } action: {
            showsWager = true
        }
    }

    /// The game saved on this phone. Nothing stands between the row and the cards.
    private func resumeDoor(_ saved: SavedGame) -> some View {
        ResumeDoor(saved: saved) {
            store.resumeSavedGame()
        } forget: {
            if saved.stake != nil { confirmsForget = true } else { forgetSavedGame() }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// A game to go back to, one at a time: two such rows would push the ladder under the
    /// banner. A seat at a room game goes first, since that table plays on without you and
    /// the saved one waits; it is only a guest's seat, as the game lives on the host's phone.
    @ViewBuilder private var comebackDoor: some View {
        if store.onlineStatus == nil, let ticket = store.connection.ticket {
            RejoinDoor(hostName: ticket.hostName) {
                store.rejoin(ticket)
            } forget: {
                store.connection.forgetTicket()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        } else if let saved = store.savedGame, !DebugLaunch.hidesResume {
            resumeDoor(saved)
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

    /// Today's board as one line: who leads, and the whole board a tap away.
    private var ladderPeek: some View {
        LadderPeek(store: store, oneLine: true) { showsLadder = true }
    }

    // MARK: Actions

    /// The first hand, dealt once the walkthrough and the name are both out of the way.
    private func dealCoachedHandIfAsked() {
        guard startsCoached else { return }
        startsCoached = false
        store.playCoached()
    }

    /// The first launch's hand, at the level of help just picked rather than the coach's.
    private func dealFirstHandIfAsked() {
        guard startsCoached else { return }
        startsCoached = false
        store.playFirstHand()
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
            await purse.awardSeason(SeasonReward.denari(for: finish), season: finish.season)
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
