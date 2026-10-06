import ScopaRewards
import SwiftUI

/// The day's wheel: one free turn, a few seconds of brass studs clicking under the pointer,
/// then the prize, one more turn for a video, and the hours until the next one.
struct DailyWheelSheet: View {
    let wheel: DailyWheel
    let purse: PurseStore
    let ads: AdsStore
    let book: AlbumBook
    let name: String
    let day: String

    private enum Phase: Equatable {
        case ready
        case spinning
        case won(DailyWheel.Spin)
        /// Spent on another device, so there is no prize here to show.
        case taken
    }

    /// One turn of the wheel in flight, eased out from `from` to `to`.
    private struct Turn: Equatable {
        let start: Date
        let from: Double
        let to: Double
        let duration: Double
    }

    @State private var phase: Phase
    @State private var rest: Double
    @State private var turn: Turn?
    @State private var ticks = 0
    @State private var landed = 0
    /// True only for a prize won with the sheet open, which is the one that gets the sparks.
    @State private var isFresh = false
    @State private var bursts = 0
    @State private var showsOdds = false
    /// Other players' turns, once the Worker has answered.
    @State private var strip: Ladder.WheelStrip?
    @State private var isWatching = false
    /// The last video asked for never came.
    @State private var noVideo = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let size: CGFloat = 316
    private static var slice: Double { 360 / Double(DailyWheel.segments.count) }

    init(wheel: DailyWheel, purse: PurseStore, ads: AdsStore, book: AlbumBook, name: String, day: String) {
        self.wheel = wheel
        self.purse = purse
        self.ads = ads
        self.book = book
        self.name = name
        self.day = day
        let spin = wheel.spin(on: day)
        let isAvailable = wheel.isAvailable(on: day, paid: purse.purse.keys)
        _phase = State(initialValue: spin.map(Phase.won) ?? (isAvailable ? .ready : .taken))
        _rest = State(initialValue: spin.map { -Double($0.segment) * Self.slice } ?? 0)
    }

