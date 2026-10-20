import SwiftUI
import ScopaCore

/// Places a court's pieces on the card: x against the card's width, y against its height,
/// every size against the width.
struct MosaicoEasel {
    let w: CGFloat
    let h: CGFloat
    /// Robes and horse.
    let pitch: CGFloat
    /// Faces and hands, set finer as every workshop set them.
    let fine: CGFloat

    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * h) }

    func oval(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat,
              from: CGFloat = 0, to: CGFloat = 2 * .pi) -> MosaicoPiece {
        .oval(p(x, y), rx: rx * w, ry: ry * w, from: from, to: to)
    }

    func strip(_ spine: [(CGFloat, CGFloat)], _ widths: [CGFloat]) -> MosaicoPiece {
        .strip(spine.map { p($0.0, $0.1) }, widths: widths.map { $0 * w })
    }

    /// The same strip the other side of the card's centre line.
    func mirror(_ spine: [(CGFloat, CGFloat)], _ widths: [CGFloat]) -> MosaicoPiece {
        strip(spine.map { (1 - $0.0, $0.1) }, widths)
    }
}

/// How a piece's courses are coloured, from the outline in.
enum MosaicoPaint {
    static func edged(_ edge: Smalti, _ body: Smalti, at threshold: CGFloat = 0.3) -> (CGFloat) -> Smalti {
        { $0 < threshold ? edge : body }
    }

    /// Drapery: an edge course, then cloth with a darker fold every other band.
    static func folds(_ edge: Smalti, _ cloth: Smalti, _ fold: Smalti) -> (CGFloat) -> Smalti {
        { f in f < 0.16 ? edge : Int(f * 5) % 2 == 1 ? fold : cloth }
    }

    static func plain(_ material: Smalti) -> (CGFloat) -> Smalti { { _ in material } }

    static let purple = folds(Smalti(.ink, .purpleDeep, .purpleDeep), Smalti(.purple, .purple, .purple, .mauve),
                              Smalti(.purpleDeep, .purpleDeep, .purple))
    static let white = folds(Smalti(.steel, .slate), Smalti(.stone, .stonePale, .white, .white),
                             Smalti(.silver, .stoneShade, .stone))
    static let green = folds(Smalti(.greenDeep), Smalti(.green, .green, .greenPale),
                             Smalti(.greenDeep, .green))
    static let lapis = folds(Smalti(.lapisDeep), Smalti(.lapis, .lapis, .lapisLight, .sky),
                             Smalti(.lapisDeep, .lapis))
    static let red = folds(Smalti(.redDeep), Smalti(.red, .red, .terracotta, .rose), Smalti(.redDeep, .red))
    static let skin = edged(Smalti(.umber, .fleshShade), Smalti(.fleshShade, .flesh, .flesh, .fleshPale, .fleshPale),
                            at: 0.2)
    static let hair = edged(Smalti(.ink, .brown), Smalti(.brown, .brown, .umber, .ink), at: 0.2)
    static let gold = edged(.rim, .gold, at: 0.2)
    /// A jewelled band: pearls along both edges, gold set with garnets and emeralds between.
    static let jewelled = edged(.pearl, .jewels, at: 0.4)
}

extension MosaicoWork {
    mutating func robe(_ piece: MosaicoPiece, _ e: MosaicoEasel, _ paint: (CGFloat) -> Smalti) {
        lay(piece, pitch: e.pitch, grout: .groutDark, paint: paint)
    }

    /// Flesh is grouted in its own shadow colour, so a face reads as skin and not as a grid.
    mutating func skin(_ piece: MosaicoPiece, _ e: MosaicoEasel) {
        lay(piece, pitch: e.fine, grout: .fleshShade, paint: MosaicoPaint.skin)
    }

    /// How large a court holds its suit: slender swords and cudgels larger than a coin.
    static func held(_ suit: Suit) -> CGFloat {
        switch suit {
        case .coins: 0.42
        case .cups: 0.44
        case .swords: 0.54
        case .clubs: 0.52
        }
    }

