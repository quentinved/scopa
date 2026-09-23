import SwiftUI

/// Half of the goals row: today's deal on the left, the week on the right.
///
/// The two were a card each, stacked, and together they took more of the lobby than the
/// four doors under them. Halved and set on one row they still answer what today is and
/// how far through the week you are.
///
/// A shape rather than a view of its own: the deal and the week keep their own words, marks
/// and way in, and share only the geometry, so the two tiles line up.
struct GoalTile<Mark: View, Stat: View, Foot: View>: View {
    @Environment(\.lift) private var lift
    /// The name of the thing, in two lines at most. `Text` rather than a key so the week
    /// can hand over a goal's own title.
    let title: Text
    var tint: Color? = nil
    /// Set where the tile is wrapped in a button, so the glass answers a press.
    var interactive = false
    /// Top left: what it is, at a glance. A play coin, a symbol, a score.
    @ViewBuilder var mark: Mark
    /// Top right: the one figure worth carrying at this size.
    @ViewBuilder var stat: Stat
    /// The foot: a line of small print, or a bar. Kept to one height so both tiles have
    /// their last row on the same line.
    @ViewBuilder var foot: Foot

    var body: some View {
        VStack(alignment: .leading, spacing: 0 * lift) {
            HStack(spacing: 8 * lift) {
                mark
                Spacer(minLength: 4 * lift)
                stat
            }
            .frame(height: 30 * lift)
            Spacer(minLength: 8 * lift)
            title
                .font(.system(size: 13 * lift, weight: .semibold))
                .foregroundStyle(Palette.onTable)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 5 * lift)
            foot.frame(height: 14 * lift)
        }
        // Both halves stretch to whichever of them is taller, which is the week whenever
        // its goal takes two lines. Without this the row is a step.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 12 * lift)
        .padding(.vertical, 11 * lift)
        .glassPanel(radius: GlassRadius.panel, tint: tint, interactive: interactive)
    }
}
