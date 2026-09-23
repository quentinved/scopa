import SwiftUI
import ScopaCore

/// A move, played out in beats: the card crosses from the player who laid it and turns
/// face up on the way, the cards it takes light up where they sit, they gather into a fan
/// beside it, and the lot of them fly across and shrink into that player's pile.
///
/// A card that takes nothing gets the first beat and stays: it crosses, turns over and
/// rests on the cloth long enough to be read.
///
/// Drawn over the table rather than by it. By the time this appears the model has taken
/// those cards off the cloth, so what flies are copies placed from the frames the cloth
/// last reported. See `TableScreen.tableFrames`.
struct CardFlight: Identifiable {
    let id = UUID()
    /// The card that was laid down. Nil for the round's leftovers, which nobody played.
    let played: Card?
    /// What was taken, each from where it was sitting.
    let taken: [Placed]
    /// Where the played card comes in from: the badge of whoever laid it, face down. Nil
    /// for your own card and for the leftovers, which grow on the cloth instead.
    let origin: CGPoint?
    /// The middle of the cloth, where the played card lands, the fan gathers and the
    /// caption sits. For a card laid down and left, the place in the row it settles into.
    let from: CGPoint
    /// Where they are all going: the winner's badge, or your own pile.
    let to: CGPoint
    /// The width the played card is drawn at while it is held up in the middle of the
    /// cloth, readable from the far side of a phone on a table. Everything else in the
    /// flight is sized from this.
    let cardWidth: CGFloat
    let tint: Color
    /// Said under the cards while they fly. Only the leftovers need it: every other move
    /// already has the tag in the corner of the cloth.
    let caption: String?
    /// A sweep, which is worth an extra beat of holding still.
    let sweeps: Bool
    /// The round's last cards. The summary is held back until these have landed.
    let endsTheRound: Bool
    /// Coming your way, which is the only case the phone says anything about.
    let isMine: Bool
    /// Nothing was taken: the card crosses to the cloth, is held up in the middle, then
    /// settles into its place in the row. See `TableScreen.settling`.
    var laysDown: Bool = false
    /// The size that place in the row wants, for the card to shrink to as it settles.
    /// Only a card being laid down has one.
    var restingWidth: CGFloat?

    struct Placed: Identifiable, Equatable {
        var id: Card { card }
        let card: Card
        let frame: CGRect
    }

    /// How long each beat runs. Slow enough to follow a card across the cloth and read its
    /// face, short enough not to keep the next player waiting. See `HotSeatTable.pace`.
    static let land: TimeInterval = 0.44
    /// The takes sitting lit where they were, before anything moves.
    static let lit: TimeInterval = 0.2
    /// The takes sliding in beside the card that won them.
    static let gather: TimeInterval = 0.4
    /// The whole set laid out together, which is the beat that says what the move was.
    static let fan: TimeInterval = 0.3
    static let fly: TimeInterval = 0.62
    /// Each card leaves a little after the one before it, so four cards read as four
    /// cards rather than as one clump.
    static let stagger: TimeInterval = 0.06
    /// A sweep is worth stopping on.
    static let sweepPause: TimeInterval = 0.3
    /// How long a card laid down is held up in the middle before it settles into the row.
    static let rest: TimeInterval = 0.5
    /// And how long that settling takes.
    static let settle: TimeInterval = 0.3
    /// A card of your own reaching the cloth. Shorter than `land`, which carries a card
    /// the width of the table from somebody else's hand.
    static let reach: TimeInterval = 0.26

    /// How long the played card takes to reach the cloth.
    var travel: TimeInterval { laysDown && isMine ? Self.reach : Self.land }
    /// How long it is held up in the middle of the cloth to be read before it goes on.
    /// Nothing to read on a card you played yourself, so yours does not stop at all.
    var hold: TimeInterval { laysDown && isMine ? 0 : Self.rest }

    /// When the last card has landed in the pile, or when the table can have a card that
    /// was laid down.
    var duration: TimeInterval {
        if laysDown { return travel + hold + Self.settle }
        return departure + Self.fly + Self.stagger * Double(max(taken.count - 1, 0))
    }

    /// The moment the fan leaves the cloth, which is when the phone should thump.
    var departure: TimeInterval {
        Self.land + Self.lit + Self.gather + Self.fan + (sweeps ? Self.sweepPause : 0)
    }

    /// The moment the takes start sliding in beside the played card.
    var gathering: TimeInterval { Self.land + Self.lit }
}

/// The cards in the air. Positioned in the table's own coordinate space, so it must be
/// laid over the view that names that space rather than over the one wrapping it.
struct CardFlightLayer: View {
    let flight: CardFlight

    /// Beat one: the played card has arrived, face up, and the takes are lit where they sit.
    @State private var landed = false
    /// Beat two: the takes have come in beside it and the move is laid out as a fan, or a
    /// card that took nothing has settled into its place in the row.
    @State private var gathered = false
    /// Beat three: everything is on its way to the winner.
    @State private var gone = false

