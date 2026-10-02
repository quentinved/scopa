import SwiftUI

/// Where a stitch falls while walking the edge of the cloth: the point itself, the way the
/// edge runs there, and the way into the middle.
struct TapisStitch {
    var point: CGPoint
    var along: CGPoint
    var inward: CGPoint
}

/// One leg of a rounded rectangle: a straight run, or a quarter turn at a corner.
private enum Leg {
    case run(from: CGPoint, along: CGPoint, length: CGFloat)
    case turn(centre: CGPoint, radius: CGFloat, from: Double)

    var length: CGFloat {
        switch self {
        case .run(_, _, let length): length
        case .turn(_, let radius, _): radius * .pi / 2
        }
    }

    /// The stitch that far along this leg. Walking clockwise on a screen, the way into the
    /// cloth is the direction of travel turned a quarter turn.
    func stitch(at distance: CGFloat) -> TapisStitch {
        switch self {
        case .run(let from, let along, _):
            return TapisStitch(point: CGPoint(x: from.x + along.x * distance, y: from.y + along.y * distance),
                               along: along, inward: CGPoint(x: -along.y, y: along.x))
        case .turn(let centre, let radius, let from):
            let angle = from + Double(distance / max(radius, 0.001))
            let out = CGPoint(x: cos(angle), y: sin(angle))
            return TapisStitch(point: CGPoint(x: centre.x + out.x * radius, y: centre.y + out.y * radius),
                               along: CGPoint(x: -out.y, y: out.x),
                               inward: CGPoint(x: -out.x, y: -out.y))
        }
    }
}

extension TapisWeave {
    /// Stitches laid round a rounded rectangle, as evenly as its perimeter allows.
    ///
    /// The spacing is rounded to a whole number of stitches, because a chain that does not
    /// meet where it began is the one fault the eye finds straight away.
    func walk(_ rect: CGRect, radius: CGFloat, step: CGFloat) -> [TapisStitch] {
        let radius = max(0, min(radius, min(rect.width, rect.height) / 2))
        let across = rect.width - radius * 2
        let down = rect.height - radius * 2
        let perimeter = (across + down) * 2 + 2 * .pi * radius
        guard perimeter > 0, step > 0 else { return [] }
        let count = max(8, Int((perimeter / step).rounded()))
        let legs = legs(of: rect, radius: radius, across: across, down: down)

        let spacing = perimeter / CGFloat(count)
        var stitches: [TapisStitch] = []
        stitches.reserveCapacity(count)
        var leg = 0
        var travelled: CGFloat = 0
        for index in 0..<count {
            let distance = CGFloat(index) * spacing
            while leg < legs.count - 1, distance > travelled + legs[leg].length {
                travelled += legs[leg].length
                leg += 1
            }
            stitches.append(legs[leg].stitch(at: distance - travelled))
        }
        return stitches
    }

    /// Clockwise from the top left corner, the eight legs of a rounded rectangle.
    private func legs(of rect: CGRect, radius: CGFloat, across: CGFloat, down: CGFloat) -> [Leg] {
        [
            .run(from: CGPoint(x: rect.minX + radius, y: rect.minY), along: CGPoint(x: 1, y: 0), length: across),
            .turn(centre: CGPoint(x: rect.maxX - radius, y: rect.minY + radius), radius: radius, from: -.pi / 2),
            .run(from: CGPoint(x: rect.maxX, y: rect.minY + radius), along: CGPoint(x: 0, y: 1), length: down),
            .turn(centre: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius), radius: radius, from: 0),
            .run(from: CGPoint(x: rect.maxX - radius, y: rect.maxY), along: CGPoint(x: -1, y: 0), length: across),
            .turn(centre: CGPoint(x: rect.minX + radius, y: rect.maxY - radius), radius: radius, from: .pi / 2),
            .run(from: CGPoint(x: rect.minX, y: rect.maxY - radius), along: CGPoint(x: 0, y: -1), length: down),
            .turn(centre: CGPoint(x: rect.minX + radius, y: rect.minY + radius), radius: radius, from: .pi),
        ]
    }
}
