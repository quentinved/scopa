import SwiftUI
import ScopaCore

/// Lays glazed shapes on a card in card-width units: x across 0...1, y down 0...1.5.
struct MaiolicaBrush {
    let w: CGFloat

    /// A glazed shape centred at (x, y), `pw` by `ph` card widths.
    func part<S: Shape>(_ shape: S, _ x: CGFloat, _ y: CGFloat, _ pw: CGFloat, _ ph: CGFloat,
                        _ tint: MaiolicaTint, line: Color? = MaiolicaPaint.manganese) -> some View {
        MaiolicaGlazed(shape: shape, tint: tint, unit: w, line: line, seed: Int(x * 997 + y * 613))
            .frame(width: w * pw, height: w * ph)
            .position(x: w * x, y: w * y)
    }

    /// A tapered band through a spine, widths in card widths: a limb, a sleeve, a plume.
    func limb(_ spine: [(CGFloat, CGFloat)], _ widths: [CGFloat], _ tint: MaiolicaTint,
              line: Color? = MaiolicaPaint.manganese) -> some View {
        let ribbon = Ribbon(spine: spine.map { CGPoint(x: $0.0, y: $0.1 / 1.5) }, widths: widths)
        return MaiolicaGlazed(shape: ribbon, tint: tint, unit: w, line: line,
                              seed: Int(spine[0].0 * 991 + spine[0].1 * 577))
            .frame(width: w, height: w * 1.5)
    }

    /// A line with no fill: a brow, a rein, a moustache.
    func line(_ spine: [(CGFloat, CGFloat)], _ colour: Color, _ weight: CGFloat) -> some View {
        Stroke(spine: spine.map { CGPoint(x: $0.0, y: $0.1 / 1.5) })
            .stroke(colour, style: StrokeStyle(lineWidth: max(0.4, w * weight), lineCap: .round, lineJoin: .round))
            .frame(width: w, height: w * 1.5)
    }

    /// A dab of colour with no line.
    func dab<S: Shape>(_ shape: S, _ x: CGFloat, _ y: CGFloat, _ pw: CGFloat, _ ph: CGFloat,
                       _ colour: Color) -> some View {
        shape.fill(colour)
            .frame(width: w * pw, height: w * ph)
            .position(x: w * x, y: w * y)
    }

    /// A garment: the glaze with brush drags down it, and spots if it has any.
    func cloth<S: Shape>(_ shape: S, _ x: CGFloat, _ y: CGFloat, _ pw: CGFloat, _ ph: CGFloat,
                         _ tint: MaiolicaTint, spots: Color? = nil) -> some View {
        ZStack {
            MaiolicaGlazed(shape: shape, tint: tint, unit: w, seed: Int(x * 983 + y * 607))
            MaiolicaDrags(count: 5, seed: Int(y * 100))
                .fill(tint.pool.opacity(0.30))
                .clipShape(shape)
            if let spots {
                MaiolicaSpots(step: w * 0.075, dot: w * 0.026)
                    .fill(spots.opacity(0.9))
                    .clipShape(shape)
            }
        }
        .frame(width: w * pw, height: w * ph)
        .position(x: w * x, y: w * y)
    }

    /// A frontal face as the Vietri painters do it: almond eyes under arched brows, the nose
    /// in one stroke, a small mouth and orange cheeks.
    func face(_ x: CGFloat, _ y: CGFloat, _ s: CGFloat) -> some View {
        ZStack {
            part(Ellipse(), x, y, s, s * 1.08, .flesh)
            dab(Ellipse(), x - s * 0.27, y + s * 0.17, s * 0.20, s * 0.13, MaiolicaPaint.ferraccia.opacity(0.30))
            dab(Ellipse(), x + s * 0.27, y + s * 0.17, s * 0.20, s * 0.13, MaiolicaPaint.ferraccia.opacity(0.30))
            dab(MaiolicaLemon(), x - s * 0.20, y - s * 0.02, s * 0.19, s * 0.09, MaiolicaPaint.manganese)
            dab(MaiolicaLemon(), x + s * 0.20, y - s * 0.02, s * 0.19, s * 0.09, MaiolicaPaint.manganese)
            line([(x - s * 0.33, y - s * 0.13), (x - s * 0.21, y - s * 0.21), (x - s * 0.08, y - s * 0.15)],
                 MaiolicaPaint.manganese, 0.008)
            line([(x + s * 0.33, y - s * 0.13), (x + s * 0.21, y - s * 0.21), (x + s * 0.08, y - s * 0.15)],
                 MaiolicaPaint.manganese, 0.008)
            line([(x + s * 0.01, y - s * 0.09), (x - s * 0.05, y + s * 0.13), (x + s * 0.05, y + s * 0.16)],
                 MaiolicaPaint.manganese.opacity(0.75), 0.007)
            dab(Capsule(), x, y + s * 0.31, s * 0.20, s * 0.065, MaiolicaPaint.ferracciaDeep)
        }
    }