    /// How many cards end up in the fan, the played one included.
    private var fanCount: Int { flight.taken.count + (flight.played == nil ? 0 : 1) }
    /// The size every card is drawn at once it is in the fan, whatever size it was on the
    /// cloth. Smaller than the card held up in the middle, which would not fit four across.
    private var fanWidth: CGFloat { flight.cardWidth * 0.62 }
    /// Is the winner's ring lit? While the move is being shown, and not once it is on its
    /// way or settled in among the others.
    private var ringIsOn: Bool { landed && !gone && !(flight.laysDown && gathered) }
    /// Side by side, overlapping just enough that a pair still reads as two cards.
    private var fanSpread: CGFloat { fanWidth * (fanCount > 4 ? 0.58 : 0.76) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            caption
            ForEach(Array(flight.taken.enumerated()), id: \.element.id) { index, placed in
                ghost(placed, index: index)
            }
            if let played = flight.played {
                playedCard(played)
            }
        }
        // Copies of cards the player is not meant to reach for: taps belong to the cloth
        // underneath, which is already dealing the next move.
        .allowsHitTesting(false)
        .task(id: flight.id) { await run() }
    }

    /// What the leftovers say for themselves while they cross.
    @ViewBuilder private var caption: some View {
        if let caption = flight.caption {
            Text(caption)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.cream)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .glassCapsule(tint: flight.tint.opacity(0.9))
                .fixedSize()
                .position(x: flight.from.x, y: flight.from.y - flight.cardWidth * 0.78)
                .opacity(landed && !gone ? 1 : 0)
                .animation(.easeOut(duration: 0.22), value: landed)
                .animation(.easeIn(duration: 0.22), value: gone)
        }
    }

    /// The beats, in order. Each one flips a flag the cards animate off.
    private func run() async {
        landed = false
        gathered = false
        gone = false
        withAnimation(.spring(duration: flight.travel, bounce: 0.24)) { landed = true }
        // A card that took nothing is held up to be read, then sits down in the row where
        // the table is keeping its place.
        guard !flight.laysDown else {
            try? await Task.sleep(for: .seconds(flight.travel + flight.hold))
            guard !Task.isCancelled else { return }
            gathered = true
            return
        }
        try? await Task.sleep(for: .seconds(flight.gathering))
        guard !Task.isCancelled else { return }
        gathered = true
        try? await Task.sleep(for: .seconds(flight.departure - flight.gathering))
        guard !Task.isCancelled else { return }
        gone = true
    }

    /// Where the card at `index` sits once the move is laid out: a row centred on the
    /// cloth, the played card first and everything it took following it.
    private func fanPoint(_ index: Int) -> CGPoint {
        let step = Double(index) - Double(fanCount - 1) / 2
        return CGPoint(x: flight.from.x + step * fanSpread, y: flight.from.y)
    }

    /// The slight turn each card takes in the fan, so the set reads as cards on a table
    /// rather than as a diagram.
    private func fanAngle(_ index: Int) -> Double {
        (Double(index) - Double(fanCount - 1) / 2) * 3.5
    }

    /// One taken card: sitting where it was on the cloth and ringed in the winner's
    /// colour, then in beside the card that won it, then away.
    private func ghost(_ placed: CardFlight.Placed, index: Int) -> some View {
        let slot = flight.played == nil ? index : index + 1
        let start = CGPoint(x: placed.frame.midX, y: placed.frame.midY)
        let delay = CardFlight.stagger * Double(index)
        return CardView(card: placed.card, width: placed.frame.width)
            .overlay {
                RoundedRectangle(cornerRadius: placed.frame.width * 0.12)
                    .strokeBorder(flight.tint, lineWidth: 2.5)
                    .opacity(ringIsOn ? 1 : 0)
            }
            .shadow(color: flight.tint.opacity(ringIsOn ? 0.55 : 0), radius: 10)
            .scaleEffect(ghostScale(placed.frame.width))
            .rotationEffect(.degrees(gathered && !gone ? fanAngle(slot) : 0))
            .opacity(gone ? 0 : 1)
            .position(gone ? flight.to : (gathered ? fanPoint(slot) : start))
            .animation(.easeOut(duration: 0.2), value: landed)
            .animation(.spring(duration: CardFlight.gather, bounce: 0.2).delay(delay), value: gathered)
            .animation(.spring(duration: CardFlight.fly, bounce: 0.12).delay(delay), value: gone)
    }

    /// A taken card is drawn at the size it was on the cloth, so it has to be scaled to
    /// the fan's size rather than laid out at it.
    private func ghostScale(_ width: CGFloat) -> CGFloat {
        let fan = fanWidth / width
        if gone { return fan * 0.3 }
        if gathered { return fan }
        return landed ? 1.06 : 1
    }

    /// The card that was played. It comes in from the player who laid it, face down, turns
    /// over on the way and then leads the fan across to whoever won it.
    private func playedCard(_ card: Card) -> some View {
        flipping(card)
            .shadow(color: Palette.ink.opacity(0.45), radius: 12, y: 6)
            .rotationEffect(.degrees(playedAngle))
            .scaleEffect(playedScale)
            .opacity(gone && !flight.laysDown ? 0 : (landed || flight.origin != nil ? 1 : 0))
            .position(playedPoint)
            .animation(.spring(duration: flight.travel, bounce: 0.24), value: landed)
            .animation(.spring(duration: flight.laysDown ? CardFlight.settle : CardFlight.gather,
                               bounce: 0.2), value: gathered)
            .animation(.spring(duration: CardFlight.fly, bounce: 0.12), value: gone)
    }

    /// The card turning over as it crosses. Your own card is already face up, so only a
    /// card coming in from somebody else is dealt back down first.
    @ViewBuilder private func flipping(_ card: Card) -> some View {
        if flight.origin == nil || flight.isMine {
            ringed { CardView(card: card, width: flight.cardWidth) }
        } else {
            ZStack {
                // The back is the one held the other way round, so the turn ends at zero
                // with the face the right way out. Pre-turning the face leaves the card
                // resting at 180°, which is a mirror.
                ringed { CardBack(width: flight.cardWidth) }
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .opacity(landed ? 0 : 1)
                ringed { CardView(card: card, width: flight.cardWidth) }
                    .opacity(landed ? 1 : 0)
            }
            // Swapped at the halfway point rather than faded: a cross-fade through the
            // turn shows two cards at once.
            .animation(.linear(duration: 0.01).delay(flight.travel / 2), value: landed)
            .rotation3DEffect(.degrees(landed ? 0 : 180), axis: (x: 0, y: 1, z: 0),
                              perspective: 0.4)
            .animation(.easeInOut(duration: flight.travel), value: landed)
        }
    }

    /// The winner's ring, drawn on the card itself so that it turns with it rather than
    /// hanging in the air around a card seen edge on.
    private func ringed(_ card: () -> some View) -> some View {
        card()
            .overlay {
                RoundedRectangle(cornerRadius: flight.cardWidth * 0.12)
                    .strokeBorder(flight.tint, lineWidth: 3)
                    .opacity(ringIsOn ? 1 : 0)
            }
    }

    private var playedPoint: CGPoint {
        guard landed else { return flight.origin ?? flight.from }
        if flight.laysDown { return gathered ? flight.to : flight.from }
        if gone { return flight.to }
        return gathered ? fanPoint(0) : flight.from
    }

    private var playedScale: CGFloat {
        guard landed else {
            // Off a badge across the table it is a small thing growing into a card. Out
            // of your own hand it is already a card, at the size it was in your fingers.
            if flight.origin == nil { return 0.55 }
            return flight.isMine ? 0.94 : 0.38
        }
        if flight.laysDown {
            guard gathered, let resting = flight.restingWidth else { return 1 }
            return resting / flight.cardWidth
        }
        if gone { return 0.3 * (fanWidth / flight.cardWidth) }
        return gathered ? fanWidth / flight.cardWidth : 1
    }

    private var playedAngle: Double {
        guard landed else { return -8 }
        return gathered && !gone ? fanAngle(0) : 0
    }
}

