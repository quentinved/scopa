import SwiftUI
import ScopaCore

/// The smalti mixed for each thing a Mosaico card shows.
extension Smalti {
    static let stoneGround = Smalti(.stoneShade, .stone, .stone, .stone, .stonePale, .stonePale)
    static let goldGround = Smalti(.goldDeep, .goldWarm, .gold, .gold, .gold, .goldPale)
    static let lapisGround = Smalti(.lapisDeep, .lapis, .lapis, .lapis, .lapisLight)
    static let lapisEdge = Smalti(.lapisDeep, .lapisDeep, .lapis)
    static let gold = Smalti(.goldDeep, .goldWarm, .gold, .gold, .goldPale)
    static let halo = Smalti(.gold, .goldPale, .goldPale, .stonePale)
    /// The deep red course that outlines gold, as round every halo in San Vitale.
    static let rim = Smalti(.redDeep, .redDeep, .brown)
    static let pearl = Smalti(.stonePale, .white, .white)
    static let garnet = Smalti(.redDeep, .red, .red)
    static let wine = Smalti(.redDeep, .redDeep, .red)
    static let red = Smalti(.red, .red, .red, .terracotta, .rose)
    static let blackSteel = Smalti(.slate, .slate, .lapisDeep)
    static let steel = Smalti(.lapisLight, .steel, .steel, .sky, .silver)
    static let ridge = Smalti(.silver, .white, .white)
    static let leather = Smalti(.brown, .umber, .redDeep)
    static let bark = Smalti(.ink, .brown, .brown)
    static let wood = Smalti(.brown, .umber, .umber, .umber, .goldDeep)
    static let leaf = Smalti(.green, .green, .greenPale)
    static let rings = Smalti(.umber, .brown, .umber)
    static let heartwood = Smalti(.stoneShade, .stone, .stoneShade)
    static let jewels = Smalti(.goldDeep, .gold, .gold, .goldPale, .red, .green, .gold, .white)
}

/// A part of a suit emblem. Higher tiers are laid over lower ones: a rim over its bowl, a
/// guard over its blade.
struct MosaicoPart {
    let piece: MosaicoPiece
    let paint: (CGFloat) -> Smalti
    var tier = 0
}

/// The four Italian suits as a Ravenna workshop would set them: a jewelled gold coin, a
/// red kantharos, a steel blade with a gold guard, a budding green rod.
enum MosaicoEmblem {
    /// `simple` drops the pearls and the garnet's ring for a coin too small to show them.
    static func parts(_ suit: Suit, at centre: CGPoint, size s: CGFloat, simple: Bool = false) -> [MosaicoPart] {
        let turn: CGFloat = suit == .clubs ? -14 * .pi / 180 : 0
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: centre.x + (x * cos(turn) - y * sin(turn)) * s,
                    y: centre.y + (x * sin(turn) + y * cos(turn)) * s)
        }
        switch suit {
        case .coins: return coin(at(0, 0), s, simple: simple)
        case .cups: return cup(at, s)
        case .swords: return sword(at, s)
        case .clubs: return rod(at, s)
        }
    }

    /// Edged in deep red, then gold, a ring of pearls, gold again and a garnet at the heart.
    private static func coin(_ centre: CGPoint, _ s: CGFloat, simple: Bool) -> [MosaicoPart] {
        let full: (CGFloat) -> Smalti = { f in
            f < 0.17 ? .rim : f < 0.45 ? .gold : f < 0.63 ? .pearl : f < 0.82 ? .gold : .garnet
        }
        let plain: (CGFloat) -> Smalti = { f in f < 0.2 ? .rim : f < 0.85 ? .gold : .garnet }
        return [MosaicoPart(piece: .oval(centre, rx: s * 0.44, ry: s * 0.44), paint: simple ? plain : full)]
    }

    private static func cup(_ at: (CGFloat, CGFloat) -> CGPoint, _ s: CGFloat) -> [MosaicoPart] {
        let body: (CGFloat) -> Smalti = { $0 < 0.3 ? .wine : .red }
        let metal: (CGFloat) -> Smalti = { $0 < 0.3 ? .rim : .gold }
        func handle(_ side: CGFloat) -> MosaicoPart {
            MosaicoPart(piece: .strip([at(0.30 * side, -0.25), at(0.44 * side, -0.17), at(0.41 * side, -0.04),
                                      at(0.24 * side, 0.01)], widths: [s * 0.075]), paint: metal)
        }
        return [
            handle(-1), handle(1),
            MosaicoPart(piece: .oval(at(0, -0.27), rx: s * 0.31, ry: s * 0.35, from: 0, to: .pi), paint: body),
            MosaicoPart(piece: .strip([at(0, 0.05), at(0, 0.27)], widths: [s * 0.11, s * 0.09]), paint: body),
            MosaicoPart(piece: .strip([at(0, 0.26), at(0, 0.43)], widths: [s * 0.12, s * 0.48]), paint: body),
            MosaicoPart(piece: .strip([at(-0.37, -0.27), at(0.37, -0.27)], widths: [s * 0.10]), paint: metal, tier: 1),
            MosaicoPart(piece: .oval(at(0, 0.16), rx: s * 0.07, ry: s * 0.07), paint: metal, tier: 1),
        ]
    }

    private static func sword(_ at: (CGFloat, CGFloat) -> CGPoint, _ s: CGFloat) -> [MosaicoPart] {
        let metal: (CGFloat) -> Smalti = { $0 < 0.3 ? .rim : .gold }
        return [
            MosaicoPart(piece: .strip([at(0, -0.48), at(0, -0.33), at(0, 0.14)], widths: [0, s * 0.27, s * 0.30])) { f in
                f < 0.3 ? .blackSteel : f < 0.9 ? .steel : .ridge
            },
            MosaicoPart(piece: .strip([at(0, 0.16), at(0, 0.36)], widths: [s * 0.11]), paint: { _ in .leather }),
            MosaicoPart(piece: .strip([at(-0.31, 0.15), at(0.31, 0.15)], widths: [s * 0.11]), paint: metal, tier: 1),
            MosaicoPart(piece: .oval(at(-0.34, 0.15), rx: s * 0.075, ry: s * 0.075), paint: metal, tier: 1),
            MosaicoPart(piece: .oval(at(0.34, 0.15), rx: s * 0.075, ry: s * 0.075), paint: metal, tier: 1),
            MosaicoPart(piece: .oval(at(0, 0.41), rx: s * 0.085, ry: s * 0.085), paint: metal, tier: 1),
        ]
    }

    /// A knotty cudgel lopped clean at both ends, budding two green leaves.
    private static func rod(_ at: (CGFloat, CGFloat) -> CGPoint, _ s: CGFloat) -> [MosaicoPart] {
        let cut: (CGFloat) -> Smalti = { $0 < 0.3 ? .bark : $0 < 0.7 ? .rings : .heartwood }
        let leaf: (CGFloat) -> Smalti = { $0 < 0.3 ? Smalti(.greenDeep) : .leaf }
        return [
            MosaicoPart(piece: .strip([at(0.08, -0.12), at(0.24, -0.25), at(0.38, -0.27)],
                                     widths: [s * 0.03, s * 0.13, 0]), paint: leaf),
            MosaicoPart(piece: .strip([at(-0.08, 0.20), at(-0.23, 0.12), at(-0.36, 0.13)],
                                     widths: [s * 0.03, s * 0.12, 0]), paint: leaf),
            MosaicoPart(piece: .strip([at(0, 0.45), at(0, 0.05), at(0, -0.40)], widths: [s * 0.18, s * 0.22, s * 0.30])) {
                $0 < 0.3 ? .bark : .wood
            },
            MosaicoPart(piece: .oval(at(0, -0.41), rx: s * 0.15, ry: s * 0.15), paint: cut, tier: 1),
            MosaicoPart(piece: .oval(at(0, 0.45), rx: s * 0.09, ry: s * 0.09), paint: cut, tier: 1),
            MosaicoPart(piece: .oval(at(0.07, -0.12), rx: s * 0.055, ry: s * 0.055), paint: { _ in .bark }, tier: 1),
            MosaicoPart(piece: .oval(at(-0.07, 0.20), rx: s * 0.05, ry: s * 0.05), paint: { _ in .bark }, tier: 1),
        ]
    }
}

