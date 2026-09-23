import SwiftUI
import ScopaCore
import ScopaRewards

/// The game itself. Tap a card in hand, then confirm the take.
struct TableScreen: View {
    let store: TableStore
    let ads: AdsStore
    let purse: PurseStore

    @State private var selection = HandSelection()
    @Environment(\.locale) private var locale
    @State private var showsScopa = false
    /// The seven of coins, taken. Never shown at the same time as a sweep: a scopa that
    /// happens to take it keeps the floor.
    @State private var showsSettebello = false
    /// Who took it, on that banner. Empty when it was you.
    @State private var settebelloBy = ""
    @State private var showsDeal = false
    @State private var dealtHand = 1
    /// What a ranked table is worth, over the opening deal. Nil on every other table, and
    /// on a ranked one until the ladder has said where the other chairs stand.
    @State private var stakes: RankedStakes.Odds?
    /// Said once per table: a second round is not a second game, and the price of the
    /// game has not changed since the first deal.
    @State private var stakesTold = false
    /// Where each table card sits, for finding the one under a dragged card. A box rather
    /// than state: the frames move on every frame of a table animation, and writing one
    /// must not redraw the table.
    /// Set while a drag is what picked the card up, so a touch that goes nowhere can tell
    /// a first tap from a second. See `dropHand`.
    @State private var liftedByDrag = false
    /// When the card in hand was last picked up, so only a quick second tap plays it. See `tapHand`.
    @State private var pickedAt: Date?
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var tableFrames = FrameBox()
    /// Where each card in your own hand sits, for the same reason: a card you lay down
    /// flies out of the slot it was in rather than appearing on the cloth.
    @State private var handFrames = FrameBox()
    /// Where the cloth and every player are on screen, so a capture can start in the
    /// right place and fly to the right person.
    @State private var anchors = TableAnchors()
    /// The cards currently in the air, on their way to whoever took them.
    @State private var flight: CardFlight?
    /// The round's last cards, held where they lay while the play that ended the round
    /// finishes crossing the cloth. See `sendLeftovers` and `CardHoldLayer`.
    @State private var held: [CardFlight.Placed] = []
    /// The round is over but its last cards are still flying. The summary waits for them.
    @State private var holdsSummary = false
    /// The last summary announced. See `announce`.
    @State private var announced: Announced?
    /// Whether the game that just ended earned a pack, for the line under the summary.
    @State private var earnedPack = false
    /// What the game that just ended was worth in experience, for the summary.
    @State private var gainedExperience: Experience.Gain?
    /// News from the game that just ended, held back until the summary has told who won:
    /// a level reached says how the game went before the headline does.
    @State private var pendingToasts: [Toast] = []
    @Environment(Toaster.self) private var toaster
    /// The summary on screen has finished counting the round out, so the totals in the
    /// strip behind it can stop holding back. See `stripScore`.
    @State private var summaryToldIt = false
    @State private var hovered: Card?
    @State private var deadline: Date?
    /// Who swept, on the banner. Empty when it was you.
    @State private var scopaBy = ""
    /// The last move anyone made, kept in the corner of the cloth until the next one. The
    /// move itself is played out by the cards: see `CardFlight`.
    @State private var lastMove: TableStore.Play?
    /// A card laid down whose place the cloth holds while the flight carries it in. Laid
    /// out but not drawn, so the same card is never on screen twice at once.
    @State private var settling: Card?
    /// What the coach made of that move, worked out as it landed: the table has moved on
    /// by the time the reading fades, and one taken later would be of another table.
    @State private var reading: Coach.Reading?
    /// Your own take, counted up beside the pile.
    @State private var pilePop: PilePop?
    /// The pile, opened: what has been taken so far and what it is worth.
    @State private var showsPile = false
    @State private var showsReactions = false
    @State private var showsRules = false
    @State private var showsReview = false
    /// What the finished game paid. Empty until it has been settled, and empty for good if
    /// this game was already settled once: the ledger will not pay for it twice.
    @State private var earnings: [PayoutLine] = []
    /// The opt-in ad on the last summary is out, or has paid. Once per game: the ledger
    /// would refuse a second payment anyway.
    @State private var isDoubling = false
    @State private var doubled = false
    /// Asked before leaving a table with a stake on it, because the stake stays behind.
    @State private var confirmsLeave = false
    /// The seat the phone is being handed to, on a table shared between people. While it
    /// is set, a curtain hides the cards until that player says the phone is theirs.
    @State private var curtainSeat: Int?
    @Namespace private var reactionGlass

    @Environment(\.verticalSizeClass) private var heightClass
    @Environment(\.horizontalSizeClass) private var widthClass
    /// The screen's own shape, handed down from the root: an iPad is `.regular` both ways
    /// round, so the size classes alone cannot tell it on its side from upright.
    @Environment(\.screenSize) private var screenSize
    /// The cloth in play, so the clock and the disabled action bar are shaded with it.
    @Environment(\.tableFelt) private var felt
    private var stage: Stage { Stage(heightClass, size: screenSize) }
    /// One factor over every point size on the cloth: 1 on a phone, more on an iPad.
    private var lift: CGFloat { Stage.lift(widthClass, heightClass) }

    private static let tableSpace = "table"

    /// How long the coach's word on somebody else's move stays in the strip. Long enough
    /// to read while the cards it is about are still crossing the cloth.
    private static let readingDuration: Duration = .seconds(2.8)

    private var view: PlayerView? { store.view }

    /// The colour of one chair. In teams it is the side's colour rather than the seat's, so
    /// the face across from you reads as yours. See `Palette.seat(_:teams:)`.
    private func seatTint(_ seat: Int) -> Color {
        Palette.seat(seat, teams: view?.configuration.teams == true)
    }

    /// Changes on a fresh hand and on every turn. Only the debug flag that picks a card
    /// for you uses it, and it is a string so the type checker has nothing to work out.
    private var handAndTurn: String {
        guard let view else { return "" }
        return view.hand.map(\.description).joined(separator: ",") + "@\(view.turnSeat ?? -1)"
    }

    /// Every card in hand, weighed. Empty unless the coach is on, so nothing is spent
    /// thinking at the levels that would not show it.
    private var counsels: [Coach.Counsel] {
        guard selection.assist.explains, let view, view.isMyTurn, !gameIsOver else { return [] }
        return Coach.hand(view)
    }

    /// What is on the table at a wager game, for the warning before walking away from it.
    private var stakedCoins: Int { store.stake?.amount.coins ?? 0 }

    private var gameIsOver: Bool {
        if case .finished = view?.phase { true } else { false }
    }

    /// The table and what sits on it, then everything that reacts to it. Kept in separate
    /// expressions because one chain of forty modifiers is more than the type checker will
    /// take in reasonable time.
    var body: some View {
        curtained(reacting(canvas))
    }

    private var canvas: some View {
        banners(tableLayers)
    }

