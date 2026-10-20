import SwiftUI

/// The geometry of a `MosaicoPiece`: its outline, the courses that fill it, and the flat bands
/// that stand in for them on a small card.
extension MosaicoPiece {
    var bounds: CGRect {
        let points = outline(0)
        let xs = points.map(\.x), ys = points.map(\.y)
        return CGRect(x: xs.min() ?? 0, y: ys.min() ?? 0,
                      width: (xs.max() ?? 0) - (xs.min() ?? 0), height: (ys.max() ?? 0) - (ys.min() ?? 0))
    }

    /// The outline grown by `outset`, or shrunk when it is negative.
    func outline(_ outset: CGFloat) -> [CGPoint] {
        switch self {
        case let .oval(centre, rx, ry, from, to):
            return Self.arcOutline(centre, rx + outset, ry + outset, from, to, outset)
        case let .strip(points, widths):
            return Spine(points, widths).outline(grow: outset, scale: 1)
        }
    }

    /// Courses from the outline in.
    func courses(_ pitch: CGFloat) -> [MosaicoCourse] {
        switch self {
        case let .oval(centre, rx, ry, from, to):
            return Self.ovalCourses(centre, rx, ry, from, to, pitch)
        case let .strip(points, widths):
            return Spine(points, widths).courses(pitch)
        }
    }

    /// Nested polygons of the same courses, outermost first, for laying flat.
    func bands(_ pitch: CGFloat) -> [(polygon: [CGPoint], inward: CGFloat)] {
        switch self {
        case let .oval(centre, rx, ry, from, to):
            let count = max(1, Int((min(rx, ry) / pitch).rounded()))
            return (0..<count).map { rank in
                let scale = 1 - CGFloat(rank) / CGFloat(count)
                return (Self.arcOutline(centre, rx * scale, ry * scale, from, to, 0),
                        (CGFloat(rank) + 0.5) / CGFloat(count))
            }
        case let .strip(points, widths):
            let spine = Spine(points, widths)
            let half = CGFloat(spine.courseCount(pitch)) / 2
            return (0..<Int(half.rounded(.up))).map { rank in
                (spine.outline(grow: 0, scale: 1 - CGFloat(rank) / half), min(1, (CGFloat(rank) + 0.5) / half))
            }
        }
    }

    private static func isWhole(_ from: CGFloat, _ to: CGFloat) -> Bool { to - from >= 2 * .pi - 0.001 }

    private static func arcPoints(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat,
                                  _ from: CGFloat, _ to: CGFloat) -> [CGPoint] {
        let rx = max(rx, 0), ry = max(ry, 0)
        let sweep = to - from
        let count = max(8, min(96, Int(max(rx, ry) * sweep / 1.4)))
        let last = isWhole(from, to) ? count - 1 : count
        return (0...last).map { index in
            let angle = from + sweep * CGFloat(index) / CGFloat(count)
            return CGPoint(x: c.x + cos(angle) * rx, y: c.y + sin(angle) * ry)
        }
    }

    /// An arc closes along its chord, and the chord moves out with the outset too.
    private static func arcOutline(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat,
                                   _ from: CGFloat, _ to: CGFloat, _ outset: CGFloat) -> [CGPoint] {
        var points = arcPoints(c, rx, ry, from, to)
        guard !isWhole(from, to), let first = points.first, let last = points.last else { return points }
        let middle = (from + to) / 2
        let (ux, uy) = (cos(middle) * outset, sin(middle) * outset)
        points.append(CGPoint(x: last.x - ux, y: last.y - uy))
        points.append(CGPoint(x: first.x - ux, y: first.y - uy))
        return points
    }

