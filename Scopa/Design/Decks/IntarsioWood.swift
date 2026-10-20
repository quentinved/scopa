import ScopaCore
import SwiftUI

/// One veneer: its colour, the colour its grain is drawn in, how the grain runs, and what
/// the hot sand turns it at a shaded edge.
struct IntarsioWood {
    let face: Color
    let grain: Color
    let scorch: Color
    let figure: IntarsioFigure

    init(_ r: Double, _ g: Double, _ b: Double, grain: (Double, Double, Double),
         _ figure: IntarsioFigure = .straight, grainOpacity: Double = 0.62) {
        face = Color(red: r, green: g, blue: b)
        self.grain = Color(red: grain.0, green: grain.1, blue: grain.2).opacity(grainOpacity)
        scorch = Color(red: r * 0.40, green: g * 0.32, blue: b * 0.26).opacity(0.62)
        self.figure = figure
    }
}

/// How a veneer's grain runs.
enum IntarsioFigure {
    /// Close and nearly straight: box, holly, pear.
    case straight
    /// Lines that swing: walnut, rosewood, padauk.
    case wavy
    /// Olive's dark streaks over its fine grain.
    case streaked
    /// No grain to speak of: brass.
    case plain
}

/// The Sorrento workshop's woods. Nothing is painted: every colour on the card is one of these.
extension IntarsioWood {
    /// Acero: the pale field of a numeral, cut flat so it shows its cathedral.
    static let maple = IntarsioWood(0.905, 0.790, 0.580, grain: (0.64, 0.45, 0.25), .wavy, grainOpacity: 0.52)
    /// Bosso: stringing, trim, the tablets the index is set in.
    static let box = IntarsioWood(0.965, 0.880, 0.635, grain: (0.80, 0.64, 0.36))
    /// Agrifoglio: the whitest wood, for ermine, plumes and the knight's horse.
    static let holly = IntarsioWood(0.950, 0.928, 0.868, grain: (0.76, 0.71, 0.62), grainOpacity: 0.5)
    /// Pero: faces and hands.
    static let pear = IntarsioWood(0.918, 0.722, 0.560, grain: (0.74, 0.50, 0.36), grainOpacity: 0.45)
    /// Ulivo: the coin's rim and the club, golden and dark-streaked.
    static let olive = IntarsioWood(0.812, 0.682, 0.420, grain: (0.40, 0.29, 0.14), .streaked, grainOpacity: 0.55)
    static let walnut = IntarsioWood(0.478, 0.310, 0.176, grain: (0.27, 0.16, 0.08), .wavy, grainOpacity: 0.7)
    /// Palissandro: the court's dark field.
    static let rosewood = IntarsioWood(0.318, 0.158, 0.106, grain: (0.17, 0.07, 0.04), .wavy, grainOpacity: 0.75)
    static let ebony = IntarsioWood(0.118, 0.094, 0.080, grain: (0.24, 0.20, 0.17), grainOpacity: 0.4)
    /// Padouk: the cups' red.
    static let padauk = IntarsioWood(0.722, 0.298, 0.165, grain: (0.47, 0.15, 0.07), .wavy)
    /// Harewood, sycamore turned silver in the dye: the swords' grey.
    static let harewood = IntarsioWood(0.700, 0.708, 0.672, grain: (0.48, 0.49, 0.46))
    /// Harewood left longer in the dye: the shaded side of a blade.
    static let steel = IntarsioWood(0.455, 0.478, 0.478, grain: (0.30, 0.32, 0.32))
    /// Sycamore dyed green: leaves and the clubs' cloth.
    static let green = IntarsioWood(0.430, 0.545, 0.300, grain: (0.24, 0.33, 0.14))
    /// Madreperla, for the settebello only: shell, not wood, its growth lines faintly blue.
    static let pearl = IntarsioWood(0.940, 0.940, 0.918, grain: (0.66, 0.76, 0.82), .wavy, grainOpacity: 0.7)
    /// Ottone: crowns, coins' stringing and the settebello's.
    static let brass = IntarsioWood(0.812, 0.624, 0.282, grain: (0.60, 0.43, 0.16), .plain)

    /// The fine dark line where two pieces meet: the saw's kerf, filled with glue and dust.
    static let kerf = Color(red: 0.125, green: 0.078, blue: 0.045).opacity(0.82)
    /// An engraved line filled with black mastic: eyes, brows, the barbs of a plume.
    static let mastic = Color(red: 0.105, green: 0.070, blue: 0.050)
}

/// Which woods a court of each suit wears: a gown in the suit's own, a cloak never in it,
/// and a trim for belts and hems.
struct IntarsioDress {
    let gown: IntarsioWood
    let cloak: IntarsioWood
    let trim: IntarsioWood

    init(_ suit: Suit) {
        switch suit {
        case .coins: (gown, cloak, trim) = (.olive, .padauk, .brass)
        case .cups: (gown, cloak, trim) = (.padauk, .harewood, .box)
        case .swords: (gown, cloak, trim) = (.harewood, .padauk, .box)
        case .clubs: (gown, cloak, trim) = (.green, .olive, .box)
        }
    }
}
