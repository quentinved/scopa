import SwiftUI

/// The pillow a face is worked on: a drawing context, the card's width every measure
/// follows, and the velvet under the lace. Places are in card widths, x across 0...1 and
/// y down 0...1.5.
struct MerlettoPillow {
    let context: GraphicsContext
    let w: CGFloat
    var velvet: Color = MerlettoThread.velvet
    /// How far the velvet is cut back round a piece. A suit mark off the card is mounted wider.
    var mount: CGFloat = 1
    /// -1 on a pillow turned over, so a shadow still falls to the right.
    var lean: CGFloat = 1

    /// Stitch rows, réseau, wrapping and picots. Below this the lace is laid flat.
    var fine: Bool { w >= 40 }
    /// How far a thread's shadow falls on what lies under it.
    var lift: CGSize { CGSize(width: max(0.3, w * 0.0055) * lean, height: max(0.45, w * 0.0085)) }
    var cord: CGFloat { max(0.6, w * 0.0125) }
    var hair: CGFloat { max(0.3, w * 0.0042) }
    /// Between two rows of buttonhole stitch.
    var pitch: CGFloat { max(0.9, w * 0.0125) }
    var picot: CGFloat { max(0.45, w * 0.0085) }
}

// MARK: Stitches

extension MerlettoPillow {
    /// Toile: buttonhole stitch laid close, row on row at `angle`, inside a raised cord.
    /// `parted` cuts the velvet back round it first, so it stands clear of what it overlaps.
    func toile(_ piece: Path, _ thread: MerlettoThread = .linen, rows angle: CGFloat = 0,
               cord edge: MerlettoThread? = .linen, parted: Bool = true, eo: Bool = false) {
        let style = FillStyle(eoFill: eo)
        if parted { part(piece) }
        context.fill(piece.offsetBy(dx: lift.width, dy: lift.height), with: .color(MerlettoThread.shadow), style: style)
        context.fill(piece, with: .color(thread.face), style: style)
        if fine {
            var inside = context
            inside.clip(to: piece, style: style)
            let rows = MerlettoMesh.rows(in: piece.boundingRect, angle: angle, pitch: pitch)
            inside.stroke(rows, with: .color(thread.stitch.opacity(0.6)),
                          style: StrokeStyle(lineWidth: pitch * 0.3, dash: [pitch * 0.8, pitch * 0.32]))
        }
        if let edge { cordonnet(piece, edge) }
    }

    /// Réseau: a honeycomb of single twisted threads, the velvet showing through every cell.
    func net(_ piece: Path, cell: CGFloat = 0.03, _ thread: MerlettoThread = .ivory,
             cord edge: MerlettoThread? = .linen, parted: Bool = true, eo: Bool = false) {
        let style = FillStyle(eoFill: eo)
        if parted { part(piece) }
        context.fill(piece, with: .color(velvet), style: style)
        if fine {
            var inside = context
            inside.clip(to: piece, style: style)
            let mesh = MerlettoMesh.honeycomb(in: piece.boundingRect, cell: cell * w)
            inside.stroke(mesh, with: .color(thread.face.opacity(0.78)), lineWidth: hair)
        } else {
            context.fill(piece, with: .color(thread.face.opacity(0.32)), style: style)
        }
        if let edge { cordonnet(piece, edge) }
    }

    /// Cuts the velvet back round a piece, so it stands clear of whatever it lies over.
    func part(_ piece: Path) {
        context.stroke(piece, with: .color(velvet), lineWidth: max(1.1, w * 0.034) * mount)
    }

    /// The raised cord round a motif, buttonholed over: its shadow on what lies under it,
    /// the cord, and the wrapping across it.
    func cordonnet(_ edge: Path, _ thread: MerlettoThread = .linen, weight: CGFloat = 1) {
        let width = cord * weight
        context.stroke(edge.offsetBy(dx: lift.width * 0.7, dy: lift.height * 0.7),
                       with: .color(MerlettoThread.shadow), lineWidth: width)
        context.stroke(edge, with: .color(thread.face), lineWidth: width)
        guard fine else { return }
        context.stroke(edge, with: .color(thread.stitch.opacity(0.5)),
                       style: StrokeStyle(lineWidth: width * 0.8, dash: [width * 0.22, width * 0.44]))
    }

    /// A single thread thrown open across the velvet: a bride, a vein, a rod.
    func thread(_ path: Path, _ thread: MerlettoThread = .linen, weight: CGFloat = 0.55) {
        let style = StrokeStyle(lineWidth: cord * weight, lineCap: .round, lineJoin: .round)
        context.stroke(path.offsetBy(dx: lift.width * 0.7, dy: lift.height * 0.7),
                       with: .color(MerlettoThread.shadow), style: style)
        context.stroke(path, with: .color(thread.face), style: style)
    }

