import SwiftUI

// MARK: - Finishing

/// Fills a shape the way the chosen style draws it: flat colour, colour under a fine line,
/// or a wash under a woodcut outline. Every filled part of every figure goes through here.
struct Drawn<S: Shape>: View {
    let shape: S
    let style: CardStyle
    let colour: Color
    let ink: Color
    /// The figure's size, so the outline scales with the drawing rather than the shape.
    let unit: CGFloat

    // Only the paper is read from the environment. The style arrives as a parameter so a
    // shape drawn in a hand other than the equipped one keeps its own wash.
    @Environment(\.cardTheme) private var theme

    init(_ shape: S, style: CardStyle, colour: Color, ink: Color, unit: CGFloat) {
        self.shape = shape
        self.style = style
        self.colour = colour
        self.ink = ink
        self.unit = unit
    }

    var body: some View {
        shape
            .fill(colour.opacity(theme.fillOpacity(for: style)))
            .overlay {
                if style.outlineOpacity > 0 {
                    shape.stroke(ink.opacity(style.outlineOpacity),
                                 lineWidth: max(0.5, unit * style.outlineWeight))
                }
            }
    }
}

// MARK: - Ribbon

/// A tapered band running through a spine of points: a leg, an arm, a tail, a lock of mane.
///
/// The spine is in unit coordinates against the rect's width and height. The widths are
/// against its shorter side, so a limb inside a wide box does not come out fat.
struct Ribbon: Shape {
    var spine: [CGPoint]
    var widths: [CGFloat]

    func path(in r: CGRect) -> Path {
        guard spine.count > 1, widths.count == spine.count else { return Path() }
        let unit = min(r.width, r.height)
        let points = spine.map { CGPoint(x: r.minX + r.width * $0.x, y: r.minY + r.height * $0.y) }

        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for index in points.indices {
            let before = points[max(index - 1, 0)]
            let after = points[min(index + 1, points.count - 1)]
            let run = CGPoint(x: after.x - before.x, y: after.y - before.y)
            let length = max(hypot(run.x, run.y), 0.0001)
            let half = widths[index] * unit / 2
            let normal = CGPoint(x: -run.y / length * half, y: run.x / length * half)
            left.append(CGPoint(x: points[index].x + normal.x, y: points[index].y + normal.y))
            right.append(CGPoint(x: points[index].x - normal.x, y: points[index].y - normal.y))
        }

        var path = Path()
        trace(left, into: &path)
        trace(right.reversed(), into: &path)
        path.closeSubpath()
        return path
    }

    /// Curves through the points rather than joining them, so a bent limb reads as flesh.
    private func trace(_ points: [CGPoint], into path: inout Path) {
        guard let first = points.first else { return }
        if path.isEmpty { path.move(to: first) } else { path.addLine(to: first) }
        guard points.count > 2 else {
            points.dropFirst().forEach { path.addLine(to: $0) }
            return
        }
        for index in 1..<(points.count - 1) {
            let next = points[index + 1]
            let mid = CGPoint(x: (points[index].x + next.x) / 2, y: (points[index].y + next.y) / 2)
            path.addQuadCurve(to: mid, control: points[index])
        }
        path.addLine(to: points[points.count - 1])
    }
}

/// A curved path through points with no width, for reins, fold lines and hatching.
struct Stroke: Shape {
    var spine: [CGPoint]

    func path(in r: CGRect) -> Path {
        guard spine.count > 1 else { return Path() }
        let points = spine.map { CGPoint(x: r.minX + r.width * $0.x, y: r.minY + r.height * $0.y) }
        var path = Path()
        path.move(to: points[0])
        guard points.count > 2 else {
            points.dropFirst().forEach { path.addLine(to: $0) }
            return path
        }
        for index in 1..<(points.count - 1) {
            let next = points[index + 1]
            let mid = CGPoint(x: (points[index].x + next.x) / 2, y: (points[index].y + next.y) / 2)
            path.addQuadCurve(to: mid, control: points[index])
        }
        path.addLine(to: points[points.count - 1])
        return path
    }
}

// MARK: - Figure parts

