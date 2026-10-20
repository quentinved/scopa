import SwiftUI
import ScopaCore

/// The glazes a Vietri or Caltagirone painter works from: a tin-white ground, cobalt,
/// saffron, copper green, iron orange, and manganese for the line.
enum MaiolicaPaint {
    static let tin = Color(red: 0.969, green: 0.953, blue: 0.910)
    /// Where the tin ran thick in the kiln and greyed.
    static let tinPool = Color(red: 0.890, green: 0.870, blue: 0.812)
    static let cobalt = Color(red: 0.122, green: 0.255, blue: 0.612)
    static let cobaltDeep = Color(red: 0.067, green: 0.153, blue: 0.443)
    static let cobaltWash = Color(red: 0.451, green: 0.592, blue: 0.835)
    static let saffron = Color(red: 0.961, green: 0.737, blue: 0.180)
    static let ochre = Color(red: 0.804, green: 0.494, blue: 0.118)
    static let lemon = Color(red: 0.988, green: 0.855, blue: 0.290)
    static let copper = Color(red: 0.200, green: 0.553, blue: 0.408)
    static let copperDeep = Color(red: 0.102, green: 0.376, blue: 0.267)
    static let ferraccia = Color(red: 0.843, green: 0.376, blue: 0.153)
    static let ferracciaDeep = Color(red: 0.631, green: 0.220, blue: 0.094)
    static let manganese = Color(red: 0.290, green: 0.176, blue: 0.153)
    static let flesh = Color(red: 0.988, green: 0.902, blue: 0.796)
    static let cream = Color(red: 0.965, green: 0.902, blue: 0.769)
}

/// A glaze and the darker ring it leaves where the brush lifted.
struct MaiolicaTint {
    let body: Color
    let pool: Color

    static let cobalt = MaiolicaTint(body: MaiolicaPaint.cobalt, pool: MaiolicaPaint.cobaltDeep)
    static let wash = MaiolicaTint(body: MaiolicaPaint.cobaltWash, pool: MaiolicaPaint.cobalt)
    static let saffron = MaiolicaTint(body: MaiolicaPaint.saffron, pool: MaiolicaPaint.ochre)
    static let lemon = MaiolicaTint(body: MaiolicaPaint.lemon, pool: MaiolicaPaint.ochre)
    static let copper = MaiolicaTint(body: MaiolicaPaint.copper, pool: MaiolicaPaint.copperDeep)
    static let ferraccia = MaiolicaTint(body: MaiolicaPaint.ferraccia, pool: MaiolicaPaint.ferracciaDeep)
    static let manganese = MaiolicaTint(body: MaiolicaPaint.manganese, pool: .black)
    static let tin = MaiolicaTint(body: MaiolicaPaint.tin, pool: MaiolicaPaint.tinPool)
    static let flesh = MaiolicaTint(body: MaiolicaPaint.flesh, pool: Color(red: 0.918, green: 0.733, blue: 0.588))
    static let cream = MaiolicaTint(body: MaiolicaPaint.cream, pool: MaiolicaPaint.ochre)
    static let ochre = MaiolicaTint(body: MaiolicaPaint.ochre, pool: MaiolicaPaint.ferracciaDeep)
    /// The far side of a white horse.
    static let shade = MaiolicaTint(body: Color(red: 0.878, green: 0.808, blue: 0.663), pool: MaiolicaPaint.ochre)

    /// Coins saffron, cups iron orange, swords cobalt, clubs copper green.
    static func suit(_ suit: Suit) -> MaiolicaTint {
        switch suit {
        case .coins: .saffron
        case .cups: .ferraccia
        case .swords: .cobalt
        case .clubs: .copper
        }
    }
}

/// Repeatable scatter, so a card is painted the same way every time it is drawn.
enum MaiolicaNoise {
    /// A value in 0..<1 for a handful of integers.
    static func value(_ a: Int, _ b: Int = 0, _ c: Int = 0) -> CGFloat {
        var h = UInt64(truncatingIfNeeded: (a &* 73_856_093) ^ (b &* 19_349_663) ^ (c &* 83_492_791))
        h ^= h >> 33
        h &*= 0xff51_afd7_ed55_8ccd
        h ^= h >> 33
        h &*= 0xc4ce_b9fe_1a85_ec53
        h ^= h >> 33
        return CGFloat(h % 10_007) / 10_007
    }
}