    /// The suit held in both hands in front of the body, the way Justinian holds the paten.
    mutating func presented(_ suit: Suit, _ e: MosaicoEasel, at y: CGFloat) {
        emblems(suit, at: [e.p(0.5, y)], size: Self.held(suit) * e.w, pitch: e.pitch, ring: nil)
        layer()
        let hand: [(CGFloat, CGFloat)] = [(0.30, y + 0.04), (0.33, y + 0.027), (0.36, y + 0.013)]
        skin(e.strip(hand, [0.05, 0.062, 0.045]), e)
        skin(e.mirror(hand, [0.05, 0.062, 0.045]), e)
    }

    // MARK: Re

    /// An emperor: halo, a crown hung with pearls, a purple chlamys over a white tunic with
    /// the jewelled loros down its front, and a short beard.
    mutating func king(_ suit: Suit, _ e: MosaicoEasel) {
        layer()
        lay(e.oval(0.5, 0.20, 0.235, 0.235), pitch: e.pitch, grout: .groutGold, lit: false,
            paint: MosaicoPaint.edged(.rim, .halo, at: 0.12))
        imperialRobes(e)
        beard(e)
        crown(e)
        presented(suit, e, at: 0.585)
        layer()
        features(e, at: 0.5, 0.215, rx: 0.11, ry: 0.145)
    }

    /// Tunic, chlamys and loros, from the back forward, ending on the jewelled collar.
    private mutating func imperialRobes(_ e: MosaicoEasel) {
        layer()
        robe(e.strip([(0.5, 0.37), (0.5, 1.0)], [0.22, 0.26]), e, MosaicoPaint.white)
        skin(e.strip([(0.5, 0.29), (0.5, 0.375)], [0.08, 0.10]), e)
        lay(e.oval(0.5, 0.205, 0.13, 0.16), pitch: e.fine, grout: .groutDark, paint: MosaicoPaint.hair)
        layer()
        robe(e.oval(0.28, 0.40, 0.14, 0.085), e, MosaicoPaint.purple)
        robe(e.oval(0.72, 0.40, 0.14, 0.085), e, MosaicoPaint.purple)
        layer()
        let panel: [(CGFloat, CGFloat)] = [(0.28, 0.37), (0.265, 0.66), (0.25, 1.0)]
        robe(e.strip(panel, [0.24, 0.27, 0.30]), e, MosaicoPaint.purple)
        robe(e.mirror(panel, [0.24, 0.27, 0.30]), e, MosaicoPaint.purple)
        skin(e.oval(0.5, 0.215, 0.11, 0.145), e)
        layer()
        robe(e.strip([(0.5, 0.39), (0.5, 1.0)], [0.085, 0.09]), e, MosaicoPaint.jewelled)
        let sleeve: [(CGFloat, CGFloat)] = [(0.25, 0.40), (0.25, 0.50), (0.30, 0.60)]
        robe(e.strip(sleeve, [0.11, 0.10, 0.08]), e, MosaicoPaint.white)
        robe(e.mirror(sleeve, [0.11, 0.10, 0.08]), e, MosaicoPaint.white)
        layer()
        robe(e.strip([(0.24, 0.37), (0.37, 0.405), (0.5, 0.415), (0.63, 0.405), (0.76, 0.37)], [0.07]), e, MosaicoPaint.jewelled)
    }

    private mutating func beard(_ e: MosaicoEasel) {
        let jaw: [(CGFloat, CGFloat)] = [(0.392, 0.235), (0.42, 0.285), (0.5, 0.305), (0.58, 0.285), (0.608, 0.235)]
        lay(e.strip(jaw, [0.02, 0.05, 0.07, 0.05, 0.02]), pitch: e.fine, grout: .groutDark, paint: MosaicoPaint.hair)
        lay(e.strip([(0.45, 0.256), (0.5, 0.251), (0.55, 0.256)], [0.014, 0.024, 0.014]),
            pitch: e.fine, grout: .groutDark, paint: MosaicoPaint.hair)
    }

