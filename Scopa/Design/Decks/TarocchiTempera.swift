import ScopaCore
import SwiftUI

/// The Bembo workshop's grounds and lines: the leaf, the bole under it, the gesso, the ink.
enum Tempera {
    /// The leaf: one flat warm gold. Its tooling, never a sheen, is what makes it read as metal.
    static let gold = Color(red: 0.858, green: 0.694, blue: 0.365)
    /// A line incised in the leaf with a stylus.
    static let tool = Color(red: 0.545, green: 0.375, blue: 0.140).opacity(0.8)
    /// A punch struck into it.
    static let punch = Color(red: 0.420, green: 0.270, blue: 0.095).opacity(0.85)
    /// Armenian bole, the red clay laid under the leaf, left showing as the card's border.
    static let bole = Color(red: 0.560, green: 0.235, blue: 0.140)
    /// The chalk and glue ground a numeral is painted on.
    static let gesso = Color(red: 0.958, green: 0.925, blue: 0.835)
    /// The underdrawing's red earth, for the index.
    static let sinopia = Color(red: 0.490, green: 0.170, blue: 0.100)
    /// The fine dark outline round every shape.
    static let ink = Color(red: 0.200, green: 0.125, blue: 0.075)
    /// Shoes, ermine tails, a horse's hooves.
    static let sable = Color(red: 0.150, green: 0.105, blue: 0.075)
    /// The rose touched on a cheek.
    static let cheek = Color(red: 0.880, green: 0.500, blue: 0.450).opacity(0.5)
}

/// A pigment as the workshop ground it, and the darker tone its folds are drawn in.
struct TarocchiPigment {
    let body: Color
    let shade: Color

    init(_ r: Double, _ g: Double, _ b: Double, shade: Double = 0.7) {
        body = Color(red: r, green: g, blue: b)
        self.shade = Color(red: r * shade, green: g * shade, blue: b * shade)
    }

    static let ultramarine = TarocchiPigment(0.215, 0.315, 0.665, shade: 0.62)
    static let vermilion = TarocchiPigment(0.820, 0.290, 0.170)
    static let verde = TarocchiPigment(0.330, 0.505, 0.300, shade: 0.66)
    /// Lacca, the rose red of madder.
    static let lacca = TarocchiPigment(0.765, 0.395, 0.455)
    /// Biacca, lead white, its folds in a warm grey.
    static let biacca = TarocchiPigment(0.955, 0.935, 0.870, shade: 0.78)
    static let flesh = TarocchiPigment(0.948, 0.840, 0.720, shade: 0.80)
    static let chestnut = TarocchiPigment(0.500, 0.310, 0.170, shade: 0.65)
    static let flaxen = TarocchiPigment(0.835, 0.655, 0.370, shade: 0.72)
    /// Silver leaf, glazed over so it stays pale: blades.
    static let silver = TarocchiPigment(0.800, 0.815, 0.815)
    static let wood = TarocchiPigment(0.600, 0.400, 0.220, shade: 0.66)
    static let meadow = TarocchiPigment(0.285, 0.425, 0.255)
}

/// What a court of each suit wears: a gown in the suit's own colour, a mantle and its
/// lining in two others, and the colour of their hair.
struct TarocchiDress {
    let gown: TarocchiPigment
    let mantle: TarocchiPigment
    let lining: TarocchiPigment
    let hair: TarocchiPigment

    init(_ suit: Suit) {
        switch suit {
        case .coins: (gown, mantle, lining, hair) = (.vermilion, .ultramarine, .verde, .flaxen)
        case .cups: (gown, mantle, lining, hair) = (.ultramarine, .lacca, .biacca, .chestnut)
        case .swords: (gown, mantle, lining, hair) = (.biacca, .verde, .vermilion, .chestnut)
        case .clubs: (gown, mantle, lining, hair) = (.verde, .vermilion, .biacca, .flaxen)
        }
    }
}
