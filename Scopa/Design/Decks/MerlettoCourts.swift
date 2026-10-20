import ScopaCore
import SwiftUI

/// Re and fante worked as Burano works a figure: the solid parts in toile, the light ones
/// in réseau, every part cut clear of the next, and the suit's thread in the gown.
extension MerlettoPillow {
    // MARK: Re

    /// A king standing to the knee: a mantle of réseau off both shoulders, a gown in the
    /// suit's thread with a toile orphrey, an ermine cape with its tails left open, a sceptre
    /// in one hand and the suit in the other.
    func king(_ suit: Suit) {
        let house = MerlettoThread.house(suit)
        let mantle: [(CGFloat, CGFloat)] = [(0.31, 0.55), (0.19, 0.74), (0.13, 1.05), (0.11, 1.46), (0.50, 1.46), (0.50, 0.55)]
        net(outline(mantle), cell: 0.034)
        net(outline(mirrored(mantle)), cell: 0.034)
        let lining: [(CGFloat, CGFloat)] = [(0.355, 0.60), (0.325, 0.92), (0.28, 1.46)]
        toile(limb(lining, [0.05, 0.05, 0.05]), rows: .pi / 2)
        toile(limb(mirrored(lining), [0.05, 0.05, 0.05]), rows: .pi / 2)
        toile(polygon([(0.38, 0.56), (0.62, 0.56), (0.71, 1.46), (0.29, 1.46)]), house, rows: .pi / 2)
        orphrey(x: 0.5, from: 0.64, to: 1.46, width: 0.085)
        toile(cut(Capsule(), 0.5, 0.95, 0.36, 0.04), rows: 0)
        sleeves(house)
        ermine(0.5, 0.585)
        kingHead(house)
        sceptre(0.285, 0.47, 1.22)
        hand(0.285, 0.87)
        held(suit, hand: 0.75, 0.87, size: 0.30)
    }

    /// Out from under the ermine, in the gown's thread, a lace cuff at each wrist.
    private func sleeves(_ house: MerlettoThread) {
        toile(limb([(0.36, 0.60), (0.29, 0.71), (0.285, 0.83)], [0.13, 0.11, 0.09]), house, rows: .pi * 0.6)
        toile(limb([(0.64, 0.60), (0.73, 0.70), (0.75, 0.83)], [0.13, 0.11, 0.09]), house, rows: .pi * 0.4)
        cuff(0.285, 0.835)
        cuff(0.75, 0.835)
    }

    /// A rod of corded linen under a lily of three toile petals.
    private func sceptre(_ x: CGFloat, _ top: CGFloat, _ bottom: CGFloat) {
        var rod = Path()
        rod.move(to: p(x, top + 0.03))
        rod.addLine(to: p(x, bottom))
        part(rod)
        thread(rod, weight: 2.1)
        for (angle, length) in [(0.0, 0.10), (-0.30, 0.075), (0.30, 0.075)] as [(CGFloat, CGFloat)] {
            leaf(p(x, top + 0.02), length: length * w, breadth: length * 0.5 * w, angle: angle * .pi, .linen)
        }
        toile(oval(x, top + 0.025, 0.024, 0.02))
    }

    /// A shoulder cape of toile edged in scallops, its ermine tails left open to the velvet.
    func ermine(_ x: CGFloat, _ y: CGFloat) {
        let cape: [(CGFloat, CGFloat)] = [(x - 0.29, y + 0.05), (x - 0.21, y - 0.06), (x, y - 0.085), (x + 0.21, y - 0.06),
                                          (x + 0.29, y + 0.05), (x + 0.22, y + 0.10), (x, y + 0.115), (x - 0.22, y + 0.10)]
        let (edge, tips) = beads(p(x, y - 0.055), 0.275 * w, 0.17 * w, count: 11, r: w * 0.021, from: .pi * 0.86, to: .pi * 0.14)
        toile(edge, rows: 0)
        picots(tips)
        toile(outline(cape), rows: 0)
        let tails: [(CGFloat, CGFloat)] = [(-0.19, 0.035), (-0.10, 0.065), (0, 0.075), (0.10, 0.065), (0.19, 0.035),
                                           (-0.145, -0.02), (0.145, -0.02)]
        var spots = Path()
        for (dx, dy) in tails {
            spots.addPath(outline([(x + dx, y + dy - 0.022), (x + dx + 0.012, y + dy + 0.012), (x + dx, y + dy + 0.02),
                                   (x + dx - 0.012, y + dy + 0.012)]))
        }
        context.fill(spots, with: .color(velvet))
    }

    /// Hair and a forked beard worked in curls, the face between them, a crown on top.
    private func kingHead(_ house: MerlettoThread) {
        let hair: [(CGFloat, CGFloat)] = [(0.37, 0.53), (0.36, 0.36), (0.40, 0.255), (0.50, 0.23), (0.60, 0.255),
                                          (0.64, 0.36), (0.63, 0.53), (0.56, 0.47), (0.44, 0.47)]
        curls(outline(hair))
        face(0.5, 0.36, 0.098, 0.118, mouth: false)
        let beard: [(CGFloat, CGFloat)] = [(0.402, 0.37), (0.415, 0.45), (0.455, 0.515), (0.485, 0.535), (0.5, 0.515),
                                           (0.515, 0.535), (0.545, 0.515), (0.585, 0.45), (0.598, 0.37), (0.56, 0.415),
                                           (0.5, 0.405), (0.44, 0.415)]
        curls(outline(beard), r: 0.0095)
        toile(outline([(0.44, 0.432), (0.5, 0.405), (0.56, 0.432), (0.5, 0.425)]), rows: 0, parted: false)
        lips(0.5, 0.447, 0.024)
        crown(0.5, 0.215, 0.25, house)
    }