    /// The cloth itself, the cards in the air over it, and the glow that says it is your turn.
    private var tableLayers: some View {
        Group {
            if let view {
                switch stage {
                case .tall: tallLayout(view)
                case .wide: wideLayout(view)
                }
            } else {
                ProgressView().tint(Palette.onTable)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .top, spacing: 0) {
            if let view { topStrip(view).padding(.horizontal, 20).frame(maxWidth: Stage.column(widthClass, heightClass)) }
        }
        .background { TableGround() }
        // Your turn, said by the whole screen: a terracotta glow around the edge. The pill
        // says it in words, this says it from across the room.
        .overlay { TurnEdge(isOn: (view?.isMyTurn ?? false) && !gameIsOver) }
        // The cards in the air must go inside the named space rather than after it: an
        // overlay hung on the coordinate-space view is that space's sibling, not its child,
        // and every frame it was given would be read against the screen.
        .overlay { if !held.isEmpty { CardHoldLayer(cards: held) } }
        .overlay { if let flight { CardFlightLayer(flight: flight) } }
        .coordinateSpace(.named(Self.tableSpace))
    }

    /// Everything laid over the cloth: the callouts, the sheets and the way out.
    private func banners(_ content: some View) -> some View {
        content
            .overlay { settebelloBanner }
            // `scopaBy` is empty exactly when the sweep was yours, which is also when your
            // own flourish is the one to play.
            .overlay {
                if showsScopa {
                    ScopaBanner(by: scopaBy, flourish: scopaBy.isEmpty ? store.flourish : .stendardo)
                }
            }
            .overlay { if showsDeal { DealBanner(hand: dealtHand) } }
            .task {
                guard DebugLaunch.repeatsSweep else { return }
                while !Task.isCancelled {
                    announceScopa(by: "")
                    try? await Task.sleep(for: .seconds(3))
                }
            }
            .overlay { stakesBanner }
            .overlay(alignment: .topTrailing) { ReactionBubbles(store: store) }
            // Mid-game is when a rule is actually in question, so the ? follows you here.
            .sheet(isPresented: $showsRules) { RulesView() }
            .sheet(isPresented: $showsReview) { ReviewView(store: store) }
            .onChange(of: store.review == nil) { _, missing in
                if !missing, DebugLaunch.showsReview { showsReview = true }
            }
            .confirmationDialog("Leave the table?", isPresented: $confirmsLeave, titleVisibility: .visible) {
                Button(leaving?.action ?? "Leave", role: .destructive) { store.leaveTable() }
                Button("Keep playing", role: .cancel) {}
            } message: {
                if let leaving { Text(leaving.cost) }
            }
            .overlay { roundOverlay }
            .overlay { passCurtain }
    }

    /// Placed rather than centred: see `settebelloHeight`. The reader stays outside the `if`
    /// so the banner itself is the view being inserted and its own transition runs.
    private var settebelloBanner: some View {
        GeometryReader { proxy in
            if showsSettebello {
                SettebelloBanner(by: settebelloBy)
                    .frame(width: proxy.size.width)
                    .position(x: proxy.size.width / 2,
                              y: proxy.size.height * settebelloHeight)
            }
        }
        .allowsHitTesting(false)
    }

    /// Placed high rather than centred: the bot is already thinking by the time this comes
    /// up, and a banner over the middle of the cloth covers the cards being played.
    private var stakesBanner: some View {
        GeometryReader { proxy in
            if let stakes {
                // Wrapped, so the banner keeps its own width and sits in the middle of the
                // cloth rather than being stretched to the screen's edges.
                ZStack { RankedStakes(odds: stakes) }
                    .frame(width: proxy.size.width)
                    .position(x: proxy.size.width / 2,
                              y: proxy.size.height * stage.pick(tall: 0.27, wide: 0.30))
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder private var passCurtain: some View {
        if let seat = curtainSeat, let view, let player = view.configuration.players[safe: seat] {
            PassCurtain(name: player.name, mark: SeatMark(player), cornice: Cornice(player),
                        livery: SeatLivery(player),
                        tint: seatTint(seat)) {
                withAnimation(.easeOut(duration: 0.3)) { curtainSeat = nil }
            }
        }
    }

    /// Everything the table does in answer to a change. Split in four groups because one
    /// chain of forty modifiers is more than the type checker will take in reasonable time.
    private func reacting(_ content: some View) -> some View {
        sessionReactions(clockReactions(playReactions(noticeReactions(content))))
    }

    /// The banners: a round dealt away, a sweep called.
    private func noticeReactions(_ content: some View) -> some View {
        content
            .onChange(of: view?.roundNumber) { _, _ in startRound() }
            .onChange(of: store.notice) { _, notice in handleNotice(notice) }
    }

    /// A move landing: the cards in the air, the haptics, the coach and the pile pop.
    private func playReactions(_ content: some View) -> some View {
        content
            .onChange(of: store.lastPlay?.id) { _, _ in announceLastPlay() }
            .task(id: lastMove?.id) { await fadeReading() }
            .onChange(of: store.leftovers) { _, leftovers in handleLeftovers(leftovers) }
            .task(id: flight?.id) { await runFlight() }
            .task(id: pilePop?.id) { await fadePilePop() }
            .task(id: showsSettebello) { await fadeSettebello() }
            .sensoryFeedback(trigger: store.lastPlay?.id) { _, _ in playFeedback() }
            .sensoryFeedback(trigger: selection.card) { _, picked in picked == nil ? nil : Haptic.pick }
            .onChange(of: view?.isMyTurn == true && !gameIsOver) { was, now in feelTurn(was: was, now: now) }
            .tableSounds(store, view: view, picked: selection.card)
    }

    /// The turn clock and the coach level, both of which restart on a change of turn.
    private func clockReactions(_ content: some View) -> some View {
        content
            .onChange(of: view?.turnSeat) { _, _ in handleTurn() }
            .onChange(of: view?.phase) { _, _ in restartClock() }
            .onAppear { restartClock() }
            .task(id: deadline) { await runClock() }
            .onAppear { selection.assist = store.assist }
            .onChange(of: store.assist) { _, level in handleAssist(level) }
    }

    /// The table's own housekeeping: debug hands, the ads warm-up, opponent ranks, the
    /// pile sheet and the payout of a game that has been dealt away.
    private func sessionReactions(_ content: some View) -> some View {
        content
            .task(id: view?.turnSeat) { await playForMe() }
            .task(id: view?.phase) { await dealForMe() }
            .task(id: handAndTurn) { await selectFirstCard() }
            .task { warmAds() }
            .task(id: store.view?.configuration.players.map(\.id)) { await loadRanks() }
            .sheet(isPresented: $showsPile) { if let view = store.view { PileSheet(view: view) } }
            .onChange(of: store.view?.isFinished) { _, finished in clearEarnings(finished: finished) }
    }

    // MARK: - Notices

    /// A fresh round puts the strip back to holding its points back, so the next summary
    /// is the one that gives them out. See `stripScore`.
    private func startRound() {
        summaryToldIt = false
        held = []
    }

    private func handleNotice(_ notice: TableStore.Notice?) {
        switch notice {
        case .scopa(let name): announceScopa(by: name)
        case .dealt: announceDeal()
        default: break
        }
    }

    private func announceScopa(by name: String) {
        scopaBy = store.lastPlay?.seat == view?.seat ? "" : name
        withAnimation(.spring(duration: 0.35)) { showsScopa = true }
        Task {
            try? await Task.sleep(for: .seconds(1.9))
            withAnimation(.easeOut(duration: 0.3)) { showsScopa = false }
            store.clearNotice()
        }
    }

    private func announceDeal() {
        dealtHand = view?.handNumber ?? 1
        withAnimation(.spring(duration: 0.4, bounce: 0.28)) { showsDeal = true }
        Task {
            try? await Task.sleep(for: .seconds(1.9))
            withAnimation(.easeOut(duration: 0.3)) { showsDeal = false }
            store.clearNotice()
        }
    }

    // MARK: - The last move

    private func announceLastPlay() {
        // A round dealt away takes its last move with it.
        settling = nil
        guard let play = store.lastPlay, let view else {
            withAnimation(.easeOut(duration: 0.25)) { lastMove = nil }
            return
        }
        // First, before anything else looks at the cloth: this is the last moment the
        // cards this play took are still where the layout put them.
        sendFlight(for: play, in: view)
        feel(play, in: view)
        if play.tookSettebello, !play.sweeps {
            settebelloBy = play.seat == view.seat ? "" : play.name
            withAnimation(.spring(duration: 0.32, bounce: 0.3)) { showsSettebello = true }
        }
        withAnimation(.spring(duration: 0.38, bounce: 0.22)) { lastMove = play }
        if play.seat == view.seat { popPile(for: play) } else { readCoach(on: play, in: view) }
    }

    /// A sweep and a bare lay-down of your own are felt as the move is called. An ordinary
    /// take waits until the cards land, which is `settleCapture`.
    private func feel(_ play: TableStore.Play, in view: PlayerView) {
        if play.sweeps {
            Rumble.shared.sweep(mine: play.seat == view.seat)
        } else if play.captures.isEmpty, play.seat == view.seat {
            Rumble.shared.lay(mine: true)
        }
    }

    private func popPile(for play: TableStore.Play) {
        guard !play.captures.isEmpty else { return }
        withAnimation(.spring(duration: 0.4, bounce: 0.35)) {
            pilePop = PilePop(cards: play.captures.count + 1, settebello: play.tookSettebello)
        }
    }

    /// Read from the view this play produced: two seconds later the bot has moved again
    /// and the reading would be of another table.
    private func readCoach(on play: TableStore.Play, in view: PlayerView) {
        reading = selection.assist.explains
            ? Coach.reading(of: play.card, taking: play.captures, sweeps: play.sweeps, in: view)
            : nil
    }

    private func fadeReading() async {
        guard lastMove != nil else { return }
        try? await Task.sleep(for: Self.readingDuration)
        guard !Task.isCancelled else { return }
        // The tag in the corner stays; only the coach's word on the move goes.
        withAnimation(.easeOut(duration: 0.3)) { reading = nil }
    }

    /// The round's last cards, swept up by whoever captured last. Nobody plays them, so
    /// nothing else on the table would ever show them moving.
    private func handleLeftovers(_ leftovers: TableStore.Leftovers?) {
        guard let leftovers, let view else { return }
        sendLeftovers(leftovers, in: view)
    }

    // MARK: - Cards in the air

    private func runFlight() async {
        guard let current = flight else { return }
        if current.laysDown { await settleLayDown(current) } else { await settleCapture(current) }
    }

    /// A card laid down: the row takes over drawing it on the very frame the flight stops.
    private func settleLayDown(_ current: CardFlight) async {
        if current.isMine {
            try? await Task.sleep(for: .seconds(current.duration))
        } else {
            try? await Task.sleep(for: .seconds(current.travel + current.hold))
            guard !Task.isCancelled else { return }
            Rumble.shared.lay(mine: false)
            try? await Task.sleep(for: .seconds(CardFlight.settle))
        }
        guard !Task.isCancelled else { return }
        flight = nil
        settling = nil
    }

    private func settleCapture(_ current: CardFlight) async {
        if current.isMine {
            // Your own cards land a full second after the move that won them, so the phone
            // waits with them rather than thumping while they are still in the air.
            try? await Task.sleep(for: .seconds(current.duration - 0.1))
            guard !Task.isCancelled else { return }
            // A sweep already spoke at the moment it was called.
            if !current.sweeps {
                Rumble.shared.gather(count: current.taken.count + (current.played == nil ? 0 : 1))
            }
            try? await Task.sleep(for: .seconds(0.18))
        } else {
            try? await Task.sleep(for: .seconds(current.duration + 0.08))
        }
        guard !Task.isCancelled else { return }
        flight = nil
        if current.endsTheRound { holdsSummary = false }
    }

    private func fadePilePop() async {
        guard pilePop != nil else { return }
        try? await Task.sleep(for: .seconds(1.4))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.3)) { pilePop = nil }
    }

    /// Shorter than the sweep's banner: the seven is worth stopping for, not worth
    /// stopping the game for.
    private func fadeSettebello() async {
        guard showsSettebello else { return }
        try? await Task.sleep(for: .seconds(1.5))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.3)) { showsSettebello = false }
    }

    // MARK: - Haptics

    /// Soft for cards moving, a thud for the seven of coins. A sweep is a pattern played by
    /// `Rumble`, and a take of your own is felt when the cards land.
    private func playFeedback() -> SensoryFeedback? {
        guard let play = store.lastPlay, let view else { return nil }
        if play.sweeps { return nil }
        if play.tookSettebello { return Haptic.settebello }
        let mine = play.seat == view.seat
        if play.captures.isEmpty { return mine ? Haptic.play : Haptic.pick }
        return mine ? nil : Haptic.theirTake
    }

    /// Fires on the edge into your turn and never while it lasts, so a phone face down on
    /// the table speaks once. A pattern rather than a tap: one tap among a game of taps
    /// is not noticed from across a room.
    private func feelTurn(was: Bool, now: Bool) {
        guard !was, now else { return }
        Rumble.shared.yourTurn()
    }

    // MARK: - Clock and coach level

    private func handleTurn() {
        selection.clear()
        restartClock()
    }

    private func handleAssist(_ level: AssistLevel) {
        selection.assist = level
        selection.clear()
    }

    // MARK: - Session

    private func playForMe() async {
        guard DebugLaunch.playsItself, let view, view.isMyTurn else { return }
        // A person's pace rather than a machine's, so the flights and pops that follow the
        // other side's moves can actually be watched.
        try? await Task.sleep(for: .milliseconds(2600))
        guard let card = view.hand.randomElement() else { return }
        let capture = Rules.captureOptions(for: card, on: view.table).randomElement() ?? []
        store.play(card, capturing: capture)
    }

    private func dealForMe() async {
        guard DebugLaunch.playsItself, store.isHost, !store.isDailyDeal, let view else { return }
        if case .roundOver = view.phase {
            // Long enough for the summary to tell the whole round before it is dealt away.
            try? await Task.sleep(for: .seconds(14))
            store.dealNextRound()
        } else if case .finished = view.phase, DebugLaunch.playsAgain {
            try? await Task.sleep(for: .seconds(20))
            #if DEBUG
            store.playAgain()
            #endif
        }
    }