    private static func ovalCourses(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat,
                                    _ from: CGFloat, _ to: CGFloat, _ pitch: CGFloat) -> [MosaicoCourse] {
        let minor = min(rx, ry)
        let count = max(1, Int((minor / pitch).rounded()))
        let spacing = minor / CGFloat(count)
        let whole = isWhole(from, to)
        return (0..<count).map { rank in
            let scale = 1 - (CGFloat(rank) + 0.5) / CGFloat(count)
            let inward = (CGFloat(rank) + 0.5) / CGFloat(count)
            if whole && minor * scale < pitch * 0.6 && abs(rx - ry) < pitch {
                return MosaicoCourse(points: [c], depths: [spacing], closed: false, inward: inward)
            }
            let points = arcPoints(c, rx * scale, ry * scale, from, to)
            return MosaicoCourse(points: points, depths: Array(repeating: spacing, count: points.count),
                          closed: whole, inward: inward)
        }
    }
}

/// A strip's centre line, sampled smooth through its control points.
private struct Spine {
    var points: [CGPoint] = []
    var widths: [CGFloat] = []
    var normals: [CGPoint] = []

    init(_ controls: [CGPoint], _ controlWidths: [CGFloat]) {
        let last = controls.count - 1
        guard last > 0 else { return }
        let steps = 8
        for segment in 0..<last {
            let p0 = controls[max(segment - 1, 0)], p1 = controls[segment]
            let p2 = controls[segment + 1], p3 = controls[min(segment + 2, last)]
            let w1 = controlWidths[min(segment, controlWidths.count - 1)]
            let w2 = controlWidths[min(segment + 1, controlWidths.count - 1)]
            for step in 0..<steps {
                let t = CGFloat(step) / CGFloat(steps)
                points.append(Self.catmullRom(p0, p1, p2, p3, t))
                widths.append(w1 + (w2 - w1) * t)
            }
        }
        points.append(controls[last])
        widths.append(controlWidths[min(last, controlWidths.count - 1)])
        normals = points.indices.map { index in
            let a = points[max(index - 1, 0)], b = points[min(index + 1, points.count - 1)]
            let length = max(hypot(b.x - a.x, b.y - a.y), 0.0001)
            return CGPoint(x: -(b.y - a.y) / length, y: (b.x - a.x) / length)
        }
    }

    private static func catmullRom(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint,
                                   _ t: CGFloat) -> CGPoint {
        func axis(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
            0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (3 * b - a - 3 * c + d) * t * t * t)
        }
        return CGPoint(x: axis(p0.x, p1.x, p2.x, p3.x), y: axis(p0.y, p1.y, p2.y, p3.y))
    }

    func courseCount(_ pitch: CGFloat) -> Int { max(1, Int(((widths.max() ?? 0) / pitch).rounded())) }

    /// Both sides of the strip, each moved out by `grow` once the width is scaled. The ends
    /// move out along the spine too.
    func outline(grow: CGFloat, scale: CGFloat) -> [CGPoint] {
        guard points.count > 1 else { return [] }
        var left: [CGPoint] = [], right: [CGPoint] = []
        for index in points.indices {
            let half = max(widths[index] * scale / 2 + grow, 0)
            var p = points[index]
            if index == 0 || index == points.count - 1 {
                let n = normals[index], sign: CGFloat = index == 0 ? -1 : 1
                p = CGPoint(x: p.x + n.y * grow * sign, y: p.y - n.x * grow * sign)
            }
            let n = normals[index]
            left.append(CGPoint(x: p.x + n.x * half, y: p.y + n.y * half))
            right.append(CGPoint(x: p.x - n.x * half, y: p.y - n.y * half))
        }
        return left + right.reversed()
    }

    func courses(_ pitch: CGFloat) -> [MosaicoCourse] {
        let count = courseCount(pitch)
        let half = CGFloat(count) / 2
        return (0..<count).map { lane in
            let across = -1 + (2 * CGFloat(lane) + 1) / CGFloat(count)
            let line = points.indices.map { index in
                let offset = across * widths[index] / 2
                return CGPoint(x: points[index].x + normals[index].x * offset,
                               y: points[index].y + normals[index].y * offset)
            }
            let rank = CGFloat(min(lane, count - 1 - lane))
            return MosaicoCourse(points: line, depths: widths.map { $0 / CGFloat(count) },
                          closed: false, inward: min(1, (rank + 0.5) / half))
        }
    }
}
