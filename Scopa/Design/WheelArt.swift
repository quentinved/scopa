import ScopaRewards
import SwiftUI

/// The face of the day's wheel: painted slices, a walnut rim with brass studs at every
/// division, and a coin for a hub. Drawn once and rasterised, so a turn is one transform.
struct WheelFace: View {
    var size: CGFloat

    private var count: Int { DailyWheel.segments.count }
    private var slice: Double { 360 / Double(count) }
    private var rim: CGFloat { size * 0.075 }
    private var face: CGFloat { size / 2 - rim }

    var body: some View {
        ZStack {
            rimBand
            ForEach(0..<count, id: \.self) { index in wedge(index) }
            divisions
            shading
            ForEach(0..<count, id: \.self) { index in label(index) }
            hub
            studs
        }
        .frame(width: size, height: size)
        .drawingGroup()
    }

    // MARK: Slices

    private func wedge(_ index: Int) -> some View {
        WheelWedge(start: .degrees(Double(index) * slice - slice / 2 - 90), sweep: .degrees(slice))
            .fill(WheelPaint.fill(index))
            .frame(width: face * 2, height: face * 2)
            .overlay { if DailyWheel.segments[index].prize == .jackpot { jackpotEngraving(index) } }
    }

    /// Fine lines chased into the gold slice, so the big one reads as worked metal.
    private func jackpotEngraving(_ index: Int) -> some View {
        ForEach(-3...3, id: \.self) { line in
            Rectangle()
                .fill(Palette.goldDeep.opacity(0.35))
                .frame(width: 0.8, height: face * 0.5)
                .offset(y: -face * 0.55)
                .rotationEffect(.degrees(Double(index) * slice + Double(line) * slice / 8))
        }
    }

    private var divisions: some View {
        ForEach(0..<count, id: \.self) { index in
            Rectangle()
                .fill(Palette.goldLight.opacity(0.85))
                .frame(width: 1.2, height: face)
                .offset(y: -face / 2)
                .rotationEffect(.degrees(Double(index) * slice + slice / 2))
        }
    }

    /// The slices fall away towards the rim, as a dished wheel does under a lamp.
    private var shading: some View {
        Circle()
            .fill(RadialGradient(colors: [.clear, .clear, Palette.ink.opacity(0.22)],
                                 center: .center, startRadius: 0, endRadius: face))
            .frame(width: face * 2, height: face * 2)
    }

    // MARK: Labels

    private func label(_ index: Int) -> some View {
        WheelPrizeLabel(prize: DailyWheel.segments[index].prize, ink: WheelPaint.ink(index), size: size)
            .offset(y: -face * 0.64)
            .rotationEffect(.degrees(Double(index) * slice))
    }

    // MARK: Rim and hub

    private var rimBand: some View {
        ZStack {
            Circle().fill(WheelPaint.walnut)
            Circle().strokeBorder(Palette.goldLight.opacity(0.9), lineWidth: 1.5)
            Circle()
                .strokeBorder(Palette.goldDeep.opacity(0.75),
                              style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                .padding(rim * 0.5 - 0.5)
            Circle()
                .strokeBorder(Palette.gold, lineWidth: 2)
                .padding(rim - 2)
        }
    }

    /// A brass stud at every division: what the pointer clicks over.
    private var studs: some View {
        ForEach(0..<count, id: \.self) { index in
            BrassStud(size: rim * 0.62)
                .offset(y: -(size / 2 - rim / 2))
                .rotationEffect(.degrees(Double(index) * slice + slice / 2))
        }
    }

    private var hub: some View {
        ZStack {
            Circle().fill(WheelPaint.walnut)
            Circle().strokeBorder(Palette.goldLight, lineWidth: 1.5)
            DenariMark(size: size * 0.15)
                .shadow(color: Palette.ink.opacity(0.35), radius: 2, y: 1)
        }
        .frame(width: size * 0.21, height: size * 0.21)
    }
}

/// What a slice says: the coin and its sum, the pack, a gift off the shop's shelves, or the crown.
private struct WheelPrizeLabel: View {
    let prize: DailyWheel.Prize
    let ink: Color
    let size: CGFloat

    var body: some View {
        VStack(spacing: size * 0.008) {
            icon
            if let figure {
                Text(verbatim: figure)
                    .font(.display(size * (figure.count > 3 ? 0.056 : 0.066)))
                    .monospacedDigit()
                    .foregroundStyle(ink)
            }
        }
    }