    /// Keyed on the turn as well as the hand: the turn coming back round clears the
    /// selection, so picking only at the deal showed the action bar for one move.
    private func selectFirstCard() async {
        guard DebugLaunch.selectsFirstCard, let view, view.isMyTurn else { return }
        try? await Task.sleep(for: .milliseconds(120))
        guard !Task.isCancelled, selection.isEmpty, let card = view.hand.first else { return }
        selection.select(card, on: view.table)
    }

    /// Warmed on arrival: the first round can already end the game, so the ad cannot wait
    /// for a round to finish.
    private func warmAds() {
        ads.prepareForEndOfGame()
        ads.prepareReward()
    }

    /// Keyed on who is sitting down rather than run once: a seat can still be filling when
    /// the screen appears, and a chair that arrives late should get its medal too.
    private func loadRanks() async {
        await store.loadOpponentRanks()
        await tellStakes()
    }

    /// The host dealt again: the payout and the offer belonged to the game that ended.
    private func clearEarnings(finished: Bool?) {
        guard finished == false else { return }
        earnings = []
        doubled = false
        isDoubling = false
        gainedExperience = nil
        earnedPack = false
    }

    /// The phone changing hands, on a table shared between people. Its own step in the
    /// chain: `reacting` is already as long as the type checker will take.
    ///
    /// Whoever set the table up is holding it, so their own first hand comes up uncovered;
    /// every other seat's does not, including on a game picked back up in the lobby with
    /// somebody else's turn pending.
    private func curtained(_ content: some View) -> some View {
        content
            .onChange(of: view?.seat, initial: true) { old, new in
                guard store.passesThePhone, let new else { return }
                if old == nil || old == new, new == store.deviceSeat { return }
                withAnimation(.easeOut(duration: 0.25)) { curtainSeat = new }
            }
            .sensoryFeedback(.selection, trigger: curtainSeat)
            .sound(trigger: curtainSeat) { _, seat in seat == nil ? nil : .notice }
    }

    // MARK: Layouts

    /// Portrait: one column, read top to bottom the way the cards are dealt.
    private func tallLayout(_ view: PlayerView) -> some View {
        let counsels = counsels
        return VStack(spacing: 0) {
            opponents(view).padding(.top, 10)
            if showsTurnClock(view) { turnClockBar(view) }
            tableArea(view)
            reactionRow
            statusRow(view)
            VStack(spacing: 0) {
                actionBar(view)
                handCards(view, counsels: counsels)
            }
            advice(view, counsels: counsels)
        }
        // Anchored to the top, so anything that will not fit spills off the bottom. A
        // stack centres its overflow by default, which lifts the score row up under the
        // clock. An iPad has height to spare, so there the same column sits in the middle
        // of the screen at the phone's width.
        .frame(maxHeight: .infinity, alignment: widthClass == .regular ? .center : .top)
        .padding(.horizontal, 20)
        .frame(maxWidth: Stage.column(widthClass, heightClass))
    }

    /// Landscape: the same table folded sideways.
    ///
    /// Turning the phone halves the height, so rows come out of the column: the reactions
    /// go up into the top strip, the last three come down side by side (piles, hand, button)
    /// and the other players move into a rail down each side of the cloth, where they would
    /// be sitting.
    private func wideLayout(_ view: PlayerView) -> some View {
        let seated = seating(view)
        return VStack(spacing: 0) {
            if showsTurnClock(view) { turnClockBar(view) }
            HStack(spacing: 10 * lift) {
                rail(seated.left, in: view, alignment: .leading)
                tableArea(view)
                rail(seated.right, in: view, alignment: .trailing)
            }
            bottomRow(view)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 20)
        // Held to a table's width on an iPad, so the seats stay beside the cloth. See
        // `Stage.spreadWidth`.
        .frame(maxWidth: Stage.spread(widthClass, heightClass))
    }

    /// How wide a side rail is, before the lift. Both are the same whether anybody is
    /// sitting there, so the cloth stays in the middle of the screen at a table for two as
    /// well as one for four.
    private static let railWidth: CGFloat = 76

    /// Where everyone else is sitting, in landscape. Play passes on round the table, so the
    /// seat that plays after this one is on the right, the one that plays before it is on
    /// the left, and at a table for four the seat opposite goes across the top.
    private func seating(_ view: PlayerView) -> (left: PlayerView.Opponent?, across: PlayerView.Opponent?, right: PlayerView.Opponent?) {
        let count = view.configuration.seatCount
        let ordered = (1..<max(count, 1)).compactMap { step -> PlayerView.Opponent? in
            let seat = (view.seat + step) % count
            return view.opponents.first { $0.seat == seat }
        }
        switch ordered.count {
        case 0: return (nil, nil, nil)
        case 1: return (nil, nil, ordered[0])
        case 2: return (ordered[1], nil, ordered[0])
        default: return (ordered[2], ordered[1], ordered[0])
        }
    }

    /// One side of the cloth: whoever is sitting there, held to the middle of the height.
    @ViewBuilder private func rail(_ opponent: PlayerView.Opponent?, in view: PlayerView,
                                   alignment: HorizontalAlignment) -> some View {
        VStack(spacing: 0) {
            if let opponent {
                railTag(opponent, in: view, alignment: alignment)
                    .seatAnchor(opponent.seat, in: Self.tableSpace, into: anchors)
            }
        }
        .frame(width: Self.railWidth * lift, alignment: alignment == .leading ? .leading : .trailing)
        .frame(maxHeight: .infinity)
    }

