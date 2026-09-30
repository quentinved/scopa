import SwiftUI

/// Your own animal, let off the status row: tap the cloth and it hops over there, tap its
/// empty square in the row and it hops back. Only on this phone: everyone else at the
/// table still sees it beside your seat.
///
/// Positioned in the table's own coordinate space, like `CardFlightLayer`, so it must be
/// laid over the view that names that space. `CompanionView` still draws the animal and
/// takes the pokes; this only carries it about.
struct RoamingCompanion: View {
    let companion: Companion
    let size: CGFloat
    let mood: Companion.Mood
    /// The middle of its square in the status row.
    let home: CGPoint
    /// Where it has been sent. `nil` is home.
    let spot: CGPoint?

    /// Where it is standing. `nil` while it is home, so it follows the row when the row
    /// moves.
    @State private var at: CGPoint?
    /// How far off the cloth it is, mid-hop.
    @State private var hop: CGFloat = 0
    /// Tipped the way it is going. Every animal faces the room, so this is the only thing
    /// that says which way that is.
    @State private var lean: Double = 0
    @State private var isTravelling = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CompanionView(companion: companion, size: size, mood: isTravelling ? .watching : mood)
            .offset(y: -hop)
            .rotationEffect(.degrees(lean), anchor: .bottom)
            .position(at ?? home)
            .animation(.spring(duration: 0.4, bounce: 0.25), value: home)
            .task(id: spot) { await travel() }
    }

    /// From wherever it stands to wherever it was sent. A second tap cancels this and sets
    /// off again from where the last hop put it down.
    private func travel() async {
        let from = at ?? home
        let to = spot ?? home
        let distance = hypot(to.x - from.x, to.y - from.y)
        if distance > 1 {
            isTravelling = true
            withAnimation(.spring(duration: 0.3)) { lean = Double((to.x - from.x) / distance) * 10 }
            if reduceMotion {
                withAnimation(.easeInOut(duration: 0.5)) { at = to }
                try? await Task.sleep(for: .seconds(0.5))
            } else {
                await hops(from: from, to: to, distance: distance)
            }
            guard !Task.isCancelled else { return }
        }
        withAnimation(.spring(duration: 0.35, bounce: 0.4)) { lean = 0 }
        isTravelling = false
        at = spot
    }

    /// A body length a hop, and never more than eight of them: a long way is covered in
    /// longer hops rather than a longer wait.
    private func hops(from: CGPoint, to: CGPoint, distance: CGFloat) async {
        let count = min(max(Int((distance / (size * 1.1)).rounded(.up)), 1), 8)
        for step in 1...count {
            let share = CGFloat(step) / CGFloat(count)
            withAnimation(.easeInOut(duration: 0.22)) {
                at = CGPoint(x: from.x + (to.x - from.x) * share, y: from.y + (to.y - from.y) * share)
            }
            withAnimation(.easeOut(duration: 0.11)) { hop = size * 0.3 }
            try? await Task.sleep(for: .seconds(0.11))
            withAnimation(.easeIn(duration: 0.11)) { hop = 0 }
            try? await Task.sleep(for: .seconds(0.11))
            guard !Task.isCancelled else { return }
        }
    }
}
