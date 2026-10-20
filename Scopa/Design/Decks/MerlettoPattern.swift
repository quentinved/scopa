import SwiftUI

/// The pattern a piece is pricked out on before the needle follows it: where things go,
/// in card widths.
extension MerlettoPillow {
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * w) }

    func oval(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: (x - rx) * w, y: (y - ry) * w, width: 2 * rx * w, height: 2 * ry * w))
    }

    /// A circle in points, for a motif already placed in points.
    func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }

    /// A shape `pw` by `ph` centred on (x, y).
    func cut<S: Shape>(_ shape: S, _ x: CGFloat, _ y: CGFloat, _ pw: CGFloat, _ ph: CGFloat) -> Path {
        shape.path(in: CGRect(x: (x - pw / 2) * w, y: (y - ph / 2) * w, width: pw * w, height: ph * w))
    }

    /// A tapered strip through a spine: an arm, a leg, a plume.
    func limb(_ spine: [(CGFloat, CGFloat)], _ widths: [CGFloat]) -> Path {
        Ribbon(spine: spine.map { CGPoint(x: $0.0, y: $0.1 / 1.5) }, widths: widths)
            .path(in: CGRect(x: 0, y: 0, width: w, height: w * 1.5))
    }

    /// A closed outline rounded through its points.
    func outline(_ points: [(CGFloat, CGFloat)]) -> Path {
        let corners = points.map { p($0.0, $0.1) }
        var path = Path()
        guard corners.count > 2 else { return path }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        path.move(to: mid(corners[corners.count - 1], corners[0]))
        for index in corners.indices {
            path.addQuadCurve(to: mid(corners[index], corners[(index + 1) % corners.count]), control: corners[index])
        }
        path.closeSubpath()
        return path
    }

    func polygon(_ points: [(CGFloat, CGFloat)]) -> Path {
        var path = Path()
        path.addLines(points.map { p($0.0, $0.1) })
        path.closeSubpath()
        return path
    }

    /// An open curve through points: each a control, each midpoint passed through.
    func line(_ points: [(CGFloat, CGFloat)]) -> Path {
        let at = points.map { p($0.0, $0.1) }
        var path = Path()
        guard let first = at.first, let last = at.last else { return path }
        path.move(to: first)
        for index in at.indices.dropFirst().dropLast() {
            let next = at[index + 1]
            path.addQuadCurve(to: CGPoint(x: (at[index].x + next.x) / 2, y: (at[index].y + next.y) / 2), control: at[index])
        }
        path.addLine(to: last)
        return path
    }

    func mirrored(_ points: [(CGFloat, CGFloat)]) -> [(CGFloat, CGFloat)] { points.map { (1 - $0.0, $0.1) } }

    /// `count` points round an ellipse about `c`, in points, from `phase` (0 is right).
    func around(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat? = nil, _ count: Int, phase: CGFloat = 0) -> [CGPoint] {
        (0..<count).map { k in
            let angle = phase + CGFloat(k) / CGFloat(count) * 2 * .pi
            return CGPoint(x: c.x + cos(angle) * rx, y: c.y + sin(angle) * (ry ?? rx))
        }
    }

    /// Scallops hung along a run from `a` to `b`, half-discs bulging to the run's right,
    /// which is inward on an edge followed clockwise. Returns them and their picots' places.
    func scallops(from a: CGPoint, to b: CGPoint, count: Int, picots: Int = 3) -> (Path, [CGPoint]) {
        let dx = (b.x - a.x) / CGFloat(count), dy = (b.y - a.y) / CGFloat(count)
        let r = hypot(dx, dy) / 2, run = atan2(dy, dx)
        var shape = Path()
        var tips: [CGPoint] = []
        for k in 0..<count {
            let c = CGPoint(x: a.x + dx * (CGFloat(k) + 0.5), y: a.y + dy * (CGFloat(k) + 0.5))
            shape.move(to: CGPoint(x: c.x - cos(run) * r, y: c.y - sin(run) * r))
            shape.addArc(center: c, radius: r, startAngle: .radians(run + .pi), endAngle: .radians(run), clockwise: true)
            shape.closeSubpath()
            for j in 0..<picots {
                let angle = run + .pi / 2 + (CGFloat(j) - CGFloat(picots - 1) / 2) * 0.66
                tips.append(CGPoint(x: c.x + cos(angle) * (r + picot * 1.15), y: c.y + sin(angle) * (r + picot * 1.15)))
            }
        }
        return (shape, tips)
    }

    /// Beads of toile strung round an ellipse: a ruff, a collar's edge, a medallion's rim.
    func beads(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat, count: Int, r: CGFloat,
               from start: CGFloat = 0, to end: CGFloat = 2 * .pi) -> (Path, [CGPoint]) {
        var shape = Path()
        var tips: [CGPoint] = []
        let closed = end - start >= 2 * .pi - 0.001
        for k in 0..<count {
            let t = closed ? CGFloat(k) / CGFloat(count) : CGFloat(k) / CGFloat(max(count - 1, 1))
            let angle = start + (end - start) * t
            let (ux, uy) = (cos(angle), sin(angle))
            let centre = CGPoint(x: c.x + ux * rx, y: c.y + uy * ry)
            shape.addEllipse(in: CGRect(x: centre.x - r, y: centre.y - r, width: 2 * r, height: 2 * r))
            tips.append(CGPoint(x: centre.x + ux * (r + picot * 1.1), y: centre.y + uy * (r + picot * 1.1)))
        }
        return (shape, tips)
    }
}