// MARK: - The hand

/// Any outline redrawn freehand: flattened, nudged along its normal by two slow waves, and
/// joined again with curves, so no edge is ruled.
struct MaiolicaBrushed<S: Shape>: Shape {
    var shape: S
    /// How far the edge strays, in points.
    var wander: CGFloat
    var seed: Int

    func path(in rect: CGRect) -> Path {
        let source = shape.path(in: rect)
        guard wander > 0.05 else { return source }
        let flat = Path(source.cgPath.flattened(threshold: max(0.25, wander * 0.5)))
        var result = Path()
        for run in MaiolicaRun.runs(of: flat) {
            let points = nudge(run.resampled(step: max(0.9, wander * 5)), closed: run.closed)
            if run.closed { Self.closed(points, into: &result) } else { Self.open(points, into: &result) }
        }
        return result
    }

    /// Pushes every point out or in along the edge's normal.
    private func nudge(_ points: [CGPoint], closed: Bool) -> [CGPoint] {
        let n = points.count
        guard n > 2 else { return points }
        let phase = CGFloat(seed % 97) * 0.731
        var travelled: CGFloat = 0
        return points.indices.map { i in
            let before = points[closed ? (i + n - 1) % n : max(i - 1, 0)]
            let after = points[closed ? (i + 1) % n : min(i + 1, n - 1)]
            if i > 0 { travelled += hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y) }
            let run = hypot(after.x - before.x, after.y - before.y)
            guard run > 0.0001 else { return points[i] }
            let s = travelled / wander
            let push = wander * (0.65 * sin(s * 0.16 + phase) + 0.35 * sin(s * 0.47 + phase * 2.3))
            return CGPoint(x: points[i].x - (after.y - before.y) / run * push,
                           y: points[i].y + (after.x - before.x) / run * push)
        }
    }

    private static func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    private static func closed(_ p: [CGPoint], into path: inout Path) {
        guard p.count > 2 else { return }
        path.move(to: mid(p[p.count - 1], p[0]))
        for i in p.indices { path.addQuadCurve(to: mid(p[i], p[(i + 1) % p.count]), control: p[i]) }
        path.closeSubpath()
    }

    private static func open(_ p: [CGPoint], into path: inout Path) {
        guard let first = p.first, let last = p.last else { return }
        path.move(to: first)
        if p.count > 2 {
            for i in 1..<(p.count - 1) { path.addQuadCurve(to: mid(p[i], p[i + 1]), control: p[i]) }
        }
        path.addLine(to: last)
    }
}

/// One subpath of a flattened outline.
struct MaiolicaRun {
    var points: [CGPoint]
    var closed: Bool

    static func runs(of path: Path) -> [MaiolicaRun] {
        var runs: [MaiolicaRun] = []
        var current: [CGPoint] = []
        path.forEach { element in
            switch element {
            case .move(let to):
                if current.count > 1 { runs.append(MaiolicaRun(points: current, closed: false)) }
                current = [to]
            case .line(let to), .quadCurve(let to, _), .curve(let to, _, _):
                current.append(to)
            case .closeSubpath:
                if current.count > 2 { runs.append(MaiolicaRun(points: current, closed: true)) }
                current = []
            }
        }
        if current.count > 1 { runs.append(MaiolicaRun(points: current, closed: false)) }
        return runs
    }

