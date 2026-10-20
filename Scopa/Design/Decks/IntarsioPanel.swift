import SwiftUI

/// Where a piece was shaded in hot sand: darkened along one side, or all round its edge.
enum IntarsioScorch {
    case none
    case rim
    /// Toward this angle: 0 is right, π/2 down.
    case side(CGFloat)

    static let left = side(.pi)
    static let right = side(0)
    static let down = side(.pi / 2)
    static let lowerRight = side(.pi / 4)
    static let lowerLeft = side(.pi * 0.75)
}

/// The panel a face is inlaid on: a drawing context and the card's width, which every
/// measure follows. Places are in card widths, x across 0...1 and y down 0...1.5.
struct IntarsioPanel {
    let context: GraphicsContext
    let w: CGFloat
    var seed: UInt64 = 0

    /// Grain and sand shading. Below this the pieces are laid flat, with their kerfs.
    var fine: Bool { w >= 40 }
    private var hair: CGFloat { max(0.25, w * 0.0042) }
    private var kerfWidth: CGFloat { max(0.3, w * 0.006) }
    var pitch: CGFloat { w * 0.026 }

    // MARK: Laying

    /// One piece of veneer: cut, grained, scorched, and set with its kerf round it.
    func lay(_ piece: Path, _ wood: IntarsioWood, grain: CGFloat = .pi / 2,
             scorch: IntarsioScorch = .lowerRight, kerf: Bool = true) {
        context.fill(piece, with: .color(wood.face))
        if fine {
            var inside = context
            inside.clip(to: piece)
            let box = piece.boundingRect
            grained(box, wood, grain, in: inside)
            scorched(piece, box, wood, scorch, in: inside)
        }
        if kerf { context.stroke(piece, with: .color(IntarsioWood.kerf), lineWidth: kerfWidth) }
    }

    /// Grain over a piece already filled, clipped to it.
    func grain(_ piece: Path, _ wood: IntarsioWood, angle: CGFloat) {
        guard fine else { return }
        var inside = context
        inside.clip(to: piece)
        grained(piece.boundingRect, wood, angle, in: inside)
    }

    private func grained(_ box: CGRect, _ wood: IntarsioWood, _ angle: CGFloat, in inside: GraphicsContext) {
        guard wood.figure != .plain, min(box.width, box.height) > pitch * 0.6 else { return }
        let seed = seed(of: box)
        let wave = wood.figure == .straight ? pitch * 0.25 : pitch * 0.9
        let lines = IntarsioGrain.lines(in: box, angle: angle, pitch: pitch, wave: wave, seed: seed)
        inside.stroke(lines, with: .color(wood.grain), lineWidth: hair)
        if wood.figure == .streaked {
            let streaks = IntarsioGrain.lines(in: box, angle: angle, pitch: pitch * 3.2, wave: wave, seed: seed &+ 1)
            inside.stroke(streaks, with: .color(wood.grain.opacity(0.5)), lineWidth: hair * 3.5)
        }
    }

    private func scorched(_ piece: Path, _ box: CGRect, _ wood: IntarsioWood, _ scorch: IntarsioScorch,
                          in inside: GraphicsContext) {
        switch scorch {
        case .none:
            return
        case .rim:
            let reach = min(box.width, box.height)
            inside.stroke(piece, with: .color(wood.scorch.opacity(0.45)), lineWidth: reach * 0.30)
            inside.stroke(piece, with: .color(wood.scorch.opacity(0.55)), lineWidth: reach * 0.11)
        case let .side(angle):
            let (dx, dy) = (cos(angle), sin(angle))
            let half = abs(dx) * box.width / 2 + abs(dy) * box.height / 2
            let start = CGPoint(x: box.midX - dx * half * 0.15, y: box.midY - dy * half * 0.15)
            let end = CGPoint(x: box.midX + dx * half, y: box.midY + dy * half)
            inside.fill(Path(box), with: .linearGradient(Gradient(colors: [.clear, wood.scorch]),
                                                         startPoint: start, endPoint: end))
        }
    }

    /// A seed for a piece, from where it sits on the card, so it grains alike at every size.
    private func seed(of box: CGRect) -> UInt64 {
        let x = UInt64(truncatingIfNeeded: Int((box.midX / w * 300).rounded()))
        let y = UInt64(truncatingIfNeeded: Int((box.midY / w * 300).rounded()))
        return seed ^ (x &* 0x9E37_79B9) ^ (y &* 0x85EB_CA6B)
    }

    /// A line of stringing: one thin strip of wood or brass, no grain to show.
    func string(_ path: Path, _ wood: IntarsioWood, _ weight: CGFloat) {
        context.stroke(path, with: .color(wood.face), lineWidth: max(0.4, w * weight))
    }

    /// An engraved line filled with mastic, `weight` card widths across.
    func incise(_ spine: [(CGFloat, CGFloat)], _ weight: CGFloat) {
        context.stroke(line(spine), with: .color(IntarsioWood.mastic),
                       style: StrokeStyle(lineWidth: max(0.3, w * weight), lineCap: .round, lineJoin: .round))
    }

    /// The same panel turned about `centre` by `angle`, its pieces seeded afresh.
    func turned(_ angle: CGFloat, about centre: CGPoint) -> IntarsioPanel {
        var turned = context
        turned.translateBy(x: centre.x, y: centre.y)
        turned.rotate(by: .radians(angle))
        turned.translateBy(x: -centre.x, y: -centre.y)
        return IntarsioPanel(context: turned, w: w, seed: seed &+ UInt64(max(0, centre.x * 31 + centre.y * 17)))
    }
}

// MARK: Cutting

extension IntarsioPanel {
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * w) }

    func oval(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: (x - rx) * w, y: (y - ry) * w, width: 2 * rx * w, height: 2 * ry * w))
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

    /// Lays a limb with its grain running down it.
    func layLimb(_ spine: [(CGFloat, CGFloat)], _ widths: [CGFloat], _ wood: IntarsioWood,
                 scorch: IntarsioScorch = .lowerRight) {
        guard let first = spine.first, let last = spine.last else { return }
        lay(limb(spine, widths), wood, grain: atan2(last.1 - first.1, last.0 - first.0), scorch: scorch)
    }

    /// A closed outline rounded through its points, as a fretsaw follows a drawing.
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

    /// An open curve through points.
    func line(_ points: [(CGFloat, CGFloat)]) -> Path {
        var path = Path()
        IntarsioGrain.trace(points.map { p($0.0, $0.1) }, into: &path)
        if points.count == 2 { path.move(to: p(points[0].0, points[0].1)); path.addLine(to: p(points[1].0, points[1].1)) }
        return path
    }

    /// The other half of a figure, across the card's centre line.
    func mirrored(_ points: [(CGFloat, CGFloat)]) -> [(CGFloat, CGFloat)] { points.map { (1 - $0.0, $0.1) } }
}
