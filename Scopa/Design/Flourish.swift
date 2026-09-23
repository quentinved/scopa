import ScopaRewards
import SwiftUI

/// What the table does when somebody sweeps it.
///
/// The band across the cloth is the game's loudest moment and it has only ever done one
/// thing. A flourish is what happens *around* the band: the band still says "Scopa!",
/// because that is the announcement and it is not for sale, and the flourish is the room
/// reacting to it.
///
/// Every one of these is drawn rather than imported — shapes, gradients and a phase — so
/// they cost nothing to ship and can be re-timed without an asset pipeline.
enum Flourish: String, CaseIterable, Codable, Sendable, Identifiable {
    /// The band on its own, which is what the game shipped with.
    case stendardo
    /// Paper confetti, falling and turning.
    case coriandoli
    /// Embers thrown up off the cloth.
    case scintille
    /// A shower of coins, tumbling.
    case pioggia
    /// A ring of gold pushed out from the middle, once.
    case aureola

    var id: String { rawValue }

    static let stored = "flourish"

    /// The ones the shop sells. `stendardo` is never locked.
    static let forSale: [Flourish] = allCases.filter { $0 != .stendardo }

    var title: String {
        switch self {
        case .stendardo: "Stendardo"
        case .coriandoli: "Coriandoli"
        case .scintille: "Scintille"
        case .pioggia: "Pioggia"
        case .aureola: "Aureola"
        }
    }

    /// Written into the ledger with a purchase, so it stays in one language.
    var detail: String {
        switch self {
        case .stendardo: "The band on its own"
        case .coriandoli: "Paper confetti over the table"
        case .scintille: "Embers off the cloth"
        case .pioggia: "A shower of denari"
        case .aureola: "A ring of gold, pushed out once"
        }
    }

    var explanation: LocalizedStringKey {
        switch self {
        case .stendardo: "Just the band"
        case .coriandoli: "Paper, falling"
        case .scintille: "Embers, rising"
        case .pioggia: "It rains denari"
        case .aureola: "One ring of gold"
        }
    }

    var grade: Grade {
        switch self {
        case .stendardo: .comune
        case .coriandoli, .scintille: .raro
        case .pioggia: .prezioso
        case .aureola: .leggendario
        }
    }

    /// How much money the shop asks. Nil for the one everybody has.
    var price: Denari? {
        switch self {
        case .stendardo: nil
        case .coriandoli: 220
        case .scintille: 220
        case .pioggia: 480
        case .aureola: 900
        }
    }
}

/// A flourish, played once over the whole table.
///
/// It runs off a single `phase` driven from 0 to 1 by one animation, rather than a timer
/// per mote: forty independent animations is forty things that can be left running when
/// the banner leaves, and one is one. The motes are laid out from a seeded generator so a
/// sweep looks the same every time it is replayed in a preview and different between the
/// five flourishes.
struct FlourishView: View {
    var flourish: Flourish
    /// Where the sweep happened, so the burst has somewhere to come from. Unit space.
    var origin: UnitPoint = .center

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    fileprivate static let count = 34

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                switch flourish {
                case .stendardo: EmptyView()
                case .coriandoli: motes(in: size, kind: .paper)
                case .scintille: motes(in: size, kind: .ember)
                case .pioggia: motes(in: size, kind: .coin)
                case .aureola: if !reduceMotion { Aureola(origin: origin) }
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear {
            // The aureola keeps its own clock; see `Aureola`.
            guard !reduceMotion, flourish != .stendardo, flourish != .aureola else { return }
            withAnimation(.easeOut(duration: 2.1)) { phase = 1 }
        }
    }

    // MARK: The motes

    private enum Mote { case paper, ember, coin }

    private func motes(in size: CGSize, kind: Mote) -> some View {
        ForEach(0..<Self.count, id: \.self) { index in
            let seed = Self.seeds(index)
            mote(kind, seed: seed)
                .position(place(seed, kind: kind, in: size))
                .rotationEffect(.degrees(seed.spin * 720 * phase))
                .opacity(fade(kind))
        }
    }

