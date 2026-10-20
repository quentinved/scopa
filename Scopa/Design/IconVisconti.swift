import SwiftUI

/// The Visconti icon's materials: gold leaf laid in squares, the umber its tooling shows in,
/// and the ultramarine the duke's painters ground from lapis.
///
/// Written out rather than taken from `Palette`, like `IconArtwork`'s, so this file compiles
/// on its own for `Tools/render-icon.sh`.
nonisolated enum ViscontiTone {
    static let leafLight = Color(red: 0.902, green: 0.749, blue: 0.408)
    static let leaf = Color(red: 0.792, green: 0.600, blue: 0.267)
    static let leafDeep = Color(red: 0.565, green: 0.392, blue: 0.145)
    /// What a punch leaves in the leaf: the gesso's shadow, never black.
    static let umber = Color(red: 0.333, green: 0.200, blue: 0.067)
    static let ultramarineLight = Color(red: 0.200, green: 0.290, blue: 0.659)
    static let ultramarine = Color(red: 0.110, green: 0.169, blue: 0.494)
    static let ultramarineDeep = Color(red: 0.039, green: 0.063, blue: 0.239)
}

/// The ground of the Visconti icon: gold leaf laid square by square, each a shade off its
/// neighbours with its seam showing, and a diaper punched into it the way the Visconti
/// tarot's gold is tooled: lines of dots on both diagonals, a rosette in every lozenge.
/// Detail in the drawing, never light.
struct ViscontiLeaf: View {
    let unit: CGFloat

    var body: some View {
        Canvas { context, size in
            squares(&context, size)
            // Inside the frame's inner line, so the tooling stops where the border starts.
            context.clip(to: Path(roundedRect: CGRect(x: 84 * unit, y: 84 * unit, width: 856 * unit, height: 856 * unit),
                                  cornerRadius: 146 * unit, style: .continuous))
            diaper(&context, size)
            rosettes(&context, size)
        }
        .allowsHitTesting(false)
    }

    /// Leaf comes in squares, laid edge over edge, and no two catch the light the same.
    private func squares(_ context: inout GraphicsContext, _ size: CGSize) {
        var random = VaultRandom(seed: 0x7A40CC)
        let side = 102.4 * unit
        var lighter = Path(), darker = Path(), seams = Path()
        for row in 0..<10 {
            for column in 0..<10 {
                let square = CGRect(x: CGFloat(column) * side, y: CGFloat(row) * side, width: side, height: side)
                let shade = random.unit()
                if shade < 0.3 { darker.addRect(square) } else if shade > 0.72 { lighter.addRect(square) }
                seams.addRect(CGRect(x: square.minX, y: square.minY, width: side, height: 1.6 * unit))
                seams.addRect(CGRect(x: square.minX, y: square.minY, width: 1.6 * unit, height: side))
            }
        }
        context.fill(darker, with: .color(ViscontiTone.umber.opacity(0.07)))
        context.fill(lighter, with: .color(ViscontiTone.leafLight.opacity(0.22)))
        context.fill(seams, with: .color(ViscontiTone.umber.opacity(0.10)))
    }

    /// Dots punched one by one along both diagonals, a lozenge to every cell.
    private func diaper(_ context: inout GraphicsContext, _ size: CGSize) {
        let cell = 128 * unit, pitch = 12.8 * unit, dot = 3 * unit
        var punches = Path()
        let reach = Int((size.width + size.height) / cell) + 1
        for line in -reach...reach {
            let offset = CGFloat(line) * cell
            for step in 0...Int(size.width * 1.5 / pitch) {
                let t = CGFloat(step) * pitch
                for centre in [CGPoint(x: offset + t, y: t), CGPoint(x: offset + t, y: size.height - t)] {
                    guard centre.x > -dot, centre.x < size.width + dot else { continue }
                    punches.addEllipse(in: CGRect(x: centre.x - dot, y: centre.y - dot, width: dot * 2, height: dot * 2))
                }
            }
        }
        context.fill(punches, with: .color(ViscontiTone.umber.opacity(0.5)))
    }

