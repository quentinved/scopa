import ScopaCore
import SwiftUI

/// One thread: the colour it shows, and the colour where its stitches part or its wrapping
/// turns away from the light.
struct MerlettoThread {
    let face: Color
    let stitch: Color

    init(_ r: Double, _ g: Double, _ b: Double, shade: Double = 0.74) {
        face = Color(red: r, green: g, blue: b)
        stitch = Color(red: r * shade, green: g * shade, blue: b * (shade + 0.02))
    }
}

/// Burano's threads. Nothing is painted: every colour on a card is a thread, the velvet the
/// lace is mounted on, or the velvet in a thread's shadow.
extension MerlettoThread {
    /// Bleached linen: toile, cordonnet, picots.
    static let linen = MerlettoThread(0.972, 0.954, 0.912)
    /// Unbleached and finer, for the réseau.
    static let ivory = MerlettoThread(0.905, 0.862, 0.765)
    /// Oro filato, for the settebello alone.
    static let gold = MerlettoThread(0.905, 0.722, 0.330, shade: 0.70)
    /// A lip, worked in a single rose stitch.
    static let rose = MerlettoThread(0.880, 0.470, 0.480)

    /// One colour per suit, after the houses along the canals: yellow, red, blue and green.
    static func house(_ suit: Suit) -> MerlettoThread {
        switch suit {
        case .coins: MerlettoThread(0.965, 0.770, 0.235)
        case .cups: MerlettoThread(0.900, 0.310, 0.270)
        case .swords: MerlettoThread(0.330, 0.585, 0.900)
        case .clubs: MerlettoThread(0.360, 0.700, 0.420)
        }
    }

    /// Blu notte: the velvet every card is mounted on.
    static let velvet = Color(red: 0.100, green: 0.116, blue: 0.172)
    /// Garnet, inside the settebello's medallion.
    static let garnet = Color(red: 0.300, green: 0.082, blue: 0.125)
    /// Where a thread stands off what lies under it. A hard shadow, never a blur.
    static let shadow = Color.black.opacity(0.46)
}
