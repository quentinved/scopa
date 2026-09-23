import SwiftUI

/// A laurel around the seat, worn for a week by anyone who finished the week's challenge.
///
/// It expires and it has to sit around whatever mark the player picked, so it overflows
/// its frame and never changes the layout. Two sprigs rather than a closed ring: at the
/// twenty-six points it is drawn at on a table, a full ring reads as a smudge.
///
/// The leaf shape is `Leaf`, shared with the batons suit so the two cannot drift apart.
struct HonourWreath: View {
    var size: CGFloat
    /// Glows for the moment it is won, off at every other table.
    var isFresh = false

    /// How far past the circle it reaches, for callers with tight neighbours.
    static let reach: CGFloat = 1.42

    var body: some View {
        ZStack {
            branch.scaleEffect(x: -1)
            branch
        }
        .frame(width: size * Self.reach, height: size * Self.reach)
        .shadow(color: Palette.goldDeep.opacity(0.45), radius: size * 0.03, y: size * 0.015)
        .shadow(color: isFresh ? Palette.goldLight.opacity(0.7) : .clear, radius: size * 0.30)
    }

    /// One side of the laurel: five leaves climbing an arc, smallest at the top.
    private var branch: some View {
        let leaves = 5
        return ZStack {
            ForEach(0..<leaves, id: \.self) { index in
                // Just past horizontal up to near the crown, so the gap sits over the top.
                let t = Double(index) / Double(leaves - 1)
                let angle = 112.0 - t * 76.0
                Leaf()
                    .fill(Palette.goldSheen)
                    .frame(width: size * (0.15 - t * 0.035), height: size * (0.32 - t * 0.085))
                    // Swept along the arc: leaves on the radius read as a sunburst.
                    .rotationEffect(.degrees(-56))
                    .offset(y: -size * 0.58)
                    .rotationEffect(.degrees(angle))
            }
        }
    }
}

#Preview {
    HStack(spacing: 30) {
        SeatBadge(name: "Quentin", tint: Palette.seat(0), size: 30, honoured: true)
        SeatBadge(name: "Hugo", tint: Palette.seat(1), size: 54, mark: .crown, honoured: true)
        SeatBadge(name: "Lina", tint: Palette.seat(2), size: 84, honoured: true)
    }
    .padding(60)
    .background(TableGround())
}
