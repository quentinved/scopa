import SwiftUI

// MARK: Lino

extension TapisWeave {
    /// Linen: a plain weave of uneven threads across the whole cloth, a hem turned under
    /// round the edge and held with a running stitch, and inside it a hemstitched ladder —
    /// the drawn-thread border a good tablecloth is finished with.
    func lino(_ context: inout GraphicsContext, whole: CGRect, visible: CGRect) {
        weave(&context, in: whole)
        let hem = visible.insetBy(dx: pt(12), dy: pt(12))
        let radius = pt(44)
        let depth = pt(13)
        let fold = hem.insetBy(dx: depth, dy: depth)
        guard fold.width > 0, fold.height > 0 else { return }

        // The hem is two layers of the same linen, so a shade lighter than the cloth.
        var band = roundedPath(hem, radius: radius)
        band.addPath(roundedPath(fold, radius: radius - depth))
        context.fill(band, with: Self.cream(0.05), style: FillStyle(eoFill: true))
        raise(roundedPath(fold, radius: radius - depth), in: &context, with: Self.cream(0.12), width: 0.8)
        context.stroke(roundedPath(hem, radius: radius), with: Self.cream(0.1), lineWidth: hair(0.7))

        // A pick stitch: short on top, long underneath, in a thread a shade darker than linen.
        let seam = roundedPath(hem.insetBy(dx: depth / 2, dy: depth / 2), radius: radius - depth / 2)
        let stitch = StrokeStyle(lineWidth: hair(1.1), lineCap: .round, dash: [pt(2.6), pt(4.2)])
        context.stroke(seam.offsetBy(dx: pt(0.4), dy: pt(0.8)), with: .color(.black.opacity(0.28)), style: stitch)
        context.stroke(seam, with: .color(Palette.linenDeep.opacity(0.5)), style: stitch)
        let rung = fold.insetBy(dx: pt(7), dy: pt(7))
        ladder(&context, along: rung, radius: radius - depth - pt(7))
        motifs(&context, inside: rung, turn: radius - depth - pt(7), light: visible)
    }

    /// A cross-stitched motif sewn into each corner, inside the turn of the ladder, in gold.
    private func motifs(_ context: inout GraphicsContext, inside rect: CGRect, turn: CGFloat, light: CGRect) {
        var motifs = Path()
        for (corner, inward) in corners(of: rect) {
            motifs.addPath(crossStitch(at: offset(corner, by: inward, turn * 0.88 + pt(6))))
        }
        let thread = StrokeStyle(lineWidth: hair(0.9), lineCap: .round)
        context.stroke(motifs.offsetBy(dx: pt(0.4), dy: pt(0.7)), with: .color(.black.opacity(0.3)), style: thread)
        context.stroke(motifs, with: gilt(in: light, 0.6), style: thread)
    }

    /// A diamond in cross stitch: its outline, a ring inside that, and a stitch at the
    /// heart, each stitch an X across one square of the weave.
    private func crossStitch(at centre: CGPoint) -> Path {
        let cell = pt(3.8)
        var path = Path()
        for row in -4...4 {
            for column in -4...4 where [4, 2].contains(abs(row) + abs(column)) || (row == 0 && column == 0) {
                let x = centre.x + CGFloat(column) * cell
                let y = centre.y + CGFloat(row) * cell
                let h = cell * 0.36
                path.move(to: CGPoint(x: x - h, y: y - h))
                path.addLine(to: CGPoint(x: x + h, y: y + h))
                path.move(to: CGPoint(x: x + h, y: y - h))
                path.addLine(to: CGPoint(x: x - h, y: y + h))
            }
        }
        return path
    }

    /// The hemstitch: two drawn-thread lines with the threads between them gathered into
    /// little bars. One wide dashed stroke is a row of bars, which is the whole trick.
    private func ladder(_ context: inout GraphicsContext, along rect: CGRect, radius: CGFloat) {
        let width = pt(4.5)
        let middle = roundedPath(rect, radius: radius)
        var rails = roundedPath(rect.insetBy(dx: -width / 2, dy: -width / 2), radius: radius + width / 2)
        rails.addPath(roundedPath(rect.insetBy(dx: width / 2, dy: width / 2), radius: radius - width / 2))
        context.stroke(rails, with: .color(.black.opacity(0.12)), lineWidth: hair(0.8))
        context.stroke(middle, with: Self.cream(0.09),
                       style: StrokeStyle(lineWidth: width, dash: [hair(0.7), pt(1.7)]))
    }

    /// Warp and weft, every thread its own weight and a little off its neighbour's
    /// spacing, with a slub here and there where the yarn thickens.
    private func weave(_ context: inout GraphicsContext, in rect: CGRect) {
        var dice = TapisDice(state: 0x11A0_C0FF_EE15)
        let pitch = max(pt(2.8), 1.6)
        var light = Path(), dark = Path(), slubs = Path()
        var y = rect.minY
        while y < rect.maxY {
            let line = threadPath(from: CGPoint(x: rect.minX, y: y), to: CGPoint(x: rect.maxX, y: y))
            if dice.unit() < 0.5 { light.addPath(line) } else { dark.addPath(line) }
            for _ in 0..<2 where dice.unit() < 0.45 {
                slubs.addPath(slub(across: rect, at: y, horizontal: true, &dice))
            }
            y += pitch * (0.75 + dice.unit() * 0.5)
        }
        var x = rect.minX
        while x < rect.maxX {
            let line = threadPath(from: CGPoint(x: x, y: rect.minY), to: CGPoint(x: x, y: rect.maxY))
            if dice.unit() < 0.5 { light.addPath(line) } else { dark.addPath(line) }
            x += pitch * (0.75 + dice.unit() * 0.5)
        }
        // Faint enough that no single thread is seen, only the cloth they make; the slubs
        // are what say linen rather than graph paper.
        context.stroke(light, with: Self.cream(0.018), lineWidth: hair(0.7))
        context.stroke(dark, with: .color(.black.opacity(0.03)), lineWidth: hair(0.7))
        context.stroke(slubs, with: Self.cream(0.045), style: StrokeStyle(lineWidth: hair(1.1), lineCap: .round))
    }