/// A head in three-quarter profile facing left, with the brow, nose and chin cut into the
/// leading edge.
struct Head: Shape {
    func path(in r: CGRect) -> Path {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y)
        }
        var p = Path()
        p.move(to: at(0.50, 0.005))
        p.addQuadCurve(to: at(0.145, 0.300), control: at(0.205, 0.035))   // brow
        p.addLine(to: at(0.115, 0.400))                                    // bridge
        p.addQuadCurve(to: at(0.022, 0.520), control: at(0.022, 0.452))   // nose
        p.addQuadCurve(to: at(0.140, 0.598), control: at(0.062, 0.606))   // lip
        p.addQuadCurve(to: at(0.212, 0.780), control: at(0.132, 0.706))   // chin
        p.addQuadCurve(to: at(0.540, 0.975), control: at(0.302, 0.948))   // jaw
        p.addQuadCurve(to: at(0.965, 0.590), control: at(0.878, 0.926))
        p.addQuadCurve(to: at(0.50, 0.005), control: at(1.005, 0.150))
        p.closeSubpath()
        return p
    }
}

/// The mass of hair over the crown and down behind the ear.
struct Hair: Shape {
    func path(in r: CGRect) -> Path {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y)
        }
        var p = Path()
        p.move(to: at(0.075, 0.900))
        p.addQuadCurve(to: at(0.520, 0.030), control: at(0.140, 0.180))
        p.addQuadCurve(to: at(0.975, 0.760), control: at(0.960, 0.150))
        p.addQuadCurve(to: at(0.760, 0.640), control: at(0.900, 0.640))
        p.addQuadCurve(to: at(0.075, 0.900), control: at(0.420, 0.430))
        p.closeSubpath()
        return p
    }
}

/// A beard: a wedge under the jaw, widest at the chin and tapering to the ear.
struct Beard: Shape {
    func path(in r: CGRect) -> Path {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y)
        }
        var p = Path()
        p.move(to: at(0.140, 0.070))
        p.addQuadCurve(to: at(0.330, 0.960), control: at(0.075, 0.640))
        p.addQuadCurve(to: at(0.820, 0.560), control: at(0.640, 0.980))
        p.addQuadCurve(to: at(0.900, 0.060), control: at(0.940, 0.320))
        p.addQuadCurve(to: at(0.140, 0.070), control: at(0.520, 0.320))
        p.closeSubpath()
        return p
    }
}

/// A robe: narrow at the shoulders, flaring to the hem.
struct Robe: Shape {
    var flare: CGFloat

    func path(in r: CGRect) -> Path {
        let spread = r.width * flare
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.22, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.22, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX + spread * 0.5, y: r.maxY),
                       control: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.minX - spread * 0.5, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX + r.width * 0.22, y: r.minY),
                       control: CGPoint(x: r.minX, y: r.midY))
        p.closeSubpath()
        return p
    }
}

/// The collar of a mantle falling over both shoulders.
struct Mantle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY),
                       control: CGPoint(x: r.maxX - r.width * 0.08, y: r.minY + r.height * 0.28))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.34),
                       control: CGPoint(x: r.midX + r.width * 0.22, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY),
                       control: CGPoint(x: r.midX - r.width * 0.22, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY),
                       control: CGPoint(x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.28))
        p.closeSubpath()
        return p
    }
}

/// A soft cap with a turned brim, for the fante.
struct Cap: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX - r.width * 0.10, y: r.minY + r.height * 0.18),
                       control: CGPoint(x: r.minX + r.width * 0.20, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY),
                       control: CGPoint(x: r.maxX, y: r.minY + r.height * 0.70))
        p.closeSubpath()
        return p
    }
}

/// A rounded helm with a nasal, for the cavallo.
struct Helmet: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: r.midX, y: r.maxY),
                 radius: r.width / 2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY + r.height * 0.10))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY + r.height * 0.10))
        p.closeSubpath()
        return p
    }
}

/// Three points over a band.
struct KingCrown: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.42))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.22, y: r.minY + r.height * 0.72))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.32, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.62))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.32, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.22, y: r.minY + r.height * 0.72))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.42))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Pip parts

/// A bowl: `roundness` at 1 is a hemisphere, at 0 a straight-sided beaker.
struct Bowl: Shape {
    var roundness: CGFloat