    /// A ring of eight punches round a ring punch, in the middle of every lozenge: halfway
    /// along a column's crossings, and halfway along a row's.
    private func rosettes(_ context: inout GraphicsContext, _ size: CGSize) {
        let cell: CGFloat = 128 * unit
        var dots = Path(), rings = Path()
        for row in 0...8 {
            for column in 0...8 {
                let x = CGFloat(column) * cell, y = CGFloat(row) * cell
                rosette(at: CGPoint(x: x, y: y + cell / 2), dots: &dots, rings: &rings)
                rosette(at: CGPoint(x: x + cell / 2, y: y), dots: &dots, rings: &rings)
            }
        }
        context.fill(dots, with: .color(ViscontiTone.umber.opacity(0.40)))
        context.stroke(rings, with: .color(ViscontiTone.umber.opacity(0.45)), lineWidth: 2.4 * unit)
    }

    private func rosette(at centre: CGPoint, dots: inout Path, rings: inout Path) {
        let reach: CGFloat = 17 * unit, dot: CGFloat = 3.4 * unit, eye: CGFloat = 6 * unit
        for petal in 0..<8 {
            let angle = CGFloat(petal) * .pi / 4
            let x: CGFloat = centre.x + cos(angle) * reach
            let y: CGFloat = centre.y + sin(angle) * reach
            dots.addEllipse(in: CGRect(x: x - dot, y: y - dot, width: dot * 2, height: dot * 2))
        }
        rings.addEllipse(in: CGRect(x: centre.x - eye, y: centre.y - eye, width: eye * 2, height: eye * 2))
    }
}

/// The border a Visconti card is ruled in: an umber line, a row of punches inside it, and a
/// line of ultramarine inside those.
struct ViscontiFrame: View {
    let unit: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 189 * unit, style: .continuous)
                .strokeBorder(ViscontiTone.umber.opacity(0.85), lineWidth: 8 * unit)
                .padding(40 * unit)
            // Ring punches: a dot struck in umber, its middle left standing in leaf.
            punches(ViscontiTone.umber.opacity(0.7), width: 11 * unit)
            punches(ViscontiTone.leaf, width: 4.5 * unit)
            RoundedRectangle(cornerRadius: 156 * unit, style: .continuous)
                .strokeBorder(ViscontiTone.ultramarine, lineWidth: 6 * unit)
                .padding(72 * unit)
        }
    }

    private func punches(_ colour: Color, width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 168 * unit, style: .continuous)
            .stroke(colour, style: StrokeStyle(lineWidth: width, lineCap: .round, dash: [0, 22 * unit]))
            .padding(57 * unit)
    }
}

/// The coin on the front card, tooled rather than polished: an engraved rim, a ring of
/// punches inside it, and a rosette struck in the middle.
struct ViscontiCoin: View {
    let unit: CGFloat
    let light: Color
    let metal: Color
    let deep: Color

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [light, metal], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().strokeBorder(deep, lineWidth: 5 * unit)
            Circle().inset(by: 22 * unit)
                .stroke(ViscontiTone.umber.opacity(0.7),
                        style: StrokeStyle(lineWidth: 7 * unit, lineCap: .round, dash: [0, 17 * unit]))
            Circle().strokeBorder(deep.opacity(0.85), lineWidth: 4 * unit).padding(36 * unit)
            ForEach(0..<6, id: \.self) { petal in
                Ellipse()
                    .strokeBorder(deep.opacity(0.85), lineWidth: 3.5 * unit)
                    .frame(width: 17 * unit, height: 30 * unit)
                    .offset(y: -22 * unit)
                    .rotationEffect(.degrees(Double(petal) * 60))
            }
            Circle().fill(deep.opacity(0.85)).frame(width: 14 * unit)
        }
        .frame(width: 176 * unit, height: 176 * unit)
    }
}