    // MARK: Fante

    /// A page head to foot: a plumed beret, a ruff, a doublet in the suit's thread with a
    /// scalloped hem, hose parted in linen and the suit's thread, one hand on his hip and
    /// the suit held up in the other.
    func knave(_ suit: Suit) {
        let house = MerlettoThread.house(suit)
        ground()
        toile(limb([(0.448, 0.88), (0.44, 1.10), (0.432, 1.33)], [0.10, 0.085, 0.07]), house, rows: .pi / 2)
        toile(limb([(0.552, 0.88), (0.56, 1.10), (0.568, 1.33)], [0.10, 0.085, 0.07]), rows: .pi / 2)
        toile(outline([(0.39, 1.36), (0.40, 1.32), (0.455, 1.32), (0.465, 1.365)]), rows: 0)
        toile(outline([(0.61, 1.36), (0.60, 1.32), (0.545, 1.32), (0.535, 1.365)]), rows: 0)
        toile(polygon([(0.40, 0.46), (0.37, 0.70), (0.31, 0.93), (0.69, 0.93), (0.63, 0.70), (0.60, 0.46)]), house,
              rows: .pi / 2)
        let (hem, tips) = beads(p(0.5, 0.93), 0.19 * w, 0.01 * w, count: 7, r: w * 0.027, from: .pi, to: 0)
        toile(hem, rows: 0)
        picots(tips.filter { $0.y > 0.93 * w })
        toile(cut(Capsule(), 0.5, 0.72, 0.30, 0.04), rows: 0)
        eyelets([p(0.5, 0.72)] + (0..<3).map { p(0.5, 0.53 + CGFloat($0) * 0.06) }, r: 0.012)
        knaveArms(suit, house)
        knaveHead(house)
    }

    /// The ground a standing figure is set on, in réseau across the foot of the field.
    func ground() {
        net(outline([(0.0, 1.37), (0.25, 1.345), (0.5, 1.335), (0.75, 1.345), (1.0, 1.37), (1.0, 1.6), (0.0, 1.6)]),
            cell: 0.03)
    }

    private func knaveArms(_ suit: Suit, _ house: MerlettoThread) {
        toile(limb([(0.63, 0.50), (0.745, 0.60), (0.655, 0.705)], [0.10, 0.085, 0.075]), house, rows: .pi * 0.3)
        hand(0.64, 0.715)
        for x in [0.372, 0.628] as [CGFloat] {
            toile(oval(x, 0.50, 0.068, 0.052), rows: .pi / 2)
            for dx in [-0.024, 0.024] as [CGFloat] { open(line([(x + dx, 0.468), (x + dx * 1.2, 0.532)]), weight: 0.012) }
        }
        toile(limb([(0.37, 0.53), (0.30, 0.62), (0.275, 0.70)], [0.09, 0.08, 0.072]), house, rows: .pi * 0.7)
        cuff(0.275, 0.705, width: 0.085)
        held(suit, hand: 0.275, 0.735, size: 0.30)
    }

    private func knaveHead(_ house: MerlettoThread) {
        toile(polygon([(0.465, 0.40), (0.535, 0.40), (0.54, 0.47), (0.46, 0.47)]), rows: .pi / 2)
        let (ruff, tips) = beads(p(0.5, 0.468), 0.10 * w, 0.028 * w, count: 12, r: w * 0.024)
        toile(ruff, rows: 0)
        picots(tips)
        let hair: [(CGFloat, CGFloat)] = [(0.385, 0.40), (0.38, 0.29), (0.42, 0.225), (0.50, 0.21), (0.58, 0.225),
                                          (0.62, 0.29), (0.615, 0.40), (0.57, 0.38), (0.5, 0.27), (0.43, 0.38)]
        curls(outline(hair))
        face(0.5, 0.315, 0.09, 0.105)
        plume([(0.58, 0.215), (0.66, 0.16), (0.74, 0.12), (0.80, 0.115)], [0.05, 0.065, 0.05, 0.015])
        toile(oval(0.5, 0.215, 0.135, 0.045), house, rows: 0)
        toile(cut(Capsule(), 0.5, 0.245, 0.24, 0.03), rows: 0)
    }

    /// A feather of réseau on a corded quill, picoted along its upper edge.
    func plume(_ spine: [(CGFloat, CGFloat)], _ widths: [CGFloat]) {
        net(limb(spine, widths), cell: 0.018)
        thread(line(spine), weight: 0.6)
        let tips = zip(spine, widths).dropLast().map { point, width in p(point.0 + width * 0.1, point.1 - width * 0.62) }
        picots(tips)
    }
}
