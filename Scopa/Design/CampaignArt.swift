import SwiftUI

/// The engraved ground under each region of the campaign map: the region's own colour, and
/// a few lines of what it is known for, drawn faint like the plate of an old road atlas.
///
/// Line art only, in cream at low opacity. Nothing moves: the map is a page, not a scene.
struct RegionGround: View {
    let region: CampaignRegion

    var body: some View {
        ZStack {
            LinearGradient(colors: [region.ground.light, region.ground.deep], startPoint: .top, endPoint: .bottom)
            RegionEngraving(region: region)
                .stroke(Palette.cream.opacity(0.13), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
            // A hem of gold where one region gives way to the next. None over the first,
            // whose plate runs on up under the header.
            if region.index > 0 {
                VStack {
                    Rectangle().fill(Palette.gold.opacity(0.45)).frame(height: 1)
                    Spacer(minLength: 0)
                }
            }
        }
        .drawingGroup(opaque: true)
    }
}

/// What each region's plate shows, in one path.
struct RegionEngraving: Shape {
    let region: CampaignRegion

    func path(in rect: CGRect) -> Path {
        switch region {
        case .liguria: Engraving.terraces(rect) + Engraving.waves(rect, from: 0.62) + Engraving.sail(rect)
        case .piemonte: Engraving.alps(rect) + Engraving.vineyards(rect) + Engraving.mole(rect)
            + Engraving.river(rect, at: 0.88)
        case .napoli: Engraving.volcano(rect, at: 0.78, smoke: true) + Engraving.waves(rect, from: 0.7)
        case .sicilia: Engraving.sun(rect) + Engraving.volcano(rect, at: 0.24, smoke: false) + Engraving.waves(rect, from: 0.82)
        case .venezia: Engraving.arcade(rect, at: 0.18, pointed: true) + Engraving.waves(rect, from: 0.5)
            + Engraving.gondola(rect)
        case .roma: Engraving.colosseum(rect) + Engraving.columns(rect)
        }
    }
}

private extension Path {
    static func + (a: Path, b: Path) -> Path {
        var path = a
        path.addPath(b)
        return path
    }
}

/// The plates' drawings, each a pure function of the rect it is laid in.
private enum Engraving {
    /// Rows of gentle swell, the sea every region but Rome looks out on.
    static func waves(_ rect: CGRect, from start: CGFloat) -> Path {
        var path = Path()
        var y = rect.minY + rect.height * start
        var row = 0
        while y < rect.maxY - 8 {
            let span: CGFloat = 46
            var x = rect.minX - CGFloat(row % 2) * span / 2
            path.move(to: CGPoint(x: x, y: y))
            while x < rect.maxX {
                path.addQuadCurve(to: CGPoint(x: x + span, y: y),
                                  control: CGPoint(x: x + span / 2, y: y - 7))
                x += span
            }
            y += 26
            row += 1
        }
        return path
    }

