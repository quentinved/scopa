import ScopaCore
import ScopaRewards
import SwiftUI

/// Opening a pack, in the middle of the screen and nowhere else.
///
/// It was three small backs in a row that turned over on a timer, which told you what you
/// had got without ever letting you get it. This is the same information as an act: the
/// sealed pack is in your hands and does not open until you tear it, the cards come off the
/// top one at a time and each one is the only thing on screen while it is there, and the
/// best card in the pack is kept for last.
///
/// It takes both shelves. A pack off the album is cards with something for the table
/// behind them; a pack off the shop is all table and no cards, and turns over the same way
/// with the card half of it simply empty.
///
/// Nothing here can go wrong. Everything the pack did — a card that was missing, a spare
/// paid for, a felt off the shelves, a suit finished — was decided before this view
/// existed. It is paced rather than computed, which is what lets a tap take the rest of it
/// at once for anyone who would rather just know.
struct PackOpening: View {
    let opening: AlbumBook.Opening
    /// The player's own name, for previewing a mark or a colour they have just won.
    var name = "?"

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Where the opening has got to. It only ever moves forwards.
    private enum Act: Equatable {
        /// The pack, sealed, waiting to be torn.
        case sealed
        /// The wrapper coming apart. Half a second, and then the cards.
        case tearing
        /// Turning them over, `place` of them done.
        case turning(place: Int)
        /// Everything it came to.
        case counted
    }

    @State private var act: Act = .sealed
    /// How far the pack has been dragged open, 0 to 1.
    @State private var pull: CGFloat = 0
    /// Whether the thing in the middle has gone over yet. Each one lands face down and
    /// waits as long as its fanfare says, or until a tap hurries it.
    @State private var faceUp = false
    @State private var turning: Task<Void, Never>?
    /// Counted up to fire the room's own flash and shake, which belong to the screen and
    /// not to the card.
    @State private var flares = 0
    @State private var shakes = 0
    /// The pack has been torn, and what is best inside it is showing through the tear.
    @State private var torn = false

