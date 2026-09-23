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
    /// Nudges the sealed pack so it reads as something you can take hold of.
    @State private var breathing = false

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

    /// How many things there are to turn over: the cards, then anything off the shelves.
    private var steps: Int { running.count + opening.won.count }

    /// The cloth under it, so what it drops is the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        ZStack {
            ground
            content
            skipHint
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TableGround())
        .contentShape(.rect)
        .onTapGesture(perform: advance)
        .sensoryFeedback(trigger: act) { _, act in feedback(for: act) }
        .statusBarHidden()
    }

    // MARK: The room

    /// A wash of the pack's own colour behind everything, so a reliquia does not open on
    /// the same green a mazzetto does.
    private var ground: some View {
        RadialGradient(colors: [PackLook.accent(opening.tier).opacity(glow), .clear],
                       center: .center, startRadius: 0, endRadius: 420)
            .ignoresSafeArea()
            .animation(.easeOut(duration: 0.6), value: act)
    }

    private var glow: Double {
        switch act {
        case .sealed: 0.10
        case .tearing: 0.26
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
            .scaleEffect(breathing ? 1.02 : 1)
            .rotationEffect(.degrees(breathing ? 1.1 : -1.1))
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
                Image(systemName: "chevron.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.onTableSoft)
                    .offset(y: breathing ? -4 : 2)
            }
            .opacity(act == .tearing ? 0 : 1)
            Spacer(minLength: 0)
        }
        .padding(30)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
                breathing = true
            }
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
        breathing = false
        withAnimation(.easeIn(duration: 0.4)) { act = .tearing }
        Audio.shared.play(.deal)
        Task {
            try? await Task.sleep(for: .milliseconds(420))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.5, bounce: 0.24)) { act = .turning(place: 0) }
            say(at: 0)
        }
    }

    // MARK: Turning them over

    /// One thing at a time in the middle, with what is left of the pack stacked behind it
    /// and what has already been turned over stacked below.
    private func reveal(at place: Int) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack {
                if place < running.count {
                    foundCard(running[place], place: place)
                } else {
                    wonTile(opening.won[place - running.count])
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

    /// A card, turned over, with its rarity behind it and what it was under it.
    private func foundCard(_ found: Album.Found, place: Int) -> some View {
        let rarity = found.card.rarity
        return VStack(spacing: 18) {
            ZStack {
                RarityBurst(count: Rarities.rays(rarity), tint: Rarities.tint(rarity), size: 330)
                CardView(card: found.card, width: 168)
                    .shadow(color: felt.shade(0.5), radius: 22, y: 12)
                    .overlay {
                        if rarity == .settebello {
                            RoundedRectangle(cornerRadius: 168 * 0.09)
                                .strokeBorder(Palette.goldLight, lineWidth: 2.5)
                                .shadow(color: Palette.goldLight.opacity(0.9), radius: 10)
                        }
                    }
                    .rotation3DEffect(.degrees(reduceMotion ? 0 : 8), axis: (x: 1, y: -0.4, z: 0))
            }
            .frame(height: 330)
            VStack(spacing: 10) {
                RarityTag(rarity, locale: locale, size: 12, filled: rarity > .plain)
                foundTag(found)
            }
        }
    }

    /// What the card was: missing until now, or one more of something already in there.
    @ViewBuilder private func foundTag(_ found: Album.Found) -> some View {
        switch found {
        case .new:
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 13, weight: .bold))
                Text("New in the album").font(.system(size: 15, weight: .heavy))
            }
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

    /// Something off the shelves, which is the moment a dear pack was bought for.
    private func wonTile(_ won: AlbumBook.Won) -> some View {
        VStack(spacing: 18) {
            ZStack {
                RarityBurst(count: won.item.map { $0.grade == .leggendario ? 28 : 18 } ?? 0,
                            tint: Rarities.tint(won.item?.grade ?? .comune), size: 330)
                Group {
                    if let item = won.item {
                        WonItemCard(item: item, name: name)
                    } else {
                        insteadCard(won.denari)
                    }
                }
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
                    .fill(index <= place ? Palette.goldLight : Palette.onTableSoft.opacity(0.3))
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
                            .overlay(alignment: .topTrailing) {
                                if found.isNew {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Palette.ink)
                                        .padding(3)
                                        .background { Circle().fill(Palette.goldSheen) }
                                        .offset(x: 4, y: -4)
                                }
                            }
                        RarityTag(found.card.rarity, locale: locale, size: 8)
                    }
                }
            }
            ForEach(opening.won) { won in
                if let item = won.item {
                    HStack(spacing: 10) {
                        RarityTag(item.grade, size: 9, filled: true)
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
                line(suitName(suit) + " " + String(localized: "complete", locale: locale),
                     value: Album.suitBonus, tint: Palette.goldLight,
                     note: String(localized: "A mark for your seat, in the shop", locale: locale))
            }
            if opening.deck {
                line(String(localized: "The whole deck", locale: locale),
                     value: Album.deckBonus, tint: Palette.goldLight,
                     note: String(localized: "The Settebello mark, for your seat", locale: locale))
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
        if case .turning(let place) = act, place < steps - 1 {
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
        case .turning(let place) where place + 1 < steps:
            withAnimation(.spring(duration: 0.42, bounce: 0.22)) { act = .turning(place: place + 1) }
            say(at: place + 1)
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

    /// The sound a card makes as it lands. The seven of coins has had its own since the
    /// first game shipped, and this is the other place it is worth hearing.
    private func say(at place: Int) {
        guard place < steps else { return }
        guard place < running.count else {
            Audio.shared.play(.purchase)
            return
        }
        let found = running[place]
        if found.card == .settebello, found.isNew {
            Audio.shared.play(.settebello)
        } else if found.isNew {
            Audio.shared.play(.purchase)
        } else {
            Audio.shared.play(.denaro)
        }
    }

    /// What the phone does at each beat. The tear is the one thing here somebody does with
    /// their hand, so it is the only heavy one; a prize gets the success pattern and an
    /// ordinary card gets the same soft tap a card gets at the table.
    private func feedback(for act: Act) -> SensoryFeedback? {
        switch act {
        case .sealed: nil
        case .tearing: Haptic.tear
        case .turning(let place): isPrize(at: place) ? Haptic.prize : Haptic.turn
        case .counted: nil
        }
    }

    /// Whether the thing turned over at this place is worth more than a tap: a card new to
    /// the album and better than a numeral, or anything at all off the shelves.
    private func isPrize(at place: Int) -> Bool {
        guard place < running.count else { return true }
        let found = running[place]
        return found.isNew && found.card.rarity > .plain
    }
}

/// A thing off the shelves, drawn at the size a card is drawn at so a pack of cards and a
/// felt read as the same kind of prize.
///
/// The preview is the real cosmetic wherever there is one to draw — the actual felt, the
/// actual badge, the actual deck — because a name on a plate is a receipt and the thing
/// itself is a reward.
struct WonItemCard: View {
    let item: ShopItem
    /// Whose it now is, so a won mark or livery is previewed wearing their own initial
    /// rather than a placeholder.
    var name: String = "?"

    /// The cloth under it, so the glass is tinted with the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        VStack(spacing: 14) {
            preview
                .frame(height: 104)
            VStack(spacing: 3) {
                Text(verbatim: item.title)
                    .font(.display(26))
                    .foregroundStyle(Palette.onTable)
                Text(Cosmetics.title(of: item.kind))
                    .font(.system(size: 12, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.onTableSoft)
            }
        }
        .padding(22)
        .frame(width: 236)
        // All but opaque: the rays are behind this card, and at anything translucent they
        // show through the tile and turn the prize into a smear.
        .background {
            RoundedRectangle(cornerRadius: GlassRadius.panel)
                .fill(felt.shade(0.96))
        }
        .overlay {
            RoundedRectangle(cornerRadius: GlassRadius.panel)
                .strokeBorder(Rarities.sheen(item.grade), lineWidth: 2)
        }
    }

    @ViewBuilder private var preview: some View {
        switch item.kind {
        case .felt:
            if let felt = Cosmetics.felt(of: item.id) { FeltSwatch(felt: felt) }
        case .tapis:
            if let tapis = Tapis.allCases.first(where: { Cosmetics.item(for: $0)?.id == item.id }) {
                TapisSwatch(tapis: tapis, felt: .riviera)
            }
        case .mark:
            if let mark = Cosmetics.mark(of: item.id) {
                SeatBadge(name: name, tint: Palette.seat(0), size: 72, mark: mark)
            }
        case .cornice:
            if let cornice = Cornice.allCases.first(where: { Cosmetics.item(for: $0)?.id == item.id }) {
                SeatBadge(name: name, tint: Palette.seat(0), size: 60, cornice: cornice)
            }
        case .companion:
            if let companion = Companion.allCases.first(where: { Cosmetics.item(for: $0)?.id == item.id }) {
                CompanionSwatch(companion: companion, felt: .riviera)
            }
        case .livery:
            if let livery = Cosmetics.livery(of: item.id) {
                SeatBadge(name: name, tint: Palette.seat(0), size: 72, livery: livery)
            }
        case .cardBack:
            if let back = CardBackPattern.allCases.first(where: { Cosmetics.item(for: $0)?.id == item.id }) {
                CardBack(width: 68).environment(\.cardBack, back)
            }
        case .cardTheme, .cardSkin:
            deckPreview
        case .flourish:
            if let flourish = Cosmetics.flourish(of: item.id) {
                FlourishSwatch(flourish: flourish, felt: .riviera)
            }
        case .cheer:
            Image(systemName: Cosmetics.cheer(of: item.id)?.symbol ?? "speaker.wave.2.fill")
                .font(.system(size: 66, weight: .semibold))
                .foregroundStyle(Rarities.tint(item.grade))
        case .reactions:
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 62, weight: .semibold))
                .foregroundStyle(Rarities.tint(item.grade))
        }
    }

    /// The won deck, drawn in its own art rather than in whatever is equipped.
    @ViewBuilder private var deckPreview: some View {
        let theme = wonTheme
        HStack(spacing: -22) {
            CardView(card: Card(.knight, of: .coins), width: 60)
            CardBack(width: 60).rotationEffect(.degrees(8))
        }
        .environment(\.cardTheme, theme)
    }

    private var wonTheme: CardTheme {
        if let style = CardStyle.options.first(where: { $0.shopItem?.id == item.id }) {
            return CardTheme(style: style, skin: .riviera)
        }
        if let skin = CardSkin.options.first(where: { $0.shopItem?.id == item.id }) {
            return CardTheme(style: .moderna, skin: skin)
        }
        return CardTheme(style: .moderna, skin: .riviera)
    }
}
