import SwiftUI

// MARK: Cubi

extension TapisWeave {
    /// Sorrento parquet: tumbling blocks inlaid in three woods, the lid in the pale one, the
    /// side towards the lamp in the middle one and the far side in the dark, so the floor
    /// reads as cubes stacked all over with nothing round it. Every lid is cut from its own
    /// board, the grain runs along each piece, and a gold string is laid round every cube
    /// the way a Sorrento box lid is strung.
    func cubi(_ context: inout GraphicsContext, whole: CGRect, visible: CGRect) {
        let radius = pt(19)
        var wood = CubiWood()
        var dice = TapisDice(state: 0xC0B1_501E_7700)
        for centre in cubeCentres(in: whole, centredOn: visible, radius: radius) {
            inlay(cubeAt: centre, radius: radius, into: &wood, &dice)
        }
        polish(wood, in: &context, light: visible)
    }

    /// Hexagons on their points, a cube on the middle of the screen and the rows offset by
    /// half a cube, out past the bleed.
    private func cubeCentres(in whole: CGRect, centredOn visible: CGRect, radius: CGFloat) -> [CGPoint] {
        let across = radius * sqrt(3), down = radius * 1.5
        let columns = Int(((visible.midX - whole.minX) / across).rounded(.up)) + 1
        let rows = Int(((visible.midY - whole.minY) / down).rounded(.up)) + 1
        var centres: [CGPoint] = []
        for row in -rows...rows {
            let shift = row.isMultiple(of: 2) ? 0 : across / 2
            for column in -columns...columns {
                centres.append(CGPoint(x: visible.midX + CGFloat(column) * across + shift,
                                       y: visible.midY + CGFloat(row) * down))
            }
        }
        return centres
    }

    /// One cube: its three faces, the grain on each, the joints of the Y between them and
    /// the string round the outside.
    private func inlay(cubeAt centre: CGPoint, radius: CGFloat, into wood: inout CubiWood,
                       _ dice: inout TapisDice) {
        // From the top, clockwise: top, upper right, lower right, bottom, lower left, upper left.
        let v = (0..<6).map { offset(centre, by: unit(Double($0) * .pi / 3 - .pi / 2), radius) }
        let lid = [centre, v[1], v[0], v[5]], near = [centre, v[5], v[4], v[3]]
        let far = [centre, v[3], v[2], v[1]]
        wood.lids[min(Int(dice.unit() * 3), 2)].addPath(piece(lid))
        wood.near.addPath(piece(near))
        wood.far.addPath(piece(far))
        grain(lid, into: &wood.paleGrain, &dice)
        grain(near, into: &wood.darkGrain, &dice)
        grain(far, into: &wood.darkGrain, &dice)
        for corner in [v[1], v[3], v[5]] {
            wood.joints.move(to: centre)
            wood.joints.addLine(to: corner)
        }
        wood.strings.addPath(piece(v))
    }

    /// A few lines along a rhombus, each a little off where the last board's was, stopped
    /// short of the joints.
    private func grain(_ face: [CGPoint], into path: inout Path, _ dice: inout TapisDice) {
        func along(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
        for line in 1...2 {
            let t = CGFloat(line) / 3 + (dice.unit() - 0.5) * 0.14
            let start = along(face[0], face[3], t), end = along(face[1], face[2], t)
            path.move(to: along(start, end, 0.08))
            path.addLine(to: along(start, end, 0.92))
        }
    }

    private func piece(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }

    /// The woods in the felt's own light: the lids pale, the near sides barely, the far
    /// sides in shadow, then the grain, the joints, and the string raised a hair off them.
    private func polish(_ wood: CubiWood, in context: inout GraphicsContext, light: CGRect) {
        for (lid, opacity) in zip(wood.lids, [0.045, 0.055, 0.07]) {
            context.fill(lid, with: Self.cream(opacity))
        }
        context.fill(wood.near, with: Self.cream(0.012))
        context.fill(wood.far, with: .color(.black.opacity(0.11)))
        context.stroke(wood.paleGrain, with: Self.cream(0.03), lineWidth: hair(0.5))
        context.stroke(wood.darkGrain, with: .color(.black.opacity(0.05)), lineWidth: hair(0.5))
        context.stroke(wood.joints, with: .color(.black.opacity(0.1)), lineWidth: hair(0.6))
        raise(wood.strings, in: &context, with: gilt(in: light, 0.3), width: 0.7, height: 0.5)
    }
}

/// Everything a field of cubes is cut into, gathered so each wood is laid in one pass.
private struct CubiWood {
    var lids = [Path(), Path(), Path()]
    var near = Path()
    var far = Path()
    var paleGrain = Path()
    var darkGrain = Path()
    var joints = Path()
    var strings = Path()
}
