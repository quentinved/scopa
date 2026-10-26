import SwiftUI

/// The second road's plates, engraved like the first's: Tuscan hills and Brunelleschi's dome,
/// Apulian trulli under an olive, a Sardinian nuraghe over the granite, Milan's spires and
/// its Galleria. Line art only, each a pure function of the rect it is laid in.
extension Engraving {
    // MARK: Toscana

    /// Three long swells of hill across the plate, the nearest one lowest.
    static func hills(_ rect: CGRect) -> Path {
        var path = Path()
        for index in 0..<3 {
            let (start, one, two, end) = hill(index, in: rect)
            path.move(to: start)
            path.addCurve(to: end, control1: one, control2: two)
        }
        return path
    }

    /// The four points of hill `index`'s cubic, shared with the cypresses that stand on it.
    private static func hill(_ index: Int, in rect: CGRect) -> (CGPoint, CGPoint, CGPoint, CGPoint) {
        let y = rect.minY + rect.height * (0.34 + CGFloat(index) * 0.09)
        let rise = 46 - CGFloat(index) * 10
        return (CGPoint(x: rect.minX - 10, y: y),
                CGPoint(x: rect.minX + rect.width * (0.3 + CGFloat(index) * 0.1), y: y - rise),
                CGPoint(x: rect.minX + rect.width * 0.62, y: y + rise),
                CGPoint(x: rect.maxX + 10, y: y + 18))
    }

    /// A line of cypresses along the first hill's crest, tall flames on short trunks.
    static func cypresses(_ rect: CGRect) -> Path {
        let (a, b, c, d) = hill(0, in: rect)
        var path = Path()
        for (index, t) in ([0.12, 0.17, 0.22, 0.27, 0.32] as [CGFloat]).enumerated() {
            let foot = cubic(t, a, b, c, d)
            let height: CGFloat = index % 2 == 0 ? 56 : 46
            path.move(to: CGPoint(x: foot.x, y: foot.y - height))
            path.addQuadCurve(to: CGPoint(x: foot.x, y: foot.y - 4), control: CGPoint(x: foot.x + 13, y: foot.y - height * 0.35))
            path.addQuadCurve(to: CGPoint(x: foot.x, y: foot.y - height), control: CGPoint(x: foot.x - 13, y: foot.y - height * 0.35))
            path.move(to: CGPoint(x: foot.x, y: foot.y - 4))
            path.addLine(to: CGPoint(x: foot.x, y: foot.y + 4))
        }
        return path
    }

    /// Florence's dome on its drum: pointed, ribbed, the lantern on top, the roofs at its foot.
    static func cupola(_ rect: CGRect) -> Path {
        let x = rect.minX + rect.width * 0.8
        let foot = rect.minY + rect.height * 0.8
        let drum = foot - 34, top = drum - 74
        var path = Path()
        path.addRect(CGRect(x: x - 40, y: drum, width: 80, height: 34))
        for window: CGFloat in [-22, 0, 22] {
            path.addEllipse(in: CGRect(x: x + window - 5, y: drum + 10, width: 10, height: 10))
        }
        path.move(to: CGPoint(x: x - 38, y: drum))
        path.addQuadCurve(to: CGPoint(x: x - 8, y: top), control: CGPoint(x: x - 38, y: top + 20))
        path.addLine(to: CGPoint(x: x + 8, y: top))
        path.addQuadCurve(to: CGPoint(x: x + 38, y: drum), control: CGPoint(x: x + 38, y: top + 20))
        for rib: CGFloat in [-15, 15] {
            path.move(to: CGPoint(x: x + rib, y: drum))
            path.addQuadCurve(to: CGPoint(x: x + rib * 0.25, y: top), control: CGPoint(x: x + rib * 1.15, y: top + 26))
        }
        path.addRect(CGRect(x: x - 7, y: top - 18, width: 14, height: 18))
        path.move(to: CGPoint(x: x - 7, y: top - 18))
        path.addLine(to: CGPoint(x: x, y: top - 30))
        path.addLine(to: CGPoint(x: x + 7, y: top - 18))
        path.move(to: CGPoint(x: x, y: top - 30))
        path.addLine(to: CGPoint(x: x, y: top - 38))
        path.move(to: CGPoint(x: x - 76, y: foot))
        path.addLine(to: CGPoint(x: x + 76, y: foot))
        return path
    }

    // MARK: Puglia