    /// An opponent stood up in a side rail: their cards, their face, their name and what
    /// they have taken, in a column narrow enough to leave the cloth the room it needs.
    private func railTag(_ opponent: PlayerView.Opponent, in view: PlayerView,
                         alignment: HorizontalAlignment) -> some View {
        let isTheirTurn = view.turnSeat == opponent.seat
        // A rail on an iPad is the same rail, drawn at the size the rest of the cloth is:
        // left at the phone's points it read as a row of specks beside cards half a foot tall.
        return VStack(alignment: alignment, spacing: 5 * lift) {
            HiddenHand(count: opponent.cardsInHand, width: 20 * lift)
            PlayerBadge(name: opponent.player.name, isBot: store.isBot(opponent.player),
                        tint: seatTint(opponent.seat), size: 24 * lift,
                        mark: SeatMark(opponent.player), cornice: Cornice(opponent.player),
                        livery: SeatLivery(opponent.player))
                .overlay { if isTheirTurn { TurnRing(padding: 3 * lift) } }
            Text(opponent.player.name)
                .font(.system(size: 12 * lift, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isTheirTurn ? Palette.goldLight : Palette.onTable)
            PileCount(count: view.captureCounts[view.configuration.side(ofSeat: opponent.seat)], width: 11 * lift)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    /// The landscape floor: what you have taken, what you are holding, what to press.
    /// The two outer columns share whatever the cards leave, so the hand stays centred.
    private func bottomRow(_ view: PlayerView) -> some View {
        let counsels = counsels
        return HStack(alignment: .bottom, spacing: 14 * lift) {
            VStack(alignment: .leading, spacing: 4) {
                statusRow(view)
                advice(view, counsels: counsels)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            handCards(view, counsels: counsels)
            actionBar(view)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.bottom, 6)
    }

    // MARK: Rows

    /// What the strip says a side has.
    ///
    /// The round's points land on the totals the instant it ends, but the summary spends
    /// the next several seconds giving them away one category at a time. While it counts,
    /// the strip still reads where the round started.
    private func stripScore(_ side: Int, in view: PlayerView) -> Int {
        guard !summaryToldIt else { return view.scores[side] }
        let round: RoundScore? = switch view.phase {
        case .roundOver(let score): score
        // The phase only carries the winner, so the breakdown comes from the store.
        case .finished: store.lastRoundScore
        default: nil
        }
        guard let round else { return view.scores[side] }
        return view.scores[side] - (round.points[safe: side] ?? 0)
    }

    /// The strip along the top: who is winning, and the ways out of the game.
    ///
    /// In landscape it also carries the opponents and the reactions, which have no row of
    /// their own once the height halves.
    private func topStrip(_ view: PlayerView) -> some View {
        GlassGroup(spacing: 10) {
            HStack(spacing: 8) {
                scoreChips(view)
                    // The scores keep their width; the spacer and the buttons give way first.
                    .layoutPriority(1)
                Spacer(minLength: 6)
                if stage.isWide { wideStripExtras(view) }
                RulesButton { showsRules = true }
                leaveButton
            }
        }
        .padding(.top, stage.pick(tall: 12, wide: 4))
    }

    private func scoreChips(_ view: PlayerView) -> some View {
        HStack(spacing: 5) {
            // Your own side reads first, whichever seat holds the device.
            ForEach([view.mySide] + view.scores.indices.filter { $0 != view.mySide }, id: \.self) { side in
                ScoreChip(
                    label: view.scores.count > 2 ? nil : sideName(side, in: view),
                    badge: view.scores.count > 2 ? sideName(side, in: view) : nil,
                    tint: Palette.seat(side, teams: view.configuration.teams),
                    score: stripScore(side, in: view),
                    emphasised: side == view.mySide,
                    swatch: view.configuration.teams
                )
            }
        }
    }

    /// What the landscape strip takes in from the rows portrait has and it does not.
    @ViewBuilder private func wideStripExtras(_ view: PlayerView) -> some View {
        // The seat opposite, which is the only one a side rail cannot hold.
        if let across = seating(view).across {
            opponentTag(across, in: view)
                .seatAnchor(across.seat, in: Self.tableSpace, into: anchors)
                // Sized before the two spacers around it. Without this the strip's flexible
                // space took its share first and the name was squeezed to an ellipsis — on
                // a table in teams, of the one player who is on your side.
                .layoutPriority(1)
            Spacer(minLength: 8)
        }
        reactionRow
    }

    /// What walking out costs, which is what the dialog has to say before it does. Nil when
    /// leaving costs nothing and the X needs no dialog at all.
    ///
    /// A ranked game is lost the moment it is left — see `TableStore.leaveTable` — so the
    /// wording is what happens, not a warning that something might.
    private var leaving: (action: LocalizedStringKey, cost: LocalizedStringKey)? {
        guard !gameIsOver else { return nil }
        let ranked = store.isRanked && store.ladderTable != nil
        switch (ranked, store.stake != nil) {
        case (true, true):
            return ("Leave, and lose the game and the stake",
                    "The ladder counts a game left as a loss, and your stake of \(stakedCoins) denari stays on the table.")
        case (true, false):
            return ("Leave, and lose the game", "The ladder counts a game left as a loss.")
        case (false, true):
            return ("Leave, and lose the stake", "Your stake of \(stakedCoins) denari stays on the table.")
        case (false, false):
            return nil
        }
    }

    private var leaveButton: some View {
        Button {
            if leaving != nil { confirmsLeave = true } else { store.leaveTable() }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 38, height: 38)
                .glass(.riviera(interactive: true), in: .circle)
                .contentShape(.circle)
        }
        .foregroundStyle(Palette.onTable)
    }

    private func opponents(_ view: PlayerView) -> some View {
        HStack(alignment: stage.pick(tall: VerticalAlignment.bottom, wide: .center),
               spacing: stage.pick(tall: 16, wide: 12)) {
            ForEach(view.opponents, id: \.seat) { opponent in
                opponentTag(opponent, in: view)
                    .seatAnchor(opponent.seat, in: Self.tableSpace, into: anchors)
            }
        }
        // Centred across the screen in portrait, where it is a row of its own. In the
        // landscape strip it sits between two spacers instead and takes only its width.
        .frame(maxWidth: stage.isWide ? nil : .infinity)
    }

    /// One opponent: what they are still holding, and whether the table is waiting on them.
    /// Portrait stands the pieces up, landscape lays them on their side.
    @ViewBuilder private func opponentTag(_ opponent: PlayerView.Opponent, in view: PlayerView) -> some View {
        let side = view.configuration.side(ofSeat: opponent.seat)
        if stage.isWide {
            HStack(spacing: 6) {
                seatBadge(opponent, in: view)
                seatName(opponent, in: view)
                overTheirSeat(opponent, in: view, width: 15 * lift)
                seatTally(ofSide: side, in: view)
            }
            .animation(.spring(duration: 0.4, bounce: 0.25), value: view.scope[side])
        } else {
            VStack(spacing: 6) {
                overTheirSeat(opponent, in: view, width: 26 * lift)
                HStack(spacing: 6) {
                    seatBadge(opponent, in: view)
                    seatName(opponent, in: view)
                    seatTally(ofSide: side, in: view)
                }
            }
            .animation(.spring(duration: 0.4, bounce: 0.25), value: view.scope[side])
        }
    }

    private func seatBadge(_ opponent: PlayerView.Opponent, in view: PlayerView) -> some View {
        PlayerBadge(name: opponent.player.name, isBot: store.isBot(opponent.player),
                    tint: seatTint(opponent.seat),
                    size: stage.pick(tall: 22, wide: 20), mark: SeatMark(opponent.player),
                    honoured: ChallengeBook.honours(opponent.player.honour, on: store.challenges.week),
                    cornice: Cornice(opponent.player), livery: SeatLivery(opponent.player))
            .overlay { if view.turnSeat == opponent.seat { TurnRing(padding: 3) } }
    }

    /// The face already says it is a bot, and a tag beside the name would crowd four seats.
    private func seatName(_ opponent: PlayerView.Opponent, in view: PlayerView) -> some View {
        Text(opponent.player.name)
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
            // A long name in the landscape strip gives up a little size before it gives up
            // letters: four names and two buttons share that row.
            .minimumScaleFactor(0.75)
            .foregroundStyle(view.turnSeat == opponent.seat ? Palette.goldLight : Palette.onTable)
    }

    /// What that side has taken, and how often it has swept. Sweeps are counted by side
    /// like the pile, so in teams both partners show the side's total.
    @ViewBuilder private func seatTally(ofSide side: Int, in view: PlayerView) -> some View {
        PileCount(count: view.captureCounts[side], width: 11)
        if (view.scope[safe: side] ?? 0) > 0 {
            SweepTally(count: view.scope[side], width: 17 * lift)
        }
    }

    /// What sits over one opponent's seat: their league, what they are still holding, and
    /// whoever they brought.
    ///
    /// All three ride the line above the name rather than beside it: the name row is four
    /// names wide at a four-handed table, and a medal and an animal in it cost three letters
    /// of each name.
    @ViewBuilder private func overTheirSeat(_ opponent: PlayerView.Opponent, in view: PlayerView,
                                            width: CGFloat) -> some View {
        let pet = Companion(opponent.player)
        HStack(alignment: .bottom, spacing: 3) {
            opponentLeague(opponent.player)
            HiddenHand(count: opponent.cardsInHand, width: width)
            if pet != .nessuno {
                CompanionView(companion: pet, size: width,
                              mood: companionMood(ofSeat: opponent.seat, in: view))
            }
        }
    }

    /// The league over an opponent's seat, at a ranked table and nowhere else.
    ///
    /// A medal and a numeral rather than the full name: "Silver II" beside a name beside a
    /// pile count is more words than a chair four seats wide has room for. The full name is
    /// in the accessibility label.
    ///
    /// Kept off the name row and away from the pile count: "Hugo II 2" is two numerals in a
    /// row and neither of them looks like a league.
    @ViewBuilder private func opponentLeague(_ player: Player) -> some View {
        if let standing = store.rank(of: player)?.standing {
            HStack(spacing: 3) {
                LeagueMedal(league: standing.league, size: 15)
                Text(verbatim: ["I", "II", "III"][safe: standing.division - 1] ?? "")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(LeagueMetal.league(standing.league).light)
            }
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: standing.leagueTitle(locale: locale)))
        }
    }

    /// How big a card on the cloth is. One size, for the whole game.
    ///
    /// It used to step down as the table filled, which reflowed the row on the cheapest
    /// move in the game and, because `CardArt` rasterises from its width, redrew every court
    /// face on every frame of the spring. Nothing here changes size any more. See `OverlapRow`.
    ///
    /// Landscape has the room across to spread the cards and none downwards, so it takes the
    /// smaller size.
    private var tableCardWidth: CGFloat { stage.pick(tall: 76, wide: 56) * lift }

    /// The turn each card takes where it lies. A degree or two, derived from the card so it
    /// never shifts under you: a tight row at one angle reads as a striped block.
    private func tilt(_ card: Card) -> Double {
        let seed = card.rank.rawValue * 7 + Int(card.suit.initial.asciiValue ?? 0)
        return Double(seed % 5) - 2
    }

    /// The cloth: the last move, the cards on the table, and what is left in the stock.
    private func tableArea(_ view: PlayerView) -> some View {
        let gap = stage.pick(tall: 30, wide: 12) * lift
        // The tall column on an iPad already has more height than it needs. Letting this
        // band swallow the rest opened one hole of green between the stock and the hand;
        // left at its own height instead, the whole column floats in the middle of the
        // screen and the spare is shared out around it by the centring in `tallLayout`.
        // Folded sideways there is no spare, so there the band stretches as it always did.
        let steady = widthClass == .regular && stage == .tall
        return VStack(spacing: 10) {
            // A row of its own at the top rather than an overlay over the cards: laid over,
            // it cropped the top card of a two-row table.
            lastMoveRow(view)
            // On a phone the slack in this band belongs above the cards, so the cloth sits
            // low, near the hand that feeds it. An iPad's band is half the screen, so there
            // the spacer is capped at both ends and the cards sit in the middle of it.
            Spacer(minLength: 4)
                .frame(maxHeight: widthClass == .regular ? gap : nil)
            clothRow(view)
            stockLabel(view)
            // Capped, so the slack falls mostly above the cards and the cloth sits low in
            // its band rather than in the middle of all that green.
            Spacer(minLength: 4).frame(maxHeight: gap)
        }
        // The full width, not the cards': with one card left on the cloth this column
        // shrank to the width of "Table is clear", and the tag over it with it.
        .frame(maxWidth: .infinity)
        .frame(maxHeight: steady ? nil : .infinity)
    }

    /// The cards on the table, in one row that never wraps.
    private func clothRow(_ view: PlayerView) -> some View {
        let takeable = capturable
        let cardWidth = tableCardWidth
        return OverlapRow(spacing: 12) {
            ForEach(Array(view.table.enumerated()), id: \.element) { index, card in
                clothCard(card, at: index, in: view, width: cardWidth, takeable: takeable)
            }
        }
        // A gutter of its own inside the column's. Past six cards the row is as wide as it
        // is allowed to get, and without this the outermost cards sit flush against the
        // screen edge, with their tilt and the swell of a chosen one crossing it.
        .padding(.horizontal, 8)
        .animation(.spring(duration: 0.55, bounce: 0.18), value: view.table)
        // The middle of the cloth, where a played card is shown before it is carried off.
        // Read from the row of cards, so it follows them as the table fills.
        .clothAnchor(in: Self.tableSpace, into: anchors)
    }

    private func clothCard(_ card: Card, at index: Int, in view: PlayerView,
                           width: CGFloat, takeable: Set<Card>) -> some View {
        let chosen = selection.chosen.contains(card)
        let underFinger = hovered == card
        return CardView(
            card: card,
            width: width,
            highlighted: chosen || underFinger,
            outlined: !chosen && takeable.contains(card)
        )
        .rotationEffect(.degrees(tilt(card)))
        .scaleEffect(underFinger ? 1.12 : (chosen ? 1.06 : 1))
        // Lifted as well as grown: on a tight row a card that only swells is still tucked
        // under its neighbour.
        .offset(y: underFinger ? -10 : (chosen ? -6 : 0))
        // The card laid last lies over the one before it, so a card landing never changes
        // the look of anything already down. A card being chosen comes above the lot.
        .zIndex(chosen || underFinger ? 100 : Double(index))
        // Laid out, holding its place, but not drawn: the copy still crossing the cloth is
        // the one being watched. See `settling`.
        .opacity(settling == card ? 0 : 1)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(Self.tableSpace))
        } action: { frame in
            tableFrames.frames[card] = frame
        }
        // A taken card fades where it sat, quickly, while the copy `CardFlightLayer` draws
        // over the top carries it away. Anything slower and the card is visible twice.
        .transition(.asymmetric(
            insertion: .scale(scale: 0.5).combined(with: .opacity)
                .animation(.spring(duration: 0.5, bounce: 0.3)),
            removal: .opacity.animation(.easeOut(duration: 0.1))
        ))
        .onTapGesture { tapCloth(card, in: view) }
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(card.spoken)
        .accessibilityHint(chosen ? "Double tap to leave it" : "Double tap to take it")
    }

    /// A tap puts a card into the take or takes it back out. The take that a tap finishes
    /// goes straight out in the checked mode, so the only tap that ever plays is one that
    /// adds the last card: a card already in the take can always be let go of.
    private func tapCloth(_ card: Card, in view: PlayerView) {
        withAnimation(.snappy(duration: 0.2)) { selection.toggle(card, on: view.table) }
        playIfTakeIsComplete(in: view)
    }

    private func stockLabel(_ view: PlayerView) -> some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                CardBack(width: 14 * lift)
                Text("\(view.stockCount) left")
            }
            if view.table.isEmpty { Text("Table is clear") }
        }
        .font(.system(size: 12))
        .foregroundStyle(Palette.onTableSoft)
    }

    /// The last move, in the top corner of the cloth: the record of what `CardFlight` has
    /// just played out. The row is there whether or not anybody has played, so the cards
    /// below it do not shift when it arrives.
    private func lastMoveRow(_ view: PlayerView) -> some View {
        HStack(spacing: 0) {
            if let lastMove {
                LastMoveTag(play: lastMove, tint: seatTint(lastMove.seat),
                            isMine: lastMove.seat == view.seat, compact: stage.isWide)
                    .fixedSize()
                    // A move at a time, swapped whole: left to match itself up, the tag
                    // cross-faded its pieces.
                    .id(lastMove.id)
                    .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .leading)))
            }
            Spacer(minLength: 0)
        }
        .frame(height: LastMoveTag.height(compact: stage.isWide), alignment: .leading)
    }

    // MARK: Cards in the air

    /// How big a card is held up in the middle of the cloth while the move is being shown.
    /// Bigger than a card on the table: on a phone between four people it has to be readable
    /// from the other side of it.
    private var flightCardWidth: CGFloat { stage.pick(tall: 104, wide: 74) * lift }

    /// Sends a capture across the cloth to whoever won it.
    ///
    /// Called the moment the play lands, and it has to be: the next layout pass takes those
    /// cards off the table and overwrites the positions `tableFrames` holds.
    private func sendFlight(for play: TableStore.Play, in view: PlayerView) {
        guard !play.captures.isEmpty else {
            sendLayDown(play, in: view)
            return
        }
        let placed = play.captures.compactMap { card in
            tableFrames.frames[card].map { CardFlight.Placed(card: card, frame: $0) }
        }
        // No frames means the cards were never drawn: a move read back from a saved game,
        // or a table that has not laid out yet.
        guard !placed.isEmpty, let destination = anchors.seats[play.seat] else { return }
        flight = CardFlight(played: play.card, taken: placed,
                            origin: play.seat == view.seat ? nil : anchors.seats[play.seat],
                            from: cloth(around: placed), to: destination,
                            cardWidth: flightCardWidth,
                            tint: seatTint(play.seat),
                            caption: nil, sweeps: play.sweeps, endsTheRound: false,
                            isMine: play.seat == view.seat)
    }

    /// Carries a card that took nothing to the place the cloth has made for it.
    ///
    /// Somebody else's crosses the table from their badge, face down, turns over on the way
    /// and is held up in the middle long enough to be read: a bot's used to appear on the
    /// cloth between two glances. Your own flies out of the slot it was sitting in, face up
    /// the whole way, straight to its place. See `CardFlight.travel` and `CardFlight.hold`.
    ///
    /// Where it is going is not known yet, since the row has to make room for it first, so
    /// the card is hidden until the cloth reports the place it made.
    private func sendLayDown(_ play: TableStore.Play, in view: PlayerView) {
        let mine = play.seat == view.seat
        // Read after the card has already gone from your hand, which is why the frames are
        // a box: what it last reported stays behind, and that is where it was played from.
        let origin = mine
            ? handFrames.frames[play.card].map { CGPoint(x: $0.midX, y: $0.midY) }
            : anchors.seats[play.seat]
        guard let origin, mine || anchors.cloth != .zero else { return }
        settling = play.card
        Task { await flyLayDown(play, from: origin, mine: mine) }
    }

    private func flyLayDown(_ play: TableStore.Play, from origin: CGPoint, mine: Bool) async {
        // Two frames, which is a layout pass and the geometry read that follows it.
        try? await Task.sleep(for: .milliseconds(40))
        guard settling == play.card else { return }
        // Something else took to the air in the meantime: the round ended on this card and
        // its leftovers are already crossing the cloth. They have the floor.
        guard flight == nil else {
            settling = nil
            return
        }
        // Never drawn, so there is nowhere to set it down. Show it plainly.
        guard let slot = tableFrames.frames[play.card] else {
            settling = nil
            return
        }
        let place = CGPoint(x: slot.midX, y: slot.midY)
        flight = CardFlight(played: play.card, taken: [], origin: origin,
                            // Yours goes to its place and settles there. Somebody else's is
                            // held up in the middle of the cloth first.
                            from: mine ? place : anchors.cloth,
                            to: place,
                            cardWidth: flightCardWidth,
                            tint: seatTint(play.seat),
                            caption: nil, sweeps: false, endsTheRound: false,
                            isMine: mine, laysDown: true, restingWidth: slot.width)
    }

    /// Sends the round's last cards to the side that swept them up. The rule surprises
    /// everyone the first time, and until now the cards simply vanished.
    private func sendLeftovers(_ leftovers: TableStore.Leftovers, in view: PlayerView) {
        guard let last = leftoverFlight(leftovers, in: view) else { return }
        // The summary waits for them. Set here rather than when the flight starts, so a
        // round whose leftovers cannot be drawn is never held back for a flight that will
        // never come.
        holdsSummary = true
        // The play that ended the round may still be crossing the cloth. These follow it
        // rather than knocking it out of the air, a beat clear of its own tidying up.
        let wait = flight.map { $0.duration + 0.2 } ?? 0
        guard wait > 0 else { flight = last; return }
        // Off the cloth already and not in the air for another second: held where they lay
        // in between, rather than fading out and coming back to be taken.
        held = last.taken
        Task {
            try? await Task.sleep(for: .seconds(wait))
            // Handed over on one frame: the flight's own copies start at these very places,
            // at this very size.
            flight = last
            held = []
        }
    }

    private func leftoverFlight(_ leftovers: TableStore.Leftovers, in view: PlayerView) -> CardFlight? {
        guard !leftovers.cards.isEmpty else { return nil }
        let placed = leftovers.cards.compactMap { card in
            tableFrames.frames[card].map { CardFlight.Placed(card: card, frame: $0) }
        }
        // The side is put back on a seat: yours if it is yours, otherwise whoever from that
        // side is on screen. At a table of four either partner will do, since the pile they
        // are going into is shared.
        let seat = view.configuration.side(ofSeat: view.seat) == leftovers.side
            ? view.seat
            : view.opponents.first { view.configuration.side(ofSeat: $0.seat) == leftovers.side }?.seat
        guard !placed.isEmpty, let seat, let destination = anchors.seats[seat] else { return nil }
        let name = seat == view.seat
            ? String(localized: "you", locale: locale)
            : (view.configuration.players[safe: seat]?.name ?? "").shortName()
        return CardFlight(played: nil, taken: placed, origin: nil,
                          from: cloth(around: placed), to: destination,
                          cardWidth: flightCardWidth,
                          tint: seatTint(seat),
                          caption: String(localized: "Last cards to \(name)", locale: locale),
                          sweeps: false, endsTheRound: true, isMine: seat == view.seat)
    }

    /// Where a played card lands, and where a caption sits: the middle of the cloth, or the
    /// middle of the cards leaving it when the cloth has never reported itself.
    private func cloth(around placed: [CardFlight.Placed]) -> CGPoint {
        guard anchors.cloth == .zero, !placed.isEmpty else { return anchors.cloth }
        let sum = placed.reduce(CGPoint.zero) { total, card in
            CGPoint(x: total.x + card.frame.midX, y: total.y + card.frame.midY)
        }
        return CGPoint(x: sum.x / CGFloat(placed.count), y: sum.y / CGFloat(placed.count))
    }

    /// Whose move it is, and what you have taken so far. The old "Your pile · 12 cards"
    /// pill said the second and nobody could tell what a pile was, so this draws it.
    private func statusRow(_ view: PlayerView) -> some View {
        HStack(spacing: 8) {
            TurnPill(view: view, name: turnName(view))
            Spacer(minLength: 0)
            // Whoever you brought with you, in the slack above your own hand. Nothing at
            // all when nobody was bought.
            CompanionView(companion: store.companion, size: 34,
                          mood: companionMood(ofSeat: view.seat, in: view))
            Spacer(minLength: 0)
            sweepTally(view)
            pileButton(view)
        }
        .animation(.spring(duration: 0.4, bounce: 0.25), value: view.scope[view.mySide])
        // Portrait sets the row off the hand below it. Landscape puts it beside it.
        .padding(.bottom, stage.pick(tall: 10, wide: 0))
    }

    @ViewBuilder private func sweepTally(_ view: PlayerView) -> some View {
        if view.scope[view.mySide] > 0 {
            HStack(spacing: 4) {
                BroomMark(size: 13, tint: Palette.cream)
                Text("\(view.scope[view.mySide])")
                    .font(.system(size: 12, weight: .bold))
                    .contentTransition(.numericText())
            }
            .foregroundStyle(Palette.cream)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassCapsule(tint: Palette.terracotta)
            .transition(.scale.combined(with: .opacity))
        }
    }

    private func pileButton(_ view: PlayerView) -> some View {
        Button { showsPile = true } label: {
            PileTag(count: view.captureCounts[view.mySide], teams: view.configuration.teams, pop: pilePop,
                    showsLabel: stage.pick(tall: true, wide: false))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(view.configuration.teams
                            ? Text("\(view.captureCounts[view.mySide]) cards taken by us")
                            : Text("\(view.captureCounts[view.mySide]) cards taken"))
        .accessibilityHint("Shows what you have taken so far")
        // Your own captures fly here, which is also where they are counted.
        .seatAnchor(view.seat, in: Self.tableSpace, into: anchors)
    }

    /// What the animal at one seat is doing: watching while that player decides, pleased
    /// when they sweep, asleep otherwise. `CompanionView` times the stirring in between.
    ///
    /// By seat rather than by `view`, so each animal reacts to its own player.
    private func companionMood(ofSeat seat: Int, in view: PlayerView) -> Companion.Mood {
        if showsScopa, store.lastPlay?.seat == seat { return .delighted }
        return view.turnSeat == seat && !gameIsOver ? .watching : .resting
    }

    /// Whose turn it is, by name. Blank when it is yours, which the pill says itself.
    private func turnName(_ view: PlayerView) -> String {
        guard !view.isMyTurn, let seat = view.turnSeat else { return "" }
        return (view.configuration.players[safe: seat]?.name ?? "").shortName()
    }

    /// The three cards you are holding. The button that plays them is `actionBar`, which
    /// portrait stacks above and landscape sets beside, so the cards are their own view.
    ///
    /// The drag lives inside `HandCards`, and the screen only hears about it at the moments
    /// that change something up here: a card picked up, the finger crossing onto a table
    /// card, the card let go.
    private func handCards(_ view: PlayerView, counsels: [Coach.Counsel]) -> some View {
        HandCards(
            hand: view.hand,
            picked: selection.card,
            marks: Dictionary(counsels.map { ($0.card, $0.standing) }, uniquingKeysWith: { first, _ in first }),
            isMyTurn: view.isMyTurn,
            stage: stage,
            lift: lift,
            space: Self.tableSpace,
            frames: handFrames,
            tap: { card in tapHand(card, in: view) },
            pick: { card in pickUpHand(card, in: view) },
            hover: { point in hoverTable(at: point, in: view) },
            drop: { card, point, travel in dropHand(card, at: point, travel: travel, in: view) }
        )
    }

    /// How soon the second tap has to follow the first to play the card rather than put it down.
    private static let doubleTap: TimeInterval = 0.45

    /// First tap picks the card up. A quick second tap plays it when it allows one move
    /// only; a slow one puts it back down. Any second tap used to play it, so a player who
    /// had picked the wrong card had no way to change their mind but the other card.
    /// VoiceOver's activations are never quick, so there every second tap counts.
    private func tapHand(_ card: Card, in view: PlayerView) {
        let quick = voiceOver || pickedAt.map { Date.now.timeIntervalSince($0) < Self.doubleTap } ?? false
        if quick, selection.tapInHand(card, in: view) == .play {
            commit(in: view)
            return
        }
        withAnimation(.snappy(duration: 0.22)) { selection.select(card, on: view.table) }
        pickedAt = selection.card == nil ? nil : .now
    }

    private func pickUpHand(_ card: Card, in view: PlayerView) {
        liftedByDrag = selection.card != card
        guard liftedByDrag else { return }
        withAnimation(.snappy(duration: 0.18)) { selection.select(card, on: view.table) }
        pickedAt = .now
    }

    private func hoverTable(at point: CGPoint, in view: PlayerView) {
        let over = tableCard(under: point, in: view)
        if over != hovered { withAnimation(.snappy(duration: 0.15)) { hovered = over } }
    }

    /// How far the finger has to carry a card before the touch is taken for a drag. The
    /// gesture itself starts at twelve points, which is less than a tap that is not quick
    /// drifts, so a slow second tap was being swallowed: the card was picked up again and
    /// never played. Ending this close to where it began means nothing was carried
    /// anywhere, and the touch goes back to being the tap it was meant to be.
    private static let wander: CGFloat = 24

    private func dropHand(_ card: Card, at point: CGPoint, travel: CGSize, in view: PlayerView) {
        let target = tableCard(under: point, in: view)
        hovered = nil
        guard let target else {
            if hypot(travel.width, travel.height) < Self.wander {
                // The card this touch picked up is a first tap and stays picked up; one
                // that was already up is the second tap, which plays it.
                if !liftedByDrag { tapHand(card, in: view) }
            } else if travel.height < -60 {
                throwToTable(card, in: view)
            }
            return
        }
        if let finished = selection.completing(with: target, in: view) {
            selection = finished
            commit(in: view)
        } else {
            withAnimation(.snappy(duration: 0.2)) { selection.toggle(target, on: view.table) }
            playIfTakeIsComplete(in: view)
        }
    }

    /// The one thing to press once a card is picked. It fills whatever it is given: the
    /// screen in portrait, the right-hand column in landscape.
    @ViewBuilder private func actionBar(_ view: PlayerView) -> some View {
        if view.isMyTurn, let action = selection.action(in: view) {
            Button { commit(in: view) } label: {
                HStack(spacing: 8) {
                    if selection.assist.highlightsCaptures, case .take(_, true) = action {
                        BroomMark(size: 18, tint: Palette.cream)
                    }
                    Text(title(for: action))
                        .contentTransition(.opacity)
                }
            }
            .buttonStyle(FilledButtonStyle(
                tint: action.isPlayable ? Palette.terracotta : felt.shade(0.55),
                foreground: action.isPlayable ? Palette.cream : Palette.onTableSoft,
                minHeight: stage.pick(tall: 52, wide: 46)
            ))
            .disabled(!action.isPlayable)
            .glassMaterialize()
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            Color.clear.frame(height: stage.pick(tall: 52, wide: 46))
        }
    }

    /// Only drawn while somebody is on the move. Left up on the summaries, it sat there
    /// drained to empty as though the winner were running out of time.
    private func showsTurnClock(_ view: PlayerView) -> Bool {
        view.configuration.turnClock.seconds != nil && view.phase == .playing
    }

    /// The clock, drawn as a bar that drains.
    ///
    /// Four steps a second rather than twenty: every step redraws the bar and its glass for
    /// thirty seconds of every turn. A smooth animation would be worse still, since it keeps
    /// the screen compositing for the whole turn.
    private func turnClockBar(_ view: PlayerView) -> some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
            let remaining = deadline.map { max($0.timeIntervalSince(timeline.date), 0) } ?? 0
            let total = Double(view.configuration.turnClock.seconds ?? 1)
            let fraction = min(remaining / total, 1)
            VStack(spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.cream.opacity(0.12))
                        Capsule()
                            .fill(fraction < 0.25 ? Palette.terracotta : felt.accent)
                            .frame(width: geometry.size.width * fraction)
                    }
                    .glassCapsule()
                }
                .frame(height: 7)
                if fraction < 0.25 {
                    Text(view.isMyTurn ? "Hurry up" : "They are running out of time")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.terracotta)
                }
            }
            .padding(.top, stage.pick(tall: 12, wide: 6))
        }
    }

    private func restartClock() {
        guard let seconds = view?.configuration.turnClock.seconds, view?.phase == .playing else {
            deadline = nil
            return
        }
        deadline = Date().addingTimeInterval(TimeInterval(seconds))
    }

    /// When the clock runs out, the table plays the best move for whoever was thinking.
    private func runClock() async {
        guard let deadline else { return }
        let wait = deadline.timeIntervalSinceNow
        guard wait > 0 else { return }
        try? await Task.sleep(for: .seconds(wait))
        guard !Task.isCancelled, let view, view.isMyTurn, view.phase == .playing else { return }
        selection.clear()
        store.playAutomatically()
    }

    /// The things this player can say without typing: five for everybody, more with a pack.
    ///
    /// Lines, not faces. A sentence takes a capsule where an emoji took a circle, so the row
    /// scrolls rather than shrinking the words down to something nobody can read, and the
    /// button that opens it stays put on the right.
    private var reactionRow: some View {
        GlassGroup(spacing: 16) {
            HStack(spacing: 8) {
                if showsReactions { reactionChoices }
                Button {
                    withAnimation(.spring(duration: 0.42, bounce: 0.25)) { showsReactions.toggle() }
                } label: {
                    // An emoji here would be interface, not content, so this one is a symbol.
                    Image(systemName: showsReactions ? "xmark" : "face.smiling")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.onTable)
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .glass(.riviera(interactive: true), in: .circle)
                .contentShape(.circle)
                .glassID("reactions", in: reactionGlass)
            }
        }
        .padding(.bottom, stage.pick(tall: 6, wide: 0))
    }

    /// Only what this player owns: the five everybody has, plus any pack.
    private var reactionChoices: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(purse.reactions, id: \.self) { reaction in
                    Button {
                        store.react(reaction)
                        withAnimation(.spring(duration: 0.42, bounce: 0.25)) { showsReactions = false }
                    } label: {
                        SaidLine(reaction: reaction, size: 13)
                            .padding(.horizontal, 13)
                            .frame(height: 38)
                    }
                    .buttonStyle(.plain)
                    .glass(.riviera(interactive: true), in: .capsule)
                    .contentShape(.capsule)
                    .glassID(reaction, in: reactionGlass)
                }
            }
            // Room for the glass to bulge without the scroll view clipping it.
            .padding(.vertical, 3)
        }
        .scrollClipDisabled()
    }

    @ViewBuilder private func advice(_ view: PlayerView, counsels: [Coach.Counsel]) -> some View {
        if selection.assist.explains {
            CoachStrip(say: say(in: view, counsels: counsels), stage: stage)
                .padding(.top, stage.pick(tall: 8, wide: 0))
                .padding(.bottom, stage.pick(tall: 10, wide: 0))
        } else {
            hint(view)
        }
    }

    /// What the coach has to say, which is only ever one thing: the card in the air if
    /// there is one, what the hand holds if there is not, and otherwise whoever the table
    /// is waiting on.
    private func say(in view: PlayerView, counsels: [Coach.Counsel]) -> CoachSay {
        guard !gameIsOver, view.phase == .playing else { return .quiet }
        if let card = selection.card, let counsel = counsels.first(where: { $0.card == card }) {
            return .counsel(counsel)
        }
        // While their move is still being shown on the cloth, the strip belongs to them:
        // a learner needs telling what just happened before being asked what to do about it.
        if let reading, let lastMove, lastMove.seat != view.seat {
            return .theirMove(reading, name: lastMove.name.shortName())
        }
        guard view.isMyTurn else { return .waiting(turnName(view)) }
        return .lookingAt(counsels)
    }

    private func hint(_ view: PlayerView) -> some View {
        Text(hintText(view))
            .font(.system(size: 12))
            .foregroundStyle(Palette.onTableSoft)
            // Its own line under the hand in portrait; beside the piles in landscape,
            // where it reads as the second line of the same little column.
            .multilineTextAlignment(stage.pick(tall: TextAlignment.center, wide: .leading))
            .padding(.top, stage.pick(tall: 8, wide: 0))
            .padding(.bottom, stage.pick(tall: 12, wide: 0))
    }

    // MARK: Round and game end

    @ViewBuilder private var roundOverlay: some View {
        // The round's leftovers are still crossing the cloth, which is exactly the moment
        // the rule is worth watching, so the summary waits.
        if let view, !holdsSummary {
            switch view.phase {
            case .roundOver(let score) where store.isDailyDeal:
                dailySummary(score, in: view).onAppear { announce(.round(view.roundNumber)) }
            case .roundOver(let score):
                roundSummary(score, in: view).onAppear { announce(.round(view.roundNumber)) }
            case .finished(let winner):
                finalSummary(winner: winner, in: view).onAppear { announce(.game(view.roundNumber)) }
            default: EmptyView()
            }
        }
    }

    /// Which summary has already been announced, so that one round is announced once.
    private enum Announced: Equatable {
        case round(Int), game(Int)
    }

    /// The sound a summary arrives on.
    ///
    /// It used to sit on `RoundSummary`'s own `onAppear`, which is one appearance too
    /// many. A round with leftovers takes the panel off screen again the moment it is
    /// built — the cards are still crossing the cloth to whoever swept them up, and
    /// `sendLeftovers` holds the summary back for them — and then builds it a second time
    /// when they land. Two panels, one round: the chime was heard opening and closing.
    /// Whether it happened at all came down to whether a frame was drawn between the two
    /// halves of the round's arrival, which is why it was only sometimes.
    private func announce(_ summary: Announced) {
        guard announced != summary else { return }
        announced = summary
        Audio.shared.play(.roundOver)
    }

    /// Today's deal is one round, so its end is the end: the same final summary, with the
    /// margin over the bot for a headline.
    private func dailySummary(_ score: RoundScore, in view: PlayerView) -> some View {
        RoundSummary(score: score, view: view, showsAction: true,
                     caption: String(localized: "Today's deal", locale: locale),
                     title: dailyHeadline(score, in: view),
                     isFinal: true, totalsTold: $summaryToldIt,
                     earnings: earnings, doubling: doubling, experience: gainedExperience,
                     review: store.review == nil ? nil : { showsReview = true },
                     glance: reviewGlance(),
                     showsTarget: false) {
            Task {
                await ads.endOfGame(.ordinary)
                store.leaveTable()
            }
        }
        .task(id: store.finishedTally?.gameID) {
            guard let tally = store.finishedTally else { return }
            let paid = await settleDaily(tally)
            withAnimation(.spring(duration: 0.45, bounce: 0.2)) { earnings = paid }
        }
        .onChange(of: summaryToldIt && !pendingToasts.isEmpty) { _, ready in if ready { deliverToasts() } }
    }

    /// Only the host can deal the next round, so only the host gets a button. The review so
    /// far is offered here too: a lesson from round one is worth more before round two.
    private func roundSummary(_ score: RoundScore, in view: PlayerView) -> some View {
        RoundSummary(score: score, view: view, showsAction: store.isHost,
                     caption: String(localized: "Round \(view.roundNumber)", locale: locale),
                     title: roundHeadline(score, in: view), isFinal: false,
                     totalsTold: $summaryToldIt,
                     review: store.review == nil ? nil : { showsReview = true },
                     glance: reviewGlance(round: view.roundNumber)) {
            store.dealNextRound()
        }
    }

    /// The game is over for everyone, so every player can leave, host or not. The breakdown
    /// comes from the store: the phase only carries the winner.
    private func finalSummary(winner: Int, in view: PlayerView) -> some View {
        RoundSummary(score: store.lastRoundScore, view: view, showsAction: true,
                     caption: String(localized: "Game over", locale: locale),
                     title: winnerHeadline(winner, in: view),
                     isFinal: true, totalsTold: $summaryToldIt,
                     earnings: earnings, doubling: doubling, experience: gainedExperience,
                     review: store.review == nil ? nil : { showsReview = true },
                     glance: reviewGlance(),
                     footnote: summaryFootnote,
                     verdict: rankedMove(won: winner == view.mySide),
                     awaitingLadder: store.isAwaitingLadder,
                     again: playAgainIfAllowed) {
            Task {
                // Losing a stake is enough for one game: the pacing rules take that ending
                // off the table rather than charging for it twice.
                await ads.endOfGame(store.stake != nil && winner != view.mySide
                                    ? .lostStake : .ordinary)
                store.leaveTable()
            }
        }
        // Paid the moment the summary appears, so the denari are banked by the time anyone
        // taps away. Safe to run twice, because settling is.
        .task(id: store.finishedTally?.gameID) {
            guard let tally = store.finishedTally else { return }
            if store.isRanked { store.reportRanked(winnerSeat: winner) }
            var paid = await settle(tally, won: winner == view.mySide, players: view.configuration.seatCount)
            paid += await settleChallenge(tally, won: winner == view.mySide)
            withAnimation(.spring(duration: 0.45, bounce: 0.2)) { earnings = paid }
            Achievements.record(tally, won: winner == view.mySide, streak: store.dailyStreak)
            recordProgress(tally)
        }
        .onChange(of: summaryToldIt && !pendingToasts.isEmpty) { _, ready in if ready { deliverToasts() } }
    }

    // MARK: Selection

    private var capturable: Set<Card> {
        guard let view else { return [] }
        return selection.capturable(on: view.table)
    }

    private func title(for action: HandSelection.Action) -> LocalizedStringKey {
        switch action {
        case .lay: return selection.assist.highlightsCaptures ? "Lay it on the table" : "Play"
        case .chooseWhatToTake: return "Choose what to take"
        case .notAllowed: return "That take is not allowed"
        case .take(let cards, let sweeps):
            // Naming the take is itself a hint, so only beginners get it.
            guard selection.assist.highlightsCaptures else { return "Take" }
            return sweeps ? "Take \(cards.rankList) and sweep" : "Take \(cards.rankList)"
        }
    }

    /// Which table card the finger is over, if any. Beginners can only drop on a card a take could use.
    ///
    /// The cards overlap, so a finger is over two or three at once. The last one is the
    /// card being pointed at, since the one laid latest lies over the rest. See `OverlapRow`.
    private func tableCard(under point: CGPoint, in view: PlayerView) -> Card? {
        let under = view.table.filter { tableFrames.frames[$0]?.contains(point) == true }
        guard selection.assist.highlightsCaptures else { return under.last }
        // For a beginner, the last one the take could actually use: a drop refused because
        // the card lying over it is not part of the take has no visible reason.
        return under.last { capturable.contains($0) }
    }

    /// Plays the card outright when the take is unambiguous, otherwise leaves it picked to choose from.
    private func throwToTable(_ card: Card, in view: PlayerView) {
        guard view.isMyTurn else { return }
        var attempt = selection
        if attempt.card != card { attempt.select(card, on: view.table) }
        if attempt.move(in: view) != nil {
            selection = attempt
            commit(in: view)
        } else {
            withAnimation(.snappy(duration: 0.2)) { selection = attempt }
        }
    }

    /// In the checked mode, a finished take plays itself. No legal take contains another, so this is unambiguous.
    private func playIfTakeIsComplete(in view: PlayerView) {
        guard selection.assist.checksBeforeSending, case .take = selection.action(in: view) else { return }
        commit(in: view)
    }

    private func commit(in view: PlayerView) {
        guard view.isMyTurn, let move = selection.move(in: view) else { return }
        // The table and the hand each animate off their own value, so wrapping the whole
        // update in a bouncing spring made the score row overshoot under the status bar.
        store.play(move.card, capturing: move.captures)
        withAnimation(.snappy(duration: 0.2)) { selection.clear() }
    }

    // MARK: Copy

    private func sideName(_ side: Int, in view: PlayerView) -> String {
        guard view.configuration.teams else {
            return view.configuration.players[safe: side]?.name
                ?? String(localized: "Seat \(side + 1)", locale: locale)
        }
        return side == view.mySide
            ? String(localized: "Us", locale: locale)
            : String(localized: "Them", locale: locale)
    }

    /// Where the settebello banner sits, as a fraction of the table's height.
    ///
    /// Not centred: the seven is on its way to somebody's pile, so the banner sits on that
    /// side of the table. An opponent's rides up over their end, covering the last-play chip.
    /// Yours stays down between the table and the status row, covering the stock count
    /// whole, since your hand must not be covered at the moment the seven is called.
    ///
    /// Landscape sits both a little higher: the table comes out of about 390 points there
    /// instead of 850, so the same fraction is much further down the cloth.
    private var settebelloHeight: CGFloat {
        settebelloBy.isEmpty
            ? stage.pick(tall: 0.485, wide: 0.45)
            : stage.pick(tall: 0.22, wide: 0.18)
    }

    /// The finished game read back, for the seat whose phone this is. Nil until the review
    /// has landed, which on a phone is well before the summary has finished telling.
    ///
    /// `round` scopes it to one round, for the panel headed with one. Without it the
    /// accuracy on "Round 3" was the average over rounds one to three, which converges to
    /// the same figure every time.
    private func reviewGlance(round: Int? = nil) -> GameReview.Summary? {
        guard let review = store.review, let seat = store.reviewedSeat else { return nil }
        return review.summary(forSeat: seat, round: round)
    }

    /// The small line under the summary: what the ladder made of a ranked game, or the
    /// pack this one earned.
    ///
    /// The league wins where there is one. A ranked game is the one table with something
    /// at stake beyond the hand, and a pack does not go anywhere — the album is where it
    /// is opened, and the lobby's own door is already wearing a count of what is waiting.
    private var summaryFootnote: String? {
        if let rank = rankFootnote { return rank }
        guard earnedPack else { return nil }
        return String(localized: "A pack is waiting in the album", locale: locale)
    }

    /// "Silver II · +20", once the ladder has answered a ranked game.
    private var rankFootnote: String? {
        guard store.isRanked, let rank = store.rank else { return nil }
        let title = rank.standing.leagueTitle(locale: locale)
        guard let change = store.rankChange else { return title }
        return "\(title) · \(change >= 0 ? "+" : "−")\(abs(change))"
    }

    /// Where the league stood before this ranked game and where it stands now, which is
    /// everything `RankedVerdict` needs to run the bar. Nil until the ladder has answered,
    /// and nil for a game it answered without moving anybody.
    private func rankedMove(won: Bool) -> RankedVerdict.Move? {
        guard store.isRanked, let rank = store.rank, let change = store.rankChange else { return nil }
        // The change the Worker sends is the one it *applied*, floor and ceiling included,
        // so the rating before the game is exactly the rating after it less the change.
        return RankedVerdict.Move(before: rank.rating - change, after: rank.rating, won: won,
                                  streak: rank.streak ?? 0)
    }

    /// What this ranked table pays, over the deal that opens it.
    ///
    /// Held back until the ladder has answered for the other chairs, since a banner that
    /// said "vs Unranked" and then corrected itself is worse than silence. Shown once, on
    /// the first deal of the table.
    private func tellStakes() async {
        // Only where the ladder is watching, and only ever for what it will actually pay:
        // a table against the house pays a win in full while the day's allowance lasts, and
        // nothing once it is spent. The banner says whichever it is.
        guard store.ladderTable != nil, !stakesTold, let odds = rankedOdds() else { return }
        // Behind the hand banner, which owns the first beat of a deal.
        try? await Task.sleep(for: .milliseconds(2600))
        // Marked told only once it is actually being told: this task is keyed on who is
        // sitting at the table, and a chair filling during the wait cancels it.
        guard !Task.isCancelled, !stakesTold else { return }
        stakesTold = true
        withAnimation(.spring(duration: 0.4, bounce: 0.28)) { stakes = odds }
        Audio.shared.play(.notice, gain: 0.7)
        try? await Task.sleep(for: .seconds(3.6))
        // Cleared whether or not the wait was cut short: a banner left up is worse than
        // one cut off.
        withAnimation(.easeOut(duration: 0.35)) { stakes = nil }
    }

    /// Both sides of a ranked table as the ladder rates them. Nil where this phone does
    /// not know its own league yet, which is every ranked game before the first one.
    private func rankedOdds() -> RankedStakes.Odds? {
        guard let mine = store.rank, let view = store.view, let kind = store.ladderTable else { return nil }
        // The other side, not the other seats: `opponents` holds your partner too at a duo,
        // and averaging them in would price the game against your own friend's league.
        let facing = view.opponents.filter { view.configuration.side(ofSeat: $0.seat) != view.mySide }
        switch kind {
        case .people:
            // Only the real chairs across the table, because only they are rated. The house
            // wears a rosette so its seat does not give itself away (see `houseRank`), and
            // counting one in would promise points for beating a machine.
            let theirs = facing.filter { !$0.player.isBot }.compactMap { store.rank(of: $0.player)?.rating }
            return RankedStakes.odds(mine: mine.rating, theirs: theirs, streak: mine.streak ?? 0)
        case .house:
            let across = facing.compactMap { store.rank(of: $0.player)?.rating }.first
            return RankedStakes.houseOdds(mine: mine.rating, theirs: across,
                                          counting: mine.house?.isCounting ?? true,
                                          win: mine.house?.win ?? Ranking.houseWin,
                                          loss: mine.house?.loss ?? Ranking.houseLoss)
        }
    }

    /// The one ad anybody asks for, on the last summary: watch it and the game pays out
    /// again. Only a game that paid something, only once, and never a wager.
    private var doubling: Doubling? {
        let total = earnings.reduce(Denari.zero) { $0 + $1.value }
        guard !doubled, store.stake == nil, total.isCredit, ads.offersReward,
              let gameID = store.finishedTally?.gameID else { return nil }
        return Doubling(amount: total, isWatching: isDoubling) { double(total, gameID: gameID) }
    }

    /// Today's deal, paid: the deal itself, and the mark on the run if this one reached it.
    private func settleDaily(_ tally: RewardTally) async -> [PayoutLine] {
        var paid = await purse.settle(tally).map { PayoutLine($0, locale: locale) }
        if let milestone = store.streakMilestone, let day = store.dailyDay,
           let credited = await purse.award(milestone, day: day) {
            paid.append(PayoutLine(id: "streak", title: streakTitle(milestone), value: credited))
        }
        paid += await settleChallenge(tally, won: tally.outcome == .won)
        Achievements.record(tally, won: tally.outcome == .won, streak: store.dailyStreak)
        recordProgress(tally)
        return paid
    }

    /// The slow progress a finished game makes: experience on the bar, and a game towards
    /// the next pack. Both are shown on the summary; a level or a pack is also news.
    private func recordProgress(_ tally: RewardTally) {
        if let gain = Experience.record(tally) {
            withAnimation(.spring(duration: 0.45, bounce: 0.2)) { gainedExperience = gain }
            if gain.levelledUp {
                pendingToasts.append(Toast(
                    symbol: "star.fill", tint: Palette.gold,
                    title: String(localized: "Level \(gain.after.number) reached", locale: locale),
                    detail: String(localized: "\(gain.after.toGo) XP to level \(gain.after.number + 1)", locale: locale)))
            }
        }
        if store.albumBook.countFinishedGame() {
            earnedPack = true
            pendingToasts.append(Toast(
                symbol: "gift.fill", tint: Palette.terracotta,
                title: String(localized: "You earned a pack", locale: locale),
                detail: String(localized: "Open it in the album", locale: locale)))
        }
        if summaryToldIt { deliverToasts() }
    }

    /// Hands the held news to the toaster, a beat after the totals so the headline is read
    /// first. Not tied to this screen: leaving the table in that beat must not lose it.
    private func deliverToasts() {
        guard !pendingToasts.isEmpty else { return }
        let news = pendingToasts
        pendingToasts = []
        let toaster = toaster
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            news.forEach(toaster.post)
        }
    }

    /// The week's tasks, counted, and paid for each one this game finished — plus the bonus
    /// if it finished the last of them.
    ///
    /// Every finished game goes through here, whatever kind of table it was: the week counts
    /// across all of them, unlike the daily deal.
    private func settleChallenge(_ tally: RewardTally, won: Bool) async -> [PayoutLine] {
        guard let finish = store.recordChallenge(tally, won: won) else { return [] }
        let week = store.challenges.week
        let goals = store.challenges.goals
        var paid: [PayoutLine] = []
        for slot in finish.slots {
            guard let credited = await purse.award(goals[slot], slot: slot, week: week) else { continue }
            paid.append(PayoutLine(id: "challenge.\(slot)",
                                   title: String(localized: "A task for the week", locale: locale),
                                   value: credited))
        }
        if finish.week, let credited = await purse.awardWeek(week) {
            paid.append(PayoutLine(id: "challenge.week",
                                   title: String(localized: "Every task this week", locale: locale),
                                   value: credited))
        }
        return paid
    }

    private func streakTitle(_ milestone: Streaks.Milestone) -> String {
        if let felt = milestone.felt {
            return String(localized: "\(milestone.days) days in a row · \(felt.title) felt", locale: locale)
        }
        return String(localized: "\(milestone.days) days in a row", locale: locale)
    }

    /// The button's action, or nothing where this phone cannot deal again.
    private var playAgainIfAllowed: (() -> Void)? {
        store.canPlayAgain ? { playAgain() } : nil
    }

    /// The same seats, a new hand. The game that just ended still counts towards the ad
    /// pacing; it just had no exit to put an ad on.
    private func playAgain() {
        ads.countFinishedGame()
        store.playAgain()
    }

    private func double(_ amount: Denari, gameID: UUID) {
        guard !isDoubling else { return }
        isDoubling = true
        Task {
            defer { isDoubling = false }
            // Paid on the network's word that it was watched to the end, and keyed on the
            // game, so the same game can never be doubled twice however the taps land.
            guard await ads.watchRewarded() else { return }
            await purse.earnFromAd(amount, key: "double/\(gameID.uuidString)")
            withAnimation(.spring(duration: 0.45, bounce: 0.2)) {
                earnings.append(PayoutLine(id: "double", title: String(localized: "Watched an ad", locale: locale), value: amount))
                doubled = true
            }
            Audio.shared.play(.purchase)
        }
    }

    /// What the game paid. A wager table pays the pot and nothing else; the stake is
    /// already gone, so a loss is shown as the loss it was rather than as nothing.
    private func settle(_ tally: RewardTally, won: Bool, players: Int) async -> [PayoutLine] {
        guard let stake = store.stake else {
            return await purse.settle(tally).map { PayoutLine($0, locale: locale) }
        }
        if won, let pot = await purse.payOut(stake, players: players, gameID: store.wagerID) {
            return [PayoutLine(id: "pot", title: String(localized: "The pot", locale: locale), value: pot)]
        }
        if !won {
            return [PayoutLine(id: "stake", title: String(localized: "Stake lost", locale: locale), value: -stake.amount)]
        }
        return []
    }

    /// Who won the game, said to whoever is holding the phone.
    private func winnerHeadline(_ winner: Int, in view: PlayerView) -> String {
        // Ranked is told in the ladder's own words: what follows the headline there is a
        // league moving rather than a row of denari.
        if store.isRanked {
            return winner == view.mySide
                ? String(localized: "Victory", locale: locale)
                : String(localized: "Defeat", locale: locale)
        }
        if winner == view.mySide {
            return String(localized: view.configuration.teams ? "We win!" : "You win!", locale: locale)
        }
        return view.configuration.teams
            ? String(localized: "They win", locale: locale)
            : String(localized: "\(sideName(winner, in: view)) wins", locale: locale)
    }

    /// The margin over the bot, which is what today's deal is scored on. Level is a
    /// loss on the ladder, and the headline says so rather than calling it square.
    private func dailyHeadline(_ score: RoundScore, in view: PlayerView) -> String {
        let margin = (score.points[safe: 0] ?? 0) - (score.points[safe: 1] ?? 0)
        if margin > 0 { return String(localized: "You, by \(margin)", locale: locale) }
        if margin < 0 { return String(localized: "Hugo, by \(-margin)", locale: locale) }
        return String(localized: "Level, so Hugo", locale: locale)
    }

    /// Who came out ahead this round, said the way a person would say it.
    private func roundHeadline(_ score: RoundScore, in view: PlayerView) -> String {
        guard let best = score.points.max(), best > 0 else {
            return String(localized: "Nobody scored", locale: locale)
        }
        let leaders = score.points.indices.filter { score.points[$0] == best }
        guard leaders.count == 1, let side = leaders.first else {
            return String(localized: "All square", locale: locale)
        }
        if side == view.mySide {
            return String(localized: view.configuration.teams ? "We take the round" : "You take the round", locale: locale)
        }
        return view.configuration.teams
            ? String(localized: "They take the round", locale: locale)
            : String(localized: "\(sideName(side, in: view)) takes the round", locale: locale)
    }

    private func hintText(_ view: PlayerView) -> LocalizedStringKey {
        // The turn pill already names who is playing, so there is nothing to add.
        guard view.isMyTurn else { return " " }
        switch selection.action(in: view) {
        case .none: return "Tap a card, or swipe it up to play"
        case .lay:
            return selection.assist.highlightsCaptures ? "Nothing on the table matches it" : "Tap the cards to take, or play it down"
        case .chooseWhatToTake:
            return selection.assist.highlightsCaptures ? "Tap the outlined cards to take them" : "Tap the cards you want to take"
        case .notAllowed, .take: return "Swipe the card up, or use the button"
        }
    }
}

// MARK: - Pieces

extension String {
    /// A name cut short enough to sit inside a chip beside other things. Game Center display
    /// names have no length limit, and left whole one like "Massimiliano Bartolomeo" pushed
    /// the pile count off the end of the status row.
    func shortName(_ limit: Int = 12) -> String {
        guard count > limit else { return self }
        return prefix(limit).trimmingCharacters(in: .whitespaces) + "…"
    }
}