    /// Brides from motif to motif, each with a picot standing off its middle.
    func brides(_ bars: [(CGPoint, CGPoint)], _ thread: MerlettoThread = .linen, weight: CGFloat = 0.55) {
        var path = Path()
        var knots: [CGPoint] = []
        for (index, (a, b)) in bars.enumerated() {
            path.move(to: a)
            path.addLine(to: b)
            let length = max(hypot(b.x - a.x, b.y - a.y), 0.001)
            let side: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            let off = (picot * 0.85 + cord * weight * 0.5) * side
            knots.append(CGPoint(x: (a.x + b.x) / 2 - (b.y - a.y) / length * off,
                                 y: (a.y + b.y) / 2 + (b.x - a.x) / length * off))
        }
        self.thread(path, thread, weight: weight)
        picots(knots, thread, size: 0.8)
    }

    /// A ground of brides, as Venice and Alençon work it: a honeycomb of buttonholed bars
    /// each picoted once, the velvet open in every cell, laid a little unevenly by hand.
    func brideGround(_ area: Path, cell: CGFloat = 0.1, _ thread: MerlettoThread = .ivory, seed: UInt64) {
        guard fine else { return }
        let bars = MerlettoMesh.bars(in: area.boundingRect, cell: cell * w, wobble: 0.1, seed: seed)
        clipped(to: area).brides(bars, thread, weight: 0.38)
    }

    /// Ricci: a ground of little raised rings, for hair, beards and a mane.
    func curls(_ piece: Path, r: CGFloat = 0.0105, _ thread: MerlettoThread = .ivory) {
        part(piece)
        context.fill(piece, with: .color(velvet))
        guard fine else {
            context.fill(piece, with: .color(thread.face.opacity(0.45)))
            return cordonnet(piece)
        }
        var inside = context
        inside.clip(to: piece)
        let rings = MerlettoMesh.rings(in: piece.boundingRect, r: r * w)
        let width = cord * 0.6
        inside.stroke(rings.offsetBy(dx: lift.width * 0.6, dy: lift.height * 0.6), with: .color(MerlettoThread.shadow),
                      lineWidth: width)
        inside.stroke(rings, with: .color(thread.face), lineWidth: width)
        cordonnet(piece)
    }

    /// Picots: little loops of thread standing off an edge, centred on `points`.
    func picots(_ points: [CGPoint], _ thread: MerlettoThread = .linen, size: CGFloat = 1) {
        guard fine, !points.isEmpty else { return }
        let r = picot * size
        var loops = Path()
        for c in points { loops.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)) }
        context.fill(loops.offsetBy(dx: lift.width * 0.6, dy: lift.height * 0.6), with: .color(MerlettoThread.shadow))
        context.fill(loops, with: .color(thread.face))
    }

    /// Eyelets: holes worked round with a fine cord, the velvet showing through, `r` card
    /// widths across.
    func eyelets(_ centres: [CGPoint], r: CGFloat, _ thread: MerlettoThread = .linen) {
        var holes = Path()
        let radius = r * w
        for c in centres {
            holes.addEllipse(in: CGRect(x: c.x - radius, y: c.y - radius, width: 2 * radius, height: 2 * radius))
        }
        context.fill(holes, with: .color(velvet))
        cordonnet(holes, thread, weight: 0.55)
    }

    /// An opening cut clean through a piece of toile: an eye, a brow, the velvet behind.
    func open(_ path: Path, weight: CGFloat) {
        context.stroke(path, with: .color(velvet),
                       style: StrokeStyle(lineWidth: max(0.5, w * weight), lineCap: .round, lineJoin: .round))
    }

    /// The same pillow turned about `centre` by `angle`.
    func turned(_ angle: CGFloat, about centre: CGPoint) -> MerlettoPillow {
        var turned = context
        turned.translateBy(x: centre.x, y: centre.y)
        turned.rotate(by: .radians(angle))
        turned.translateBy(x: -centre.x, y: -centre.y)
        return MerlettoPillow(context: turned, w: w, velvet: velvet, mount: mount, lean: lean)
    }

    /// The same pillow cut to `shape`, for a figure that runs under the edging.
    func clipped(to shape: Path) -> MerlettoPillow {
        var inside = context
        inside.clip(to: shape)
        return MerlettoPillow(context: inside, w: w, velvet: velvet, mount: mount, lean: lean)
    }
}