/// The ground threads a piece is filled with.
enum MerlettoMesh {
    /// A honeycomb of cells `cell` across covering `box`: one zigzag per row of cells and
    /// the bars between them.
    static func honeycomb(in box: CGRect, cell: CGFloat) -> Path {
        let q = cell / (2 * 3.squareRoot())
        var path = Path()
        var cy = box.minY, row = 0
        while cy - 2 * q < box.maxY, row < 400 {
            var cx = box.minX - cell + (row.isMultiple(of: 2) ? 0 : cell / 2)
            path.move(to: CGPoint(x: cx - cell / 2, y: cy - q))
            var bars: [CGFloat] = []
            while cx - cell / 2 < box.maxX + cell {
                path.addLine(to: CGPoint(x: cx, y: cy - 2 * q))
                path.addLine(to: CGPoint(x: cx + cell / 2, y: cy - q))
                bars.append(cx - cell / 2)
                cx += cell
            }
            for x in bars {
                path.move(to: CGPoint(x: x, y: cy - q))
                path.addLine(to: CGPoint(x: x, y: cy + q))
            }
            cy += 3 * q
            row += 1
        }
        return path
    }

    /// The bars of a honeycomb `cell` across covering `box`, each knot nudged by up to
    /// `wobble` of a cell, the same at every size because the nudge follows the knot's place.
    static func bars(in box: CGRect, cell: CGFloat, wobble: CGFloat, seed: UInt64) -> [(CGPoint, CGPoint)] {
        let q = cell / (2 * 3.squareRoot())
        func knot(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let i = UInt64(bitPattern: Int64(((x - box.minX) / q).rounded()))
            let j = UInt64(bitPattern: Int64(((y - box.minY) / q).rounded()))
            let key = seed ^ (i &* 0x9E37_79B9_7F4A_7C15) ^ (j &* 0xC2B2_AE3D_27D4_EB4F)
            return CGPoint(x: x + (dice(key, 0) - 0.5) * 2 * wobble * cell, y: y + (dice(key, 1) - 0.5) * 2 * wobble * cell)
        }
        var bars: [(CGPoint, CGPoint)] = []
        var cy = box.minY, row = 0
        while cy - 2 * q < box.maxY, row < 200 {
            var cx = box.minX + (row.isMultiple(of: 2) ? 0 : cell / 2)
            while cx - cell / 2 < box.maxX {
                let (left, top) = (knot(cx - cell / 2, cy - q), knot(cx, cy - 2 * q))
                bars += [(left, top), (top, knot(cx + cell / 2, cy - q)), (left, knot(cx - cell / 2, cy + q))]
                cx += cell
            }
            cy += 3 * q
            row += 1
        }
        return bars
    }

    /// Rings `r` across set close in offset rows over `box`.
    static func rings(in box: CGRect, r: CGFloat) -> Path {
        let step = r * 1.75
        var path = Path()
        var y = box.minY, row = 0
        while y < box.maxY + r, row < 200 {
            var x = box.minX + (row.isMultiple(of: 2) ? 0 : step / 2)
            while x < box.maxX + r {
                path.addEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
                x += step
            }
            y += step * 0.87
            row += 1
        }
        return path
    }

    /// A number in 0..<1 for a seed and an index. SplitMix64.
    static func dice(_ seed: UInt64, _ index: Int) -> CGFloat {
        var z = seed &+ UInt64(truncatingIfNeeded: index &+ 1) &* 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return CGFloat((z ^ (z >> 31)) >> 11) / CGFloat(1 << 53)
    }

    /// Straight rows across `box` at `angle`, `pitch` apart: the courses of a toile.
    static func rows(in box: CGRect, angle: CGFloat, pitch: CGFloat) -> Path {
        let reach = hypot(box.width, box.height) / 2
        let (ax, ay) = (cos(angle), sin(angle))
        var path = Path()
        var v = -reach + pitch / 2
        while v < reach {
            let (x, y) = (box.midX - ay * v, box.midY + ax * v)
            path.move(to: CGPoint(x: x - ax * reach, y: y - ay * reach))
            path.addLine(to: CGPoint(x: x + ax * reach, y: y + ay * reach))
            v += pitch
        }
        return path
    }
}
