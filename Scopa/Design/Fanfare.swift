import ScopaRewards
import SwiftUI

/// How big a moment something turning over is: the card's rarity, or a shelf's grade, as
/// the length of the wait before it turns and how much it throws off when it does.
///
/// The wait is the tell. A numeral is face down for a breath; a court gathers a light the
/// colour of its rarity; a seven shakes in your hand; the settebello darkens the room and
/// leaks gold at the edges before it goes over. Anyone who has opened three packs knows
/// what is coming before it comes, which is the part worth waiting for.
enum Fanfare: Int, Comparable, CaseIterable {
    case quiet, bright, grand, crowning

    static func < (a: Fanfare, b: Fanfare) -> Bool { a.rawValue < b.rawValue }

    init(_ rarity: Rarity) {
        switch rarity {
        case .plain: self = .quiet
        case .court: self = .bright
        case .prime: self = .grand
        case .settebello: self = .crowning
        }
    }

    init(_ grade: Grade) {
        switch grade {
        case .comune: self = .quiet
        case .raro: self = .bright
        case .prezioso: self = .grand
        case .leggendario: self = .crowning
        }
    }

    /// How long it stays face down, gathering itself.
    var gathering: Duration {
        switch self {
        case .quiet: .milliseconds(260)
        case .bright: .milliseconds(620)
        case .grand: .milliseconds(1000)
        case .crowning: .milliseconds(1650)
        }
    }

    /// Sparks thrown off as it turns.
    var sparks: Int {
        switch self {
        case .quiet: 0
        case .bright: 22
        case .grand: 38
        case .crowning: 56
        }
    }

    /// Coins among them, spinning as they fall. Only the top two pay out in metal.
    var coins: Int {
        switch self {
        case .quiet, .bright: 0
        case .grand: 5
        case .crowning: 22
        }
    }

    /// How far it shakes at the end of the wait, in points.
    var tremble: CGFloat {
        switch self {
        case .quiet, .bright: 0
        case .grand: 2.2
        case .crowning: 4.5
        }
    }
}

// MARK: Sparks

/// A handful of sparks and coins thrown off something turning over, falling once and gone.
///
/// One Canvas drawn on the display clock for a second and a half and then removed, so
/// nothing is left ticking behind the card. Under Reduce Motion it is not drawn at all.
struct SparkBurst: View {
    var sparks: Int
    var coins: Int = 0
    var palette: [Color]
    /// How hard they are thrown, in points a second.
    var force: CGFloat = 520
    var seed: UInt64 = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var began: Date?
    @State private var flecks: [Fleck] = []

    static let life: TimeInterval = 1.7

