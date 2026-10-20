import SwiftUI
import ScopaCore

extension MosaicoWork {
    // MARK: Cavallo

    /// A soldier saint on a white horse: the horse in profile across the lower half, the
    /// rider frontal above it, the suit raised beside his halo.
    mutating func knight(_ suit: Suit, _ e: MosaicoEasel) {
        layer()
        lay(e.oval(0.55, 0.18, 0.19, 0.19), pitch: e.pitch, grout: .groutGold, lit: false,
            paint: MosaicoPaint.edged(.rim, .halo, at: 0.14))
        horse(e)
        rider(e)
        emblems(suit, at: [e.p(0.79, 0.31)], size: (Self.held(suit) * 0.68) * e.w, pitch: e.pitch, ring: nil)
        layer()
        skin(e.oval(0.785, 0.425, 0.04, 0.045), e)
        skin(e.oval(0.36, 0.485, 0.04, 0.045), e)
        solid(MosaicoLine.line([e.p(0.36, 0.49), e.p(0.22, 0.52), e.p(0.105, 0.545)], e.w * 0.014), .redDeep)
        features(e, at: 0.55, 0.19, rx: 0.10, ry: 0.13)
    }

    private mutating func horse(_ e: MosaicoEasel) {
        let coat = MosaicoPaint.edged(Smalti(.slate, .steel), Smalti(.silver, .stone, .stonePale, .white, .white), at: 0.2)
        let shade = MosaicoPaint.edged(Smalti(.slate), Smalti(.steel, .silver, .silver, .stone), at: 0.25)
        let mane = MosaicoPaint.plain(Smalti(.slate, .ink, .steel))
        layer()
        robe(e.strip([(0.35, 0.69), (0.34, 0.80), (0.355, 0.91)], [0.075, 0.05, 0.045]), e, shade)
        robe(e.strip([(0.66, 0.69), (0.69, 0.80), (0.665, 0.91)], [0.075, 0.05, 0.045]), e, shade)
        robe(e.strip([(0.80, 0.60), (0.85, 0.66), (0.84, 0.74)], [0.05, 0.065, 0.04]), e, mane)
        layer()
        robe(e.oval(0.75, 0.635, 0.11, 0.135), e, coat)
        robe(e.oval(0.27, 0.63, 0.10, 0.13), e, coat)
        layer()
        robe(e.strip([(0.28, 0.63), (0.50, 0.645), (0.75, 0.635)], [0.25, 0.27, 0.26]), e, coat)
        robe(e.strip([(0.28, 0.61), (0.22, 0.52), (0.18, 0.455)], [0.20, 0.15, 0.12]), e, coat)
        layer()
        robe(e.strip([(0.185, 0.445), (0.135, 0.505), (0.095, 0.56)], [0.11, 0.095, 0.075]), e, coat)
        robe(e.strip([(0.344, 0.59), (0.28, 0.50), (0.23, 0.44)], [0.035, 0.045, 0.035]), e, mane)
        robe(e.strip([(0.29, 0.69), (0.265, 0.80), (0.285, 0.915)], [0.08, 0.055, 0.05]), e, coat)
        robe(e.strip([(0.72, 0.69), (0.75, 0.80), (0.72, 0.915)], [0.08, 0.055, 0.05]), e, coat)
        robe(e.strip([(0.55, 0.555), (0.55, 0.70)], [0.22, 0.24]), e, MosaicoPaint.edged(.gold, Smalti(.red, .red, .terracotta)))
        layer()
        robe(e.oval(0.095, 0.56, 0.042, 0.042), e, shade)
        robe(e.strip([(0.20, 0.43), (0.215, 0.395)], [0.035, 0]), e, coat)
        for x in [0.285, 0.72, 0.355, 0.665] as [CGFloat] {
            robe(e.strip([(x - 0.03, 0.925), (x + 0.025, 0.925)], [0.03]), e, MosaicoPaint.plain(Smalti(.slate, .ink)))
        }
        solid(MosaicoLine.disc(e.p(0.165, 0.465), e.w * 0.013), .ink)
        solid(MosaicoLine.line([e.p(0.18, 0.45), e.p(0.125, 0.535)], e.w * 0.014), .redDeep)
        solid(MosaicoLine.line([e.p(0.09, 0.53), e.p(0.145, 0.545)], e.w * 0.014), .redDeep)
    }

    private mutating func rider(_ e: MosaicoEasel) {
        layer()
        robe(e.strip([(0.53, 0.575), (0.515, 0.67), (0.51, 0.77)], [0.085, 0.07, 0.06]), e, MosaicoPaint.lapis)
        robe(e.strip([(0.51, 0.76), (0.50, 0.80), (0.47, 0.815)], [0.06, 0.055, 0.045]), e, MosaicoPaint.red)
        robe(e.strip([(0.43, 0.31), (0.415, 0.44), (0.41, 0.56)], [0.10, 0.12, 0.12]), e, MosaicoPaint.red)
        robe(e.strip([(0.67, 0.31), (0.685, 0.44), (0.69, 0.56)], [0.10, 0.12, 0.12]), e, MosaicoPaint.red)
        skin(e.strip([(0.55, 0.265), (0.55, 0.33)], [0.075, 0.09]), e)
        lay(e.oval(0.55, 0.177, 0.12, 0.15), pitch: e.fine, grout: .groutDark, paint: MosaicoPaint.hair)
        layer()
        robe(e.strip([(0.55, 0.31), (0.55, 0.575)], [0.25, 0.22]), e, MosaicoPaint.lapis)
        robe(e.oval(0.44, 0.33, 0.09, 0.06), e, MosaicoPaint.red)
        robe(e.oval(0.66, 0.33, 0.09, 0.06), e, MosaicoPaint.red)
        skin(e.oval(0.55, 0.19, 0.10, 0.13), e)
        layer()
        robe(e.strip([(0.44, 0.50), (0.66, 0.50)], [0.035]), e, MosaicoPaint.gold)
        robe(e.strip([(0.47, 0.305), (0.55, 0.325), (0.63, 0.305)], [0.03]), e, MosaicoPaint.gold)
        robe(e.strip([(0.45, 0.33), (0.40, 0.41), (0.37, 0.47)], [0.085, 0.075, 0.065]), e, MosaicoPaint.lapis)
        robe(e.strip([(0.65, 0.33), (0.72, 0.38), (0.77, 0.415)], [0.085, 0.075, 0.065]), e, MosaicoPaint.lapis)
        lay(e.strip([(0.455, 0.15), (0.55, 0.127), (0.645, 0.15)], [0.04, 0.06, 0.04]), pitch: e.fine,
            grout: .groutDark, paint: MosaicoPaint.hair)
        lay(e.oval(0.64, 0.32, 0.03, 0.03), pitch: e.fine, grout: .groutDark, paint: MosaicoPaint.edged(.rim, .jewels))
    }
}
