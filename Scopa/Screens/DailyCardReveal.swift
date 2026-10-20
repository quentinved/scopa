import ScopaCore
import ScopaRewards
import SwiftUI

/// Today's card, turned over at the end of the deal: the last beat before the lobby.
///
/// The pack reveal's own stage, one card long. The card lands face down, gathers the light
/// of its rarity for as long as its `Fanfare` says, and goes over with its sparks. A suit it
/// finished follows, and a pack the run reached today comes last, to be opened in the album.
/// Everything shown was already in the album and the ledger before this appeared, except a
/// lost deal's card: that one waits face down while the player picks its odds, the loser's
/// or, for a video, the winner's, and is drawn then.
struct DailyCardReveal: View {
    @State private var gift: DailyGift
    /// The player's own name, for the mark a finished suit hands over.
    var name = "?"
    /// Back to the lobby, offered once everything is up.
    let done: () -> Void

    init(gift: DailyGift, name: String = "?", done: @escaping () -> Void) {
        _gift = State(initialValue: gift)
        self.name = name
        self.done = done
    }

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tableFelt) private var felt
    /// Absent in previews, where an undrawn card stays face down.
    @Environment(AdsStore.self) private var ads: AdsStore?
    @Environment(TableStore.self) private var store: TableStore?
    @Environment(PurseStore.self) private var purse: PurseStore?

    /// One thing to show: the card, a suit or the deck it finished, then the run's pack.
    private enum Step: Hashable {
        /// A lost deal's card, face down until its odds are picked.
        case undrawn
        case card(Album.Found)
        case finale(SuitFinale.Kind)
        case pack(PackTier)
    }

    @State private var place = 0
    @State private var faceUp = false
    @State private var turning: Task<Void, Never>?
    /// Drops a tap that lands while the card is still going over. See `RevealTaps`.
    @State private var taps = RevealTaps()
    /// Counted up to fire the white flash a seven or better goes over with.
    @State private var flares = 0
    /// The undrawn card's odds have been picked and it is being drawn, or its video played.
    @State private var isDrawing = false
    @State private var isWatching = false
    /// The last tap on the video found none to show.
    @State private var noVideo = false

    private var steps: [Step] {
        var steps: [Step] = []
        if gift.isUndrawn {
            steps.append(.undrawn)
        } else if let card = gift.card {
            steps += card.found.map(Step.card)
            steps += card.suits.map { .finale(.suit($0)) } + (card.deck ? [.finale(.deck)] : [])
        }
        if let pack = gift.pack { steps.append(.pack(pack)) }
        return steps
    }

    private var step: Step? { steps[safe: place] }
    private var isLast: Bool { place >= steps.count - 1 }
    private var volume: Volume { gift.card?.volume ?? .riviera }
    /// What the day's card did in Oro, or in Perla once Oro is full, when it came out foil.
    private var gold: Album.Found? { gift.card?.gilt.foil(at: 0) }
    private var foilAlbum: FoilAlbum { gift.card?.gilt.album ?? .oro }

    var body: some View {
        ZStack {
            wash
            dimmer
            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                ZStack { if let step { content(step) } }
                    .id(place)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.74).combined(with: .opacity),
                        removal: .offset(y: -70).combined(with: .opacity)))
                Spacer(minLength: 0)
                footer
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            flare
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TableGround())
        .contentShape(.rect)
        .onTapGesture(perform: advance)
        .sensoryFeedback(trigger: faceUp) { _, up in up ? turnFeedback : nil }
        .environment(\.cardTheme, volume.theme)
        .task { start() }
        .onDisappear { turning?.cancel() }
    }

    // MARK: Words

    private var header: some View {
        VStack(spacing: 6) {
            Text(caption)
                .font(.system(size: 12, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Palette.onTableSoft)
            Text(line)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.onTable)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
    }

    private var caption: LocalizedStringKey {
        if case .pack = step { return "\(gift.days) days in a row" }
        return "Today's card"
    }

    /// The rule the card was handed over by, so the reveal teaches it as it pays it.
    private var line: LocalizedStringKey {
        if case .pack = step { return "Every seventh day in a row brings a pack" }
        if step == .undrawn {
            return "Hugo won this one, so the card comes at \(DailyCard.odds(won: false).title) odds. A short ad brings a winner's."
        }
        if gift.watchedFor { return "Watched for: \(DailyCard.odds(won: true).title) odds, as if you had won" }
        return gift.won
            ? "Beat Hugo and the card comes at \(DailyCard.odds(won: true).title) odds"
            : "Every deal you finish puts a card in your album"
    }

    @ViewBuilder private var footer: some View {
        if step == .undrawn {
            choice
        } else if isLast, faceUp {
            // A double tap that turned the last card over does not also leave.
            Button { if taps.isOpen { done() } } label: {
                Text("Back to the lobby")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background { Capsule().fill(Palette.goldSheen) }
                    .foregroundStyle(Palette.ink)
            }
            .buttonStyle(.plain)
            .transition(.opacity)
        } else {
            Text(faceUp ? "Tap for the next one" : "Tap to turn it over")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.onTableSoft.opacity(0.8))
                .frame(height: 50)
        }
    }

    // MARK: What is in the middle

    @ViewBuilder private func content(_ step: Step) -> some View {
        switch step {
        case .undrawn: undrawnStage
        case .card(let found): cardStage(found)
        case .finale(let kind):
            SuitFinale(kind: kind, volume: volume, name: name, crowned: faceUp,
                       note: kind == .deck ? PackOpening.prizeNote(for: volume, locale: locale) : nil)
        case .pack(let tier): DailyPackStage(tier: tier, isUp: faceUp)
        }
    }

    /// The card face down until it goes over, its rarity and what it was under it.
    private func cardStage(_ found: Album.Found) -> some View {
        let rarity = found.card.rarity
        return VStack(spacing: 18) {
            RevealStage(fanfare: Fanfare(rarity, foil: gold != nil),
                        tint: gold == nil ? Rarities.tint(rarity) : foilAlbum.tint, faceUp: faceUp,
                        isNew: found.isNew, rays: 0, width: 168, radius: 168 * 0.09) {
                CardView(card: found.card, width: 168)
                    .foil(gold != nil, in: foilAlbum)
                    .shadow(color: felt.shade(0.5), radius: 22, y: 12)
                    .overlay(alignment: .topLeading) {
                        if gold != nil, faceUp {
                            OroStamp(afterNew: found.isNew, album: foilAlbum).offset(x: -20, y: -14)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if found.isNew, faceUp {
                            NewStamp(sound: found.card == .settebello ? .play : .purchase)
                                .offset(x: 20, y: -14)
                        }
                    }
            } back: {
                CardBack(width: 168)
                    .shadow(color: felt.shade(0.5), radius: 22, y: 12)
            }
            .rotation3DEffect(.degrees(reduceMotion ? 0 : 8), axis: (x: 1, y: -0.4, z: 0))
            .frame(height: 330)
            VStack(spacing: 10) {
                RarityTag(rarity, locale: locale, size: 12, filled: rarity > .plain)
                foundLine(found)
                if let gold { OroFoundLine(found: gold, album: foilAlbum) }
            }
            .opacity(faceUp ? 1 : 0)
            .offset(y: faceUp ? 0 : 10)
        }
    }

    /// The lost deal's card, face down, over what the video would change.
    private var undrawnStage: some View {
        VStack(spacing: 18) {
            CardBack(width: 168)
                .shadow(color: felt.shade(0.5), radius: 22, y: 12)
                .rotation3DEffect(.degrees(reduceMotion ? 0 : 8), axis: (x: 1, y: -0.4, z: 0))
                .frame(height: 330)
            oddsLine
        }
    }

    /// How often the card is a court or better at each odds, worked out for the volume it
    /// goes into rather than printed, since later volumes hold their good cards back harder.
    private var oddsLine: some View {
        let volume = store?.albumBook.openVolume ?? .riviera
        let now = DailyCard.chance(ofAtLeast: .court, won: false, volume: volume)
        let watched = DailyCard.chance(ofAtLeast: .court, won: true, volume: volume)
        return HStack(spacing: 7) {
            Text("A court or better")
                .foregroundStyle(Palette.onTableSoft)
            Text(verbatim: percent(now))
                .foregroundStyle(Palette.onTable)
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.onTableSoft)
            Text(verbatim: percent(watched))
                .fontWeight(.bold)
                .foregroundStyle(Palette.goldLight)
        }
        .font(.system(size: 14, weight: .medium))
        .monospacedDigit()
    }

    private func percent(_ chance: Double) -> String {
        chance.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    /// The two ways to turn the lost deal's card over. A tap on the cloth does neither, so the
    /// better odds are never thrown away by a stray touch.
    private var choice: some View {
        VStack(spacing: 6) {
            Button { choose(watching: true) } label: {
                HStack(spacing: 8) {
                    if isWatching {
                        ProgressView().tint(Palette.ink)
                    } else {
                        Image(systemName: "play.rectangle.fill")
                    }
                    Text("Watch an ad for \(DailyCard.odds(won: true).title) odds")
                }
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background { Capsule().fill(Palette.goldSheen) }
                .foregroundStyle(Palette.ink)
            }
            .buttonStyle(.plain)
            Button { choose(watching: false) } label: {
                Text(noVideo ? "No video right now. Turn it over as it is"
                     : "Turn it over at \(DailyCard.odds(won: false).title) odds")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.onTableSoft)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .disabled(isDrawing)
        .animation(.easeInOut(duration: 0.2), value: noVideo)
    }

    /// Missing until now, or a spare and what it paid, as a pack says it.
    @ViewBuilder private func foundLine(_ found: Album.Found) -> some View {
        switch found {
        case .new:
            Text("New in the album")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(Palette.goldLight)
        case .spare(_, let paid):
            HStack(spacing: 6) {
                Text("Already had it").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.onTableSoft)
                DenariMark(size: 14)
                Text(verbatim: "+\(paid.coins)")
                    .font(.system(size: 15, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.goldLight)
            }
        }
    }

    // MARK: The room

    /// A wash of the step's colour behind everything, a little brighter once it is up.
    private var wash: some View {
        RadialGradient(colors: [tint.opacity(faceUp ? 0.2 : 0.12), .clear],
                       center: .center, startRadius: 0, endRadius: 420)
            .ignoresSafeArea()
            .animation(.easeOut(duration: 0.6), value: faceUp)
    }

    private var tint: Color {
        switch step {
        case .card where gold != nil: foilAlbum.tint
        case .card(let found) where found.card.rarity > .plain: Rarities.tint(found.card.rarity)
        case .pack(let tier): PackLook.accent(tier)
        default: Palette.goldLight
        }
    }

    /// The room darkens round a seven and the settebello while they wait face down.
    private var dimmer: some View {
        Color.black
            .opacity(faceUp ? 0 : fanfare(at: place) == .crowning ? 0.5 : fanfare(at: place) == .grand ? 0.22 : 0)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .animation(faceUp ? .easeOut(duration: 0.35) : .easeIn(duration: 0.9), value: faceUp)
    }

    /// White across the screen as a seven or better goes over.
    private var flare: some View {
        Color.white
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .keyframeAnimator(initialValue: 0.0, trigger: flares) { view, value in
                view.opacity(value)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(0.55, duration: 0.05)
                    CubicKeyframe(0, duration: 0.6)
                }
            }
    }

    // MARK: Moving it along

    /// A tap turns the thing in the middle over, or brings the next one once it has landed.
    /// Leaving is the button's alone, so a tap through the reveal never lands on an ad.
    private func advance() {
        guard taps.isOpen, step != .undrawn else { return }
        if !faceUp { turnOver() } else if !isLast { show(place + 1) }
    }

    /// Draws the lost deal's card at the odds picked, after the video when that was the pick,
    /// and sets it going the way a drawn card does. A day paid meanwhile, here or on another
    /// phone, has no card left to draw, so the reveal moves on to what remains.
    private func choose(watching: Bool) {
        guard !isDrawing, let store, let purse else { return }
        isDrawing = true
        isWatching = watching
        noVideo = false
        Task {
            defer { isDrawing = false; isWatching = false }
            if watching {
                switch await ads?.watchRewarded(.dailyCard) ?? .unavailable {
                case .watched: break
                case .unavailable: noVideo = true; return
                case .closedEarly: return
                }
            }
            // The debug reveal has no day in the ledger to draw against.
            let drawn = gift.day == nil ? DebugLaunch.drawnSample(gift, watched: watching)
                : await DailyCardPayout.draw(gift, watched: watching, store: store, purse: purse)
            guard let drawn else {
                gift.isUndrawn = false
                return steps.isEmpty ? done() : show(0)
            }
            gift = drawn
            show(0, after: .milliseconds(300))
        }
    }

    private func start() {
        // Face down until the player picks its odds: nothing turns it over by itself.
        if gift.isUndrawn {
            ads?.prepareReward(.dailyCard)
            return
        }
        if DebugLaunch.dailyStartsOnPack, let at = steps.lastIndex(where: Self.isPack) {
            place = at
            faceUp = true
            return
        }
        show(0, after: .milliseconds(500))
    }

    nonisolated private static func isPack(_ step: Step) -> Bool {
        if case .pack = step { true } else { false }
    }

    /// Puts the next thing down face down and sets it going over once it has waited, the
    /// way a pack's cards do. The first waits a beat longer, to be seen landing.
    private func show(_ next: Int, after landing: Duration = .zero) {
        turning?.cancel()
        faceUp = false
        taps.moved()
        withAnimation(.spring(duration: 0.42, bounce: 0.22)) { place = next }
        Audio.shared.play(.pick)
        let fanfare = fanfare(at: next)
        let lead: Duration = fanfare == .crowning && !reduceMotion ? .milliseconds(700) : .zero
        turning = Task {
            try? await Task.sleep(for: landing + lead)
            guard !Task.isCancelled else { return }
            if fanfare >= .grand, !reduceMotion { Audio.shared.play(.rise) }
            try? await Task.sleep(for: fanfare.gathering - lead)
            guard !Task.isCancelled else { return }
            turnOver()
        }
    }

    private func turnOver() {
        guard !faceUp, step != nil, step != .undrawn else { return }
        turning?.cancel()
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.55, bounce: 0.3)) {
            faceUp = true
        }
        taps.turned(reduceMotion: reduceMotion)
        say()
        if fanfare(at: place) >= .grand { flares += 1 }
    }

    /// The sound it makes going over, the pack's own: glitter from a court up, the
    /// settebello's chime, the till for a spare.
    private func say() {
        if fanfare(at: place) > .quiet { Audio.shared.play(.shine) }
        switch step {
        case .card(let found) where found.card == .settebello: Audio.shared.play(.settebello)
        case .card(let found) where found.isNew:
            if found.card.rarity == .plain { Audio.shared.play(.play) }
        case .card: Audio.shared.play(.denaro)
        case .finale, .pack: Audio.shared.play(.purchase)
        case .undrawn, nil: break
        }
    }

    private func fanfare(at index: Int) -> Fanfare {
        switch steps[safe: index] {
        case .undrawn: .quiet
        case .card(let found): Fanfare(found.card.rarity, foil: gold != nil)
        case .finale: .crowning
        case .pack: .bright
        case nil: .quiet
        }
    }

    private var turnFeedback: SensoryFeedback? {
        switch fanfare(at: place) {
        case .quiet: Haptic.turn
        case .bright: Haptic.flip
        case .grand: Haptic.prize
        case .crowning: Haptic.settebello
        }
    }
}
