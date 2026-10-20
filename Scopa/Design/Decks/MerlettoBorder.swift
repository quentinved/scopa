import ScopaCore
import SwiftUI

/// The edging round every card: a raised cord in the suit's thread at the footing, a band
/// of réseau, a row of toile scallops picoted along the field, and a rosette in the two
/// corners the index leaves free. The settebello's runs in gold, with a second cord.
struct MerlettoBorder {
    let pillow: MerlettoPillow
    let card: Card

    private var w: CGFloat { pillow.w }
    private var h: CGFloat { pillow.w * 1.5 }
    private var settebello: Bool { card == .settebello }
    private var accent: MerlettoThread { settebello ? .gold : .house(card.suit) }

    /// Where the footing cord runs, in card widths in from the edge.
    static let footing: CGFloat = 0.036
    /// Where the scallops hang from: the field's edge.
    static let inner: CGFloat = 0.088
    private static let fieldRadius: CGFloat = 0.05

    func work() {
        let band = rounded(Self.footing)
        var ring = band
        ring.addPath(field)
        pillow.net(ring, cell: 0.026, cord: nil, parted: false, eo: true)
        if settebello { pillow.cordonnet(rounded((Self.footing + Self.inner) / 2), .gold, weight: 0.6) }
        scallopRow()
        pillow.cordonnet(band, accent, weight: 1.35)
        rosettes()
    }

    /// A rounded rect `inset` card widths in from the edge, concentric with the card's.
    func rounded(_ inset: CGFloat) -> Path {
        let box = CGRect(x: 0, y: 0, width: w, height: h).insetBy(dx: inset * w, dy: inset * w)
        return RoundedRectangle(cornerRadius: w * max(0.02, 0.12 - inset)).path(in: box)
    }

    /// The field inside the edging, the scallops hanging over its rim.
    var field: Path {
        let box = CGRect(x: 0, y: 0, width: w, height: h).insetBy(dx: Self.inner * w, dy: Self.inner * w)
        return RoundedRectangle(cornerRadius: w * Self.fieldRadius).path(in: box)
    }

    /// Half-discs of toile along each side, clockwise from the top, one cord round them all.
    private func scallopRow() {
        let (i, r) = (Self.inner * w, Self.fieldRadius * w)
        let runs: [(CGPoint, CGPoint, Int)] = [
            (CGPoint(x: i + r, y: i), CGPoint(x: w - i - r, y: i), 13),
            (CGPoint(x: w - i, y: i + r), CGPoint(x: w - i, y: h - i - r), 22),
            (CGPoint(x: w - i - r, y: h - i), CGPoint(x: i + r, y: h - i), 13),
            (CGPoint(x: i, y: h - i - r), CGPoint(x: i, y: i + r), 22),
        ]
        var shape = Path()
        var tips: [CGPoint] = []
        for (a, b, count) in runs {
            let (run, picots) = pillow.scallops(from: a, to: b, count: count, picots: 3)
            shape.addPath(run)
            tips += picots
        }
        pillow.toile(shape, rows: 0, parted: false)
        pillow.picots(tips, settebello ? .gold : .linen)
    }

    /// A six-bead rosette in the free corners, its heart in the suit's thread.
    private func rosettes() {
        let inset = Self.inner + 0.035
        for corner in [pillow.p(1 - inset, inset), pillow.p(inset, 1.5 - inset)] {
            let (petals, tips) = pillow.beads(corner, w * 0.022, w * 0.022, count: 6, r: w * 0.015, from: -.pi / 2)
            pillow.toile(petals, rows: .pi / 4)
            pillow.toile(pillow.circle(corner, w * 0.013), accent, parted: false)
            pillow.picots(tips, settebello ? .gold : .linen, size: 0.8)
        }
    }

    // MARK: Tablets

    /// The velvet windows the index is worked in, corded and picoted along the two sides
    /// that face the field.
    func tablets() {
        let size = Self.tablet(card.rank)
        let box = CGRect(x: Self.tabletInset * w, y: Self.tabletInset * w, width: size.width * w, height: size.height * w)
        let turned = CGRect(x: w - box.maxX, y: h - box.maxY, width: box.width, height: box.height)
        for (rect, outward) in [(box, CGFloat(1)), (turned, -1)] {
            let window = RoundedRectangle(cornerRadius: w * 0.035).path(in: rect)
            pillow.part(window)
            pillow.context.fill(window, with: .color(pillow.velvet))
            pillow.cordonnet(window, .linen, weight: 0.9)
            pillow.picots(tabletPicots(rect, outward), settebello ? .gold : .linen, size: 0.8)
        }
    }

    private func tabletPicots(_ rect: CGRect, _ outward: CGFloat) -> [CGPoint] {
        let off = pillow.picot * 1.6 + pillow.cord * 0.5
        let (edgeX, edgeY) = outward > 0 ? (rect.maxX + off, rect.maxY + off) : (rect.minX - off, rect.minY - off)
        let down = (1...3).map { CGPoint(x: edgeX, y: rect.minY + rect.height * CGFloat($0) / 4) }
        let across = (1...2).map { CGPoint(x: rect.minX + rect.width * CGFloat($0) / 3, y: edgeY) }
        return down + across
    }

    static let tabletInset: CGFloat = 0.108

    /// A tablet's size in card widths: wider for the king's two figures, taller for a rule.
    static func tablet(_ rank: Rank) -> CGSize {
        let ruled = rank == .six || rank == .knight
        return CGSize(width: rank == .king ? 0.235 : 0.165, height: ruled ? 0.255 : 0.235)
    }
}
