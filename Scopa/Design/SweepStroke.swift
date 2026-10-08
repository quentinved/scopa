import SwiftUI

/// A broom drawn across the cloth, once: a band of bristle streaks crossing from the left
/// edge to the right, kicking gold dust up behind them as they pass.
///
/// It runs with the scopa band, which enters from the same side, so the band reads as
/// having been swept in. Painted on one clock that stops when the last mote is out.
struct SweepStroke: View {
    /// Your own sweep gets the full broom; anyone else's is thinner and paler.
    var mine: Bool
    /// The band's tilt, so the bristles cross the cloth along it.
    var tilt: Double = -6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    @State private var isDone = false

    /// How long the bristles take to cross the screen.
    static let crossing: CGFloat = 0.42
    /// How long a mote of dust lives once it is kicked up.
    static let dustLife: CGFloat = 0.62
    static let length: TimeInterval = 1.15

    private var bristles: Int { mine ? 26 : 12 }
    private var motes: Int { mine ? 34 : 12 }

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation(paused: isDone)) { timeline in
                let age = CGFloat(timeline.date.timeIntervalSince(start))
                Canvas { context, size in
                    guard age < CGFloat(Self.length) else { return }
                    context.blendMode = .plusLighter
                    paintBristles(&context, size: size, age: age)
                    paintDust(&context, size: size, age: age)
                }
            }
            .allowsHitTesting(false)
            .task {
                try? await Task.sleep(for: .seconds(Self.length + 0.05))
                isDone = true
            }
        }
    }

    /// Where the broom's head is across the screen at `progress`: fast off the edge, easing
    /// as it reaches the far side.
    private static func head(_ progress: CGFloat, width: CGFloat) -> CGFloat {
        let eased = 1 - pow(1 - min(max(progress, 0), 1), 2.2)
        return -width * 0.15 + width * 1.3 * eased
    }

    /// When the head passes `x`, the inverse of `head`, so dust rises exactly as it goes by.
    private static func passing(_ x: CGFloat, width: CGFloat) -> CGFloat {
        let fraction = min(max((x + width * 0.15) / (width * 1.3), 0), 1)
        return (1 - pow(1 - fraction, 1 / 2.2)) * crossing
    }

    /// The height of the band of bristles, a little more than the scopa band itself.
    private func reach(_ size: CGSize) -> CGFloat {
        min(size.height * 0.34, 300) * (mine ? 1 : 0.7)
    }

    /// The tilt as a slope, so a bristle at `x` sits on the band's own line.
    private var slope: CGFloat { CGFloat(tan(tilt * .pi / 180)) }

    private func paintBristles(_ context: inout GraphicsContext, size: CGSize, age: CGFloat) {
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        let colours: [Color] = mine ? [Palette.goldLight, Palette.cream, Palette.gold] : [Palette.cream]
        for index in 0..<bristles {
            let seed = Self.seed(index)
            let time = age - seed.lag * 0.09
            guard time > 0 else { continue }
            let progress = time / Self.crossing
            let left = progress < 1 ? 1 : max(0, 1 - (time - Self.crossing) / 0.18)
            guard left > 0.01 else { continue }
            let x = Self.head(progress, width: size.width)
            let trail = size.width * (0.18 + 0.2 * seed.size) * (1 - min(progress, 1) * 0.4)
            let lane = (seed.lane - 0.5) * reach(size)
            let tipY = centre.y + lane + (x - centre.x) * slope
            let tail = CGPoint(x: x - trail, y: tipY - trail * slope)
            let tip = CGPoint(x: x, y: tipY)
            var streak = Path()
            streak.move(to: tail)
            streak.addLine(to: tip)
            let colour = colours[index % colours.count]
            var brush = context
            brush.opacity = Double(left) * (mine ? 0.8 : 0.45)
            brush.stroke(streak, with: .linearGradient(Gradient(colors: [colour.opacity(0), colour]),
                                                       startPoint: tail, endPoint: tip),
                         style: StrokeStyle(lineWidth: (mine ? 1.4 : 1) + 2 * seed.size, lineCap: .round))
        }
    }

    /// Dust kicked up where the bristles pass: thrown on ahead and up a little, slowed by
    /// the air almost at once, and gone.
    private func paintDust(_ context: inout GraphicsContext, size: CGSize, age: CGFloat) {
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        for index in 0..<motes {
            let seed = Self.seed(index + 101)
            let x = size.width * (0.04 + 0.92 * seed.lane)
            let time = age - Self.passing(x, width: size.width)
            guard time > 0, time < Self.dustLife else { continue }
            let y = centre.y + (seed.size - 0.5) * reach(size) * 1.1 + (x - centre.x) * slope
            let carried = (1 - exp(-3.4 * time)) / 3.4
            let at = CGPoint(x: x + size.width * 0.5 * (0.4 + seed.lag) * carried,
                             y: y - size.height * 0.12 * (0.3 + seed.size) * carried + 26 * time * time)
            let radius = (mine ? 1.4 : 1) + 2.2 * seed.lag * (1 - time / Self.dustLife)
            var mote = context
            mote.opacity = Double(pow(1 - time / Self.dustLife, 1.4))
            mote.fill(Circle().path(in: CGRect(x: at.x - radius, y: at.y - radius,
                                               width: radius * 2, height: radius * 2)),
                      with: .color(index.isMultiple(of: 3) ? Palette.cream : Palette.goldLight))
        }
    }

    private struct Seed {
        let lane: CGFloat
        let size: CGFloat
        let lag: CGFloat
    }

    /// Three numbers per bristle from one index, each on its own irrational stride.
    private static func seed(_ index: Int) -> Seed {
        func fract(_ x: CGFloat) -> CGFloat { x - floor(x) }
        let i = CGFloat(index)
        return Seed(lane: fract(i * 0.61803398875 + 0.21), size: fract(i * 0.7548776662 + 0.53),
                    lag: fract(i * 0.38196601125 + 0.07))
    }
}

#Preview("A sweep, yours and theirs") {
    VStack(spacing: 0) {
        SweepStroke(mine: true)
        SweepStroke(mine: false)
    }
    .background { TableGround() }
}