    /// A stemma: a jewelled band with pendilia, strings of pearls, hanging by the cheeks.
    private mutating func crown(_ e: MosaicoEasel) {
        lay(e.strip([(0.385, 0.13), (0.5, 0.122), (0.615, 0.13)], [0.06]), pitch: e.fine,
            grout: .groutDark, paint: MosaicoPaint.jewelled)
        for x in [0.388, 0.612] as [CGFloat] {
            lay(e.strip([(x, 0.14), (x, 0.245)], [0.026]), pitch: e.fine, grout: .groutDark,
                paint: MosaicoPaint.plain(Smalti(.white, .white, .red)))
        }
        layer()
        for (x, r) in [(0.42, 0.03), (0.5, 0.04), (0.58, 0.03)] as [(CGFloat, CGFloat)] {
            lay(e.oval(x, 0.108 - r * 0.2, r, r), pitch: e.fine, grout: .groutDark, paint: MosaicoPaint.gold)
        }
    }

    // MARK: Fante

    /// A young courtier, bareheaded: white chlamys pinned at the shoulder over a green tunic
    /// with red clavi, a purple tablion on the cloak.
    mutating func knave(_ suit: Suit, _ e: MosaicoEasel) {
        layer()
        robe(e.strip([(0.5, 0.35), (0.5, 1.0)], [0.24, 0.28]), e, MosaicoPaint.green)
        skin(e.strip([(0.5, 0.28), (0.5, 0.36)], [0.085, 0.10]), e)
        lay(e.oval(0.5, 0.185, 0.145, 0.175), pitch: e.fine, grout: .groutDark, paint: MosaicoPaint.hair)
        layer()
        robe(e.oval(0.28, 0.39, 0.14, 0.085), e, MosaicoPaint.white)
        robe(e.oval(0.72, 0.39, 0.14, 0.085), e, MosaicoPaint.white)
        for x in [0.455, 0.545] as [CGFloat] { robe(e.strip([(x, 0.37), (x, 1.0)], [0.03]), e, MosaicoPaint.plain(.wine)) }
        layer()
        let panel: [(CGFloat, CGFloat)] = [(0.28, 0.36), (0.26, 0.66), (0.245, 1.0)]
        robe(e.strip(panel, [0.24, 0.27, 0.30]), e, MosaicoPaint.white)
        robe(e.mirror(panel, [0.24, 0.27, 0.30]), e, MosaicoPaint.white)
        skin(e.oval(0.5, 0.20, 0.12, 0.155), e)
        layer()
        robe(e.strip([(0.245, 0.74), (0.24, 0.90)], [0.15]), e, MosaicoPaint.edged(.gold, Smalti(.purple, .purple, .mauve)))
        let sleeve: [(CGFloat, CGFloat)] = [(0.25, 0.40), (0.25, 0.50), (0.30, 0.60)]
        robe(e.strip(sleeve, [0.11, 0.10, 0.08]), e, MosaicoPaint.green)
        robe(e.mirror(sleeve, [0.11, 0.10, 0.08]), e, MosaicoPaint.green)
        lay(e.strip([(0.385, 0.155), (0.5, 0.128), (0.615, 0.155)], [0.05, 0.075, 0.05]), pitch: e.fine,
            grout: .groutDark, paint: MosaicoPaint.hair)
        layer()
        robe(e.strip([(0.40, 0.335), (0.5, 0.36), (0.60, 0.335)], [0.035]), e, MosaicoPaint.gold)
        lay(e.oval(0.29, 0.375, 0.035, 0.035), pitch: e.fine, grout: .groutDark, paint: MosaicoPaint.edged(.rim, .jewels))
        presented(suit, e, at: 0.585)
        layer()
        features(e, at: 0.5, 0.20, rx: 0.12, ry: 0.155)
    }