    @ViewBuilder private var icon: some View {
        switch prize {
        case .denari:
            DenariMark(size: size * 0.07)
        case .pack(let tier):
            PackArt(tier: tier, width: size * 0.085)
                .rotationEffect(.degrees(-6))
        case .shelf:
            Image(systemName: "gift.fill")
                .font(.system(size: size * 0.08, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(ink, Palette.goldLight)
        case .jackpot:
            Image(systemName: "crown.fill")
                .font(.system(size: size * 0.07, weight: .semibold))
                .foregroundStyle(WheelPaint.oxblood)
        }
    }

    private var figure: String? {
        switch prize {
        case .denari(let amount): "\(amount.coins)"
        case .jackpot: "\(DailyWheel.jackpotDenari.coins)"
        case .pack, .shelf: nil
        }
    }
}

/// The colours of the wheel, taken from the deck: terracotta and card stock round the edge,
/// the album's blue for its pack, plum for the shop, and gold for the big one.
enum WheelPaint {
    static let walnut = LinearGradient(colors: [Color(red: 0.42, green: 0.25, blue: 0.14),
                                                Color(red: 0.26, green: 0.14, blue: 0.07)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
    static let oxblood = Color(red: 0.55, green: 0.13, blue: 0.11)
    static let plum = Color(red: 0.49, green: 0.31, blue: 0.47)
    static let blue = Color(red: 0.27, green: 0.43, blue: 0.56)

    static func fill(_ index: Int) -> AnyShapeStyle {
        switch DailyWheel.segments[index].prize {
        case .jackpot: AnyShapeStyle(Palette.goldSheen)
        case .shelf: AnyShapeStyle(plum)
        case .pack: AnyShapeStyle(blue)
        case .denari: AnyShapeStyle(index.isMultiple(of: 2) ? Palette.terracotta : Palette.stock)
        }
    }

    static func ink(_ index: Int) -> Color {
        switch DailyWheel.segments[index].prize {
        case .jackpot: oxblood
        case .denari where !index.isMultiple(of: 2): Palette.ink
        default: Palette.cream
        }
    }
}

/// One slice of the wheel, from the centre out.
struct WheelWedge: Shape {
    var start: Angle
    var sweep: Angle

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: centre)
        path.addRelativeArc(center: centre, radius: min(rect.width, rect.height) / 2,
                            startAngle: start, delta: sweep)
        path.closeSubpath()
        return path
    }
}

/// A domed brass stud.
struct BrassStud: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Palette.goldSheen)
            Circle().strokeBorder(Palette.goldDeep, lineWidth: max(size * 0.1, 0.6))
            Circle()
                .fill(Color.white.opacity(0.75))
                .frame(width: size * 0.3, height: size * 0.3)
                .offset(x: -size * 0.16, y: -size * 0.16)
        }
        .frame(width: size, height: size)
    }
}

/// The marker over the wheel: a leather pin with a brass rivet, hung by its head so it
/// flicks as each stud goes under it.
struct WheelPointer: View {
    var width: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            PinShape()
                .fill(LinearGradient(colors: [Color(red: 0.88, green: 0.45, blue: 0.33), Palette.terracotta,
                                              WheelPaint.oxblood],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay { PinShape().stroke(Palette.goldLight, lineWidth: 1.5) }
                .shadow(color: Palette.ink.opacity(0.45), radius: 3, y: 2)
            BrassStud(size: width * 0.38)
                .padding(.top, width * 0.31)
        }
        .frame(width: width, height: width * 1.45)
    }
}

/// A round head drawn down to a point.
struct PinShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = rect.width / 2
        let centre = CGPoint(x: rect.midX, y: rect.minY + radius)
        let tip = CGPoint(x: rect.midX, y: rect.maxY)
        let reach = tip.y - centre.y
        let turn = acos(min(radius / reach, 1))
        var path = Path()
        path.move(to: tip)
        path.addRelativeArc(center: centre, radius: radius, startAngle: .radians(.pi / 2 + turn),
                            delta: .radians(2 * .pi - 2 * turn))
        path.closeSubpath()
        return path
    }
}

/// The wheel at the size of a lobby chip: the slices, a gold rim and a hub, nothing to read.
struct WheelGlyph: View {
    var size: CGFloat

    var body: some View {
        let count = DailyWheel.segments.count
        let slice = 360 / Double(count)
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                WheelWedge(start: .degrees(Double(index) * slice - slice / 2 - 90), sweep: .degrees(slice))
                    .fill(WheelPaint.fill(index))
            }
            Circle().strokeBorder(Palette.goldLight, lineWidth: size * 0.09)
            Circle().fill(Palette.goldSheen).frame(width: size * 0.26, height: size * 0.26)
        }
        .frame(width: size, height: size)
        .drawingGroup()
    }
}

#Preview {
    VStack(spacing: -12) {
        WheelPointer(width: 30).zIndex(1)
        WheelFace(size: 320)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { TableGround() }
}
