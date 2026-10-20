import SwiftUI

/// The grain drawn across a piece of veneer. Every line is placed by a seed, so a piece
/// shows the same grain each time it is drawn and at every size.
enum IntarsioGrain {
    /// A number in 0..<1 for a seed and an index. SplitMix64.
    static func dice(_ seed: UInt64, _ index: Int) -> CGFloat {
        var z = seed &+ UInt64(truncatingIfNeeded: index &+ 1) &* 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return CGFloat((z ^ (z >> 31)) >> 11) / CGFloat(1 << 53)
    }

    /// Lines across `box` running at `angle`, about `pitch` apart. Neighbours swing
    /// together by up to `wave`, as grain does, rather than each on its own.
    static func lines(in box: CGRect, angle: CGFloat, pitch: CGFloat, wave: CGFloat, seed: UInt64) -> Path {
        let reach = hypot(box.width, box.height) / 2 + pitch
        let (ax, ay, nx, ny) = (cos(angle), sin(angle), -sin(angle), cos(angle))
        let phase = dice(seed, 0) * 2 * .pi, bend = 0.7 + dice(seed, 1) * 1.4
        var path = Path()
        var v = -reach + pitch * dice(seed, 2)
        var index = 3
        while v < reach, index < 160 {
            let swing = wave * (0.55 + 0.9 * dice(seed, index))
            let points = (0...6).map { step -> CGPoint in
                let u = -reach + 2 * reach * CGFloat(step) / 6
                let off = v + swing * sin(u / reach * bend * .pi + phase + v / reach * 1.6)
                return CGPoint(x: box.midX + ax * u + nx * off, y: box.midY + ay * u + ny * off)
            }
            trace(points, into: &path)
            v += pitch * (0.4 + 1.2 * dice(seed, index + 700))
            index += 1
        }
        return path
    }

    /// Nested arches, the cathedral of a flat-cut leaf. The outer ones rise past its top
    /// and run up its sides as straight grain.
    static func cathedral(in leaf: CGRect, pitch: CGFloat, seed: UInt64) -> Path {
        let centre = leaf.midX + (dice(seed, 0) - 0.5) * leaf.width * 0.25
        let base = leaf.maxY + leaf.height * 0.06
        let lowest = leaf.height * (0.28 + 0.14 * dice(seed, 1))
        let widest = leaf.width * 1.15
        var path = Path()
        var half = pitch * (0.4 + dice(seed, 2))
        var index = 3
        while half < widest, index < 120 {
            let rise = lowest + (leaf.height * 1.25 - lowest) * pow(half / widest, 0.8)
            let sway = pitch * 1.2 * (dice(seed, index) - 0.5)
            let points = (0...12).map { step -> CGPoint in
                let s = CGFloat(step) / 6 - 1
                return CGPoint(x: centre + half * s + sway * (1 - s * s), y: base - rise * (1 - s * s))
            }
            trace(points, into: &path)
            half += pitch * (0.45 + 1.1 * dice(seed, index + 300))
            index += 1
        }
        return path
    }

    /// A smooth open curve through points: each point a control, each midpoint passed through.
    static func trace(_ points: [CGPoint], into path: inout Path) {
        guard points.count > 2, let first = points.first, let last = points.last else { return }
        path.move(to: first)
        for index in 1..<(points.count - 1) {
            let next = points[index + 1]
            path.addQuadCurve(to: CGPoint(x: (points[index].x + next.x) / 2, y: (points[index].y + next.y) / 2),
                              control: points[index])
        }
        path.addLine(to: last)
    }
}