extension MosaicoWork {
    /// Emblems laid tier by tier, each tier one layer batched across every pip.
    /// `ring` sets one course of the ground round each part, the way a mosaicist lets the
    /// background follow a figure before the rows take over.
    mutating func emblems(_ suit: Suit, at centres: [CGPoint], size: CGFloat, pitch: CGFloat,
                          ring: (material: Smalti, pitch: CGFloat, grout: Smalto)?) {
        let sets = centres.map { MosaicoEmblem.parts(suit, at: $0, size: size, simple: !detailed) }
        if let ring, detailed {
            layer()
            for parts in sets { surround(parts, with: ring.material, pitch: ring.pitch, grout: ring.grout) }
        }
        for tier in 0...2 where sets.contains(where: { $0.contains { $0.tier == tier } }) {
            layer()
            for parts in sets {
                for part in parts where part.tier == tier {
                    lay(part.piece, pitch: pitch, grout: .groutDark, paint: part.paint)
                }
            }
        }
    }

    private mutating func surround(_ parts: [MosaicoPart], with material: Smalti, pitch: CGFloat, grout: Smalto) {
        let gap = pitch * 0.12
        let shapes = parts.map { $0.piece.outline(gap + pitch * 0.35) }
        for (index, part) in parts.enumerated() {
            bed(part.piece.outline(gap * 2 + pitch), grout)
            let line = part.piece.outline(gap + pitch * 0.5)
            let others = shapes.enumerated().filter { $0.offset != index }.map(\.element)
            course(MosaicoCourse(points: line, depths: Array(repeating: pitch, count: line.count), closed: true, inward: 0),
                   pitch: pitch, material: material, light: { _ in -0.2 },
                   keep: { point in !others.contains { $0.encloses(point) } })
        }
    }
}

/// Where the pips of a numeral go: the rows `PipField` uses, so a Mosaico seven sits where
/// every other deck's seven does.
enum MosaicoPipLayout {
    private static let rows: [Int: [Int]] = [
        1: [1], 2: [1, 1], 3: [1, 1, 1], 4: [2, 2], 5: [2, 1, 2], 6: [2, 2, 2], 7: [2, 3, 2],
    ]

    static func place(_ count: Int, in area: CGRect) -> (size: CGFloat, centres: [CGPoint]) {
        let rows = rows[count] ?? [count]
        let widest = CGFloat(rows.max() ?? 1), lines = CGFloat(rows.count)
        let pip = min(area.width / (widest + (widest - 1) * 0.28), area.height / (lines + (lines - 1) * 0.22))
        let top = area.midY - (lines * pip + (lines - 1) * pip * 0.22) / 2 + pip / 2
        var centres: [CGPoint] = []
        for (row, across) in rows.enumerated() {
            let left = area.midX - (CGFloat(across) * pip + CGFloat(across - 1) * pip * 0.28) / 2 + pip / 2
            for column in 0..<across {
                centres.append(CGPoint(x: left + CGFloat(column) * pip * 1.28, y: top + CGFloat(row) * pip * 1.22))
            }
        }
        return (pip, centres)
    }
}
