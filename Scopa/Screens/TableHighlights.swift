import ScopaCore
import SwiftUI

/// A take worth stopping on that is not a sweep: the seven of coins, and the moments the
/// house rules add. Each gets a plate on the cloth, smaller and shorter than a scopa's band.
enum TableHighlight: Equatable {
    case settebello
    /// The king of coins, where re bello is played.
    case reBello
    /// A napola made or run on, and what it is now worth.
    case napola(points: Int)
    /// An ace that took the whole table under asso piglia tutto.
    case assoPigliaTutto(Card)

    /// The one moment a play earns, if any. A sweep keeps the floor, so it never gets one;
    /// a napola first made outranks the seven, which outranks everything after it.
    static func of(_ play: TableStore.Play, in view: PlayerView) -> TableHighlight? {
        guard !play.sweeps, !play.captures.isEmpty else { return nil }
        let house = view.configuration.house
        let taken = play.captures + [play.card]
        let napola = house.contains(.napola) ? napolaGrowth(play, taken: taken, in: view) : nil
        if let napola, napola.before == 0 { return .napola(points: napola.after) }
        if play.tookSettebello { return .settebello }
        if house.contains(.reBello), taken.contains(.reBello) { return .reBello }
        if let napola { return .napola(points: napola.after) }
        if house.contains(.assoPigliaTutto), play.card.rank == .ace, play.captures.count >= 2 {
            return .assoPigliaTutto(play.card)
        }
        return nil
    }

    /// The side's napola before and after this take, when the take made it grow.
    private static func napolaGrowth(_ play: TableStore.Play, taken: [Card],
                                     in view: PlayerView) -> (before: Int, after: Int)? {
        let side = view.configuration.side(ofSeat: play.seat)
        // The pile may or may not hold this take yet, so both are worked out from the union.
        let pile = Set(view.capturedBySide[safe: side] ?? []).union(taken)
        let after = Scoring.napola(of: Array(pile))
        let before = Scoring.napola(of: Array(pile.subtracting(taken)))
        return after > before ? (before, after) : nil
    }

    /// How long the plate stays up. Somebody else's is told and gone sooner.
    func length(mine: Bool) -> Double { mine ? 1.6 : 1.2 }

    /// The cards the plate shows: the prize itself, or the run of coins a napola is.
    var cards: [Card] {
        switch self {
        case .settebello: [.settebello]
        case .reBello: [.reBello]
        case .napola(let points): Rank.allCases.prefix(min(points, 5)).map { Card($0, of: .coins) }
        case .assoPigliaTutto(let ace): [ace]
        }
    }

    var title: String {
        switch self {
        case .settebello: "Settebello!"
        case .reBello: "Re bello!"
        case .napola: "Napola!"
        case .assoPigliaTutto: "Asso piglia tutto!"
        }
    }

    /// The glass behind it: gold for the coins, bronze for the ace.
    var tint: Color {
        if case .assoPigliaTutto = self { return Palette.goldDeep.opacity(0.94) }
        return Palette.gold.opacity(0.92)
    }

    /// What the plate throws off when its card lands, on your own take only.
    var sparks: (count: Int, coins: Int, palette: [Color]) {
        switch self {
        case .settebello: (26, 0, [Palette.goldLight, .white, Palette.gold, Palette.cream])
        case .reBello: (18, 0, [Palette.cream, Palette.goldLight, .white])
        case .napola: (16, 4, [Palette.goldLight, Palette.cream, .white])
        case .assoPigliaTutto: (14, 0, [Palette.cream, Palette.goldLight])
        }
    }

    /// The phone's part, beside the plate. The seven's own thud for somebody else's is
    /// `TableScreen.playFeedback`; the seven's bells are `Audio.announce`.
    @MainActor func feel(mine: Bool) {
        if mine {
            let coins = if case .napola(let points) = self { min(points, 5) } else { 0 }
            Rumble.shared.prize(coins: coins)
        }
        switch self {
        case .reBello, .napola: Audio.shared.play(.shine, gain: mine ? 1 : 0.6, after: .milliseconds(140))
        case .settebello, .assoPigliaTutto: break
        }
    }
}

/// One highlight on the cloth, and who earned it. Its own identity, so a second plate in
/// quick succession plays its arrival again rather than taking over the first.
struct HighlightMoment: Equatable, Identifiable {
    let id = UUID()
    let kind: TableHighlight
    /// Who took it, or empty when it was you.
    let by: String
}

/// The plate for a `TableHighlight`: the card turned over onto the glass, the name, and
/// who took it. Yours lands with a ring and a handful of sparks; anyone else's is smaller
/// and only catches the light.
struct HighlightPlate: View {
    let highlight: TableHighlight
    /// Who took it, or empty when it was you.
    var by: String

