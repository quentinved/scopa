import ScopaCore
import SwiftUI

/// The panel round every card: walnut cross-banding mitred at the corners, a string of
/// ebony, box and ebony inside it, and the field, two leaves of one veneer opened like a
/// book. A coin strings in brass for box; the settebello adds a band of pearl and ebony.
struct IntarsioFrame {
    let panel: IntarsioPanel
    let card: Card

    private var w: CGFloat { panel.w }
    private var h: CGFloat { panel.w * 1.5 }
    private var settebello: Bool { card == .settebello }

    /// Where the field starts, in card widths in from the edge.
    static func inset(_ card: Card) -> CGFloat { card == .settebello ? 0.092 : 0.083 }

    func inlay() {
        crossBanding()
        if settebello { gildedStringing() } else { stringing() }
        field()
    }

    /// A rounded rect `inset` card widths in from the edge, concentric with the card's.
    func rounded(_ inset: CGFloat) -> Path {
        let box = CGRect(x: 0, y: 0, width: w, height: h).insetBy(dx: inset * w, dy: inset * w)
        return RoundedRectangle(cornerRadius: w * max(0.02, 0.12 - inset)).path(in: box)
    }

    // MARK: Banding

    /// Short lengths of walnut laid with the grain across the band, mitred at the corners.
    private func crossBanding() {
        panel.context.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)), with: .color(IntarsioWood.walnut.face))
        guard panel.fine else { return }
        let d = w * 0.16
        let sides: [([CGPoint], CGFloat)] = [
            ([CGPoint(x: 0, y: 0), CGPoint(x: w, y: 0), CGPoint(x: w - d, y: d), CGPoint(x: d, y: d)], .pi / 2),
            ([CGPoint(x: 0, y: h), CGPoint(x: w, y: h), CGPoint(x: w - d, y: h - d), CGPoint(x: d, y: h - d)], .pi / 2),
            ([CGPoint(x: 0, y: 0), CGPoint(x: 0, y: h), CGPoint(x: d, y: h - d), CGPoint(x: d, y: d)], 0),
            ([CGPoint(x: w, y: 0), CGPoint(x: w, y: h), CGPoint(x: w - d, y: h - d), CGPoint(x: w - d, y: d)], 0),
        ]
        var joints = Path()
        for (corners, angle) in sides {
            var piece = Path()
            piece.addLines(corners)
            piece.closeSubpath()
            panel.grain(piece, .walnut, angle: angle)
            joints.move(to: corners[0])
            joints.addLine(to: corners[3])
        }
        // A joint between lengths every so often along each side.
        for x in [0.31, 0.64] as [CGFloat] {
            joints.move(to: CGPoint(x: x * w, y: 0)); joints.addLine(to: CGPoint(x: x * w, y: d))
            joints.move(to: CGPoint(x: (1 - x) * w, y: h)); joints.addLine(to: CGPoint(x: (1 - x) * w, y: h - d))
        }
        for y in [0.42, 0.79, 1.13] as [CGFloat] {
            joints.move(to: CGPoint(x: 0, y: y * w)); joints.addLine(to: CGPoint(x: d, y: y * w))
            joints.move(to: CGPoint(x: w, y: h - y * w)); joints.addLine(to: CGPoint(x: w - d, y: h - y * w))
        }
        panel.context.stroke(joints, with: .color(IntarsioWood.kerf), lineWidth: max(0.3, w * 0.006))
    }

    /// Ebony, box and ebony, each a fill inside the last. A coin strings in brass.
    private func stringing() {
        let middle: IntarsioWood = card.suit == .coins ? .brass : .box
        let courses: [(CGFloat, IntarsioWood)] = [(0.055, .ebony), (0.0615, middle), (0.0755, .ebony)]
        for (inset, wood) in courses { panel.context.fill(rounded(inset), with: .color(wood.face)) }
    }

    /// The settebello's: brass either side of a band of pearl squares set in ebony.
    private func gildedStringing() {
        let courses: [(CGFloat, IntarsioWood)] = [(0.048, .ebony), (0.053, .brass), (0.061, .ebony)]
        for (inset, wood) in courses { panel.context.fill(rounded(inset), with: .color(wood.face)) }
        chequer(inset: 0.0635, size: 0.0145)
        for (inset, wood) in [(0.080, IntarsioWood.brass), (0.086, .ebony)] {
            panel.context.fill(rounded(inset), with: .color(wood.face))
        }
    }

    /// Squares of pearl in a run along each straight side, the corners left in ebony.
    private func chequer(inset: CGFloat, size: CGFloat) {
        let s = size * w, a = inset * w, step = s * 2
        var squares = Path()
        var x = w * 0.15
        while x + s < w * 0.85 {
            squares.addRect(CGRect(x: x, y: a, width: s, height: s))
            squares.addRect(CGRect(x: w - x - s, y: h - a - s, width: s, height: s))
            x += step
        }
        var y = w * 0.15
        while y + s < h - w * 0.15 {
            squares.addRect(CGRect(x: a, y: y, width: s, height: s))
            squares.addRect(CGRect(x: w - a - s, y: h - y - s, width: s, height: s))
            y += step
        }
        panel.context.fill(squares, with: .color(IntarsioWood.pearl.face))
    }

    // MARK: Field

    /// Maple for a numeral, rosewood behind a court: two leaves of the same flitch, the
    /// right one the left turned over, so the cathedral figure meets itself at the seam.
    private func field() {
        let field = rounded(Self.inset(card))
        let wood: IntarsioWood = card.rank.isFace ? .rosewood : .maple
        panel.context.fill(field, with: .color(wood.face))
        guard panel.fine else { return }
        let box = field.boundingRect
        let leaf = CGRect(x: box.minX, y: box.minY, width: box.width / 2, height: box.height)
        let left = IntarsioGrain.cathedral(in: leaf, pitch: panel.pitch * 1.05, seed: panel.seed &+ 11)
        let right = left.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 2 * box.midX, ty: 0))
        var inside = panel.context
        inside.clip(to: field)
        let hair = max(0.3, w * 0.005)
        inside.stroke(left, with: .color(wood.grain), lineWidth: hair)
        inside.stroke(right, with: .color(wood.grain), lineWidth: hair)
        var seam = Path()
        seam.move(to: CGPoint(x: box.midX, y: box.minY))
        seam.addLine(to: CGPoint(x: box.midX, y: box.maxY))
        inside.stroke(seam, with: .color(IntarsioWood.kerf.opacity(0.6)), lineWidth: max(0.3, w * 0.005))
    }

    // MARK: Tablets

    /// The box cartouches a court's index is set in, ebony-strung, so the figure passes
    /// behind the number rather than through it.
    func tablets() {
        let size = Self.tablet(card.rank)
        let box = CGRect(x: 0.094 * w, y: 0.094 * w, width: size.width * w, height: size.height * w)
        let turned = CGRect(x: w - box.maxX, y: h - box.maxY, width: box.width, height: box.height)
        for rect in [box, turned] {
            let string = RoundedRectangle(cornerRadius: w * 0.04).path(in: rect.insetBy(dx: -w * 0.012, dy: -w * 0.012))
            panel.context.fill(string, with: .color(IntarsioWood.ebony.face))
            panel.lay(RoundedRectangle(cornerRadius: w * 0.03).path(in: rect), .box, grain: 0, scorch: .none)
        }
    }

    /// A tablet's size in card widths: wider for the king's two figures, taller for the
    /// knight's rule.
    static func tablet(_ rank: Rank) -> CGSize {
        CGSize(width: rank == .king ? 0.30 : 0.205, height: rank == .knight ? 0.30 : 0.265)
    }
}
