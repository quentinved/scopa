import SwiftUI

/// Where the tile frame sits, as fractions of the card width.
enum MaiolicaFrame {
    /// The cobalt edge.
    static let rim: CGFloat = 0.036
    /// The middle of the garland band.
    static let band: CGFloat = 0.072
    /// The line round the picture.
    static let line: CGFloat = 0.108
    /// The corner block the index sits in, measured from the card's corner.
    static let notch = CGSize(width: 0.33, height: 0.30)
    /// How far the garland stops short of a rosette corner.
    static let rosette: CGFloat = 0.15
}

/// The cobalt run round the edge of the tile, its inner edge freehand. Fill even-odd.
struct MaiolicaRim: Shape {
    var unit: CGFloat

    func path(in r: CGRect) -> Path {
        var p = Path(r.insetBy(dx: -unit * 0.05, dy: -unit * 0.05))
        let inset = unit * MaiolicaFrame.rim
        let inner = MaiolicaBrushed(shape: RoundedRectangle(cornerRadius: unit * 0.075),
                                    wander: unit * 0.006, seed: 5)
        p.addPath(inner.path(in: r.insetBy(dx: inset, dy: inset)))
        return p
    }
}

/// The line round the picture, in two runs that stop where the index blocks step in.
struct MaiolicaFieldLine: Shape {
    var unit: CGFloat

    func path(in r: CGRect) -> Path {
        let i = unit * MaiolicaFrame.line
        let nx = unit * MaiolicaFrame.notch.width, ny = unit * MaiolicaFrame.notch.height
        let bend = unit * 0.05
        var p = Path()
        p.move(to: CGPoint(x: r.minX + nx, y: r.minY + i))
        p.addArc(tangent1End: CGPoint(x: r.maxX - i, y: r.minY + i),
                 tangent2End: CGPoint(x: r.maxX - i, y: r.maxY), radius: bend)
        p.addLine(to: CGPoint(x: r.maxX - i, y: r.maxY - ny))
        p.move(to: CGPoint(x: r.maxX - nx, y: r.maxY - i))
        p.addArc(tangent1End: CGPoint(x: r.minX + i, y: r.maxY - i),
                 tangent2End: CGPoint(x: r.minX + i, y: r.minY), radius: bend)
        p.addLine(to: CGPoint(x: r.minX + i, y: r.minY + ny))
        return p
    }
}

/// The top-left index corner. `patch` is the tin laid over the picture; otherwise the step
/// the field line takes round the number. The bottom-right is the same turned over.
struct MaiolicaBlock: Shape {
    var unit: CGFloat
    var patch: Bool

    func path(in r: CGRect) -> Path {
        let i = unit * MaiolicaFrame.line
        let nx = unit * MaiolicaFrame.notch.width, ny = unit * MaiolicaFrame.notch.height
        let corner = CGPoint(x: r.minX + nx, y: r.minY + ny)
        var p = Path()
        if patch {
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX + nx, y: r.minY))
            p.addArc(tangent1End: corner, tangent2End: CGPoint(x: r.minX, y: r.minY + ny), radius: unit * 0.045)
            p.addLine(to: CGPoint(x: r.minX, y: r.minY + ny))
            p.closeSubpath()
        } else {
            p.move(to: CGPoint(x: r.minX + i, y: r.minY + ny))
            p.addArc(tangent1End: corner, tangent2End: CGPoint(x: r.minX + nx, y: r.minY), radius: unit * 0.045)
            p.addLine(to: CGPoint(x: r.minX + nx, y: r.minY + i))
        }
        return p
    }
}

// MARK: - The garland

/// Lemons and leaves on a wavy stem round the band, one path per glaze, so the border is a
/// handful of fills however many lemons it holds.
struct MaiolicaGarland: Shape {
    enum Part { case stem, lemons, leaves }
    var part: Part
    var unit: CGFloat

    func path(in r: CGRect) -> Path {
        var p = Path()
        for (start, end) in runs(in: r) {
            let length = hypot(end.x - start.x, end.y - start.y)
            guard length > unit * 0.08 else { continue }
            let run = Run(start: start, end: end, length: length,
                          slots: max(1, Int(length / (unit * 0.105))), sway: unit * 0.009)
            if part == .stem { stem(run, into: &p) } else { motifs(run, into: &p) }
        }
        return p
    }