    @State private var turned = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var heightClass
    @Environment(\.screenSize) private var screenSize
    private var stage: Stage { Stage(heightClass, size: screenSize) }
    private var mine: Bool { by.isEmpty }
    private var cardWidth: CGFloat { stage.pick(tall: mine ? 46 : 36, wide: mine ? 38 : 32) }

    var body: some View {
        HStack(spacing: stage.pick(tall: 14, wide: 12)) {
            art
            VStack(alignment: .leading, spacing: -2) {
                Text(verbatim: highlight.title)
                    .font(.display(stage.pick(tall: mine ? 36 : 28, wide: mine ? 30 : 24)))
                    .foregroundStyle(Palette.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(subtitle)
                    .font(.system(size: stage.pick(tall: mine ? 13 : 12, wide: 12), weight: .semibold))
                    .foregroundStyle(Palette.cream.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, mine ? 18 : 14)
        .padding(.vertical, mine ? 12 : 9)
        .glassPanel(radius: GlassRadius.panel, tint: highlight.tint)
        .shadow(color: Palette.goldDeep.opacity(mine ? 0.45 : 0.3), radius: mine ? 24 : 14, y: 10)
        .padding(.horizontal, 24)
        .transition(.scale(scale: 0.82).combined(with: .opacity))
        .allowsHitTesting(false)
        .task { await turn() }
    }

    private var subtitle: LocalizedStringKey {
        switch highlight {
        case .settebello: mine ? "The seven of coins is yours" : "\(by) takes the seven of coins"
        case .reBello: mine ? "The king of coins is yours" : "\(by) takes the king of coins"
        case .napola(let points): mine ? "A napola worth \(points) points" : "\(by) makes a napola worth \(points) points"
        case .assoPigliaTutto: mine ? "Your ace takes the whole table" : "\(by)'s ace takes the whole table"
        }
    }

    /// The card goes over a beat after the plate arrives, so it is seen turning.
    private func turn() async {
        guard !reduceMotion else { turned = true; return }
        try? await Task.sleep(for: .milliseconds(80))
        withAnimation(.spring(duration: 0.38, bounce: 0.3)) { turned = true }
    }

    /// One card turned face up, or a napola's coins dealt out in a run.
    private var art: some View {
        let cards = highlight.cards
        return ZStack {
            ForEach(Array(cards.enumerated()), id: \.element) { index, card in
                dealt(card, index: index, of: cards.count)
            }
            if turned, mine, !reduceMotion { burst }
        }
        .frame(width: cardWidth * (1 + CGFloat(cards.count - 1) * 0.42), height: cardWidth * 1.6)
    }

    /// A card in the plate: a single prize turns over, a run fans out one after another.
    private func dealt(_ card: Card, index: Int, of count: Int) -> some View {
        let spread = (CGFloat(index) - CGFloat(count - 1) / 2) * cardWidth * 0.42
        let flips = count == 1
        return face(card, flips: flips)
            .overlay {
                if turned, !reduceMotion {
                    FoilGlare(fanfare: mine ? .bright : .quiet, tint: Palette.goldLight, glance: 0,
                              radius: cardWidth * 0.12)
                }
            }
            .rotation3DEffect(.degrees(turned || !flips ? 0 : 180), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .rotationEffect(.degrees(flips ? -6 : Double(index - count / 2) * 6))
            .offset(x: turned ? spread : 0, y: turned ? 0 : -cardWidth * 0.3)
            .opacity(turned || flips ? 1 : 0)
            .animation(.spring(duration: 0.38, bounce: 0.3).delay(flips ? 0 : Double(index) * 0.08), value: turned)
    }

    /// The back held the other way round and swapped for the face halfway through the
    /// turn, so the card ends face out rather than mirrored.
    private func face(_ card: Card, flips: Bool) -> some View {
        ZStack {
            if flips {
                CardBack(width: cardWidth)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .opacity(turned ? 0 : 1)
            }
            CardView(card: card, width: cardWidth)
                .opacity(turned || !flips ? 1 : 0)
        }
        .animation(.linear(duration: 0.01).delay(0.14), value: turned)
    }

    /// The ring and the sparks off the card as it lands.
    private var burst: some View {
        let sparks = highlight.sparks
        return ZStack {
            Shockwave(tint: Palette.goldLight, size: cardWidth * 1.4, delay: 0.12)
            SparkBurst(sparks: sparks.count, coins: sparks.coins, palette: sparks.palette,
                       force: 420, seed: 11)
        }
        .allowsHitTesting(false)
    }
}

#Preview("Highlights") {
    VStack(spacing: 20) {
        HighlightPlate(highlight: .settebello, by: "")
        HighlightPlate(highlight: .reBello, by: "Mario")
        HighlightPlate(highlight: .napola(points: 4), by: "")
        HighlightPlate(highlight: .assoPigliaTutto(Card(.ace, of: .cups)), by: "Lucia")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { TableGround() }
}
