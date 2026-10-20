import SwiftUI

/// The parts of a Mosaico card that are not figure: the frame round the edge and the ground
/// inside it.
extension MosaicoWork {
    /// Courses round the card's edge, outermost first, on a bed of their own.
    mutating func frame(_ size: CGSize, radius: CGFloat, pitch: CGFloat, courses: [Smalti], grout: Smalto) {
        layer()
        let card = CGRect(origin: .zero, size: size)
        let depth = pitch * CGFloat(courses.count)
        guard detailed else {
            for (index, material) in courses.enumerated() {
                let inset = pitch * CGFloat(index)
                solidRing(outer: Self.rounded(card, inset, radius), inner: Self.rounded(card, depth, radius), material.main)
            }
            return
        }
        bedRing(outer: Self.rounded(card, 0, radius), inner: Self.rounded(card, depth + pitch * 0.1, radius), grout)
        for (index, material) in courses.enumerated() {
            let line = Self.rounded(card, pitch * (CGFloat(index) + 0.5), radius)
            course(MosaicoCourse(points: line, depths: Array(repeating: pitch, count: line.count), closed: true, inward: 0),
                   pitch: pitch, material: material, light: { _ in 0 })
        }
    }

    /// The ground: one course following the frame, then level rows, the opus tessellatum of
    /// every Ravenna background.
    mutating func ground(_ size: CGSize, radius: CGFloat, inset: CGFloat, pitch: CGFloat,
                         material: Smalti, grout: Smalto) {
        let card = CGRect(origin: .zero, size: size)
        guard detailed else { return solid(Self.rounded(card, 0, radius), material.main) }
        bed(Self.rounded(card, 0, radius), grout)
        let line = Self.rounded(card, inset + pitch * 0.5, radius)
        course(MosaicoCourse(points: line, depths: Array(repeating: pitch, count: line.count), closed: true, inward: 0),
               pitch: pitch, material: material, light: { _ in 0 })
        let inner = inset + pitch
        let lines = max(1, Int(((size.height - inner * 2) / pitch).rounded()))
        let rowPitch = (size.height - inner * 2) / CGFloat(lines)
        for row in 0..<lines {
            let y = inner + (CGFloat(row) + 0.5) * rowPitch
            var x = inner - rng.unit() * pitch
            while x < size.width - inner + pitch {
                let at = CGPoint(x: x + rng.spread(pitch * 0.06), y: y + rng.spread(pitch * 0.06))
                if Self.depth(of: at, in: size, inset: inner, radius: radius) < -pitch * 0.42 {
                    let shade = material.pick(&rng, light: 0)
                    tessera(at: at, angle: 0, along: pitch, across: rowPitch, shade)
                }
                x += pitch * (0.94 + rng.unit() * 0.12)
            }
        }
    }

    /// Small gold crosses on the lapis, as on Galla Placidia's vault. Kept clear of the pips,
    /// the corners where the index is printed, and the caption.
    mutating func stars(_ size: CGSize, pitch: CGFloat, avoiding pips: [CGPoint], reach: CGFloat) {
        guard detailed else { return }
        layer()
        let columns = 4, rows = 6
        for row in 0..<rows {
            for column in 0..<columns {
                let at = CGPoint(x: size.width * (CGFloat(column) + 0.5 + rng.spread(0.3)) / CGFloat(columns),
                                 y: size.height * (CGFloat(row) + 0.5 + rng.spread(0.3)) / CGFloat(rows))
                let clear = pips.allSatisfy { hypot($0.x - at.x, $0.y - at.y) > reach }
                let corner = (at.x < size.width * 0.34 && at.y < size.width * 0.44)
                    || (at.x > size.width * 0.66 && at.y > size.height - size.width * 0.44)
                let caption = at.y > size.height - size.width * 0.26
                let inside = Self.depth(of: at, in: size, inset: size.width * 0.12, radius: 0) < 0
                if clear && !corner && !caption && inside { star(at, pitch: pitch) }
            }
        }
    }

    private mutating func star(_ centre: CGPoint, pitch: CGFloat) {
        let arms = [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: -1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 0, y: -1)]
        bed(Self.rounded(CGRect(x: centre.x - pitch * 1.6, y: centre.y - pitch * 0.6, width: pitch * 3.2, height: pitch * 1.2), 0, 0), .groutNight)
        bed(Self.rounded(CGRect(x: centre.x - pitch * 0.6, y: centre.y - pitch * 1.6, width: pitch * 1.2, height: pitch * 3.2), 0, 0), .groutNight)
        for (index, arm) in arms.enumerated() {
            let at = CGPoint(x: centre.x + arm.x * pitch, y: centre.y + arm.y * pitch)
            tessera(at: at, angle: 0, along: pitch, across: pitch, index == 0 ? .goldPale : .gold)
        }
    }

    /// A rounded rectangle inset from `rect`, as a closed line.
    static func rounded(_ rect: CGRect, _ inset: CGFloat, _ radius: CGFloat) -> [CGPoint] {
        let box = rect.insetBy(dx: inset, dy: inset)
        let r = max(radius - inset, 0)
        let corners = [(box.maxX - r, box.minY + r, -CGFloat.pi / 2), (box.maxX - r, box.maxY - r, 0),
                       (box.minX + r, box.maxY - r, CGFloat.pi / 2), (box.minX + r, box.minY + r, CGFloat.pi)]
        let steps = max(1, Int(r / 1.2))
        var points: [CGPoint] = []
        for (x, y, start) in corners {
            for step in 0...steps {
                let angle = start + CGFloat.pi / 2 * CGFloat(step) / CGFloat(steps)
                points.append(CGPoint(x: x + cos(angle) * r, y: y + sin(angle) * r))
            }
        }
        return points
    }

    /// Signed distance to the card's outline inset by `inset`: negative inside.
    static func depth(of point: CGPoint, in size: CGSize, inset: CGFloat, radius: CGFloat) -> CGFloat {
        let r = max(radius - inset, 0)
        let qx = abs(point.x - size.width / 2) - (size.width / 2 - inset - r)
        let qy = abs(point.y - size.height / 2) - (size.height / 2 - inset - r)
        return hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - r
    }
}