    /// Points no further apart than `step`, so a long straight side wanders too.
    func resampled(step: CGFloat) -> [CGPoint] {
        var source = points
        if closed, let first = source.first, let last = source.last,
           hypot(first.x - last.x, first.y - last.y) < 0.01 { source.removeLast() }
        let segments = closed ? source.count : source.count - 1
        var out: [CGPoint] = []
        for i in 0..<segments {
            let a = source[i], b = source[(i + 1) % source.count]
            let pieces = max(1, Int((hypot(b.x - a.x, b.y - a.y) / step).rounded(.up)))
            for k in 0..<pieces {
                let t = CGFloat(k) / CGFloat(pieces)
                out.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        if !closed, let last = source.last { out.append(last) }
        return out
    }
}

/// A shape painted in glaze: the colour laid a touch out of register with the trek line,
/// pooled darker at its edge, then the line over it.
struct MaiolicaGlazed<S: Shape>: View {
    let shape: S
    let tint: MaiolicaTint
    /// The card width. The brush is one brush across the whole card.
    let unit: CGFloat
    var line: Color? = MaiolicaPaint.manganese
    var seed = 0

    var body: some View {
        let colour = MaiolicaBrushed(shape: shape, wander: unit * 0.007, seed: seed)
        let trek = MaiolicaBrushed(shape: shape, wander: unit * 0.005, seed: seed &+ 11)
        let slip = CGSize(width: unit * 0.006, height: unit * 0.004)
        ZStack {
            colour.fill(tint.body.opacity(0.95)).offset(slip)
            // Inside the colour only: glaze darkens at its own edge, it does not bleed.
            colour.stroke(tint.pool.opacity(0.55), lineWidth: max(0.8, unit * 0.024))
                .clipShape(colour)
                .offset(slip)
            if let line {
                trek.stroke(line.opacity(0.9), style: StrokeStyle(lineWidth: max(0.45, unit * 0.010),
                                                                  lineCap: .round, lineJoin: .round))
            }
        }
    }
}

// MARK: - The ground

/// Craquelure: the fine net of cracks tin glaze takes as it cools. A staggered lattice,
/// each crack kinked at its middle and a share of them left out, so no cell repeats.
struct MaiolicaCrackle: Shape {
    var cell: CGFloat
    var seed: Int

    func path(in r: CGRect) -> Path {
        var p = Path()
        let cols = Int(r.width / cell) + 2
        let rows = Int(r.height / cell) + 2
        for row in 0...rows {
            for col in 0...cols {
                let key = col * 131 + row
                if MaiolicaNoise.value(seed, key, 2) > 0.2 { crack(col, row, col + 1, row, key, &p, r) }
                if MaiolicaNoise.value(seed, key, 3) > 0.3 { crack(col, row, col, row + 1, key + 7, &p, r) }
            }
        }
        return p
    }

    private func crack(_ c0: Int, _ r0: Int, _ c1: Int, _ r1: Int, _ key: Int,
                       _ p: inout Path, _ r: CGRect) {
        let a = node(c0, r0, r), b = node(c1, r1, r)
        let kink = CGPoint(x: (a.x + b.x) / 2 + (MaiolicaNoise.value(seed, key, 4) - 0.5) * cell * 0.35,
                           y: (a.y + b.y) / 2 + (MaiolicaNoise.value(seed, key, 5) - 0.5) * cell * 0.35)
        p.move(to: a)
        p.addLine(to: kink)
        p.addLine(to: b)
    }

    private func node(_ col: Int, _ row: Int, _ r: CGRect) -> CGPoint {
        let key = col * 131 + row
        let stagger: CGFloat = col.isMultiple(of: 2) ? 0 : 0.5
        return CGPoint(x: r.minX + (CGFloat(col) - 0.5 + (MaiolicaNoise.value(seed, key, 0) - 0.5) * 0.8) * cell,
                       y: r.minY + (CGFloat(row) - 0.5 + stagger + (MaiolicaNoise.value(seed, key, 1) - 0.5) * 0.8) * cell)
    }
}

// MARK: - Repeats

/// Copies of one small shape gathered into a single path, so a border of forty lemons or a
/// robe of sixty spots is still one fill.
enum MaiolicaScatter {
    /// Adds `shape`, drawn `size` across and turned to `angle`, centred on `point`.
    static func place<S: Shape>(_ shape: S, size: CGSize, at point: CGPoint, angle: CGFloat,
                                into path: inout Path) {
        let local = shape.path(in: CGRect(x: -size.width / 2, y: -size.height / 2,
                                          width: size.width, height: size.height))
        let turn = CGAffineTransform(rotationAngle: angle)
            .concatenating(CGAffineTransform(translationX: point.x, y: point.y))
        path.addPath(local, transform: turn)
    }

    /// A leaf sprouting from `base` towards `direction` (radians, 0 pointing right).
    static func leaf(from base: CGPoint, direction: CGFloat, length: CGFloat, width: CGFloat,
                     into path: inout Path) {
        let centre = CGPoint(x: base.x + cos(direction) * length / 2, y: base.y + sin(direction) * length / 2)
        place(Leaf(), size: CGSize(width: width, height: length), at: centre,
              angle: direction + .pi / 2, into: &path)
    }
}

/// A lemon lying on its side, with a nub at either end.
struct MaiolicaLemon: Shape {
    func path(in r: CGRect) -> Path {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y)
        }
        var p = Path()
        p.move(to: at(0.0, 0.50))
        p.addQuadCurve(to: at(0.11, 0.30), control: at(0.05, 0.36))
        p.addCurve(to: at(0.89, 0.30), control1: at(0.28, -0.10), control2: at(0.72, -0.10))
        p.addQuadCurve(to: at(1.0, 0.50), control: at(0.95, 0.36))
        p.addQuadCurve(to: at(0.89, 0.70), control: at(0.95, 0.64))
        p.addCurve(to: at(0.11, 0.70), control1: at(0.72, 1.10), control2: at(0.28, 1.10))
        p.addQuadCurve(to: at(0.0, 0.50), control: at(0.05, 0.64))
        p.closeSubpath()
        return p
    }
}

