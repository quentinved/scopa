import SwiftUI
import ScopaCore
import ScopaRewards

/// The front door: who you are, what is on today, and the ways to sit down.
///
/// The identity row stays at the top and the rest scrolls. Under the goals the four doors
/// sit two by two, grouped by the question they answer: what the game is worth on the top
/// row — the league and the stakes — and who is at the table on the bottom one, the bots or
/// your friends. They were a wide tile over a row of three, which put the quick game and the
/// league at different sizes without saying why.
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
    @State private var showsRules = false
    @State private var showsLadder = false
    @State private var showsWeekly = false
    @State private var showsAlbum = false
    /// Asked once, after the rules on a first launch, if the name is still the stand-in.
    @State private var asksName = false
    /// The walkthrough ended on "deal me a hand". The table cannot be dealt from under the
    /// sheet that asked for it, so the offer is held until the sheets are out of the way.
    @State private var startsCoached = false
    /// Asked before throwing away a saved game with denari on it: the stake would go too.
    @State private var confirmsForget = false
    /// Asked before a quick game deals over the table saved on this phone. The quick door
    /// used to be hidden while a game was saved, which is how the save was protected; both
    /// tiles are on the grid now, so the question is asked instead of the door being taken
    /// away.
    @State private var confirmsDealOver = false
    /// Which page the friends sheet opens on; the debug launch can ask for the second.
    @State private var friendsPath: [FriendsSheet.Page] = []
    /// A season that ended while the app was closed, held until it has been collected.
    @State private var finishedSeason: Ladder.RankAnswer.Finish?
    @State private var isCollectingSeason = false

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
            }
            .sheet(isPresented: $showsShop) {
                ShopView(store: store, purse: purse, ads: ads)
            }
            .sheet(isPresented: $showsLadder) {
                LeaderboardView(store: store)
            }
            .sheet(isPresented: $showsWeekly) {
                WeeklySheet(store: store)
            }
            .sheet(isPresented: $showsAlbum) {
                NavigationStack { AlbumView(store: store, purse: purse) }
            }
            .sheet(isPresented: $showsRules, onDismiss: handleRulesDismissed) {
                // No coached hand over a game already under way: it would be saved over
                // the one waiting behind the Resume tile.
                RulesView(onFinish: store.savedGame == nil ? { startsCoached = true } : nil)
            }
            .sheet(isPresented: $asksName, onDismiss: dealCoachedHandIfAsked) {
                NameSheet(store: store)
            }
            .sheet(isPresented: $showsOnline, onDismiss: { if store.route == .lobby { store.cancelOnline() } }) {
                OnlineSheet(store: store)
            }
            .sheet(isPresented: $showsWager) {
                WagerSheet(store: store, purse: purse)
            }
            .sheet(isPresented: $showsFriends, onDismiss: handleFriendsDismissed) {
                FriendsSheet(store: store, path: $friendsPath)
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
        // A first launch lands here, so this is where the rules introduce themselves.
        if DebugLaunch.showsRules || !store.hasSeenRules { showsRules = true }
    }

    private func applyDebugLaunch() {
        if DebugLaunch.showsSettings { isEditingSettings = true }
        if DebugLaunch.showsShop { showsShop = true }
        if DebugLaunch.showsAlbum { showsAlbum = true }
        if DebugLaunch.showsLadder {
            // `-ladder week` opens the week's own room instead, which is where the week's
            // card goes and the one page two devices and a Worker are needed to see.
            if DebugLaunch.ladderOpensOnTheWeek { showsWeekly = true } else { showsLadder = true }
        }
        if DebugLaunch.showsFriends { showsFriends = true }
        if DebugLaunch.showsStakes { showsWager = true }
        if DebugLaunch.showsOnlineSheet { showsOnline = true }
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
            masthead.padding(.top, 28 * lift)
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
            purseChip
            RulesButton { showsRules = true }
        }
        .padding(.top, 8 * lift)
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
            }
            .padding(.horizontal, 13 * lift)
            .padding(.vertical, 9 * lift)
            .glassCapsule(interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Shop")
        // The name truncates before the balance does.
        .layoutPriority(1)
        .opacity(purse.isReady ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: purse.isReady)
        .animation(.snappy, value: purse.balance)
    }

    // MARK: The masthead

    /// The broom on its glass coin, with a fan of the deck in use behind it.
    private var masthead: some View {
        VStack(spacing: stage.pick(tall: 10, wide: 8) * lift) {
            ZStack {
                MastheadFan(width: stage.pick(tall: 46, wide: 38) * lift)
                    .offset(y: stage.pick(tall: -24, wide: -20) * lift)
                BroomMark(size: stage.pick(tall: 38, wide: 34) * lift, tint: Palette.goldLight)
                    .padding(stage.pick(tall: 16, wide: 14) * lift)
                    .glass(.riviera(), in: .circle)
                    .offset(y: stage.pick(tall: 16, wide: 12) * lift)
            }
            .frame(height: stage.pick(tall: 94, wide: 92) * lift)
            Text(Brand.title)
                .font(.display(stage.pick(tall: 50, wide: 50) * lift))
                .foregroundStyle(Palette.onTable)
                .padding(.top, stage.pick(tall: 4, wide: 2) * lift)
            RankPlate(rank: store.rank) { showsOnline = true }
            // The album rides under the league: both are where you stand rather than ways to
            // play, and a pill here costs the column one line instead of a slab of its own.
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

    /// One way to play, and a row of the others.
    ///
    /// It was four doors of equal weight, two by two, each with its own sentence — on top of
    /// the goals, the album and the ladder, a lobby of a dozen things to tap and no telling
    /// which one was the game. The quick game is the door most people want most evenings,
    /// so it takes the width; ranked, the denari tables and friends share one row as three
    /// small doors, a mark and a name each. A saved game still takes the width above it all.
    private var doors: some View {
        VStack(spacing: 10 * lift) {
            if let saved = store.savedGame { resumeDoor(saved) }
            quickDoor
            HStack(spacing: 10 * lift) {
                rankedDoor
                denariDoor
                friendsDoor
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        // Only on the way open: read as one flag, the close of a sheet would tap too.
        .sound(trigger: showsWager || showsFriends || showsOnline) { _, open in open ? .tap : nil }
        .animation(.spring(duration: 0.35, bounce: 0.15), value: store.savedGame == nil)
        .confirmationDialog("Deal over the saved game?", isPresented: $confirmsDealOver,
                            titleVisibility: .visible) {
            Button(dealOverIsCostly ? "Deal, and lose the stake" : "Deal a new table",
                   role: .destructive) { dealOverSavedGame() }
            Button("Resume that one instead") { store.resumeSavedGame() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let stake = store.savedGame?.stake {
                Text("Your stake of \(stake.amount.coins) denari is on that table.")
            } else {
                Text("The table you left is kept on this phone until it is played out.")
            }
        }
    }

    /// Whether dealing over the saved game would cost denari as well as the table.
    private var dealOverIsCostly: Bool { store.savedGame?.stake != nil }

    /// A quick game is a hot-seat table, and a hot-seat table writes itself over whatever is
    /// saved on this phone the moment the first card lands. Asked first, then thrown away
    /// deliberately rather than by a side effect.
    private func dealOverSavedGame() {
        store.forgetSavedGame()
        store.playQuickGame()
    }

    /// The door with a league behind it wears the medal, the edge of its own grade, and what
    /// the next game up the ladder costs.
    private var rankedDoor: some View {
        ModeDoor(title: "Ranked", league: rankedLeague, compact: true) {
            if let league = rankedLeague {
                LeagueMedal(league: league, size: 30 * lift)
            } else {
                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: 24 * lift, weight: .semibold))
                    .foregroundStyle(Palette.goldLight)
            }
        } action: {
            showsOnline = true
        }
    }

    private var denariDoor: some View {
        ModeDoor(title: "For denari", compact: true) {
            DenariMark(size: 28 * lift)
        } action: {
            showsWager = true
        }
    }

    /// A fresh game against the bots, at whichever table the pills are set to. It asks its
    /// question on the tile, so nothing stands between the door and the cards.
    private var quickDoor: some View {
        QuickDoor(table: $store.quickTable) {
            if store.savedGame != nil { confirmsDealOver = true } else { store.playQuickGame() }
        }
    }

    private var friendsDoor: some View {
        ModeDoor(title: "With friends", compact: true) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 24 * lift, weight: .semibold))
                .foregroundStyle(Palette.goldLight)
        } action: {
            friendsPath = []
            showsFriends = true
        }
    }

    /// The game saved on this phone, with an × to throw it away. It keeps the full width:
    /// a scoreline, a round number and a way out do not fit in half a row.
    private func resumeDoor(_ saved: SavedGame) -> some View {
        DoorTile(title: "Resume", detail: resumeDetail(saved), tint: Palette.terracotta,
                 wide: true, showsChevron: false) {
            HStack(spacing: -12) {
                CardBack(width: 22).rotationEffect(.degrees(-8))
                CardBack(width: 22).rotationEffect(.degrees(6))
            }
        } action: {
            store.resumeSavedGame()
        }
        // The × takes the chevron's slot: a corner button on a one-line tile overlapped it.
        .overlay(alignment: .trailing) { forgetButton(saved) }
        .confirmationDialog("Forget this game?", isPresented: $confirmsForget, titleVisibility: .visible) {
            Button("Forget it, and lose the stake", role: .destructive) { forgetSavedGame() }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Your stake of \(saved.stake?.amount.coins ?? 0) denari is on that table.")
        }
    }

    private func forgetButton(_ saved: SavedGame) -> some View {
        Button {
            if saved.stake != nil { confirmsForget = true } else { forgetSavedGame() }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12 * lift, weight: .bold))
                .foregroundStyle(Palette.cream.opacity(0.9))
                .frame(width: 34 * lift, height: 34 * lift)
                .background { Circle().fill(Palette.ink.opacity(0.18)) }
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 6 * lift)
        .accessibilityLabel("Forget this game")
    }

    /// "Hugo · 3 – 1 · Round 2": who, where it stands, how far in.
    private func resumeDetail(_ saved: SavedGame) -> LocalizedStringKey {
        let names = saved.opponentNames.formatted(.list(type: .and, width: .short))
        return "\(names) · \(saved.ownScore) – \(saved.bestOtherScore) · Round \(saved.state.roundNumber)"
    }

    /// The league to dress the ranked door in. Nil until the ladder has answered for a game
    /// actually played: an unranked door must not wear bronze, which somebody earned.
    private var rankedLeague: Int? {
        guard let rank = store.rank, rank.games > 0 else { return nil }
        return rank.standing.league
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