    @ViewBuilder private func mote(_ kind: Mote, seed: Seed) -> some View {
        switch kind {
        case .paper:
            RoundedRectangle(cornerRadius: 1)
                .fill(Self.confettiColours[Int(seed.tint * 5) % 5])
                .frame(width: 6 + seed.scale * 5, height: 9 + seed.scale * 7)
                // Turned about its own short axis as it falls, which is what makes paper
                // read as paper rather than as a falling rectangle.
                .rotation3DEffect(.degrees(seed.spin * 900 * phase), axis: (x: 1, y: 0.3, z: 0))
        case .ember:
            Circle()
                .fill(RadialGradient(colors: [.white, Palette.goldLight, Palette.terracotta.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: 5 + seed.scale * 4))
                .frame(width: 8 + seed.scale * 7, height: 8 + seed.scale * 7)
                .blur(radius: 0.6)
        case .coin:
            DenariMark(size: 13 + seed.scale * 9)
                // Flipping edge-on and back, so a shower reads as coins turning.
                .rotation3DEffect(.degrees(seed.spin * 1080 * phase), axis: (x: 0.2, y: 1, z: 0))
        }
    }

    /// Where a mote is at the current phase. Paper and coins fall from above the top edge;
    /// embers are thrown up out of the sweep and slow as they rise.
    private func place(_ seed: Seed, kind: Mote, in size: CGSize) -> CGPoint {
        let x: CGFloat
        let y: CGFloat
        switch kind {
        case .paper, .coin:
            let drift = sin((seed.offset + phase) * .pi * 2) * 26
            x = seed.across * size.width + drift
            y = -60 + (size.height + 140) * Self.eased(phase, delay: seed.offset * 0.35)
        case .ember:
            let rise = Self.eased(phase, delay: seed.offset * 0.3)
            let spread = (seed.across - 0.5) * size.width * 0.9
            x = origin.x * size.width + spread * rise
            // Decelerating rather than linear: an ember is thrown, not dropped.
            y = origin.y * size.height - size.height * 0.55 * (1 - pow(1 - rise, 2.2))
        }
        return CGPoint(x: x, y: y)
    }

    /// Paper and coins are gone by the time they reach the bottom; embers burn out early.
    private func fade(_ kind: Mote) -> Double {
        switch kind {
        case .paper, .coin: phase < 0.75 ? 1 : max(0, 1 - (phase - 0.75) / 0.25)
        case .ember: phase < 0.45 ? 1 : max(0, 1 - (phase - 0.45) / 0.55)
        }
    }

    // MARK: The seeded scatter

    fileprivate struct Seed {
        /// Across the table, 0 to 1.
        let across: CGFloat
        /// How far into the flourish this one starts.
        let offset: CGFloat
        let scale: CGFloat
        let spin: CGFloat
        let tint: CGFloat
    }

    /// Five numbers per mote from one index, each on its own irrational stride so they do
    /// not march together. Cheaper and steadier than seeding a generator per view.
    fileprivate static func seeds(_ index: Int) -> Seed {
        func fract(_ x: CGFloat) -> CGFloat { x - floor(x) }
        let i = CGFloat(index)
        return Seed(across: fract(i * 0.61803398875),
                    offset: fract(i * 0.38196601125 + 0.37),
                    scale: fract(i * 0.7548776662 + 0.11),
                    spin: fract(i * 0.5698402909 + 0.83) * 2 - 1,
                    tint: fract(i * 0.4301597090 + 0.29))
    }

    /// The phase this mote is at, once its own delay is taken off and the rest re-spread
    /// over what is left.
    fileprivate static func eased(_ phase: CGFloat, delay: CGFloat) -> CGFloat {
        guard delay < 1 else { return 0 }
        return min(max((phase - delay) / (1 - delay), 0), 1)
    }

    private static let confettiColours: [Color] = [
        Palette.goldLight, Palette.terracotta, Palette.cream,
        Color(red: 0.400, green: 0.749, blue: 0.702), Color(red: 0.706, green: 0.400, blue: 0.741),
    ]
}

/// The `leggendario` flourish: gold, pushed out from where the sweep landed.
///
/// The top grade is the one that does the least, and for a long time it did too
/// little: two hairline circles over nine tenths of a second, which is less happening
/// than the `prezioso` below it and over before anybody has looked up. What it is has
/// not changed — one ring, gold, pushed out once — but a `leggendario` has to survive
/// being looked at, so the one ring is now struck rather than merely drawn.
///
/// Five things, all off the one phase, each with its own delay and its own curve:
/// the strike it leaves from, three rings travelling out on a stagger, the spokes the
/// first one throws, gold riding the wavefront, and the dust it leaves behind. The
/// stagger is what makes it read as one event rather than five: nothing here starts
/// on its own, everything starts because the first thing did.
///
/// Painted into one `Canvas` on its own clock rather than built from views. As views it
/// was three blurred rings each larger than the screen, a blurred fan of spokes and
/// thirty-four gradient motes, every one blended onto the table on its own, so each frame
/// paid a dozen full-screen offscreen passes and stuttered on a real phone. It also never
/// played its own curves: an animated `@State` is only interpolated between its two ends,
/// so the thrown ring travelled at an even pace. Here every frame is worked out from the
/// real phase, and a faint wide stroke under each band stands in for the blur.
private struct Aureola: View {
    var origin: UnitPoint