    var body: some View {
        if !reduceMotion, sparks + coins > 0, began.map({ Date.now.timeIntervalSince($0) < Self.life }) ?? true {
            // Capped at 60: a ProMotion screen would otherwise draw it twice as often for
            // nothing anybody could see in a second and a half. Drawn on the GPU, because on
            // the CPU each frame is a fresh bitmap the size of the screen to upload.
            // Hung off a point rather than laid out: a canvas wider than the screen in the
            // layout made the screen wider for as long as it was there, and the table's
            // whole ground was baked again at the new size, twice a burst.
            Color.clear
                .frame(width: 1, height: 1)
                .overlay {
                    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                        Canvas { context, size in
                            let age = began.map { timeline.date.timeIntervalSince($0) } ?? 0
                            for fleck in flecks { fleck.draw(in: &context, size: size, age: age) }
                        }
                    }
                    .frame(width: 760, height: 900)
                    .drawingGroup()
                }
                .allowsHitTesting(false)
                .task { await fly() }
        }
    }

    private func fly() async {
        var generator = SeededGenerator(seed: seed)
        flecks = (0..<(sparks + coins)).map { index in
            Fleck(isCoin: index < coins, colour: palette[index % max(palette.count, 1)],
                  force: force, using: &generator)
        }
        began = .now
        try? await Task.sleep(for: .seconds(Self.life))
        // Re-evaluated as expired, which takes the Canvas and its clock away.
        began = .distantPast
    }

    /// One spark or coin: where it is thrown, how hard, and how it turns as it goes.
    struct Fleck {
        let isCoin: Bool
        let colour: Color
        let angle: Double
        let speed: CGFloat
        let size: CGFloat
        let spin: Double
        let delay: Double

        init(isCoin: Bool, colour: Color, force: CGFloat, using generator: inout SeededGenerator) {
            self.isCoin = isCoin
            self.colour = colour
            // Thrown mostly upwards and outwards, as if off the face of the card.
            angle = -.pi / 2 + Double.random(in: -.pi * 0.85 ... .pi * 0.85, using: &generator)
            speed = force * CGFloat.random(in: 0.35...1, using: &generator)
            size = isCoin ? CGFloat.random(in: 13...18, using: &generator)
                          : CGFloat.random(in: 3.5...8, using: &generator)
            spin = Double.random(in: 5...14, using: &generator)
            delay = Double.random(in: 0...0.12, using: &generator)
        }

        func draw(in context: inout GraphicsContext, size canvas: CGSize, age: TimeInterval) {
            let t = age - delay
            guard t > 0, t < SparkBurst.life else { return }
            // Air slows them, then they fall.
            let carried = (1 - exp(-2.6 * t)) / 2.6
            let x = canvas.width / 2 + cos(angle) * speed * carried
            let y = canvas.height / 2 + sin(angle) * speed * carried + 0.5 * 520 * t * t
            let fade = 1 - pow(t / SparkBurst.life, 2.2)
            context.opacity = fade
            if isCoin { drawCoin(in: &context, at: CGPoint(x: x, y: y), t: t) }
            else { drawSpark(in: &context, at: CGPoint(x: x, y: y), t: t) }
        }

        /// A four-pointed glint that twinkles as it falls.
        private func drawSpark(in context: inout GraphicsContext, at point: CGPoint, t: Double) {
            let r = size * (0.75 + 0.25 * sin(t * spin * 2))
            var star = Path()
            for i in 0..<8 {
                let a = Double(i) * .pi / 4 + t * spin * 0.3
                let reach = i.isMultiple(of: 2) ? r : r * 0.28
                let p = CGPoint(x: point.x + cos(a) * reach, y: point.y + sin(a) * reach)
                i == 0 ? star.move(to: p) : star.addLine(to: p)
            }
            star.closeSubpath()
            context.fill(star, with: .color(colour))
        }

        /// A denaro, turning over in the air: its width is the cosine of its spin, and it
        /// catches the light as it comes face on.
        private func drawCoin(in context: inout GraphicsContext, at point: CGPoint, t: Double) {
            let turn = max(abs(cos(t * spin)), 0.14)
            let rect = CGRect(x: point.x - size / 2 * turn, y: point.y - size / 2,
                              width: size * turn, height: size)
            let face = Path(ellipseIn: rect)
            context.fill(face, with: .linearGradient(
                Gradient(colors: [Palette.cream, Palette.goldLight, Palette.gold]),
                startPoint: rect.origin, endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
            context.stroke(face, with: .color(Palette.goldDeep), lineWidth: 1)
            let inner = rect.insetBy(dx: rect.width * 0.24, dy: rect.height * 0.24)
            context.stroke(Path(ellipseIn: inner), with: .color(Palette.goldDeep.opacity(0.55)),
                           lineWidth: 0.8)
            if turn > 0.8 {
                let glint = CGRect(x: rect.minX + rect.width * 0.22, y: rect.minY + rect.height * 0.18,
                                   width: size * 0.2, height: size * 0.2)
                context.fill(Path(ellipseIn: glint), with: .color(.white.opacity(0.85)))
            }
        }
    }
}

/// SplitMix64: the same burst for the same seed, so two runs of a screenshot agree.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: Rings and light

/// A ring thrown out from where something landed, once.
struct Shockwave: View {
    var tint: Color
    var size: CGFloat
    var delay: Double = 0

    @State private var out = false
    @State private var gone = false

    var body: some View {
        if !gone {
            Circle()
                .strokeBorder(tint, lineWidth: out ? 1 : 7)
                .frame(width: size, height: size)
                .scaleEffect(out ? 2.5 : 0.35)
                .opacity(out ? 0 : 0.9)
                .allowsHitTesting(false)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.8).delay(delay)) { out = true } completion: {
                        gone = true
                    }
                }
        }
    }
}

/// A band of light across a card face: once on its own as the card lands, and then
/// wherever the card is tilted to.
///
/// `glance` is the tilt, -1 to 1 across; at rest the band is out of sight beyond the edge.
struct FoilGlare: View {
    var fanfare: Fanfare
    var tint: Color
    var glance: CGFloat
    var radius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep: CGFloat = -1.4
    @State private var swept = false

    // Each band is only there while it is moving. A blended layer left over the card
    // makes the compositor re-blend the face every frame the rays behind it turn.
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                if !swept, !reduceMotion { band(in: proxy.size, at: sweep) }
                if glance != 0 {
                    band(in: proxy.size, at: glance * 1.1)
                        .opacity(min(abs(glance) * 1.6, 1))
                }
            }
        }
        .clipShape(.rect(cornerRadius: radius))
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.95).delay(0.1)) { sweep = 1.4 } completion: {
                swept = true
            }
        }
    }

    /// The band with its middle `position` card-widths from the middle of the card.
    private func band(in size: CGSize, at position: CGFloat) -> some View {
        LinearGradient(colors: colours, startPoint: .leading, endPoint: .trailing)
            .frame(width: size.width * 0.62, height: size.height * 1.6)
            .rotationEffect(.degrees(22))
            .offset(x: size.width * (0.19 + position), y: -size.height * 0.3)
            .blendMode(.plusLighter)
    }

    private var colours: [Color] {
        switch fanfare {
        case .quiet:
            [.clear, .white.opacity(0.28), .clear]
        case .bright:
            [.clear, tint.opacity(0.28), .white.opacity(0.5), tint.opacity(0.28), .clear]
        case .grand, .crowning:
            // A little of the rainbow a foil card has, warmed toward the rarity.
            [.clear, Color(red: 0.55, green: 0.8, blue: 1).opacity(0.3), tint.opacity(0.45),
             .white.opacity(0.65), Color(red: 1, green: 0.62, blue: 0.75).opacity(0.3), .clear]
        }
    }
}