    /// Stepped lemon terraces down the left of the Ligurian hill.
    static func terraces(_ rect: CGRect) -> Path {
        var path = Path()
        for step in 0..<6 {
            let y = rect.minY + rect.height * (0.16 + CGFloat(step) * 0.05)
            let reach = rect.width * (0.08 + CGFloat(step) * 0.035)
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.minX + reach, y: y))
            path.addLine(to: CGPoint(x: rect.minX + reach + 8, y: y + rect.height * 0.05))
            // A lemon tree on every other terrace.
            if step % 2 == 0 {
                path.addEllipse(in: CGRect(x: rect.minX + reach * 0.6, y: y - 16, width: 14, height: 14))
            }
        }
        return path
    }

    static func sail(_ rect: CGRect) -> Path {
        let base = CGPoint(x: rect.minX + rect.width * 0.8, y: rect.minY + rect.height * 0.56)
        var path = Path()
        path.move(to: CGPoint(x: base.x - 26, y: base.y))
        path.addLine(to: CGPoint(x: base.x + 26, y: base.y))
        path.addLine(to: CGPoint(x: base.x + 18, y: base.y + 9))
        path.addLine(to: CGPoint(x: base.x - 18, y: base.y + 9))
        path.closeSubpath()
        path.move(to: CGPoint(x: base.x, y: base.y))
        path.addLine(to: CGPoint(x: base.x, y: base.y - 58))
        path.addLine(to: CGPoint(x: base.x + 24, y: base.y - 8))
        path.addLine(to: CGPoint(x: base.x, y: base.y - 8))
        return path
    }

    /// A saw of snowy peaks along the top of the plate, the Alps behind Turin.
    static func alps(_ rect: CGRect) -> Path {
        let peaks: [(x: CGFloat, y: CGFloat)] = [(0, 0.22), (0.09, 0.165), (0.17, 0.2), (0.27, 0.15), (0.37, 0.195),
                                                 (0.47, 0.16), (0.58, 0.205), (0.69, 0.155), (0.8, 0.19), (0.9, 0.15),
                                                 (1, 0.2)]
        let points = peaks.map { CGPoint(x: rect.minX + rect.width * $0.x, y: rect.minY + rect.height * $0.y) }
        var path = Path()
        path.addLines(points)
        // A snow line under every summit.
        for (index, peak) in points.enumerated() where index > 0 && index < points.count - 1
            && peak.y < points[index - 1].y && peak.y < points[index + 1].y {
            path.move(to: CGPoint(x: peak.x - 12, y: peak.y + 14))
            path.addLine(to: CGPoint(x: peak.x - 4, y: peak.y + 9))
            path.addLine(to: CGPoint(x: peak.x + 3, y: peak.y + 15))
            path.addLine(to: CGPoint(x: peak.x + 11, y: peak.y + 11))
        }
        return path
    }

    /// Three rounded hills of the Langhe down the left, combed with rows of vines.
    static func vineyards(_ rect: CGRect) -> Path {
        var path = Path()
        for (index, foot) in [0.36, 0.45, 0.54].enumerated() {
            let y = rect.minY + rect.height * foot
            let start = CGPoint(x: rect.minX - 12, y: y)
            let end = CGPoint(x: rect.minX + rect.width * (0.44 - CGFloat(index) * 0.06), y: y)
            let control = CGPoint(x: (start.x + end.x) / 2, y: y - 72)
            path.move(to: start)
            path.addQuadCurve(to: end, control: control)
            for step in 2...8 {
                let t = CGFloat(step) / 10
                let x = (1 - t) * (1 - t) * start.x + 2 * (1 - t) * t * control.x + t * t * end.x
                let top = (1 - t) * (1 - t) * start.y + 2 * (1 - t) * t * control.y + t * t * end.y
                path.move(to: CGPoint(x: x, y: top + 5))
                path.addLine(to: CGPoint(x: x, y: min(top + 22, y)))
            }
        }
        return path
    }

    /// The Mole Antonelliana: a temple base, the tall square dome, the lantern and its needle.
    static func mole(_ rect: CGRect) -> Path {
        let x = rect.minX + rect.width * 0.86
        let foot = rect.minY + rect.height * 0.74
        let shoulder = foot - 46, neck = foot - 150
        var path = Path()
        path.addRect(CGRect(x: x - 26, y: shoulder, width: 52, height: 46))
        for column in stride(from: -18.0, through: 18.0, by: 9.0) {
            path.move(to: CGPoint(x: x + column, y: shoulder + 6))
            path.addLine(to: CGPoint(x: x + column, y: foot - 6))
        }
        path.move(to: CGPoint(x: x - 24, y: shoulder))
        path.addQuadCurve(to: CGPoint(x: x - 7, y: neck), control: CGPoint(x: x - 23, y: neck + 36))
        path.addLine(to: CGPoint(x: x + 7, y: neck))
        path.addQuadCurve(to: CGPoint(x: x + 24, y: shoulder), control: CGPoint(x: x + 23, y: neck + 36))
        path.addRect(CGRect(x: x - 7, y: neck - 22, width: 14, height: 22))
        path.addRect(CGRect(x: x - 4, y: neck - 36, width: 8, height: 14))
        path.move(to: CGPoint(x: x, y: neck - 36))
        path.addLine(to: CGPoint(x: x, y: neck - 104))
        path.addEllipse(in: CGRect(x: x - 3, y: neck - 110, width: 6, height: 6))
        return path
    }

    /// The Po, two banks winding across the foot of the plate together.
    static func river(_ rect: CGRect, at fraction: CGFloat) -> Path {
        var path = Path()
        for bank: CGFloat in [0, 12] {
            let y = rect.minY + rect.height * fraction + bank
            var x = rect.minX - 20
            var bend: CGFloat = 16
            path.move(to: CGPoint(x: x, y: y))
            while x < rect.maxX {
                path.addQuadCurve(to: CGPoint(x: x + 84, y: y), control: CGPoint(x: x + 42, y: y + bend))
                x += 84
                bend = -bend
            }
        }
        return path
    }

    /// A cone with a broken top, smoking or not.
    static func volcano(_ rect: CGRect, at fraction: CGFloat, smoke: Bool) -> Path {
        let mid = rect.minX + rect.width * fraction
        let foot = rect.minY + rect.height * 0.5
        let top = rect.minY + rect.height * 0.16
        var path = Path()
        path.move(to: CGPoint(x: mid - rect.width * 0.32, y: foot))
        path.addQuadCurve(to: CGPoint(x: mid - 18, y: top), control: CGPoint(x: mid - rect.width * 0.12, y: foot - 20))
        path.addLine(to: CGPoint(x: mid + 18, y: top + 4))
        path.addQuadCurve(to: CGPoint(x: mid + rect.width * 0.32, y: foot), control: CGPoint(x: mid + rect.width * 0.12, y: foot - 20))
        for ridge in [-1.0, 0.0, 1.0] {
            path.move(to: CGPoint(x: mid + ridge * 10, y: top + 8))
            path.addLine(to: CGPoint(x: mid + ridge * 40, y: foot - 30))
        }
        guard smoke else { return path }
        path.move(to: CGPoint(x: mid, y: top - 4))
        path.addCurve(to: CGPoint(x: mid + 40, y: top - 60), control1: CGPoint(x: mid - 24, y: top - 26),
                      control2: CGPoint(x: mid + 46, y: top - 24))
        path.addCurve(to: CGPoint(x: mid + 96, y: top - 70), control1: CGPoint(x: mid + 36, y: top - 92),
                      control2: CGPoint(x: mid + 80, y: top - 96))
        return path
    }

    /// Rings round a disc, engraved rather than lit.
    static func sun(_ rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.minX + rect.width * 0.8, y: rect.minY + rect.height * 0.2)
        var path = Path()
        for radius in [22.0, 32.0, 42.0] {
            path.addEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
        }
        return path
    }

    /// A row of arches along the top of a palazzo; pointed for Venice.
    static func arcade(_ rect: CGRect, at fraction: CGFloat, pointed: Bool) -> Path {
        var path = Path()
        let base = rect.minY + rect.height * (fraction + 0.16)
        let width: CGFloat = 30
        var x = rect.minX + 6
        path.move(to: CGPoint(x: rect.minX, y: base))
        path.addLine(to: CGPoint(x: rect.maxX, y: base))
        while x + width < rect.maxX {
            path.move(to: CGPoint(x: x, y: base))
            path.addLine(to: CGPoint(x: x, y: base - 44))
            if pointed {
                path.addQuadCurve(to: CGPoint(x: x + width / 2, y: base - 66), control: CGPoint(x: x, y: base - 60))
                path.addQuadCurve(to: CGPoint(x: x + width, y: base - 44), control: CGPoint(x: x + width, y: base - 60))
            } else {
                path.addArc(center: CGPoint(x: x + width / 2, y: base - 44), radius: width / 2,
                            startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            }
            path.addLine(to: CGPoint(x: x + width, y: base))
            x += width + 10
        }
        return path
    }

    static func gondola(_ rect: CGRect) -> Path {
        let left = CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.72)
        var path = Path()
        path.move(to: left)
        path.addQuadCurve(to: CGPoint(x: left.x + 120, y: left.y - 16), control: CGPoint(x: left.x + 64, y: left.y + 18))
        path.addLine(to: CGPoint(x: left.x + 112, y: left.y - 30))
        path.move(to: CGPoint(x: left.x + 96, y: left.y))
        path.addLine(to: CGPoint(x: left.x + 130, y: left.y - 64))
        return path
    }

    /// Three tiers of arches, bowed into the amphitheatre's curve.
    static func colosseum(_ rect: CGRect) -> Path {
        var path = Path()
        let left = rect.minX + rect.width * 0.08, right = rect.minX + rect.width * 0.62
        for tier in 0..<3 {
            let base = rect.minY + rect.height * (0.36 - CGFloat(tier) * 0.075)
            let bow: CGFloat = 16 - CGFloat(tier) * 3
            path.move(to: CGPoint(x: left, y: base))
            path.addQuadCurve(to: CGPoint(x: right, y: base), control: CGPoint(x: (left + right) / 2, y: base + bow))
            var x = left + 8
            while x + 18 < right {
                let t = (x - left) / (right - left)
                let y = base + bow * 2 * t * (1 - t) - 4
                path.addArc(center: CGPoint(x: x + 7, y: y - 12), radius: 7, startAngle: .degrees(180),
                            endAngle: .degrees(0), clockwise: false)
                x += 22
            }
        }
        return path
    }

    /// A broken colonnade down the right of the plate.
    static func columns(_ rect: CGRect) -> Path {
        var path = Path()
        let foot = rect.minY + rect.height * 0.82
        for index in 0..<4 {
            let x = rect.minX + rect.width * (0.7 + CGFloat(index) * 0.075)
            let height = rect.height * (index == 2 ? 0.16 : 0.3)
            path.addRect(CGRect(x: x, y: foot - height, width: 12, height: height))
            path.move(to: CGPoint(x: x - 4, y: foot - height))
            path.addLine(to: CGPoint(x: x + 16, y: foot - height))
            for flute in [4.0, 8.0] {
                path.move(to: CGPoint(x: x + flute, y: foot - height + 4))
                path.addLine(to: CGPoint(x: x + flute, y: foot - 4))
            }
        }
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.64, y: foot))
        path.addLine(to: CGPoint(x: rect.maxX, y: foot))
        return path
    }
}