    @State private var start = Date.now
    @State private var isDone = false

    private static let length: TimeInterval = 1.9
    /// How many rings leave, and how far apart they leave.
    private static let rings = 3
    private static let ringStagger: CGFloat = 0.1

    var body: some View {
        TimelineView(.animation(paused: isDone)) { timeline in
            let phase = CGFloat(min(timeline.date.timeIntervalSince(start) / Self.length, 1))
            Canvas { context, size in
                paint(&context, size: size, phase: phase)
            }
        }
        .blendMode(.plusLighter)
        // Stops the clock once it has all faded, so a banner that lingers costs nothing.
        .task {
            try? await Task.sleep(for: .seconds(Self.length + 0.1))
            isDone = true
        }
    }

    private func paint(_ context: inout GraphicsContext, size: CGSize, phase: CGFloat) {
        guard phase < 1 else { return }
        let reach = max(size.width, size.height) * 1.35
        let centre = CGPoint(x: origin.x * size.width, y: origin.y * size.height)
        context.blendMode = .plusLighter
        spokes(&context, at: centre, reach: reach, phase: phase)
        for index in 0..<Self.rings {
            wave(&context, index, at: centre, reach: reach, phase: phase)
        }
        gilding(&context, at: centre, reach: reach, phase: phase)
        bloom(&context, at: centre, reach: reach, phase: phase)
    }

    /// Where a ring of this age has got to, and how much of it is left.
    ///
    /// Thrown rather than dragged: nearly all the distance is covered early and the last
    /// of it is crossed slowly, which is what a shockwave does and what an evenly
    /// expanding circle conspicuously does not.
    private func front(_ phase: CGFloat, delay: CGFloat) -> (travel: CGFloat, life: CGFloat) {
        let age = FlourishView.eased(phase, delay: delay)
        return (1 - pow(1 - age, 2.6), age)
    }

    private func circle(_ centre: CGPoint, diameter: CGFloat) -> CGRect {
        CGRect(x: centre.x - diameter / 2, y: centre.y - diameter / 2, width: diameter, height: diameter)
    }

    /// The strike: a flare at the sweep itself, over inside the first fifth. Without it
    /// the rings read as having always been travelling rather than as having been pushed
    /// out of something.
    private func bloom(_ context: inout GraphicsContext, at centre: CGPoint, reach: CGFloat, phase: CGFloat) {
        let age = min(phase / 0.26, 1)
        let left = pow(1 - age, 1.6)
        guard left > 0.002 else { return }
        let width = reach * (0.05 + 0.3 * age)
        context.fill(Circle().path(in: circle(centre, diameter: width)),
                     with: .radialGradient(Gradient(colors: [.white.opacity(left),
                                                             Palette.goldLight.opacity(left * 0.7),
                                                             Palette.goldLight.opacity(0)]),
                                           center: centre, startRadius: 0, endRadius: width / 2))
    }