/// Cards the table has let go of, drawn where they last lay.
///
/// The round's last cards come off the cloth the moment the round ends, but they cannot
/// fly to whoever swept them up until the play that ended the round has finished crossing
/// it. Without this they would fade off the table and be back a second later in the same
/// places. `CardFlightLayer` takes these copies over on the frame it appears.
struct CardHoldLayer: View {
    let cards: [CardFlight.Placed]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(cards) { placed in
                CardView(card: placed.card, width: placed.frame.width)
                    .position(x: placed.frame.midX, y: placed.frame.midY)
            }
        }
        // Copies of cards nobody is going to play. The taps belong to the cloth under them.
        .allowsHitTesting(false)
    }
}

/// Where the cloth and each player are on screen, so a capture knows where it starts
/// and which way to fly.
///
/// A box rather than view state, on the same reasoning as `FrameBox`: writing one down
/// must not redraw the table.
@MainActor
final class TableAnchors {
    /// Each seat's badge, by seat number.
    var seats: [Int: CGPoint] = [:]
    /// The middle of the cloth, where a played card lands before it is carried off.
    var cloth: CGPoint = .zero
}

extension View {
    /// Notes where this seat's badge is, in `space`, for captures to fly towards.
    func seatAnchor(_ seat: Int, in space: String, into anchors: TableAnchors) -> some View {
        onGeometryChange(for: CGPoint.self) { proxy in
            let frame = proxy.frame(in: .named(space))
            return CGPoint(x: frame.midX, y: frame.midY)
        } action: { point in
            anchors.seats[seat] = point
        }
    }

    /// Notes the middle of the cloth, in `space`.
    func clothAnchor(in space: String, into anchors: TableAnchors) -> some View {
        onGeometryChange(for: CGPoint.self) { proxy in
            let frame = proxy.frame(in: .named(space))
            return CGPoint(x: frame.midX, y: frame.midY)
        } action: { point in
            anchors.cloth = point
        }
    }
}