    func path(in r: CGRect) -> Path {
        var p = Path()
        let pull = r.height * roundness
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY),
                   control1: CGPoint(x: r.maxX, y: r.minY + pull),
                   control2: CGPoint(x: r.midX + r.width * 0.30, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY),
                   control1: CGPoint(x: r.midX - r.width * 0.30, y: r.maxY),
                   control2: CGPoint(x: r.minX, y: r.minY + pull))
        p.closeSubpath()
        return p
    }
}

/// Narrower at the top than the bottom, or the other way about when `topRatio` exceeds 1.
struct Trapezoid: Shape {
    var topRatio: CGFloat

    func path(in r: CGRect) -> Path {
        let inset = (r.width - r.width * min(topRatio, 1)) / 2
        let outset = topRatio > 1 ? r.width * (topRatio - 1) / 2 : 0
        var p = Path()
        p.move(to: CGPoint(x: r.minX + inset - outset, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - inset + outset, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// A cudgel: thin at the grip, swelling towards the head.
struct Cudgel: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let grip = r.width * 0.34
        p.move(to: CGPoint(x: r.midX - grip / 2, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.14),
                   control1: CGPoint(x: r.midX - grip / 2, y: r.midY),
                   control2: CGPoint(x: r.minX, y: r.midY))
        p.addArc(center: CGPoint(x: r.midX, y: r.minY + r.height * 0.14),
                 radius: r.width / 2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(to: CGPoint(x: r.midX + grip / 2, y: r.maxY),
                   control1: CGPoint(x: r.maxX, y: r.midY),
                   control2: CGPoint(x: r.midX + grip / 2, y: r.midY))
        p.closeSubpath()
        return p
    }
}

struct Star: Shape {
    var points: Int

    func path(in r: CGRect) -> Path {
        let centre = CGPoint(x: r.midX, y: r.midY)
        let outer = min(r.width, r.height) / 2
        let inner = outer * 0.46
        var p = Path()
        for index in 0..<(points * 2) {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = Double(index) * .pi / Double(points) - .pi / 2
            let point = CGPoint(x: centre.x + cos(angle) * radius, y: centre.y + sin(angle) * radius)
            if index == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath()
        return p
    }
}

/// Parallel strokes, for the woodcut's shading.
struct Hatching: Shape {
    var count: Int

    func path(in r: CGRect) -> Path {
        var p = Path()
        let step = r.height / CGFloat(count + 1)
        for index in 1...count {
            let y = r.minY + step * CGFloat(index)
            p.move(to: CGPoint(x: r.minX, y: y))
            p.addLine(to: CGPoint(x: r.maxX, y: y))
        }
        return p
    }
}

/// A curved sabre, hilt at the bottom left. Straight blades do not cross legibly at pip size.
struct Sabre: Shape {
    func path(in r: CGRect) -> Path {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y)
        }
        var p = Path()
        p.move(to: at(0.10, 0.98))
        p.addCurve(to: at(0.98, 0.02), control1: at(0.04, 0.42), control2: at(0.60, 0.02))
        p.addCurve(to: at(0.30, 0.98), control1: at(0.56, 0.24), control2: at(0.26, 0.52))
        p.closeSubpath()
        return p
    }
}

/// A leaf, pointed at the top and swelling below the middle.
///
/// Each side is one curve cut in half at its widest point, which is the same outline a
/// single quadratic from tip to tip draws. The halves are there so the two widest points
/// are on the path rather than implied by a control point: a path whose own points all sit
/// on one vertical line has a flat bounding box, and a gradient fill given a flat box
/// paints nothing — the laurel was invisible wherever it was struck in gold.
struct Leaf: Shape {
    func path(in r: CGRect) -> Path {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y)
        }
        var p = Path()
        p.move(to: at(0.50, 1.00))
        p.addQuadCurve(to: at(0.25, 0.54), control: at(0.25, 0.79))
        p.addQuadCurve(to: at(0.50, 0.00), control: at(0.25, 0.29))
        p.addQuadCurve(to: at(0.75, 0.54), control: at(0.75, 0.29))
        p.addQuadCurve(to: at(0.50, 1.00), control: at(0.75, 0.79))
        p.closeSubpath()
        return p
    }
}

/// A blade: flat shoulders, then straight down.
struct SwordBlade: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.20))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.20))
        p.closeSubpath()
        return p
    }
}