    /// The cards in the order they are shown, which is not the order they were drawn.
    ///
    /// Sorted worst first, so a pack ends on its best card. The draw is already done and
    /// the album has already been written; this is the running order of a reveal, and a
    /// reveal that puts the settebello first and two numerals after it is a reveal that
    /// ends on two numerals.
    private var running: [Album.Found] {
        opening.found.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.card.rarity != rhs.element.card.rarity {
                    return lhs.element.card.rarity < rhs.element.card.rarity
                }
                // New before spare at the same rarity, and otherwise the drawn order, so
                // the sort is total and two runs of the same pack read identically.
                if lhs.element.isNew != rhs.element.isNew { return !lhs.element.isNew }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    /// One thing to turn over: a card, something off the shelves, or — once everything
    /// is up — a suit or the whole deck finished by this pack.
    private enum Step {
        case card(Album.Found)
        case won(AlbumBook.Won)
        case finale(SuitFinale.Kind)
    }

    /// The cards, then anything off the shelves, then what they finished.
    private var sequence: [Step] {
        running.map(Step.card) + opening.won.map(Step.won)
            + opening.suits.map { .finale(.suit($0)) } + (opening.deck ? [.finale(.deck)] : [])
    }

    private var steps: Int { sequence.count }

    private func step(at place: Int) -> Step { sequence[place] }

    /// The cloth under it, so what it drops is the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        ZStack {
            ground
            dimmer
            content
                .keyframeAnimator(initialValue: CGFloat.zero, trigger: shakes) { view, x in
                    view.offset(x: x)
                } keyframes: { _ in Self.shake }
            if torn, best > .quiet { tearLight }
            skipHint
            flare
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TableGround())
        .contentShape(.rect)
        .onTapGesture(perform: advance)
        .sensoryFeedback(trigger: act) { _, act in feedback(for: act) }
        .sensoryFeedback(trigger: faceUp) { _, up in up ? turnFeedback : nil }
        .statusBarHidden()
        .task { jump() }
        .task { await autoplay() }
    }

    // MARK: The room

    /// A wash of the pack's own colour behind everything, so a reliquia does not open on
    /// the same green a mazzetto does.
    private var ground: some View {
        RadialGradient(colors: [groundTint.opacity(glow), .clear],
                       center: .center, startRadius: 0, endRadius: 420)
            .ignoresSafeArea()
            .animation(.easeOut(duration: 0.6), value: act)
    }

    /// The pack's colour, except through the tear: what comes out of it first is the
    /// light of the best card inside, so a gold tear means a gold card.
    private var groundTint: Color {
        act == .tearing && best > .quiet ? bestTint : PackLook.accent(opening.tier)
    }

    private var glow: Double {
        switch act {
        case .sealed: 0.10
        case .tearing: best >= .grand ? 0.42 : 0.26
        case .turning: 0.18
        case .counted: 0.12
        }
    }

    @ViewBuilder private var content: some View {
        switch act {
        case .sealed, .tearing:
            sealedPack
        case .turning(let place):
            reveal(at: place)
        case .counted:
            tally
        }
    }

    // MARK: Sealed

    /// The pack itself, in the middle, breathing. Dragging up peels the crimped end; let
    /// go past a third of the way and it tears.
    private var sealedPack: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)
            AmbientClock { time in breathe(sealedHalves, at: time) }
            .animation(.spring(duration: 0.55, bounce: 0.35), value: pull)
            .animation(.easeIn(duration: 0.45), value: act)
            .gesture(tear)
            VStack(spacing: 6) {
                Text(verbatim: opening.tier.title)
                    .font(.display(30))
                    .foregroundStyle(Palette.onTable)
                Text("Pull the top off")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.onTableSoft)
                AmbientClock { time in
                    Image(systemName: "chevron.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.onTableSoft)
                        .offset(y: 2 - 6 * breath(at: time))
                }
            }
            .opacity(act == .tearing ? 0 : 1)
            Spacer(minLength: 0)
        }
        .padding(30)
    }

    /// The sealed pack's nudge, so it reads as something you can take hold of: in and out
    /// over 1.9 seconds each way on the ambient clock, and still once it is torn or under
    /// Reduce Motion. 0 is out, 1 is in.
    private func breath(at time: TimeInterval) -> CGFloat {
        guard act == .sealed else { return 0 }
        let along = time.cycle(of: 3.8) * 2
        return CGFloat(UnitCurve.easeInOut.value(at: along <= 1 ? along : 2 - along))
    }

    private func breathe(_ pack: some View, at time: TimeInterval) -> some View {
        let breath = breath(at: time)
        return pack
            .scaleEffect(1 + 0.02 * breath)
            .rotationEffect(.degrees(-1.1 + 2.2 * breath))
    }

    private var sealedHalves: some View {
        ZStack {
            // One pack drawn twice and masked along its own serrated line: the body
            // below it, which stays put, and the end above it, which comes away in
            // your hand. Two copies rather than one view with a moving mask, because
            // the two halves have to travel independently once it is torn.
            packHalf(.bottom)
                .scaleEffect(act == .tearing ? 0.9 : 1)
                .opacity(act == .tearing ? 0 : 1)
            packHalf(.top)
                .offset(y: act == .tearing ? -520 : -pull * 44)
                .rotationEffect(.degrees(act == .tearing ? -24 : Double(pull) * -5),
                                anchor: .bottomTrailing)
                .opacity(act == .tearing ? 0 : 1)
        }
    }

    /// One half of the sealed pack, masked along the line it tears on. `alignment` picks
    /// which half: `.top` is the end that comes off, `.bottom` is what is left in the hand.
    private func packHalf(_ edge: Alignment) -> some View {
        let size = PackArt.footprint(opening.tier, width: Self.packWidth)
        // The tear line is a fraction of the pack's own height, and the footprint adds
        // padding above it for the rays, so the cut runs that much further down the box.
        let above = (size.height - Self.packWidth * 1.42) / 2 + Self.packWidth * 1.42 * PackArt.tearLine
        // Both halves shimmer. One alive and one not put a seam across the pack exactly
        // where the two copies meet, which is the one place a seam must not be.
        // The mask only cuts along the tear. Everywhere else it runs well past the pack's
        // box, because the art does too: a fitted mask sliced the fanned back card of a
        // mazzetto down one side and the rays of a reliquia flat along the top, until the
        // tear swapped in the unmasked pack and they reappeared.
        let spill = Self.packWidth
        return PackArt(tier: opening.tier, width: Self.packWidth, alive: true)
            .mask(alignment: edge) {
                Rectangle()
                    .frame(width: size.width + spill * 2,
                           height: (edge == .top ? above : size.height - above) + spill)
                    .offset(y: edge == .top ? -spill : spill)
            }
            .frame(width: size.width, height: size.height)
    }

    private static let packWidth: CGFloat = 190

    private var tear: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard act == .sealed else { return }
                pull = min(max(-value.translation.height / 90, 0), 1)
            }
            .onEnded { _ in
                guard act == .sealed else { return }
                if pull > 0.34 { open() } else { pull = 0 }
            }
    }

    private func open() {
        withAnimation(.easeIn(duration: 0.4)) { act = .tearing }
        torn = true
        Audio.shared.play(.deal)
        Task {
            try? await Task.sleep(for: .milliseconds(best >= .grand ? 560 : 420))
            guard !Task.isCancelled else { return }
            show(0)
        }
    }

    /// Sparks out of the tear, in the colour of the best thing in the pack. Nothing for a
    /// pack of numerals: a pack of numerals should open like one.
    private var tearLight: some View {
        SparkBurst(sparks: best.sparks / 2, coins: best.coins / 3,
                   palette: [bestTint, .white, bestTint], force: 300, seed: 7)
            .offset(y: -125)
    }

    // MARK: Turning them over

    /// One thing at a time in the middle, with what is left of the pack stacked behind it
    /// and what has already been turned over stacked below.
    private func reveal(at place: Int) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack {
                switch step(at: place) {
                case .card(let found): foundCard(found, place: place)
                case .won(let won): wonTile(won)
                case .finale(let kind):
                    SuitFinale(kind: kind, volume: opening.volume, name: name, crowned: faceUp,
                               note: kind == .deck ? prizeNote : nil)
                }
            }
            .id(place)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.74).combined(with: .opacity),
                removal: .offset(y: -70).combined(with: .opacity)))
            Spacer(minLength: 0)
            progress(at: place)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
    }

    /// A card, face down until it goes over, with its rarity behind it and what it was
    /// under it.
    private func foundCard(_ found: Album.Found, place: Int) -> some View {
        let rarity = found.card.rarity
        return VStack(spacing: 18) {
            RevealStage(fanfare: Fanfare(rarity), tint: Rarities.tint(rarity), faceUp: faceUp,
                        isNew: found.isNew, rays: Rarities.rays(rarity), width: 168,
                        radius: 168 * 0.09) {
                cardFace(found)
            } back: {
                CardBack(width: 168)
                    .shadow(color: felt.shade(0.5), radius: 22, y: 12)
            }
            .rotation3DEffect(.degrees(reduceMotion ? 0 : 8), axis: (x: 1, y: -0.4, z: 0))
            .frame(height: 330)
            VStack(spacing: 10) {
                RarityTag(rarity, locale: locale, size: 12, filled: rarity > .plain)
                foundTag(found)
            }
            .opacity(faceUp ? 1 : 0)
            .offset(y: faceUp ? 0 : 10)
        }
    }

    private func cardFace(_ found: Album.Found) -> some View {
        CardView(card: found.card, width: 168)
            .shadow(color: felt.shade(0.5), radius: 22, y: 12)
            .overlay {
                if found.card == .settebello {
                    RoundedRectangle(cornerRadius: 168 * 0.09)
                        .strokeBorder(Palette.goldLight, lineWidth: 2.5)
                        .shadow(color: Palette.goldLight.opacity(0.9), radius: 10)
                }
            }
            .overlay(alignment: .topTrailing) {
                if found.isNew, faceUp {
                    NewStamp(sound: found.card == .settebello ? .play : .purchase)
                        .offset(x: 20, y: -14)
                }
            }
    }

    /// What the card was: missing until now, or one more of something already in there.
    @ViewBuilder private func foundTag(_ found: Album.Found) -> some View {
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

    /// Something off the shelves, which is the moment a dear pack was bought for. It lands
    /// face down too, edged in its grade, and goes over the way a card does.
    private func wonTile(_ won: AlbumBook.Won) -> some View {
        let grade = won.item?.grade ?? .comune
        return VStack(spacing: 18) {
            RevealStage(fanfare: won.item.map { Fanfare($0.grade) } ?? .quiet,
                        tint: Rarities.tint(grade), faceUp: faceUp, isNew: won.item != nil,
                        rays: won.item.map { $0.grade == .leggendario ? 28 : 18 } ?? 0,
                        width: 236, radius: GlassRadius.panel) {
                Group {
                    if let item = won.item {
                        // The shelves only hand over what you do not own, so it is always new.
                        WonItemCard(item: item, name: name)
                            .overlay(alignment: .topTrailing) {
                                if faceUp { NewStamp(sound: .purchase).offset(x: 12, y: -14) }
                            }
                    } else {
                        insteadCard(won.denari)
                    }
                }
                .shadow(color: felt.shade(0.5), radius: 22, y: 12)
            } back: {
                ShelfBack(tint: Rarities.tint(grade), sheen: Rarities.sheen(grade))
                    .shadow(color: felt.shade(0.5), radius: 22, y: 12)
            }
            .frame(height: 330)
            if let item = won.item {
                VStack(spacing: 10) {
                    RarityTag(item.grade, size: 12, filled: item.grade > .comune)
                    Text("Yours. Put it on in the shop.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.onTableSoft)
                }
                .opacity(faceUp ? 1 : 0)
                .offset(y: faceUp ? 0 : 10)
            }
        }
    }

    /// The shop had nothing left at that grade, so the pack paid instead.
    private func insteadCard(_ amount: Denari) -> some View {
        VStack(spacing: 12) {
            DenariMark(size: 64)
            Text(verbatim: "+\(amount.coins)")
                .font(.display(40))
                .monospacedDigit()
                .foregroundStyle(Palette.goldLight)
            Text("You own everything at that grade")
                .font(.system(size: 13, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.onTableSoft)
        }
        .padding(28)
        .frame(width: 230)
        .glassPanel(radius: GlassRadius.panel)
    }

    /// Dots for what is left in the pack, so nobody is tapping into the dark.
    private func progress(at place: Int) -> some View {
        HStack(spacing: 7) {
            ForEach(0..<steps, id: \.self) { index in
                Capsule()
                    .fill(index < place || (index == place && faceUp)
                          ? tint(at: index) : Palette.onTableSoft.opacity(index == place ? 0.7 : 0.3))
                    .frame(width: index == place ? 20 : 7, height: 7)
            }
        }
        .animation(.snappy, value: place)
        .accessibilityLabel(Text("\(place + 1) of \(steps)"))
    }

    // MARK: What it came to

    private var tally: some View {
        VStack(spacing: 0) {
            // Measured so the haul can sit in the middle of what is left when a pack was
            // three cards and no bonuses, and still scroll when it finished a suit.
            GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    Text(headline)
                        .font(.display(28))
                        .foregroundStyle(Palette.onTable)
                        .padding(.top, 10)
                    haul
                    lines
                }
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollIndicators(.hidden)
            }
            Button { dismiss() } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background { Capsule().fill(Palette.goldSheen) }
                    .foregroundStyle(Palette.ink)
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
        }
        .padding(26)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    /// What the opening is called once it is over.
    ///
    /// A pack off the shop puts nothing in the album, so it cannot say so. It is judged on
    /// whether it turned up a thing rather than denari: a pack that paid entirely in
    /// consolation because you own every felt there is has, honestly, found nothing new.
    private var headline: LocalizedStringKey {
        if opening.tier.isCosmeticOnly {
            return opening.bestWon == nil ? "Nothing new this time" : "That is yours"
        }
        return opening.isAllSpares && opening.won.isEmpty
            ? "Nothing new this time"
            : "That is in the album"
    }

    /// Everything the pack held, small and together, which is the picture worth keeping.
    private var haul: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(Array(running.enumerated()), id: \.offset) { _, found in
                    VStack(spacing: 5) {
                        CardView(card: found.card, width: 52)
                            // Centred on the top edge rather than hung off a corner:
                            // "NOUVEAU" is as wide as the card and covered the next one.
                            .overlay(alignment: .top) {
                                if found.isNew { NewTag(size: 7).offset(y: -7) }
                            }
                        RarityTag(found.card.rarity, locale: locale, size: 8)
                    }
                }
            }
            ForEach(opening.won) { won in
                if let item = won.item {
                    HStack(spacing: 10) {
                        RarityTag(item.grade, size: 9, filled: true)
                        NewTag(size: 9)
                        Text(verbatim: item.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.onTable)
                        Spacer(minLength: 0)
                        Text(Cosmetics.title(of: item.kind))
                            .font(.system(size: 11.5))
                            .foregroundStyle(Palette.onTableSoft)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .glassPanel(radius: GlassRadius.control)
                }
            }
        }
    }

    @ViewBuilder private var lines: some View {
        VStack(spacing: 8) {
            ForEach(opening.suits, id: \.self) { suit in
                // Only the first volume's suits come with a mark; a later one's pay denari.
                line(suitName(suit) + " " + String(localized: "complete", locale: locale),
                     value: Album.suitBonus, tint: Palette.goldLight,
                     note: opening.volume == .riviera
                        ? String(localized: "A mark for your seat, in the shop", locale: locale) : nil)
            }
            if opening.deck {
                line(String(localized: "The whole deck", locale: locale),
                     value: Album.deckBonus, tint: Palette.goldLight, note: prizeNote)
            }
            if opening.denari.isCredit {
                line(String(localized: "Into the purse", locale: locale), value: opening.denari,
                     tint: Palette.onTable)
            }
        }
    }

    /// One thing the pack paid. `note` is what it paid beyond the denari — a finished suit
    /// hands over a seat mark as well, and a line that only said "+150" would be hiding the
    /// better half of it.
    private func line(_ title: String, value: Denari, tint: Color, note: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                if let note {
                    Text(verbatim: note)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Palette.onTableSoft)
                }
            }
            Spacer(minLength: 8)
            DenariMark(size: 15)
            Text(verbatim: "\(value.coins)")
                .font(.system(size: 15, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
    }

    /// What finishing this volume handed over besides the denari.
    private var prizeNote: String {
        switch opening.volume {
        case .riviera: String(localized: "The Settebello mark, for your seat", locale: locale)
        case .napoli: String(localized: "The Golfo card back, and this deck to play with", locale: locale)
        case .pergamena: String(localized: "The Sigillo flourish, and this deck to play with", locale: locale)
        case .notturna: String(localized: "Civetta joins your table, and this deck to play with", locale: locale)
        }
    }

    private func suitName(_ suit: Suit) -> String {
        switch suit {
        case .coins: String(localized: "Coins", locale: locale)
        case .cups: String(localized: "Cups", locale: locale)
        case .swords: String(localized: "Swords", locale: locale)
        case .clubs: String(localized: "Clubs", locale: locale)
        }
    }

    // MARK: Moving it along

    @ViewBuilder private var skipHint: some View {
        if case .turning(let place) = act, place < steps - 1, faceUp {
            VStack {
                Spacer()
                Text("Tap for the next one")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.onTableSoft.opacity(0.8))
                    .padding(.bottom, 4)
            }
            .allowsHitTesting(false)
        }
    }

    /// A tap anywhere: opens the pack, turns the next thing over, or ends it.
    private func advance() {
        switch act {
        case .sealed:
            open()
        case .tearing:
            break
        case .turning(let place) where !faceUp:
            turnOver(place)
        case .turning(let place) where place + 1 < steps:
            show(place + 1)
        case .turning:
            finish()
        case .counted:
            break
        }
    }

    private func finish() {
        withAnimation(.spring(duration: 0.45, bounce: 0.2)) { act = .counted }
        if !opening.suits.isEmpty || opening.deck || opening.bestWon != nil {
            Audio.shared.play(.victory)
        }
    }

    /// Puts the next thing down face down, and sets it going over once it has waited.
    private func show(_ place: Int) {
        turning?.cancel()
        faceUp = false
        withAnimation(.spring(duration: 0.42, bounce: 0.22)) { act = .turning(place: place) }
        Audio.shared.play(.pick)
        let fanfare = fanfare(at: place)
        // The settebello sits in the dark a moment before the bells start climbing, so the
        // rise ends as it goes over.
        let lead: Duration = fanfare == .crowning && !reduceMotion ? .milliseconds(700) : .zero
        turning = Task {
            try? await Task.sleep(for: lead)
            guard !Task.isCancelled else { return }
            if fanfare >= .grand, !reduceMotion { Audio.shared.play(.rise) }
            try? await Task.sleep(for: fanfare.gathering - lead)
            guard !Task.isCancelled else { return }
            turnOver(place)
        }
    }

    /// Turns the thing at this place over, now: its wait is up, or somebody tapped.
    private func turnOver(_ place: Int) {
        guard !faceUp, act == .turning(place: place) else { return }
        turning?.cancel()
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.55, bounce: 0.3)) {
            faceUp = true
        }
        say(at: place)
        let fanfare = fanfare(at: place)
        guard fanfare >= .grand else { return }
        flares += 1
        if fanfare == .crowning, !reduceMotion { shakes += 1 }
    }

    /// The sound a thing makes as it goes over. Something new only lands here: the till
    /// waits for its stamp. The seven of coins has had its own since the first game
    /// shipped, and this is the other place it is worth hearing; anything from a court up
    /// throws glitter under whatever it says.
    private func say(at place: Int) {
        guard place < steps else { return }
        if fanfare(at: place) > .quiet { Audio.shared.play(.shine) }
        switch step(at: place) {
        case .card(let found) where found.card == .settebello: Audio.shared.play(.settebello)
        case .card(let found) where found.isNew:
            if fanfare(at: place) == .quiet { Audio.shared.play(.play) }
        case .card: Audio.shared.play(.denaro)
        case .won(let won) where won.item != nil: break
        case .won, .finale: Audio.shared.play(.purchase)
        }
    }

    // MARK: How big each one is

    private func fanfare(at place: Int) -> Fanfare {
        switch step(at: place) {
        case .card(let found): Fanfare(found.card.rarity)
        case .won(let won): won.item.map { Fanfare($0.grade) } ?? .quiet
        case .finale: .crowning
        }
    }

    private func tint(at place: Int) -> Color {
        switch step(at: place) {
        // A numeral's own colour is the table's soft text, which reads as "not yet".
        case .card(let found):
            found.card.rarity == .plain ? Palette.goldLight : Rarities.tint(found.card.rarity)
        case .won(let won): won.item.map { Rarities.tint($0.grade) } ?? Palette.goldLight
        case .finale: Palette.goldLight
        }
    }

    /// The best thing in the pack, which is the light through the tear.
    /// Only what was in the wrapper: a suit it finishes is not in there to shine through.
    private var drawn: Range<Int> { 0..<(running.count + opening.won.count) }

    private var best: Fanfare {
        drawn.map(fanfare(at:)).max() ?? .quiet
    }

    private var bestTint: Color {
        drawn.max { fanfare(at: $0) < fanfare(at: $1) }.map(tint(at:)) ?? Palette.goldLight
    }

    // MARK: The room

    /// The room darkens round a seven, and goes nearly dark round the settebello, while
    /// it waits face down. Lifted the moment it goes over.
    private var dimmer: some View {
        Color.black
            .opacity(dimming)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .animation(faceUp ? .easeOut(duration: 0.35) : .easeIn(duration: 0.9), value: dimming)
    }

    private var dimming: Double {
        guard case .turning(let place) = act, !faceUp else { return 0 }
        switch fanfare(at: place) {
        case .crowning: return 0.5
        case .grand: return 0.22
        default: return 0
        }
    }

    /// White across the whole screen as a seven or better goes over.
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

    /// The screen knocked sideways by the settebello landing, and settling.
    private static var shake: some Keyframes<CGFloat> {
        KeyframeTrack {
            CubicKeyframe(-10, duration: 0.05)
            CubicKeyframe(9, duration: 0.06)
            CubicKeyframe(-6, duration: 0.06)
            CubicKeyframe(4, duration: 0.06)
            CubicKeyframe(-2, duration: 0.06)
            CubicKeyframe(0, duration: 0.08)
        }
    }

    /// What the phone does at each beat. Everything lands with the soft tap a card gets at
    /// the table; something new gets its thump from the stamp, and the denari a dear pack
    /// paid instead, which has no stamp, gets the success pattern.
    private func feedback(for act: Act) -> SensoryFeedback? {
        switch act {
        case .sealed: nil
        case .tearing: Haptic.tear
        case .turning: Haptic.turn
        case .counted: nil
        }
    }

    /// What the phone does as the thing in the middle goes over: harder the rarer it is.
    /// Something new also gets its stamp's thump a moment later.
    private var turnFeedback: SensoryFeedback? {
        guard case .turning(let place) = act else { return nil }
        switch fanfare(at: place) {
        case .quiet:
            if case .won = step(at: place), !isNew(at: place) { return Haptic.prize }
            return isNew(at: place) ? nil : Haptic.turn
        case .bright: return Haptic.flip
        case .grand: return Haptic.prize
        case .crowning: return Haptic.settebello
        }
    }

    /// Whether the thing at this place was not yours before: a card missing from the album,
    /// or anything off the shelves, which only hand over what you do not own.
    private func isNew(at place: Int) -> Bool {
        switch step(at: place) {
        case .card(let found): found.isNew
        case .won(let won): won.item != nil
        case .finale: true
        }
    }

    /// `-packAutoplay`: the opening tapped through on a timer, round and round.
    private func autoplay() async {
        guard DebugLaunch.packAutoplay else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(2200))
            guard act == .counted else { advance(); continue }
            act = .sealed
            faceUp = false
            torn = false
            pull = 0
        }
    }

    /// `-packStep`: starts the opening part way through, already turned over.
    private func jump() {
        guard let step = DebugLaunch.packStep else { return }
        guard step != "done" else { return act = .counted }
        let place = switch step {
        case "new": running.firstIndex(where: \.isNew)
        case "spare": running.firstIndex { !$0.isNew }
        default: Int(step)
        }
        guard let place, place < steps else { return }
        act = .turning(place: place)
        faceUp = !DebugLaunch.packHolds
        if faceUp { say(at: place) }
        if let seconds = DebugLaunch.packHoldSeconds {
            turning = Task {
                try? await Task.sleep(for: .seconds(seconds))
                turnOver(place)
            }
        }
    }
}