    /// Three trulli down the left: whitewashed walls, an arched door, a cone of stone courses
    /// and the ball on its point.
    static func trulli(_ rect: CGRect) -> Path {
        let foot = rect.minY + rect.height * 0.44
        var path = Path()
        let trulli: [(offset: CGFloat, scale: CGFloat)] = [(0.1, 0.9), (0.22, 1.15), (0.34, 0.8)]
        for (offset, scale) in trulli {
            path.addPath(trullo(at: CGPoint(x: rect.minX + rect.width * offset, y: foot), scale: scale))
        }
        path.move(to: CGPoint(x: rect.minX, y: foot))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.44, y: foot))
        return path
    }

    private static func trullo(at foot: CGPoint, scale s: CGFloat) -> Path {
        let half = 22 * s, eave = foot.y - 30 * s, cone = 46 * s
        var path = Path()
        path.addRect(CGRect(x: foot.x - half, y: eave, width: half * 2, height: 30 * s))
        path.move(to: CGPoint(x: foot.x - 6 * s, y: foot.y))
        path.addLine(to: CGPoint(x: foot.x - 6 * s, y: foot.y - 12 * s))
        path.addArc(center: CGPoint(x: foot.x, y: foot.y - 12 * s), radius: 6 * s,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: foot.x + 6 * s, y: foot.y))
        path.move(to: CGPoint(x: foot.x - half - 2, y: eave))
        path.addQuadCurve(to: CGPoint(x: foot.x, y: eave - cone), control: CGPoint(x: foot.x - half * 0.55, y: eave - cone * 0.55))
        path.addQuadCurve(to: CGPoint(x: foot.x + half + 2, y: eave), control: CGPoint(x: foot.x + half * 0.55, y: eave - cone * 0.55))
        for course in 1...3 {
            let y = eave - cone * CGFloat(course) / 4.5
            let reach = half * (1 - CGFloat(course) / 4.2)
            path.move(to: CGPoint(x: foot.x - reach, y: y))
            path.addLine(to: CGPoint(x: foot.x + reach, y: y))
        }
        path.addEllipse(in: CGRect(x: foot.x - 3 * s, y: eave - cone - 7 * s, width: 6 * s, height: 6 * s))
        return path
    }

    /// An old olive on the right: a trunk in two twisted strands and a loose crown of leaves.
    static func olive(_ rect: CGRect) -> Path {
        let x = rect.minX + rect.width * 0.76, foot = rect.minY + rect.height * 0.64
        var path = Path()
        path.move(to: CGPoint(x: x - 10, y: foot))
        path.addCurve(to: CGPoint(x: x - 18, y: foot - 64), control1: CGPoint(x: x + 6, y: foot - 22),
                      control2: CGPoint(x: x - 26, y: foot - 36))
        path.move(to: CGPoint(x: x + 10, y: foot))
        path.addCurve(to: CGPoint(x: x + 20, y: foot - 60), control1: CGPoint(x: x - 4, y: foot - 24),
                      control2: CGPoint(x: x + 26, y: foot - 34))
        let leaves: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [(-40, -76, 16), (-18, -92, 18), (8, -96, 17),
                                                               (32, -84, 16), (-26, -62, 12), (24, -64, 12)]
        for leaf in leaves {
            path.addEllipse(in: CGRect(x: x + leaf.x - leaf.r, y: foot + leaf.y - leaf.r * 0.7,
                                       width: leaf.r * 2, height: leaf.r * 1.4))
        }
        path.move(to: CGPoint(x: x - 60, y: foot))
        path.addLine(to: CGPoint(x: x + 60, y: foot))
        return path
    }

    // MARK: Sardegna

    /// A nuraghe on the right: a truncated cone of dry stone, its joints staggered course by
    /// course, and the low doorway at its foot.
    static func nuraghe(_ rect: CGRect) -> Path {
        let x = rect.minX + rect.width * 0.74, foot = rect.minY + rect.height * 0.42
        let height: CGFloat = 120, base: CGFloat = 54, top: CGFloat = 34, courses = 8
        var path = Path()
        path.addLines([CGPoint(x: x - base, y: foot), CGPoint(x: x - top, y: foot - height),
                       CGPoint(x: x + top, y: foot - height), CGPoint(x: x + base, y: foot)])
        path.closeSubpath()
        for course in 1..<courses {
            let y = foot - height * CGFloat(course) / CGFloat(courses)
            let half = base - (base - top) * CGFloat(course) / CGFloat(courses)
            path.move(to: CGPoint(x: x - half, y: y))
            path.addLine(to: CGPoint(x: x + half, y: y))
            var joint = x - half + (course % 2 == 0 ? 10 : 21)
            while joint < x + half - 6 {
                // None through the doorway.
                if course > 1 || abs(joint - x) > 12 {
                    path.move(to: CGPoint(x: joint, y: y))
                    path.addLine(to: CGPoint(x: joint, y: y + height / CGFloat(courses)))
                }
                joint += 22
            }
        }
        path.addRect(CGRect(x: x - 7, y: foot - 22, width: 14, height: 22))
        return path
    }

    /// Granite boulders on the shore down the left, worn round by the wind, each split once.
    static func boulders(_ rect: CGRect) -> Path {
        let shore = rect.minY + rect.height * 0.64
        var path = Path()
        let stones: [(offset: CGFloat, width: CGFloat, height: CGFloat)] = [(0.06, 70, 44), (0.2, 54, 60), (0.32, 40, 30)]
        for (offset, width, height) in stones {
            let x = rect.minX + rect.width * offset
            path.move(to: CGPoint(x: x, y: shore))
            path.addCurve(to: CGPoint(x: x + width, y: shore), control1: CGPoint(x: x - 4, y: shore - height * 1.3),
                          control2: CGPoint(x: x + width * 0.9, y: shore - height * 1.2))
            path.move(to: CGPoint(x: x + width * 0.3, y: shore - height * 0.75))
            path.addQuadCurve(to: CGPoint(x: x + width * 0.62, y: shore - height * 0.3),
                              control: CGPoint(x: x + width * 0.55, y: shore - height * 0.7))
        }
        path.move(to: CGPoint(x: rect.minX, y: shore))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.46, y: shore))
        return path
    }

    // MARK: Lombardia

    /// The Duomo's front: its gable, three pointed doors, and a forest of spires, the middle
    /// one tallest with the Madonnina on it.
    static func spires(_ rect: CGRect) -> Path {
        let mid = rect.minX + rect.width * 0.3
        let foot = rect.minY + rect.height * 0.44
        let eave = foot - 90
        // The gable's height `dx` out from the middle.
        let gable = { (dx: CGFloat) in eave - 44 + abs(dx) * 0.55 }
        var path = Path()
        path.addLines([CGPoint(x: mid - 80, y: foot), CGPoint(x: mid - 80, y: gable(-80)), CGPoint(x: mid, y: gable(0)),
                       CGPoint(x: mid + 80, y: gable(80)), CGPoint(x: mid + 80, y: foot)])
        let needles: [(dx: CGFloat, rise: CGFloat)] = [(-80, 34), (-48, 58), (-16, 74), (16, 74), (48, 58), (80, 34)]
        for needle in needles {
            let x = mid + needle.dx, base = gable(needle.dx)
            path.move(to: CGPoint(x: x, y: foot))
            path.addLine(to: CGPoint(x: x, y: base))
            path.addLines([CGPoint(x: x - 3, y: base), CGPoint(x: x, y: base - needle.rise), CGPoint(x: x + 3, y: base)])
        }
        path.move(to: CGPoint(x: mid, y: gable(0)))
        path.addLine(to: CGPoint(x: mid, y: gable(0) - 96))
        path.addEllipse(in: CGRect(x: mid - 3, y: gable(0) - 104, width: 6, height: 8))
        let doors: [(dx: CGFloat, width: CGFloat, height: CGFloat)] = [(-32, 16, 32), (0, 22, 44), (32, 16, 32)]
        for (dx, width, height) in doors {
            let x = mid + dx
            path.move(to: CGPoint(x: x - width / 2, y: foot))
            path.addLine(to: CGPoint(x: x - width / 2, y: foot - height * 0.6))
            path.addQuadCurve(to: CGPoint(x: x, y: foot - height), control: CGPoint(x: x - width / 2, y: foot - height * 0.9))
            path.addQuadCurve(to: CGPoint(x: x + width / 2, y: foot - height * 0.6),
                              control: CGPoint(x: x + width / 2, y: foot - height * 0.9))
            path.addLine(to: CGPoint(x: x + width / 2, y: foot))
        }
        return path
    }

    /// The Galleria's front on the right: the great arch, rows of windows either side, and
    /// the ribbed glass vault showing over the top.
    static func galleria(_ rect: CGRect) -> Path {
        let x = rect.minX + rect.width * 0.76, foot = rect.minY + rect.height * 0.72
        let roof = foot - 120
        var path = Path()
        path.addRect(CGRect(x: x - 64, y: roof, width: 128, height: 120))
        path.move(to: CGPoint(x: x - 34, y: foot))
        path.addLine(to: CGPoint(x: x - 34, y: foot - 66))
        path.addArc(center: CGPoint(x: x, y: foot - 66), radius: 34, startAngle: .degrees(180), endAngle: .degrees(0),
                    clockwise: false)
        path.addLine(to: CGPoint(x: x + 34, y: foot))
        for side: CGFloat in [-1, 1] {
            for row in 0..<3 {
                path.addRect(CGRect(x: x + side * 50 - 4, y: roof + 14 + CGFloat(row) * 34, width: 8, height: 16))
            }
        }
        path.move(to: CGPoint(x: x - 46, y: roof))
        path.addQuadCurve(to: CGPoint(x: x + 46, y: roof), control: CGPoint(x: x, y: roof - 56))
        for rib: CGFloat in [-24, 0, 24] {
            let t = (rib + 46) / 92
            path.move(to: CGPoint(x: x + rib, y: roof))
            path.addLine(to: CGPoint(x: x + rib, y: roof - 112 * t * (1 - t)))
        }
        return path
    }

    // MARK: Plumbing

    private static func cubic(_ t: CGFloat, _ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> CGPoint {
        let u = 1 - t
        let x = u * u * u * a.x + 3 * u * u * t * b.x + 3 * u * t * t * c.x + t * t * t * d.x
        let y = u * u * u * a.y + 3 * u * u * t * b.y + 3 * u * t * t * c.y + t * t * t * d.y
        return CGPoint(x: x, y: y)
    }
}