    private func threadPath(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }

    /// A short thick stretch somewhere along one thread.
    private func slub(across rect: CGRect, at position: CGFloat, horizontal: Bool,
                      _ dice: inout TapisDice) -> Path {
        let length = pt(8 + dice.unit() * 46)
        let run = horizontal ? rect.width : rect.height
        let start = (horizontal ? rect.minX : rect.minY) + dice.unit() * run
        return horizontal
            ? threadPath(from: CGPoint(x: start, y: position), to: CGPoint(x: start + length, y: position))
            : threadPath(from: CGPoint(x: position, y: start), to: CGPoint(x: position, y: start + length))
    }
}

// MARK: Maiolica

extension TapisWeave {
    /// Glazed tiles, each a slightly different pour of the same glaze, set with a recessed
    /// joint. A ribbon in quarter circles turns one way or the other on every tile, so it
    /// wanders the floor in loops and runs, and a small gold insert sits at every corner
    /// where four tiles meet — the way a hotel floor on the coast is laid.
    func maiolica(_ context: inout GraphicsContext, whole: CGRect, visible: CGRect) {
        let size = pt(46)
        // A joint down the middle of the table, so the floor is laid from the centre out.
        let left = visible.midX - size * ((visible.midX - whole.minX) / size).rounded(.up)
        let top = visible.midY - size * ((visible.midY - whole.minY) / size).rounded(.up)
        var dice = TapisDice(state: 0x3A10_11CA_0001)
        var glazes = [Path(), Path(), Path()]
        var ribbons = Path(), edges = Path(), joints = Path(), inserts = Path()

        var y = top
        while y < whole.maxY {
            var x = left
            while x < whole.maxX {
                let tile = CGRect(x: x, y: y, width: size, height: size)
                glazes[Int(dice.unit() * 3)].addRect(tile)
                ribbon(in: tile, turned: dice.unit() < 0.5, band: &ribbons, edges: &edges)
                inserts.addPath(lozenge(at: tile.origin, long: pt(9), wide: pt(9)))
                x += size
            }
            joints.move(to: CGPoint(x: whole.minX, y: y))
            joints.addLine(to: CGPoint(x: whole.maxX, y: y))
            y += size
        }
        var x = left
        while x < whole.maxX {
            joints.move(to: CGPoint(x: x, y: whole.minY))
            joints.addLine(to: CGPoint(x: x, y: whole.maxY))
            x += size
        }
        lay(&context, glazes: glazes, ribbons: ribbons, edges: edges, joints: joints,
            inserts: inserts, light: visible)
    }

    private func lay(_ context: inout GraphicsContext, glazes: [Path], ribbons: Path, edges: Path,
                     joints: Path, inserts: Path, light: CGRect) {
        context.fill(glazes[0], with: Self.cream(0.035))
        context.fill(glazes[1], with: .color(.black.opacity(0.035)))
        context.fill(ribbons, with: Self.cream(0.035))
        context.stroke(edges, with: Self.cream(0.085), lineWidth: hair(0.8))
        // The joint is sunk: dark where the lamp cannot reach into it, a lit lip beyond.
        context.stroke(joints, with: .color(.black.opacity(0.12)), lineWidth: hair(1.1))
        context.stroke(joints.offsetBy(dx: max(pt(0.9), 0.4), dy: max(pt(0.9), 0.4)),
                       with: Self.cream(0.05), lineWidth: hair(0.6))
        raiseFill(inserts, in: &context, with: gilt(in: light, 0.32))
    }

    /// The ribbon across one tile: two quarter rings round opposite corners, which meet
    /// the next tile's at the middle of every edge whichever way that one is turned.
    private func ribbon(in tile: CGRect, turned: Bool, band: inout Path, edges: inout Path) {
        let half = tile.width / 2
        let width = pt(7)
        let pivots: [(CGPoint, Double)] = turned
            ? [(CGPoint(x: tile.maxX, y: tile.minY), Double.pi / 2), (CGPoint(x: tile.minX, y: tile.maxY), -Double.pi / 2)]
            : [(CGPoint(x: tile.minX, y: tile.minY), 0), (CGPoint(x: tile.maxX, y: tile.maxY), .pi)]
        for (corner, start) in pivots {
            let end = start + .pi / 2
            var ring = Path()
            arc(&ring, centre: corner, radius: half + width / 2, from: start, to: end, joined: false)
            arc(&ring, centre: corner, radius: half - width / 2, from: end, to: start, joined: true)
            ring.closeSubpath()
            band.addPath(ring)
            arc(&edges, centre: corner, radius: half + width / 2, from: start, to: end, joined: false)
            arc(&edges, centre: corner, radius: half - width / 2, from: start, to: end, joined: false)
        }
    }
}
