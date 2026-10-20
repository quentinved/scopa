import SwiftUI

/// The Mosaico album's cornice: three courses of glass round the badge, set the way a
/// Ravenna border is. A deep red fillet against the mark, a course of gold leaf, and lapis
/// outside it, every tessera lit from the upper left like the deck's own.
///
/// Badge-sized tesserae under a couple of points are only noise, so a small badge gets the
/// same three courses as flat rings.
struct TessereRing: View {
    /// The circle it is set outside, and the badge, which the shadow follows.
    let ring: CGFloat
    let size: CGFloat

    /// One course's depth, against the circle.
    static let pitch: CGFloat = 0.05
    private static let courses: [(Smalti, Smalto)] = [(.rim, .redDeep), (.gold, .gold), (.lapisGround, .lapis)]

    var body: some View {
        Group {
            if ring * Self.pitch >= 2 {
                let work = TessereSettings.work(ring: ring)
                Canvas { context, _ in work.draw(in: context) }
            } else {
                flat
            }
        }
        .frame(width: ring * 1.4, height: ring * 1.4)
        .shadow(color: .black.opacity(0.3), radius: size * 0.025, y: size * 0.012)
    }

    /// The courses as plain rings, outermost first so each inner one sits on top.
    private var flat: some View {
        ZStack {
            ForEach(Array(Self.courses.enumerated().reversed()), id: \.offset) { index, course in
                Circle()
                    .strokeBorder(course.1.colour, lineWidth: ring * Self.pitch)
                    .frame(width: ring * (1.04 + 2 * Self.pitch * CGFloat(index + 1)),
                           height: ring * (1.04 + 2 * Self.pitch * CGFloat(index + 1)))
            }
        }
    }

    /// The radius each course is centred on, in points.
    static func radius(of course: Int, ring: CGFloat) -> CGFloat {
        ring * (0.52 + pitch * (CGFloat(course) + 0.5))
    }

    static func set(ring: CGFloat) -> MosaicoWork {
        let pitch = ring * Self.pitch
        let centre = CGPoint(x: ring * 0.7, y: ring * 0.7)
        let box = CGRect(x: 0, y: 0, width: ring * 1.4, height: ring * 1.4)
        var work = MosaicoWork(seed: 61, detailed: true)
        work.bedRing(outer: circle(centre, ring * 0.52 + pitch * 3.1), inner: circle(centre, ring * 0.515),
                     .groutDark)
        for (index, course) in courses.enumerated() {
            let line = circle(centre, radius(of: index, ring: ring))
            work.course(MosaicoCourse(points: line, depths: Array(repeating: pitch, count: line.count),
                                      closed: true, inward: 0),
                        pitch: pitch, material: course.0, light: { MosaicoWork.light(in: box, at: $0) })
        }
        return work
    }

    private static func circle(_ centre: CGPoint, _ radius: CGFloat) -> [CGPoint] {
        let count = max(24, Int(radius * 2 * .pi / 1.5))
        return (0..<count).map { index in
            let angle = CGFloat(index) / CGFloat(count) * 2 * .pi - .pi / 2
            return CGPoint(x: centre.x + cos(angle) * radius, y: centre.y + sin(angle) * radius)
        }
    }
}

/// The rings already set, by size: a seat badge is drawn at a handful of sizes and redrawn
/// with every turn, and laying two hundred tesserae each time would be work thrown away.
private enum TessereSettings {
    private static var kept: [Int: MosaicoWork] = [:]

    static func work(ring: CGFloat) -> MosaicoWork {
        let key = Int((ring * 4).rounded())
        if let work = kept[key] { return work }
        if kept.count > 24 { kept.removeAll() }
        let work = TessereRing.set(ring: ring)
        kept[key] = work
        return work
    }
}