    private struct Run {
        let start: CGPoint, end: CGPoint, length: CGFloat, slots: Int, sway: CGFloat
        var step: CGFloat { length / CGFloat(slots) }
        var angle: CGFloat { atan2(end.y - start.y, end.x - start.x) }

        /// The stem's point `distance` along the run: it crosses the band's middle between
        /// slots and swings out to alternate sides at each one.
        func point(at distance: CGFloat) -> CGPoint {
            let d = CGPoint(x: (end.x - start.x) / length, y: (end.y - start.y) / length)
            let swing = sway * sin(.pi * distance / step)
            return CGPoint(x: start.x + d.x * distance - d.y * swing, y: start.y + d.y * distance + d.x * swing)
        }
    }

    /// The four sides between the corners, clockwise.
    private func runs(in r: CGRect) -> [(CGPoint, CGPoint)] {
        let b = unit * MaiolicaFrame.band, rose = unit * MaiolicaFrame.rosette
        let nx = unit * (MaiolicaFrame.notch.width + 0.02), ny = unit * (MaiolicaFrame.notch.height + 0.02)
        return [
            (CGPoint(x: r.minX + nx, y: r.minY + b), CGPoint(x: r.maxX - rose, y: r.minY + b)),
            (CGPoint(x: r.maxX - b, y: r.minY + rose), CGPoint(x: r.maxX - b, y: r.maxY - ny)),
            (CGPoint(x: r.maxX - nx, y: r.maxY - b), CGPoint(x: r.minX + rose, y: r.maxY - b)),
            (CGPoint(x: r.minX + b, y: r.maxY - rose), CGPoint(x: r.minX + b, y: r.minY + ny)),
        ]
    }

    private func stem(_ run: Run, into p: inout Path) {
        let pieces = run.slots * 6
        p.move(to: run.point(at: 0))
        for k in 1...pieces {
            p.addLine(to: run.point(at: run.length * CGFloat(k) / CGFloat(pieces)))
        }
    }

    /// A lemon with one leaf at every other crest, a pair of leaves in a V between.
    private func motifs(_ run: Run, into p: inout Path) {
        for k in 0..<run.slots {
            let side: CGFloat = k.isMultiple(of: 2) ? 1 : -1
            let at = run.point(at: run.step * (CGFloat(k) + 0.5))
            let out = run.angle + .pi / 2 * side
            if k.isMultiple(of: 2), part == .lemons {
                let hang = CGPoint(x: at.x + cos(out) * unit * 0.005, y: at.y + sin(out) * unit * 0.005)
                MaiolicaScatter.place(MaiolicaLemon(), size: CGSize(width: unit * 0.054, height: unit * 0.036),
                                      at: hang, angle: run.angle + side * 0.3, into: &p)
            } else if part == .leaves {
                let directions = k.isMultiple(of: 2)
                    ? [run.angle + .pi - side * 0.55]
                    : [run.angle + side * 0.6, run.angle + .pi - side * 0.6]
                for direction in directions {
                    MaiolicaScatter.leaf(from: at, direction: direction, length: unit * 0.042,
                                         width: unit * 0.020, into: &p)
                }
            }
        }
    }
}

/// The two corners without an index: a cobalt rosette whose side petals carry on the band,
/// copper leaves between them and a saffron eye.
struct MaiolicaRosettes: Shape {
    enum Part { case petals, leaves, eyes }
    var part: Part
    var unit: CGFloat

    func path(in r: CGRect) -> Path {
        let b = unit * MaiolicaFrame.band
        var p = Path()
        for centre in [CGPoint(x: r.maxX - b, y: r.minY + b), CGPoint(x: r.minX + b, y: r.maxY - b)] {
            let side: CGFloat
            switch part {
            case .petals: side = unit * 0.10
            case .leaves: side = unit * 0.075
            case .eyes: side = unit * 0.026
            }
            let square = CGRect(x: centre.x - side / 2, y: centre.y - side / 2, width: side, height: side)
            switch part {
            case .petals: p.addPath(MaiolicaPetals(count: 4).path(in: square))
            case .leaves: p.addPath(MaiolicaPetals(count: 4, turn: .pi / 4, breadth: 0.5).path(in: square))
            case .eyes: p.addEllipse(in: square)
            }
        }
        return p
    }
}

// MARK: - Wreath and bough

/// A Della Robbia wreath: pairs of leaves round an oval with a lemon every few, one path
/// per glaze.
struct MaiolicaWreath: Shape {
    enum Part { case leaves, lemons }
    var part: Part
    var unit: CGFloat
    var count = 32