    /// One ring. The gradient runs round it rather than across it, so the band catches the
    /// light in two places the way a struck rim does and never reads as a flat outline.
    private func wave(_ context: inout GraphicsContext, _ index: Int, at centre: CGPoint,
                      reach: CGFloat, phase: CGFloat) {
        let (travel, life) = front(phase, delay: CGFloat(index) * Self.ringStagger)
        let width = reach * travel
        let left = pow(1 - life, 1.7)
        guard width > 1, left > 0.002 else { return }
        let weight = (17 - CGFloat(index) * 5) * left + 1.2
        let rim = GraphicsContext.Shading.conicGradient(Gradient(colors: Self.rim), center: centre)
        // Inset by half the weight, as `strokeBorder` would, so the band ends at the front.
        let band = Circle().path(in: circle(centre, diameter: width).insetBy(dx: weight / 2, dy: weight / 2))
        var halo = context
        halo.opacity = Double(left) * 0.3
        halo.stroke(band, with: rim, lineWidth: weight * 2.2 + 4 + CGFloat(index) * 2)
        var lit = context
        lit.opacity = Double(left)
        lit.stroke(band, with: rim, lineWidth: weight)
        // A white hairline just inside the band, which is the edge of the light rather
        // than the light itself and is what keeps it from going woolly.
        let hair = weight * 0.28 + 0.8
        let inner = circle(centre, diameter: width * 0.955).insetBy(dx: hair / 2, dy: hair / 2)
        context.stroke(Circle().path(in: inner), with: .color(.white.opacity(Double(left) * 0.75)), lineWidth: hair)
    }

    /// Gold on the wavefront: motes carried out on the first ring and thinning behind it,
    /// so the ring arrives as something rather than as a line.
    private func gilding(_ context: inout GraphicsContext, at centre: CGPoint, reach: CGFloat, phase: CGFloat) {
        let (travel, life) = front(phase, delay: 0)
        let left = phase < 0.55 ? 1 : max(0, 1 - (phase - 0.55) / 0.45)
        let alpha = Double(left * pow(1 - life, 0.7))
        guard alpha > 0.002 else { return }
        for index in 0..<FlourishView.count {
            let seed = FlourishView.seeds(index)
            // Each mote sits a little short of or beyond the front, so the edge is a band
            // of gold rather than a wire with beads threaded on it.
            let radius = reach / 2 * travel * (0.74 + seed.scale * 0.34)
            let angle = seed.across * 2 * .pi
            let at = CGPoint(x: centre.x + cos(angle) * radius, y: centre.y + sin(angle) * radius)
            context.fill(Circle().path(in: circle(at, diameter: 5 + seed.scale * 8)),
                         with: .radialGradient(Gradient(colors: [.white.opacity(alpha),
                                                                 Palette.goldLight.opacity(alpha),
                                                                 Palette.goldLight.opacity(0)]),
                                               center: at, startRadius: 0, endRadius: 3 + seed.scale * 5))
        }
    }

    /// Twelve rays thrown out with the first ring and gone well before it is. They are the
    /// part that says the ring was struck: a wave on its own spreads, a struck thing
    /// throws light off in every direction first.
    private func spokes(_ context: inout GraphicsContext, at centre: CGPoint, reach: CGFloat, phase: CGFloat) {
        let (travel, _) = front(phase, delay: 0)
        let left = pow(max(0, 1 - phase / 0.62), 1.5)
        let outer = reach / 2 * travel
        let length = outer * 0.42
        guard left > 0.002, length > 0.5 else { return }
        let shading = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [Palette.goldLight.opacity(0), Palette.goldLight]),
            startPoint: CGPoint(x: 0, y: -outer), endPoint: CGPoint(x: 0, y: -outer + length))
        for index in 0..<12 {
            var ray = context
            ray.translateBy(x: centre.x, y: centre.y)
            ray.rotate(by: .degrees(Double(index) * 30))
            // A wide faint one under a thin bright one, which is what the blur was for.
            ray.opacity = Double(left) * 0.3
            ray.fill(Capsule().path(in: CGRect(x: -4, y: -outer, width: 8, height: length)), with: shading)
            ray.opacity = Double(left) * 0.85
            ray.fill(Capsule().path(in: CGRect(x: -1.5, y: -outer, width: 3, height: length)), with: shading)
        }
    }

    /// The colours round a ring's rim. Two bright places rather than one, because a rim
    /// lit from a single side reads as a badly drawn sphere.
    private static let rim: [Color] = [
        Palette.gold, Palette.goldLight, .white, Palette.goldLight,
        Palette.goldDeep, Palette.goldLight, .white, Palette.goldLight, Palette.gold,
    ]
}

#Preview("Flourishes") {
    ZStack {
        TableGround()
        FlourishView(flourish: .coriandoli)
    }
}