    func hand(_ x: CGFloat, _ y: CGFloat) -> some View {
        part(Ellipse(), x, y, 0.072, 0.066, .flesh)
    }

    func emblem(_ suit: Suit, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat) -> some View {
        MaiolicaSuit(suit: suit, size: w * size, unit: w, seed: 17)
            .position(x: w * x, y: w * y)
    }
}

/// Fante, cavallo and re as Vietri would paint them: frontal faces, patterned cloth, a
/// dappled horse. Each fills the card from the band to the foot; the suit dresses the
/// figure and is held up large.
struct MaiolicaCourt: View {
    let rank: Rank
    let suit: Suit
    let width: CGFloat

    private var b: MaiolicaBrush { MaiolicaBrush(w: width) }
    private var dress: MaiolicaTint { .suit(suit) }
    /// What sets the suit off: cobalt, or saffron against a cobalt suit.
    private var contrast: MaiolicaTint { suit == .swords ? .saffron : .cobalt }
    /// A third glaze for cloaks and hose: copper green, or iron orange against green.
    private var second: MaiolicaTint { suit == .clubs ? .ferraccia : .copper }
    /// Belts, buckles and trim: saffron, or cobalt against saffron.
    private var gold: MaiolicaTint { suit == .coins ? .cobalt : .saffron }

    var body: some View {
        ZStack {
            switch rank {
            case .king: king
            case .knight: knight
            default: knave
            }
        }
        .frame(width: width, height: width * 1.5)
    }

    // MARK: Re

    /// A king in a floor-length spotted robe with an orphrey down the front, a mantle with
    /// an ermine collar, a sceptre in one hand and the suit held up in the other.
    private var king: some View {
        ZStack {
            kingRobe
            kingArms
            kingHead
            b.emblem(suit, 0.735, 0.66, 0.34)
            b.hand(0.715, 0.835)
        }
    }

    private var kingRobe: some View {
        ZStack {
            b.part(Ellipse(), 0.43, 1.37, 0.11, 0.045, .manganese)
            b.part(Ellipse(), 0.57, 1.37, 0.11, 0.045, .manganese)
            b.cloth(Robe(flare: 0.34), 0.50, 0.95, 0.46, 0.80, dress, spots: gold.body)
            b.part(Rectangle(), 0.50, 0.99, 0.075, 0.68, contrast)
            ForEach(0..<5, id: \.self) { k in
                b.dab(Circle(), 0.50, 0.73 + CGFloat(k) * 0.13, 0.034, 0.034, MaiolicaPaint.tin)
            }
            b.part(Capsule(), 0.50, 1.335, 0.68, 0.055, contrast)
            ForEach(0..<8, id: \.self) { k in
                b.dab(Circle(), 0.21 + CGFloat(k) * 0.083, 1.335, 0.026, 0.026, MaiolicaPaint.tin)
            }
        }
    }

    private var kingArms: some View {
        ZStack {
            b.part(Capsule(), 0.265, 0.80, 0.034, 0.70, .saffron)
            b.part(MaiolicaLily(), 0.265, 0.40, 0.13, 0.12, contrast)
            b.part(Circle(), 0.265, 0.462, 0.052, 0.052, .saffron)
            b.limb([(0.38, 0.62), (0.31, 0.74), (0.275, 0.85)], [0.12, 0.10, 0.085], dress)
            b.limb([(0.62, 0.62), (0.70, 0.73), (0.715, 0.82)], [0.12, 0.10, 0.085], dress)
            b.hand(0.268, 0.865)
            b.part(Mantle(), 0.50, 0.665, 0.60, 0.23, second)
            b.part(Capsule(), 0.50, 0.565, 0.34, 0.07, .tin)
            ForEach(0..<5, id: \.self) { k in
                b.dab(Capsule(), 0.38 + CGFloat(k) * 0.06, 0.565, 0.014, 0.03, MaiolicaPaint.manganese)
            }
        }
    }

    private var kingHead: some View {
        ZStack {
            b.part(Ellipse(), 0.50, 0.34, 0.27, 0.25, .manganese)
            b.part(Bowl(roundness: 0.85), 0.50, 0.44, 0.23, 0.15, .manganese)
            b.face(0.50, 0.335, 0.19)
            b.line([(0.44, 0.405), (0.50, 0.392), (0.56, 0.405)], MaiolicaPaint.manganese, 0.014)
            b.part(KingCrown(), 0.50, 0.215, 0.27, 0.12, .saffron)
            ForEach(0..<3, id: \.self) { k in
                b.dab(Circle(), 0.44 + CGFloat(k) * 0.06, 0.252, 0.032, 0.032,
                      k == 1 ? MaiolicaPaint.ferraccia : MaiolicaPaint.cobalt)
            }
        }
    }

    // MARK: Fante