    // MARK: Faces

    /// Almond eyes under a long brow that runs into the nose, red at the cheeks: drawn rather
    /// than set, since at this size a tessera is wider than an eyelid.
    mutating func features(_ e: MosaicoEasel, at x: CGFloat, _ y: CGFloat, rx: CGFloat, ry: CGFloat) {
        let c = e.p(x, y), a = rx * e.w, b = ry * e.w
        func q(_ u: CGFloat, _ v: CGFloat) -> CGPoint { CGPoint(x: c.x + u * a, y: c.y + v * b) }
        for side in [-1, 1] as [CGFloat] {
            solid(MosaicoLine.disc(q(side * 0.56, 0.30), a * 0.12), .rose)
            let eye = q(side * 0.40, -0.07)
            let iris = CGPoint(x: eye.x, y: eye.y - a * 0.015)
            solid(MosaicoLine.almond(eye, half: a * 0.29, rise: a * 0.15, fall: a * 0.09), .white)
            solid(MosaicoLine.disc(iris, a * 0.105), .brown)
            solid(MosaicoLine.disc(iris, a * 0.05), .ink)
            solid(MosaicoLine.line(MosaicoLine.lid(eye, half: a * 0.31, rise: a * 0.17), a * 0.05), .ink)
            solid(MosaicoLine.line([q(side * 0.10, -0.33), q(side * 0.42, -0.43), q(side * 0.72, -0.31)], a * 0.06), .brown)
        }
        // The brow runs down into a long straight nose; the mouth is small and level.
        solid(MosaicoLine.line([q(0.03, -0.31), q(0.05, 0.20), q(-0.10, 0.27)], a * 0.05), .umber)
        solid(MosaicoLine.line([q(-0.15, 0.535), q(0, 0.515), q(0.15, 0.535)], a * 0.075), .red)
    }
}

/// Fine outlines drawn as flat shapes: eyes, brows, reins.
enum MosaicoLine {
    static func disc(_ c: CGPoint, _ r: CGFloat) -> [CGPoint] {
        (0..<16).map { CGPoint(x: c.x + cos(CGFloat($0) * .pi / 8) * r, y: c.y + sin(CGFloat($0) * .pi / 8) * r) }
    }

    static func almond(_ c: CGPoint, half: CGFloat, rise: CGFloat, fall: CGFloat) -> [CGPoint] {
        let top = (0...10).map { i -> CGPoint in
            let t = CGFloat(i) / 10
            return CGPoint(x: c.x - half + 2 * half * t, y: c.y - rise * sin(.pi * t))
        }
        let bottom = (1..<10).reversed().map { i -> CGPoint in
            let t = CGFloat(i) / 10
            return CGPoint(x: c.x - half + 2 * half * t, y: c.y + fall * sin(.pi * t))
        }
        return top + bottom
    }

    static func lid(_ c: CGPoint, half: CGFloat, rise: CGFloat) -> [CGPoint] {
        (0...8).map { i in
            let t = CGFloat(i) / 8
            return CGPoint(x: c.x - half + 2 * half * t, y: c.y - rise * sin(.pi * t))
        }
    }

    /// A polyline thickened into a polygon.
    static func line(_ points: [CGPoint], _ thickness: CGFloat) -> [CGPoint] {
        var left: [CGPoint] = [], right: [CGPoint] = []
        for index in points.indices {
            let a = points[max(index - 1, 0)], b = points[min(index + 1, points.count - 1)]
            let length = max(hypot(b.x - a.x, b.y - a.y), 0.0001)
            let nx = -(b.y - a.y) / length * thickness / 2, ny = (b.x - a.x) / length * thickness / 2
            left.append(CGPoint(x: points[index].x + nx, y: points[index].y + ny))
            right.append(CGPoint(x: points[index].x - nx, y: points[index].y - ny))
        }
        return left + right.reversed()
    }
}
