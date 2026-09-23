import SwiftUI
import ScopaCore

/// Card frames kept out of view state: they change on every frame of a table animation
/// and nothing drawn depends on them, so writing one must not redraw the table.
@MainActor
final class FrameBox {
    var frames: [Card: CGRect] = [:]
}

/// The cards in your hand, and the drag that throws one onto the table.
///
/// The drag's own state lives here so a card following the finger re-evaluates this row
/// and nothing above it. The screen hears about it through the four closures.
struct HandCards: View {
    let hand: [Card]
    /// The card currently picked, which sits lifted.
    let picked: Card?
    /// What the coach thinks of each card, when it is on.
    var marks: [Card: Coach.Standing] = [:]
    let isMyTurn: Bool
    let stage: Stage
    /// The table's own factor, so the hand is dealt at the size the cloth is drawn at.
    var lift: CGFloat = 1
    /// The coordinate space the table cards report their frames in.
    let space: String
    /// Where each card is sitting, for the table to fly one out of when it is played.
    let frames: FrameBox
    let tap: (Card) -> Void
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

    var body: some View {
        HStack(alignment: .bottom, spacing: stage.pick(tall: 10, wide: 8) * lift) {
            ForEach(Array(hand.enumerated()), id: \.element) { index, card in
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
                y: (dragged == card ? dragOffset.height : 0) + (picked == card ? -14 : 0)
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
            .onTapGesture { tap(card) }
            .gesture(throwGesture(for: card))
            // The face is drawn as shapes, so the label is the only thing VoiceOver has to
            // read. It goes on the tappable view rather than on `CardView`, so the element
            // it names is the one that can be played.
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(card.spoken)
            .accessibilityHint(picked == card ? "Double tap to play it" : "Double tap to pick it up")
    }

    /// Dealt one after another. The delay has to ride on the transition itself: a child's
    /// own `.animation(_:value:)` never drives its insertion.
    private func dealTransition(index: Int) -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.7))
                .animation(.spring(duration: 0.62, bounce: 0.32)
                    .delay(Double(index) * 0.26)),
            removal: .scale(scale: 0.7).combined(with: .opacity)
        )
    }

    /// Flick a card towards the table to play it.
    private func throwGesture(for card: Card) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .named(space))
            .onChanged { value in
                guard isMyTurn else { return }
                if dragged != card {
                    dragged = card
                    pick(card)
                }
                dragOffset = value.translation
                hover(value.location)
            }
            .onEnded { value in
                guard dragged == card else { return }
                dragged = nil
                withAnimation(.spring(duration: 0.3, bounce: 0.25)) { dragOffset = .zero }
                drop(card, value.location, value.translation)
            }
    }
}
