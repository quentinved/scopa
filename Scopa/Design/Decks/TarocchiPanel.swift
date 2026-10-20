import SwiftUI

/// The panel a Tarocchi face is painted on: a drawing context and the card's width, which
/// every measure follows. Places are in card widths, x across 0...1 and y down 0...1.5.
struct TarocchiPanel {
    let context: GraphicsContext
    let w: CGFloat

    /// Tooling, brocade, folds and flowers. Below this the colours lie flat in their lines.
    var fine: Bool { w >= 40 }
    /// The brush's fine dark outline.
    var hair: CGFloat { max(0.35, w * 0.0068) }

    // MARK: Painting

    /// Tempera laid flat inside the dark line; `line` scales the line, and 0 leaves it off.
    func paint(_ shape: Path, _ colour: Color, line: CGFloat = 1) {
        context.fill(shape, with: .color(colour))
        if line > 0 { context.stroke(shape, with: .color(Tempera.ink), lineWidth: hair * line) }
    }

    /// An open line through points, `weight` card widths across: a fold, a brow, a stem.
    func draw(_ spine: [(CGFloat, CGFloat)], _ colour: Color, _ weight: CGFloat) {
        stroke(curve(spine), colour, weight)
    }

    func stroke(_ path: Path, _ colour: Color, _ weight: CGFloat) {
        context.stroke(path, with: .color(colour),
                       style: StrokeStyle(lineWidth: max(0.3, w * weight), lineCap: .round, lineJoin: .round))
    }

    /// Punch marks `radius` points across at each centre, struck as one fill.
    func punch(_ centres: [CGPoint], radius: CGFloat, _ colour: Color = Tempera.punch) {
        var marks = Path()
        for c in centres {
            marks.addEllipse(in: CGRect(x: c.x - radius, y: c.y - radius, width: 2 * radius, height: 2 * radius))
        }
        context.fill(marks, with: .color(colour))
    }

    /// Punch marks `pitch` points apart along a path, struck as one dotted stroke.
    func punchRow(_ path: Path, radius: CGFloat, pitch: CGFloat, _ colour: Color = Tempera.punch) {
        context.stroke(path, with: .color(colour),
                       style: StrokeStyle(lineWidth: radius * 2, lineCap: .round, dash: [0.001, pitch]))
    }

    /// A row of ring punches: dots, with the leaf left standing at each one's heart.
    func ringRow(_ path: Path, radius: CGFloat, pitch: CGFloat) {
        punchRow(path, radius: radius, pitch: pitch)
        punchRow(path, radius: radius * 0.48, pitch: pitch, Tempera.gold)
    }

    /// The same panel, painting only inside `shape`.
    func within(_ shape: Path) -> TarocchiPanel {
        var inside = context
        inside.clip(to: shape)
        return TarocchiPanel(context: inside, w: w)
    }

    /// The same panel turned about `centre` by `angle`.
    func turned(_ angle: CGFloat, about centre: CGPoint) -> TarocchiPanel {
        var turned = context
        turned.translateBy(x: centre.x, y: centre.y)
        turned.rotate(by: .radians(angle))
        turned.translateBy(x: -centre.x, y: -centre.y)
        return TarocchiPanel(context: turned, w: w)
    }
}

// MARK: Drawing

extension TarocchiPanel {
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * w) }

    func oval(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: (x - rx) * w, y: (y - ry) * w, width: 2 * rx * w, height: 2 * ry * w))
    }

    /// A shape `pw` by `ph` centred on (x, y).
    func cut<S: Shape>(_ shape: S, _ x: CGFloat, _ y: CGFloat, _ pw: CGFloat, _ ph: CGFloat) -> Path {
        shape.path(in: CGRect(x: (x - pw / 2) * w, y: (y - ph / 2) * w, width: pw * w, height: ph * w))
    }

    /// A tapered band through a spine: an arm, a leg, a sleeve, a ribbon.
    func limb(_ spine: [(CGFloat, CGFloat)], _ widths: [CGFloat]) -> Path {
        Ribbon(spine: spine.map { CGPoint(x: $0.0, y: $0.1 / 1.5) }, widths: widths)
            .path(in: CGRect(x: 0, y: 0, width: w, height: w * 1.5))
    }

    /// An open curve through points.
    func curve(_ points: [(CGFloat, CGFloat)]) -> Path {
        Stroke(spine: points.map { CGPoint(x: $0.0, y: $0.1 / 1.5) })
            .path(in: CGRect(x: 0, y: 0, width: w, height: w * 1.5))
    }

    /// A closed outline rounded through its points, as a brush follows the underdrawing.
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

    /// A closed outline with straight sides.
    func polygon(_ points: [(CGFloat, CGFloat)]) -> Path {
        var path = Path()
        path.addLines(points.map { p($0.0, $0.1) })
        path.closeSubpath()
        return path
    }

    /// The other half of a figure, across the card's centre line.
    func mirrored(_ points: [(CGFloat, CGFloat)]) -> [(CGFloat, CGFloat)] { points.map { (1 - $0.0, $0.1) } }

    /// A rounded rect `inset` card widths in from the edge, concentric with the card's corner.
    func rounded(_ inset: CGFloat) -> Path {
        let box = CGRect(x: 0, y: 0, width: w, height: w * 1.5).insetBy(dx: inset * w, dy: inset * w)
        return RoundedRectangle(cornerRadius: w * max(0.02, 0.12 - inset)).path(in: box)
    }
}
