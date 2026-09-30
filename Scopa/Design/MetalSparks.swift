import SwiftUI

/// Sparks in one metal, thrown out from a point and gone in about a second and a half.
///
/// Painted on one clock, like `FlourishView`'s motes, and the clock stops once the last
/// spark is out, so a burst left on screen costs nothing. Give it a new `id` to throw again.
struct MetalSparks: View {
    let metal: LeagueMetal
    /// Where the burst starts, in unit space.
    var origin: UnitPoint = .center
    var count = 26
    /// How far the sparks fly, as a share of the smaller side.
    var reach: CGFloat = 0.45

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    @State private var isDone = false

    static let length: Double = 1.5

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation(paused: isDone)) { timeline in
                let age = timeline.date.timeIntervalSince(start)
                Canvas { context, size in
                    guard age < Self.length else { return }
                    paint(&context, size: size, age: CGFloat(age))
                }
            }
            .allowsHitTesting(false)
            .task {
                try? await Task.sleep(for: .seconds(Self.length + 0.1))
                isDone = true
            }
        }
    }

    private func paint(_ context: inout GraphicsContext, size: CGSize, age: CGFloat) {
        let from = CGPoint(x: size.width * origin.x, y: size.height * origin.y)
        let span = min(size.width, size.height) * reach
        let colours = [metal.light, .white, metal.base, metal.light]
        let left = 1 - pow(age / CGFloat(Self.length), 2)
        for index in 0..<count {
            let seed = Self.seed(index)
            let time = age - seed.delay * 0.12
            guard time > 0 else { continue }
            let angle = seed.angle * 2 * .pi
            let distance = span * (0.45 + 0.55 * seed.speed)
            let head = Self.position(from: from, angle: angle, distance: distance, span: span, time: time)
            let tail = Self.position(from: from, angle: angle, distance: distance, span: span,
                                     time: max(time - 0.06, 0))
            let width = (1.4 + 2.2 * seed.size) * (1 - time / CGFloat(Self.length) * 0.6)
            var spark = context
            spark.opacity = Double(left)
            var streak = Path()
            streak.move(to: tail)
            streak.addLine(to: head)
            let colour = colours[index % colours.count]
            spark.stroke(streak, with: .color(colour.opacity(0.35)), style: StrokeStyle(lineWidth: width * 3, lineCap: .round))
            spark.stroke(streak, with: .color(colour), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }
    }

    /// Thrown fast, slowed by the air, and pulled down a little as it goes.
    private static func position(from start: CGPoint, angle: CGFloat, distance: CGFloat,
                                 span: CGFloat, time: CGFloat) -> CGPoint {
        let travelled = distance * (1 - exp(-4.2 * time))
        let fall = span * 0.32 * time * time
        return CGPoint(x: start.x + cos(angle) * travelled, y: start.y + sin(angle) * travelled + fall)
    }

    private struct Seed {
        let angle: CGFloat
        let speed: CGFloat
        let size: CGFloat
        let delay: CGFloat
    }

    /// Four numbers per spark from one index, each on its own irrational stride.
    private static func seed(_ index: Int) -> Seed {
        func fract(_ x: CGFloat) -> CGFloat { x - floor(x) }
        let i = CGFloat(index)
        return Seed(angle: fract(i * 0.61803398875 + 0.13), speed: fract(i * 0.7548776662 + 0.41),
                    size: fract(i * 0.5698402909 + 0.07), delay: fract(i * 0.38196601125 + 0.29))
    }
}

#Preview("A burst in every metal") {
    VStack(spacing: 10) {
        ForEach(0..<6, id: \.self) { league in
            ZStack {
                LeagueMedal(league: league, size: 40)
                MetalSparks(metal: .league(league))
            }
            .frame(height: 110)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { TableGround() }
}