/// Petals round a centre, every one a leaf with its base at the middle: a rosette.
struct MaiolicaPetals: Shape {
    var count: Int
    var turn: CGFloat = 0
    /// Petal width against its length.
    var breadth: CGFloat = 0.55

    func path(in r: CGRect) -> Path {
        var p = Path()
        let centre = CGPoint(x: r.midX, y: r.midY)
        let length = min(r.width, r.height) / 2
        for k in 0..<count {
            let direction = turn + CGFloat(k) / CGFloat(count) * 2 * .pi - .pi / 2
            MaiolicaScatter.leaf(from: centre, direction: direction, length: length,
                                 width: length * breadth, into: &p)
        }
        return p
    }
}

/// A lily for the top of a sceptre: one petal up, two curling out to the sides.
struct MaiolicaLily: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let base = CGPoint(x: r.midX, y: r.maxY - r.height * 0.12)
        let length = r.height * 0.86
        for (turn, scale) in [(0.0, 1.0), (-0.95, 0.72), (0.95, 0.72)] as [(CGFloat, CGFloat)] {
            MaiolicaScatter.leaf(from: base, direction: -.pi / 2 + turn, length: length * scale,
                                 width: length * scale * 0.42, into: &p)
        }
        return p
    }
}

/// Dots in a ring, for a coin's milling or a crown's jewels.
struct MaiolicaRingDots: Shape {
    var count: Int
    /// The ring's radius and the dot's diameter, both against the frame's smaller side.
    var radius: CGFloat
    var dot: CGFloat

    func path(in r: CGRect) -> Path {
        var p = Path()
        let side = min(r.width, r.height)
        for k in 0..<count {
            let angle = CGFloat(k) / CGFloat(count) * 2 * .pi
            let centre = CGPoint(x: r.midX + cos(angle) * radius * side, y: r.midY + sin(angle) * radius * side)
            p.addEllipse(in: CGRect(x: centre.x - dot * side / 2, y: centre.y - dot * side / 2,
                                    width: dot * side, height: dot * side))
        }
        return p
    }
}

/// Staggered spots across a frame, to be clipped to a robe.
struct MaiolicaSpots: Shape {
    /// Spacing and spot size in points.
    var step: CGFloat
    var dot: CGFloat

    func path(in r: CGRect) -> Path {
        var p = Path()
        var row = 0
        var y = r.minY + step / 2
        while y < r.maxY {
            var x = r.minX + (row.isMultiple(of: 2) ? step / 2 : step)
            while x < r.maxX {
                p.addEllipse(in: CGRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot))
                x += step
            }
            y += step * 0.86
            row += 1
        }
        return p
    }
}

/// Brush drags down a robe: tapered strokes leaning a little, darker where they overlap.
struct MaiolicaDrags: Shape {
    var count: Int
    var seed: Int

    func path(in r: CGRect) -> Path {
        var p = Path()
        for k in 0..<count {
            let x = (CGFloat(k) + 0.5) / CGFloat(count)
            let lean = (MaiolicaNoise.value(seed, k) - 0.5) * 0.10
            let spine = [CGPoint(x: x, y: 0.02), CGPoint(x: x + lean, y: 0.5), CGPoint(x: x + lean * 1.6, y: 0.98)]
            let thick = 0.6 / CGFloat(count) * r.width / max(min(r.width, r.height), 0.001)
            p.addPath(Ribbon(spine: spine, widths: [thick * 0.3, thick, thick * 0.4]).path(in: r))
        }
        return p
    }
}
