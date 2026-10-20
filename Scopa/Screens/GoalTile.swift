import SwiftUI

/// A third of the "Today" row: today's deal, the week, and the wheel, side by side.
///
/// The deal and the week were a card each, stacked, and together they took more of the
/// lobby than the doors under them. Halved they still took a row of their own while the
/// wheel floated by the logo as an unlabelled coin. A row of three says what today holds in
/// one glance, each tile with its name on it.
///
/// A shape rather than a view of its own: each tile keeps its own words, marks and way in,
/// and shares only the geometry, so the three line up.
struct GoalTile<Mark: View, Stat: View, Foot: View>: View {
    @Environment(\.lift) private var lift
    /// The name of the thing, in two lines at most. `Text` rather than a key so the week
    /// can hand over a goal's own title.
    let title: Text
    var tint: Color? = nil
    /// Top left: what it is, at a glance. A play coin, a symbol, a score.
    @ViewBuilder var mark: Mark
    /// Top right: the one figure worth carrying at this size.
    @ViewBuilder var stat: Stat
    /// The foot: a line of small print, or a bar. Kept to one height so every tile has
    /// its last row on the same line.
    @ViewBuilder var foot: Foot

    var body: some View {
        VStack(alignment: .leading, spacing: 0 * lift) {
            HStack(spacing: 6 * lift) {
                mark
                Spacer(minLength: 2 * lift)
                stat
            }
            .frame(height: 28 * lift)
            Spacer(minLength: 6 * lift)
            title
                .font(.system(size: 13 * lift, weight: .semibold))
                .foregroundStyle(Palette.onTable)
                .lineLimit(2)
                // A goal in Italian runs to three lines at a third of the row.
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4 * lift)
            foot.frame(height: 14 * lift)
        }
        // Every tile stretches to the tallest, which is the week whenever its goal takes
        // two lines. Without this the row is a staircase.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 10 * lift)
        .padding(.vertical, 10 * lift)
        .glassPanel(radius: GlassRadius.panel, tint: tint)
    }
}
