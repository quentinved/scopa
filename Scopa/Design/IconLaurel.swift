import SwiftUI

/// Gran Maestro's laurel on the app icon: two sprigs rising from behind the name, round the
/// outside of the fan, to its shoulders. The medal's laurel (`MedalLaurel`) at the icon's
/// scale, behind the cards so they still lead.
///
/// Its own leaf rather than `Leaf`, and its own colours, so this file compiles on its own
/// beside `IconArtwork` for `Tools/render-icon.sh`.
struct IconLaurel: View {
    let unit: CGFloat
    let light: Color
    let metal: Color
    let deep: Color

    /// The circle the sprigs grow along, centred a little above the icon's middle.
    private var radius: CGFloat { 362 * unit }

    var body: some View {
        ZStack {
            sprig.scaleEffect(x: -1)
            sprig
        }
        .frame(width: 1024 * unit, height: 1024 * unit)
        .offset(y: -40 * unit)
        .shadow(color: deep.opacity(0.7), radius: 10 * unit, y: 5 * unit)
    }

    /// One side: a stem from behind the plaque round to the shoulder, nine leaves along it,
    /// smallest at the top.
    private var sprig: some View {
        let leaves = 9
        return ZStack {
            LaurelStem(radius: radius, from: 150, to: 30)
                .stroke(deep, style: StrokeStyle(lineWidth: 9 * unit, lineCap: .round))
            ForEach(0..<leaves, id: \.self) { index in
                let t = Double(index) / Double(leaves - 1)
                LaurelLeaf()
                    .fill(LinearGradient(colors: [light, metal, deep], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay { LaurelLeaf().stroke(deep, lineWidth: 3.5 * unit) }
                    .frame(width: (60 - t * 18) * unit, height: (124 - t * 40) * unit)
                    // Swept along the stem, tips outward, as the medal's are.
                    .rotationEffect(.degrees(-56))
                    .offset(y: -(radius + 14 * unit))
                    .rotationEffect(.degrees(146 - t * 112))
            }
        }
    }
}

/// An arc of the circle the leaves are set on, in degrees clockwise from the top.
private struct LaurelStem: Shape {
    let radius: CGFloat
    let from: Double
    let to: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 24
        for step in 0...steps {
            let angle = (from + (to - from) * Double(step) / Double(steps)) * .pi / 180
            let point = CGPoint(x: rect.midX + radius * sin(angle), y: rect.midY - radius * cos(angle))
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

/// A laurel leaf, tip up: the same outline as the app's `Leaf`.
private struct LaurelLeaf: Shape {
    func path(in r: CGRect) -> Path {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y)
        }
        var p = Path()
        p.move(to: at(0.50, 1.00))
        p.addQuadCurve(to: at(0.25, 0.54), control: at(0.25, 0.79))
        p.addQuadCurve(to: at(0.50, 0.00), control: at(0.25, 0.29))
        p.addQuadCurve(to: at(0.75, 0.54), control: at(0.75, 0.29))
        p.addQuadCurve(to: at(0.50, 1.00), control: at(0.75, 0.79))
        p.closeSubpath()
        return p
    }
}