    /// A page in a belted tunic and striped hose, one hand on his hip and the suit held up
    /// in the other.
    private var knave: some View {
        ZStack {
            knaveLegs
            b.cloth(Robe(flare: 0.24), 0.50, 0.66, 0.38, 0.44, dress)
            b.part(Capsule(), 0.50, 0.72, 0.33, 0.042, gold)
            b.part(Capsule(), 0.50, 0.875, 0.48, 0.05, contrast)
            b.part(Capsule(), 0.50, 0.448, 0.23, 0.05, .tin)
            knaveArms
            knaveHead
        }
    }

    private var knaveLegs: some View {
        ZStack {
            b.limb([(0.42, 1.30), (0.40, 1.35), (0.35, 1.365)], [0.075, 0.07, 0.05], .manganese)
            b.limb([(0.58, 1.30), (0.60, 1.35), (0.65, 1.365)], [0.075, 0.07, 0.05], .manganese)
            b.limb([(0.445, 0.86), (0.43, 1.08), (0.42, 1.31)], [0.12, 0.10, 0.08], contrast)
            b.limb([(0.555, 0.86), (0.57, 1.08), (0.58, 1.31)], [0.12, 0.10, 0.08], second)
            ForEach(0..<3, id: \.self) { k in
                let y = 0.98 + CGFloat(k) * 0.11
                b.dab(Capsule(), 0.437 - CGFloat(k) * 0.006, y, 0.10, 0.022, MaiolicaPaint.saffron)
                b.dab(Capsule(), 0.563 + CGFloat(k) * 0.006, y, 0.10, 0.022, MaiolicaPaint.tin)
            }
        }
    }

    private var knaveArms: some View {
        ZStack {
            b.limb([(0.38, 0.50), (0.31, 0.60), (0.285, 0.70)], [0.11, 0.095, 0.08], dress)
            b.limb([(0.62, 0.50), (0.715, 0.60), (0.645, 0.70)], [0.11, 0.095, 0.08], dress)
            b.hand(0.635, 0.71)
            b.emblem(suit, 0.28, 0.55, 0.33)
            b.hand(0.285, 0.715)
        }
    }

    private var knaveHead: some View {
        ZStack {
            b.part(Ellipse(), 0.50, 0.335, 0.25, 0.23, .ochre)
            b.face(0.50, 0.35, 0.17)
            b.limb([(0.60, 0.22), (0.68, 0.15), (0.80, 0.13)], [0.055, 0.04, 0.012], .copper)
            b.part(Cap(), 0.50, 0.225, 0.27, 0.10, contrast)
            b.part(Capsule(), 0.50, 0.272, 0.29, 0.036, contrast)
        }
    }

    // MARK: Cavallo

    /// A rider on a dappled cream horse walking right, his cloak flying behind and the suit
    /// raised over the horse's head.
    private var knight: some View {
        ZStack {
            b.limb([(0.38, 0.685), (0.27, 0.765), (0.17, 0.895)], [0.09, 0.13, 0.05], second)
            b.limb([(0.42, 0.725), (0.52, 0.825), (0.60, 0.865)], [0.085, 0.075, 0.065], dress)
            // Walking right, so its lifted forefoot stays left of the bottom index.
            MaiolicaHorse(unit: width, width: width * 0.86, height: width * 0.59)
                .scaleEffect(x: -1)
                .position(x: width * 0.46, y: width * 1.095)
            b.line([(0.61, 0.87), (0.72, 0.91), (0.83, 0.95)], MaiolicaPaint.manganese, 0.009)
            b.hand(0.61, 0.87)
            rider
            b.emblem(suit, 0.73, 0.43, 0.32)
            b.hand(0.72, 0.585)
        }
    }

    private var rider: some View {
        ZStack {
            b.part(Trapezoid(topRatio: 1.25), 0.42, 1.005, 0.29, 0.10, contrast)
            ForEach(0..<5, id: \.self) { k in
                b.dab(Circle(), 0.31 + CGFloat(k) * 0.055, 1.065, 0.03, 0.03, gold.body)
            }
            b.limb([(0.45, 0.935), (0.51, 0.995), (0.49, 1.105)], [0.10, 0.085, 0.07], second)
            b.limb([(0.49, 1.095), (0.495, 1.145), (0.55, 1.16)], [0.07, 0.065, 0.045], .manganese)
            b.cloth(Robe(flare: 0.14), 0.43, 0.805, 0.25, 0.30, dress)
            b.part(Capsule(), 0.43, 0.915, 0.25, 0.036, gold)
            b.part(Capsule(), 0.43, 0.665, 0.18, 0.042, .tin)
            b.limb([(0.47, 0.715), (0.59, 0.665), (0.70, 0.59)], [0.09, 0.08, 0.07], dress)
            b.part(Ellipse(), 0.43, 0.565, 0.22, 0.20, .manganese)
            b.face(0.435, 0.58, 0.17)
            b.limb([(0.33, 0.485), (0.24, 0.425), (0.15, 0.425)], [0.05, 0.04, 0.012], .copper)
            b.part(Cap(), 0.43, 0.48, 0.25, 0.10, contrast)
            b.part(Capsule(), 0.43, 0.527, 0.27, 0.036, contrast)
        }
    }
}