    var body: some View {
        SheetScaffold(title: "The wheel", subtitle: "One free turn every day.",
                      close: phase == .spinning ? nil : { dismiss() }) {
            VStack(spacing: 22) {
                stage
                footer
                if let strip, !strip.isEmpty {
                    WheelStripView(strip: strip)
                        .transition(.opacity)
                }
                odds
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .interactiveDismissDisabled(phase == .spinning)
        .sensoryFeedback(.selection, trigger: ticks)
        .sensoryFeedback(Haptic.prize, trigger: landed)
        .task { await turnForDebugging() }
        .task { ads.prepareReward() }
        .task {
            let found = await WheelTurns.today()
            withAnimation(.easeOut(duration: 0.3)) { strip = found }
        }
    }

    // MARK: The wheel

    private var stage: some View {
        ZStack(alignment: .top) {
            // Under the wheel rather than on it, so the shadow stays put while it turns.
            Circle()
                .fill(Palette.ink.opacity(0.4))
                .frame(width: Self.size, height: Self.size)
                .blur(radius: 10)
                .offset(y: 22)
            TimelineView(.animation(paused: turn == nil)) { context in
                WheelFace(size: Self.size)
                    .rotationEffect(.degrees(angle(at: context.date)))
            }
            .padding(.top, 16)
            pointer
        }
        .frame(maxWidth: .infinity)
        .overlay { sparks }
        .accessibilityElement()
        .accessibilityLabel(Text("The wheel"))
    }

    /// Flicked back by each stud and swung home on a spring, one stud at a time.
    private var pointer: some View {
        WheelPointer(width: 34)
            .keyframeAnimator(initialValue: 0.0, trigger: ticks) { content, tilt in
                content.rotationEffect(.degrees(tilt), anchor: UnitPoint(x: 0.5, y: 0.34))
            } keyframes: { _ in
                CubicKeyframe(-18, duration: 0.035)
                SpringKeyframe(0, duration: 0.3, spring: .bouncy)
            }
    }

    /// Two bursts of gold for the big one, the second a beat behind the first.
    @ViewBuilder private var sparks: some View {
        if isFresh, case .won(let spin) = phase, spin.isJackpot {
            ZStack {
                MetalSparks(metal: .gold, origin: UnitPoint(x: 0.5, y: 0.5), count: 40, reach: 0.75)
                    .id("first-\(bursts)")
                if bursts > 1 {
                    MetalSparks(metal: .gold, origin: UnitPoint(x: 0.5, y: 0.08), count: 30, reach: 0.6)
                        .id("second-\(bursts)")
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func angle(at date: Date) -> Double {
        guard let turn else { return rest }
        let progress = min(max(date.timeIntervalSince(turn.start) / turn.duration, 0), 1)
        return turn.from + (turn.to - turn.from) * Self.ease(progress)
    }

    /// Quartic ease-out: a hard throw, and a long slow last turn.
    private static func ease(_ t: Double) -> Double { 1 - pow(1 - t, 4) }
    private static func uneased(_ p: Double) -> Double { 1 - pow(1 - p, 0.25) }

    // MARK: Turning

    private func start() {
        guard phase == .ready else { return }
        turn(.free)
    }

    private func turn(_ ticket: DailyWheel.Ticket) {
        phase = .spinning
        Audio.shared.play(.tap)
        Task {
            guard let spin = await wheel.take(ticket, on: day, purse: purse, book: book) else {
                withAnimation { phase = .taken }
                return
            }
            await roll(to: spin)
        }
    }

    /// Five turns and the way round to the prize, landing somewhere inside its slice rather
    /// than dead on its middle.
    private func roll(to spin: DailyWheel.Spin) async {
        let jitter = Double.random(in: -Self.slice * 0.36...Self.slice * 0.36)
        let target = -Double(spin.segment) * Self.slice + jitter
        let delta = (target - rest).truncatingRemainder(dividingBy: 360)
        let to = rest + 360 * (reduceMotion ? 1 : 5) + (delta < 0 ? delta + 360 : delta)
        let duration = reduceMotion ? 1.6 : 4.2
        let clock = ContinuousClock()
        let began = clock.now
        turn = Turn(start: .now, from: rest, to: to, duration: duration)
        for time in tickTimes(from: rest, to: to, duration: duration) {
            try? await clock.sleep(until: began + .seconds(time))
            ticks += 1
            Audio.shared.play(.tap, gain: 0.55)
        }
        try? await clock.sleep(until: began + .seconds(duration))
        rest = to
        turn = nil
        reveal(spin)
    }

    /// When each stud passes under the pointer, thinned so the fast first turns are a rattle
    /// rather than a buzz.
    private func tickTimes(from: Double, to: Double, duration: Double) -> [Double] {
        let half = Self.slice / 2
        var crossing = (((from + half) / Self.slice).rounded(.up)) * Self.slice - half
        var times: [Double] = []
        while crossing < to {
            let time = Self.uneased((crossing - from) / (to - from)) * duration
            if time - (times.last ?? -1) >= 0.075 { times.append(time) }
            crossing += Self.slice
        }
        return times
    }

    /// Turns again once the network says the video was watched to the end.
    private func watchForTurn() {
        guard !isWatching, phase != .spinning else { return }
        isWatching = true
        noVideo = false
        Task {
            defer { isWatching = false }
            switch await ads.watchRewarded() {
            case .watched: turn(.video)
            case .unavailable: noVideo = true
            case .closedEarly: break
            }
        }
    }

    private func reveal(_ spin: DailyWheel.Spin) {
        isFresh = true
        landed += 1
        withAnimation(.spring(duration: 0.55, bounce: 0.28)) { phase = .won(spin) }
        guard spin.isJackpot else {
            Audio.shared.play(spin.denari.isCredit && spin.item == nil && spin.tiers.isEmpty ? .denaro : .purchase)
            return
        }
        Audio.shared.play(.victory)
        bursts = 1
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            bursts = 2
            Audio.shared.play(.cheerOro, gain: 0.8)
        }
    }

    /// `-wheelWin` turns the wheel by itself, so the landing can be screenshotted.
    private func turnForDebugging() async {
        guard DebugLaunch.wheelOutcome != nil, phase == .ready else { return }
        try? await Task.sleep(for: .milliseconds(250))
        start()
    }

    // MARK: Under the wheel

    @ViewBuilder private var footer: some View {
        switch phase {
        case .ready, .spinning:
            VStack(spacing: 10) {
                Button("Turn the wheel", action: start)
                    .buttonStyle(FilledButtonStyle())
                    .disabled(phase == .spinning)
                    .opacity(phase == .spinning ? 0.55 : 1)
                SheetNote("A new turn every day at midnight.")
            }
        case .won(let spin):
            VStack(spacing: 18) {
                WheelPrize(spin: spin, name: name)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                videoTurn
                comeBack
            }
        case .taken:
            VStack(spacing: 10) {
                Text("Today's turn has been taken.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.onTable)
                videoTurn
                comeBack
            }
        }
    }

    /// One more turn for a video, once a day, after the free one.
    @ViewBuilder private var videoTurn: some View {
        if ads.adsAreOn, wheel.isVideoAvailable(on: day, paid: purse.purse.keys) {
            VStack(spacing: 8) {
                Button(action: watchForTurn) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.rectangle")
                            .font(.system(size: 22))
                            .foregroundStyle(Palette.goldLight)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("One more turn")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Palette.onTable)
                            Text("Watch a short ad")
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.onTableSoft)
                        }
                        Spacer(minLength: 0)
                        if isWatching { ProgressView().tint(Palette.goldLight) }
                    }
                    .padding(14)
                    .glassPanel(radius: GlassRadius.control, interactive: true)
                }
                .buttonStyle(.plain)
                .disabled(isWatching)
                if noVideo {
                    SheetNote("No video to show right now. Try again in a little while.")
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: noVideo)
            .transition(.opacity)
        }
    }

    private var comeBack: some View {
        VStack(spacing: 4) {
            Text("Come back tomorrow")
                .font(.display(24))
                .foregroundStyle(Palette.onTable)
            Text("Next turn in \(Text(timerInterval: Date.now...DailyWheel.nextTurn(), countsDown: true))")
                .font(.system(size: 14, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Palette.onTableSoft)
        }
    }

    private var odds: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.snappy) { showsOdds.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Text("The odds")
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(showsOdds ? 180 : 0))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            if showsOdds {
                WheelOdds()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

/// What the wheel landed on, at the size of a reward.
private struct WheelPrize: View {
    let spin: DailyWheel.Spin
    let name: String

    var body: some View {
        VStack(spacing: 12) {
            if spin.isJackpot {
                // The house voice, not gilt lettering: the gold is in the strongbox and the coin.
                Text(verbatim: "Gran premio!")
                    .font(.display(44))
                    .foregroundStyle(Palette.onTable)
            } else {
                Text("Today's prize")
                    .font(.system(size: 12, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(Palette.goldLight)
            }
            prize
        }
    }

    @ViewBuilder private var prize: some View {
        if let item = spin.item.flatMap({ Cosmetics.catalogue[$0] }) {
            WonItemCard(item: item, name: name)
            SheetNote("Yours now, in the shop.")
        } else if spin.isJackpot {
            HStack(spacing: 18) {
                PackArt(tier: DailyWheel.jackpotPack, width: 50)
                DenariLabel(amount: spin.denari, size: 34, weight: .bold, tint: Palette.goldLight, signed: true)
            }
            SheetNote("The Forziere is waiting for you in the shop.")
        } else if let tier = spin.tiers.first {
            PackArt(tier: tier, width: 74)
            Text("\(tier.title) pack")
                .font(.display(26))
                .foregroundStyle(Palette.onTable)
            SheetNote(tier.shelf.waitsIn)
        } else {
            DenariLabel(amount: spin.denari, size: 38, weight: .bold, tint: Palette.goldLight, signed: true)
            if spin.prize == .shelf {
                SheetNote("You own everything on that shelf, so it paid in denari.")
            }
        }
    }
}

/// Every prize the wheel holds and how often it lands there, so the odds are never a secret.
private struct WheelOdds: View {
    @Environment(\.locale) private var locale

    /// Each prize once, in the order the wheel shows it, its slices' chances added up.
    private var rows: [(prize: DailyWheel.Prize, chance: Double)] {
        var rows: [(prize: DailyWheel.Prize, chance: Double)] = []
        for index in DailyWheel.segments.indices {
            let prize = DailyWheel.segments[index].prize
            if let at = rows.firstIndex(where: { $0.prize == prize }) {
                rows[at].chance += DailyWheel.chance(of: index)
            } else {
                rows.append((prize, DailyWheel.chance(of: index)))
            }
        }
        return rows.sorted { $0.chance > $1.chance }
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows.indices, id: \.self) { index in
                HStack {
                    label(rows[index].prize)
                    Spacer(minLength: 8)
                    Text(rows[index].chance.formatted(.percent.precision(.fractionLength(0)).locale(locale)))
                        .font(.system(size: 14, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.onTable)
                }
            }
        }
        .padding(16)
        .glassPanel(radius: GlassRadius.control)
    }

    @ViewBuilder private func label(_ prize: DailyWheel.Prize) -> some View {
        switch prize {
        case .denari(let amount):
            DenariLabel(amount: amount, size: 14)
        case .pack(let tier):
            Text("\(tier.title) pack").oddsLine
        case .shelf:
            Text("Something from the shop").oddsLine
        case .jackpot:
            Text("Gran premio: \(DailyWheel.jackpotDenari.coins) denari and a \(DailyWheel.jackpotPack.title)").oddsLine
        }
    }
}

private extension Text {
    var oddsLine: some View {
        font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.onTable)
    }
}

/// The lobby's way in: the wheel in a glass coin, with a dot while today's turn is waiting.
struct WheelChip: View {
    let isWaiting: Bool
    let action: () -> Void

    @Environment(\.lift) private var lift
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// A single quarter turn a moment after the lobby lands, while the turn is waiting.
    @State private var nudged = false

    var body: some View {
        Button(action: action) {
            WheelGlyph(size: 24 * lift)
                .rotationEffect(.degrees(nudged ? 72 : 0))
                .frame(width: 38 * lift, height: 38 * lift)
                .glass(.riviera(interactive: true), in: .circle)
                .contentShape(.circle)
                .overlay(alignment: .topTrailing) { if isWaiting { dot } }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("The wheel"))
        .task(id: isWaiting) { await nudge() }
    }

    private var dot: some View {
        Circle()
            .fill(Palette.terracotta)
            .overlay { Circle().strokeBorder(Palette.cream.opacity(0.9), lineWidth: 1.2) }
            .frame(width: 11 * lift, height: 11 * lift)
            .offset(x: 1 * lift, y: -1 * lift)
            .transition(.scale(scale: 0.4).combined(with: .opacity))
    }

    private func nudge() async {
        guard isWaiting, !reduceMotion, !nudged else { return }
        try? await Task.sleep(for: .seconds(1.2))
        withAnimation(.spring(duration: 1.1, bounce: 0.25)) { nudged = true }
    }
}
