import SwiftUI
import ScopaCore

/// Card frames kept out of view state: they change on every frame of a table animation
/// and nothing drawn depends on them, so writing one must not redraw the table.
@MainActor
final class FrameBox {
    var frames: [Card: CGRect] = [:]
}

/// The cards in your hand, and the touch that picks one up or throws it onto the table.
///
/// The drag's own state lives here so a card following the finger re-evaluates this row
/// and nothing above it. The screen hears about it through the four closures.
struct HandCards: View {
    let hand: [Card]
    /// The card currently picked, which sits lifted.
    let picked: Card?
    /// What the coach thinks of each card, when it is on.
    var marks: [Card: Coach.Standing] = [:]
    /// The cards a tap would play there and then, so VoiceOver says "play" and not "pick
    /// up". See `HandSelection.playsOnTap`.
    var playsAtOnce: Set<Card> = []
    let isMyTurn: Bool
    let stage: Stage
    /// The table's own factor, so the hand is dealt at the size the cloth is drawn at.
    var lift: CGFloat = 1
    /// The coordinate space the table cards report their frames in.
    let space: String
    /// Where each card is sitting, for the table to fly one out of when it is played.
    let frames: FrameBox
    /// A card touched and let go without being carried, and when the finger came up. The
    /// time is the touch's own, so a redraw after the first tap does not make a quick
    /// second one look slow.
    let tap: (Card, Date) -> Void
    /// A card picked up by a drag.
    let pick: (Card) -> Void
    /// The finger, with a card under it, somewhere over the table.
    let hover: (CGPoint) -> Void
    /// The card let go: which, where, and how far the finger carried it. The distance is
    /// handed over rather than read off as a flick here, because a touch that ends where
    /// it started was never a drag at all. See `dropHand`.
    let drop: (Card, CGPoint, CGSize) -> Void

    @State private var dragged: Card?
    @State private var dragOffset: CGSize = .zero

    /// How far a picked card rises out of the hand.
    private static let rise: CGFloat = 14
    /// How far the finger moves before the touch is a drag rather than a tap.
    private static let carry: CGFloat = 12

    var body: some View {
        // Three cards sit side by side; scopone's ten tuck over each other, rank corners showing.
        OverlapRow(spacing: stage.pick(tall: 10, wide: 8) * lift) {
            ForEach(Array(held.enumerated()), id: \.element) { index, card in
                handCard(card, index: index)
            }
        }
        // Room for the lift, so a chosen card never slides under the button.
        .padding(.top, stage.pick(tall: 20, wide: 16))
        // The hand changes from an async update with no transaction of its own, so
        // without this an insertion could pop in.
        .animation(.spring(duration: 0.55, bounce: 0.25), value: hand)
        .animation(.snappy(duration: 0.22), value: picked)
    }

    /// The hand in the order it is held. Ten tucked cards show only their ranks, so they are
    /// grouped by suit the way a player sorts them; three are left as they were dealt.
    private var held: [Card] {
        guard hand.count > 3 else { return hand }
        let suits = Suit.allCases
        return hand.sorted {
            (suits.firstIndex(of: $0.suit)!, $0.rank) < (suits.firstIndex(of: $1.suit)!, $1.rank)
        }
    }

    private func handCard(_ card: Card, index: Int) -> some View {
        CardView(card: card, width: stage.pick(tall: 100, wide: 74) * lift,
                 highlighted: picked == card)
            .overlay(alignment: .topTrailing) {
                if let standing = marks[card] {
                    CoachMark(standing: standing).offset(x: 7, y: -7)
                }
            }
            .offset(
                x: dragged == card ? dragOffset.width : 0,
                y: (dragged == card ? dragOffset.height : 0) + (picked == card ? -Self.rise : 0)
            )
            .rotationEffect(.degrees(dragged == card ? Double(dragOffset.width) * 0.06 : 0))
            .zIndex(dragged == card ? 1 : 0)
            // A transform does not move a layout frame, so this is the slot the card was
            // dealt to, which is where a card laid on the cloth should be seen leaving from.
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named(space))
            } action: { frame in
                frames.frames[card] = frame
            }
            .transition(dealTransition(index: index))
            // The touch area is the slot and the height a card rises to. A picked card
            // used to take its touch area up with it, so a second tap on the bottom edge,
            // where a thumb comes back down, landed below the card and did nothing.
            .padding(.top, Self.rise)
            .contentShape(.rect)
            .padding(.top, -Self.rise)
            .gesture(touchGesture(for: card))
            // The face is drawn as shapes, so the label is the only thing VoiceOver has to
            // read. It goes on the tappable view rather than on `CardView`, so the element
            // it names is the one that can be played.
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { tap(card, .now) }
            .accessibilityLabel(card.spoken)
            .accessibilityHint(hint(for: card))
    }

    /// VoiceOver's double tap is the tap here, so it is what the hint names. A card that is
    /// up and cannot go — a choice to make, or not your turn — comes back down.
    private func hint(for card: Card) -> LocalizedStringKey {
        if playsAtOnce.contains(card) { return "Double tap to play it" }
        return picked == card ? "Double tap to put it down" : "Double tap to pick it up"
    }

    /// Dealt one after another. The delay has to ride on the transition itself: a child's
    /// own `.animation(_:value:)` never drives its insertion.
    private func dealTransition(index: Int) -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.7))
                .animation(.spring(duration: 0.62, bounce: 0.32)
                    .delay(Double(index) * (hand.count > 3 ? 0.1 : 0.26))),
            removal: .scale(scale: 0.7).combined(with: .opacity)
        )
    }

    /// A tap on a card, or a flick towards the table to play it. One gesture for both: a
    /// tap beside a drag was a second recogniser to lose to it, and a touch that drifted
    /// past the tap's allowance but short of the drag's start counted as neither.
    private func touchGesture(for card: Card) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(space))
            .onChanged { value in
                guard isMyTurn else { return }
                if dragged != card {
                    guard hypot(value.translation.width, value.translation.height) >= Self.carry else { return }
                    dragged = card
                    pick(card)
                }
                dragOffset = value.translation
                hover(value.location)
            }
            .onEnded { value in
                guard dragged == card else {
                    if hypot(value.translation.width, value.translation.height) < Self.carry {
                        tap(card, value.time)
                    }
                    return
                }
                dragged = nil
                withAnimation(.spring(duration: 0.3, bounce: 0.25)) { dragOffset = .zero }
                drop(card, value.location, value.translation)
            }
    }
}