/// The word NEW, in the house voice: heavy, tracked, on a terracotta capsule.
///
/// The same tag on the card as it turns over and on the haul at the end, so the reveal and
/// the recap say it the same way.
struct NewTag: View {
    var size: CGFloat = 17

    var body: some View {
        Text("NEW")
            .font(.system(size: size, weight: .heavy))
            .tracking(size * 0.1)
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(Palette.cream)
            .padding(.horizontal, size * 0.72)
            .padding(.vertical, size * 0.3)
            .background { Capsule().fill(Palette.terracotta) }
            .overlay { Capsule().strokeBorder(Palette.cream.opacity(0.9), lineWidth: max(size * 0.1, 1)) }
    }
}

/// NEW put down on something the moment it turns over and turns out to be missing until
/// now. It drops from above the card, lands with a thump and the till, and throws off a
/// ring where it hit: the one beat of an opening about what you did not have.
private struct NewStamp: View {
    /// What it sounds like as it lands.
    var sound: Sound

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tableFelt) private var felt
    @State private var landed = false
    @State private var rung = false

    var body: some View {
        NewTag()
            .background {
                Capsule()
                    .strokeBorder(Palette.cream, lineWidth: 2)
                    .scaleEffect(rung ? 1.9 : 1)
                    .opacity(rung ? 0 : 0.85)
            }
            .shadow(color: felt.shade(0.45), radius: 6, y: 3)
            .scaleEffect(landed || reduceMotion ? 1 : 2.6)
            .rotationEffect(.degrees(landed || reduceMotion ? -9 : -26))
            .opacity(landed ? 1 : 0)
            .sensoryFeedback(Haptic.stamp, trigger: landed)
            .task { await land() }
    }

    /// Waits for the card to arrive, then comes down on it. Cancelled with the card, so
    /// tapping through a pack does not leave stamps landing on nothing.
    private func land() async {
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 340))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(duration: 0.3, bounce: 0.45)) { landed = true }
        Audio.shared.play(sound)
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.55).delay(0.06)) { rung = true }
    }
}
