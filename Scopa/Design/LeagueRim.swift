import SwiftUI

/// The edge a league wears.
///
/// `LeagueMedal` says a grade with a disc. This says the same thing with a border, so a
/// plate, a tile or a row can carry its league without a second medal pinned to it — which
/// is what the lobby wanted once the head count came off the masthead and the grade was
/// left to speak for itself.
///
/// The steps are `LeagueRank`'s and each keeps what the one below earned: a struck line,
/// then a milled outer, a ring set inside it, beading on the ring, a halo, and, at the top,
/// light turning behind the whole edge.
struct LeagueRim<S: InsettableShape>: View {
    /// The shape the rim goes round. The same one the glass under it was cut to, or the
    /// two edges will not sit concentric.
    let shape: S
    /// Bronze is 0 and Maestro 5, as the ladder counts. Anything outside that is struck.
    let league: Int
    /// Scales every line with the thing the rim goes round. 1 suits a chip on a phone.
    var weight: CGFloat = 1

    private var metal: LeagueMetal { .league(league) }
    private var rank: LeagueRank { .league(league) }
    /// Diamond and Maestro turn their light rather than standing still.
    private var turns: Bool { rank >= .set }

    /// Set on arrival rather than in the initial value, so the turn is a change to animate
    /// from instead of a state the view is simply born in.
    @State private var turning = false

    var body: some View {
        ZStack {
            edge
            if rank >= .milled { milling }
            if rank >= .ringed { innerRing }
            if rank >= .studded { beading }
        }
        .compositingGroup()
        .shadow(color: halo, radius: 7 * weight)
        // The rim is drawn over a control, so it must not take the press.
        .allowsHitTesting(false)
        .onAppear { turning = true }
    }

    /// The line itself: flat metal at the bottom of the ladder, lit metal from gold up, and
    /// a sheen that turns at the top of it.
    ///
    /// The turning leagues keep a solid line under the sweep. Without it the edge is only as
    /// bright as wherever the cone happens to be pointing, and a rim that is faint in three
    /// places with beads on it reads as a dashed border rather than as metal.
    @ViewBuilder private var edge: some View {
        if turns {
            ZStack {
                shape.strokeBorder(metal.base.opacity(0.85), lineWidth: 1.6 * weight)
                sweep.mask { shape.strokeBorder(lineWidth: 1.6 * weight) }.opacity(0.9)
            }
        } else if rank >= .ringed {
            shape.strokeBorder(metal.sheen, lineWidth: 1.5 * weight)
        } else {
            shape.strokeBorder(metal.base.opacity(0.9), lineWidth: 1.3 * weight)
        }
    }

    /// A cone of the metal's own light, turning once every nine seconds. Scaled well past
    /// the frame so a corner is never left uncovered wherever the cone happens to point.
    private var sweep: some View {
        AngularGradient(colors: [metal.dark, metal.base, metal.light, metal.base,
                                 metal.dark, metal.base, metal.light, metal.base, metal.dark],
                        center: .center)
            .scaleEffect(2.6)
            .rotationEffect(.degrees(turning ? 360 : 0))
            .animation(.linear(duration: 9).repeatForever(autoreverses: false), value: turning)
    }

    /// The knurled outer of a milled coin: fine ticks just inside the edge, close enough
    /// together to read as a texture. Loosen them and the rim reads as a dotted outline,
    /// which is what a disabled control wears.
    ///
    /// Drawn on the inset shape rather than outside the frame, so a rim never moves a layout.
    private var milling: some View {
        shape.inset(by: 2 * weight)
            .stroke(metal.light.opacity(0.22),
                    style: StrokeStyle(lineWidth: 0.6 * weight, dash: [0.7 * weight, 1.1 * weight]))
    }

    private var innerRing: some View {
        shape.inset(by: 3.8 * weight)
            .stroke(metal.dark.opacity(0.55), lineWidth: 0.7 * weight)
    }

    /// Beads set along the ring: the same dashed stroke with round caps and nothing but
    /// gaps between them, which draws a dot and not a dash. Small and well spaced, so they
    /// read as studs set into the edge and never as the edge itself.
    private var beading: some View {
        shape.inset(by: 3.8 * weight)
            .stroke(metal.light.opacity(0.65),
                    style: StrokeStyle(lineWidth: 1.8 * weight, lineCap: .round,
                                       dash: [0.01, 11 * weight]))
    }

    /// Light thrown past the edge, at the two leagues whose medal has a stone in it.
    private var halo: Color {
        switch rank {
        case .crowned: (metal.halo ?? metal.light).opacity(0.5)
        case .set: metal.stone.opacity(0.45)
        default: .clear
        }
    }
}

#Preview("Every grade of edge") {
    VStack(spacing: 18) {
        ForEach(0..<6, id: \.self) { league in
            HStack(spacing: 14) {
                LeagueMedal(league: league, size: 30)
                Text(verbatim: ["Bronze", "Silver", "Gold", "Platinum", "Diamond", "Maestro"][league])
                    .font(.system(size: 14, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .foregroundStyle(Palette.onTable)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(width: 260)
            .glassPanel(radius: GlassRadius.control, hairline: false)
            .overlay {
                LeagueRim(shape: RoundedRectangle(cornerRadius: GlassRadius.control, style: .continuous),
                          league: league)
            }
        }
    }
    .padding(30)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { TableGround() }
}
