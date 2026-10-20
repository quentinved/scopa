import SwiftUI

// The Carnevale deck's frame and ornament. Nested in `Carnevale` so the other drafts can
// name their own lozenges and scallops.

extension Carnevale {
    /// A diamond touching the middle of each side of its rect.
    struct Lozenge: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.addLines([CGPoint(x: r.midX, y: r.minY), CGPoint(x: r.maxX, y: r.midY),
                        CGPoint(x: r.midX, y: r.maxY), CGPoint(x: r.minX, y: r.midY)])
            p.closeSubpath()
            return p
        }
    }

    /// Pointed at both ends and swelling in the middle: an eye hole, a mouth.
    struct Almond: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: r.midY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.midY), control: CGPoint(x: r.midX, y: r.minY - r.height * 0.5))
            p.addQuadCurve(to: CGPoint(x: r.minX, y: r.midY), control: CGPoint(x: r.midX, y: r.maxY + r.height * 0.5))
            p.closeSubpath()
            return p
        }
    }

    /// One curve hanging from the top corners, its lowest point on the bottom edge.
    struct Swag: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.midX, y: r.minY + r.height * 2))
            return p
        }
    }

    /// A ribbon with swallowtail ends, for the settebello's name.
    struct Banner: Shape {
        func path(in r: CGRect) -> Path {
            let notch = r.height * 0.45
            var p = Path()
            p.addLines([CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
                        CGPoint(x: r.maxX - notch, y: r.midY), CGPoint(x: r.maxX, y: r.maxY),
                        CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.minX + notch, y: r.midY)])
            p.closeSubpath()
            return p
        }
    }

    /// A disc with a scalloped rim: a coin's edge, a doily, a lace cuff.
    struct Scalloped: Shape {
        var count: Int
        /// How far the scallops cut in, as a fraction of the radius.
        var depth: CGFloat

        func path(in r: CGRect) -> Path {
            let centre = CGPoint(x: r.midX, y: r.midY)
            let outer = min(r.width, r.height) / 2
            let inner = outer * (1 - depth)
            let half = Double.pi / Double(count)
            // A quadratic's apex sits halfway to its control, so the control is pushed past the rim.
            let reach = 2 * outer - inner * cos(half)
            var p = Path()
            for index in 0..<count {
                let a0 = Double(index) * 2 * half - .pi / 2
                let end = point(centre, inner, a0 + 2 * half)
                if index == 0 { p.move(to: point(centre, inner, a0)) }
                p.addQuadCurve(to: end, control: point(centre, reach, a0 + half))
            }
            p.closeSubpath()
            return p
        }

        private func point(_ c: CGPoint, _ radius: CGFloat, _ angle: Double) -> CGPoint {
            CGPoint(x: c.x + radius * cos(angle), y: c.y + radius * sin(angle))
        }
    }

    /// A ring of small dots: the holes worked into lace.
    struct DotRing: Shape {
        var count: Int
        /// The ring's radius and each dot's, as fractions of the rect's half size.
        var radius: CGFloat
        var dot: CGFloat

        func path(in r: CGRect) -> Path {
            let half = min(r.width, r.height) / 2
            var p = Path()
            for index in 0..<count {
                let angle = Double(index) / Double(count) * 2 * .pi
                let x = r.midX + half * radius * cos(angle)
                let y = r.midY + half * radius * sin(angle)
                let d = half * dot
                p.addEllipse(in: CGRect(x: x - d, y: y - d, width: d * 2, height: d * 2))
            }
            return p
        }
    }

    /// A woven repeat of small lozenges and dots on a staggered grid, for clipping into cloth.
    struct Brocade: Shape {
        /// Points between motifs, so the weave keeps its scale whatever it is clipped to.
        var step: CGFloat

        func path(in r: CGRect) -> Path {
            let s = max(step, 2)
            var p = Path()
            var row = 0
            var y = r.minY + s * 0.4
            while y < r.maxY + s {
                var x = r.minX + (row.isMultiple(of: 2) ? 0 : s / 2)
                while x < r.maxX + s {
                    motif(at: CGPoint(x: x, y: y), step: s, into: &p)
                    x += s
                }
                y += s * 0.8
                row += 1
            }
            return p
        }

        private func motif(at c: CGPoint, step s: CGFloat, into p: inout Path) {
            let d = s * 0.20
            p.addLines([CGPoint(x: c.x, y: c.y - d * 1.4), CGPoint(x: c.x + d, y: c.y),
                        CGPoint(x: c.x, y: c.y + d * 1.4), CGPoint(x: c.x - d, y: c.y)])
            p.closeSubpath()
            let dot = s * 0.06
            p.addEllipse(in: CGRect(x: c.x + s / 2 - dot, y: c.y - dot, width: dot * 2, height: dot * 2))
        }
    }

    // MARK: The frame

    /// One colour of the harlequin band: every other lozenge along the four sides. `phase`
    /// 0 and 1 are the two colours. Corners are left square for `BandCorners`.
    struct HarlequinBand: Shape {
        /// Both as fractions of the card's width.
        var inset: CGFloat
        var thickness: CGFloat
        var phase: Int

        func path(in r: CGRect) -> Path {
            let i = r.width * inset
            let t = r.width * thickness
            let long = r.height - 2 * (i + t)
            let wide = r.width - 2 * (i + t)
            var p = Path()
            lozenges(CGRect(x: r.minX + i + t, y: r.minY + i, width: wide, height: t), into: &p)
            lozenges(CGRect(x: r.minX + i + t, y: r.maxY - i - t, width: wide, height: t), into: &p)
            lozenges(CGRect(x: r.minX + i, y: r.minY + i + t, width: t, height: long), into: &p)
            lozenges(CGRect(x: r.maxX - i - t, y: r.minY + i + t, width: t, height: long), into: &p)
            return p
        }

        private func lozenges(_ s: CGRect, into p: inout Path) {
            let across = min(s.width, s.height)
            let along = max(s.width, s.height)
            let count = max(1, Int((along / (across * 1.5)).rounded()))
            let step = along / CGFloat(count)
            for index in 0..<count where index % 2 == phase {
                let a = step * CGFloat(index)
                let cell = s.width >= s.height
                    ? CGRect(x: s.minX + a, y: s.minY, width: step, height: s.height)
                    : CGRect(x: s.minX, y: s.minY + a, width: s.width, height: step)
                p.addPath(Lozenge().path(in: cell))
            }
        }
    }

    /// A gold lozenge in each corner square of the band.
    struct BandCorners: Shape {
        var inset: CGFloat
        var thickness: CGFloat

        func path(in r: CGRect) -> Path {
            let i = r.width * inset
            let t = r.width * thickness
            var p = Path()
            for x in [r.minX + i, r.maxX - i - t] {
                for y in [r.minY + i, r.maxY - i - t] {
                    p.addPath(Lozenge().path(in: CGRect(x: x, y: y, width: t, height: t)))
                }
            }
            return p
        }
    }

    /// A lace edge: small scallops along the inside of the band, bulging into the card.
    struct LaceEdge: Shape {
        /// The band's inner edge and each scallop's span, as fractions of the card's width.
        var inset: CGFloat
        var span: CGFloat

        func path(in r: CGRect) -> Path {
            let b = r.insetBy(dx: r.width * inset, dy: r.width * inset)
            let s = r.width * span
            var p = Path()
            run(CGPoint(x: b.minX, y: b.minY), CGPoint(x: b.maxX, y: b.minY), bulge: CGVector(dx: 0, dy: 1), s, &p)
            run(CGPoint(x: b.minX, y: b.maxY), CGPoint(x: b.maxX, y: b.maxY), bulge: CGVector(dx: 0, dy: -1), s, &p)
            run(CGPoint(x: b.minX, y: b.minY), CGPoint(x: b.minX, y: b.maxY), bulge: CGVector(dx: 1, dy: 0), s, &p)
            run(CGPoint(x: b.maxX, y: b.minY), CGPoint(x: b.maxX, y: b.maxY), bulge: CGVector(dx: -1, dy: 0), s, &p)
            return p
        }

        private func run(_ a: CGPoint, _ b: CGPoint, bulge: CGVector, _ span: CGFloat, _ p: inout Path) {
            let count = max(1, Int((hypot(b.x - a.x, b.y - a.y) / span).rounded()))
            let dx = (b.x - a.x) / CGFloat(count)
            let dy = (b.y - a.y) / CGFloat(count)
            p.move(to: a)
            for index in 0..<count {
                let start = CGPoint(x: a.x + dx * CGFloat(index), y: a.y + dy * CGFloat(index))
                let control = CGPoint(x: start.x + dx / 2 + bulge.dx * span * 0.8,
                                      y: start.y + dy / 2 + bulge.dy * span * 0.8)
                p.addQuadCurve(to: CGPoint(x: start.x + dx, y: start.y + dy), control: control)
            }
        }
    }
}