    func path(in r: CGRect) -> Path {
        var p = Path()
        let a = r.width / 2, b = r.height / 2
        for k in 0..<count {
            let t = CGFloat(k) / CGFloat(count) * 2 * .pi
            let at = CGPoint(x: r.midX + cos(t) * a, y: r.midY + sin(t) * b)
            let along = atan2(cos(t) * b, -sin(t) * a)
            if part == .leaves {
                for splay in [0.55, -0.55] as [CGFloat] {
                    MaiolicaScatter.leaf(from: at, direction: along + splay, length: unit * 0.088,
                                         width: unit * 0.042, into: &p)
                }
            } else if k % 4 == 1 {
                MaiolicaScatter.place(MaiolicaLemon(), size: CGSize(width: unit * 0.076, height: unit * 0.052),
                                      at: at, angle: along + 0.4, into: &p)
            }
        }
        return p
    }
}

/// A lemon bough for the aces: a stem curving up and out from under the pip, leaves along
/// it and lemons at the tip. Drawn for the left side of the frame it is given.
struct MaiolicaBough: Shape {
    enum Part { case stem, leaves, lemons }
    var part: Part
    var unit: CGFloat

    func path(in r: CGRect) -> Path {
        let from = CGPoint(x: r.maxX, y: r.maxY), bend = CGPoint(x: r.minX + r.width * 0.10, y: r.maxY)
        let to = CGPoint(x: r.minX + r.width * 0.06, y: r.minY + r.height * 0.08)
        func at(_ t: CGFloat) -> CGPoint {
            let u = 1 - t
            return CGPoint(x: u * u * from.x + 2 * u * t * bend.x + t * t * to.x,
                           y: u * u * from.y + 2 * u * t * bend.y + t * t * to.y)
        }
        func along(_ t: CGFloat) -> CGFloat {
            atan2(2 * (1 - t) * (bend.y - from.y) + 2 * t * (to.y - bend.y),
                  2 * (1 - t) * (bend.x - from.x) + 2 * t * (to.x - bend.x))
        }
        var p = Path()
        switch part {
        case .stem:
            p.move(to: from)
            p.addQuadCurve(to: to, control: bend)
        case .leaves: leaves(at: at, along: along, into: &p)
        case .lemons:
            for (t, drop) in [(0.97, 0.0), (0.62, 0.9)] as [(CGFloat, CGFloat)] {
                let point = at(t)
                let hang = CGPoint(x: point.x + unit * 0.035 * drop, y: point.y + unit * 0.012 * drop)
                MaiolicaScatter.place(MaiolicaLemon(), size: CGSize(width: unit * 0.115, height: unit * 0.078),
                                      at: hang, angle: along(t) + 0.5, into: &p)
            }
        }
        return p
    }

    private func leaves(at: (CGFloat) -> CGPoint, along: (CGFloat) -> CGFloat, into p: inout Path) {
        for (k, t) in [0.16, 0.30, 0.44, 0.56, 0.72, 0.86].enumerated() {
            let side: CGFloat = k.isMultiple(of: 2) ? 1 : -1
            MaiolicaScatter.leaf(from: at(t), direction: along(t) + side * 0.75, length: unit * 0.10,
                                 width: unit * 0.046, into: &p)
        }
    }
}

/// The cartiglio: a painted ribbon with swallowtail ends folded behind, for the settebello's
/// name.
struct MaiolicaScroll: Shape {
    var tails: Bool

    func path(in r: CGRect) -> Path {
        var p = Path()
        let tail = r.width * 0.12, drop = r.height * 0.28
        if tails {
            for side in [-1.0, 1.0] as [CGFloat] {
                let x = side < 0 ? r.minX : r.maxX
                p.move(to: CGPoint(x: x - side * tail * 0.6, y: r.minY + drop))
                p.addLine(to: CGPoint(x: x + side * tail, y: r.minY + drop))
                p.addLine(to: CGPoint(x: x + side * tail * 0.62, y: r.midY + drop))
                p.addLine(to: CGPoint(x: x + side * tail, y: r.maxY + drop))
                p.addLine(to: CGPoint(x: x - side * tail * 0.6, y: r.maxY + drop))
                p.closeSubpath()
            }
        } else {
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.midX, y: r.minY + r.height * 0.18))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY), control: CGPoint(x: r.midX, y: r.maxY + r.height * 0.18))
            p.closeSubpath()
        }
        return p
    }
}
