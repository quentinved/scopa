import ScopaCore
import SwiftUI

/// Mosaico faces and suits, set once for each card and size and kept.
///
/// Setting a face places a couple of thousand tesserae, which is the dear part; drawing
/// what was set is a few dozen fills. A `Canvas` draws again whenever it is asked to, so
/// without this every redraw of a card would set it again. The table, the hand, the album
/// and its ghosts each ask at their own width, a handful of sizes across forty cards.
enum MosaicoSettings {
    private struct Key: Hashable {
        let card: Card?
        let suit: Suit
        let quarters: Int
    }

    private static var kept: [Key: MosaicoWork] = [:]
    /// Three sizes of a whole deck and then some. A width that keeps changing, a card
    /// growing in an animation say, empties it rather than filling memory a size at a time.
    private static let limit = 160

    static func face(_ card: Card, width: CGFloat) -> MosaicoWork {
        let key = Key(card: card, suit: card.suit, quarters: Int((width * 4).rounded()))
        return kept(key) { MosaicoCard(card: card, size: CGSize(width: width, height: width * 1.5)).set() }
    }

    /// A suit on its own, without the ground a card sets round it.
    static func suit(_ suit: Suit, size: CGFloat) -> MosaicoWork {
        let key = Key(card: nil, suit: suit, quarters: Int((size * 4).rounded()))
        return kept(key) {
            var work = MosaicoWork(seed: UInt64(Suit.allCases.firstIndex(of: suit) ?? 0) + 91, detailed: size >= 24)
            work.emblems(suit, at: [CGPoint(x: size / 2, y: size / 2)], size: size * 0.94,
                         pitch: max(size * 0.085, 1.4), ring: nil)
            return work
        }
    }

    private static func kept(_ key: Key, setting: () -> MosaicoWork) -> MosaicoWork {
        if let work = kept[key] { return work }
        if kept.count >= limit { kept.removeAll() }
        let work = setting()
        kept[key] = work
        return work
    }
}

/// One suit in smalti, for a mark shown away from a card.
struct MosaicoSuit: View {
    let suit: Suit
    let size: CGFloat

    var body: some View {
        let work = MosaicoSettings.suit(suit, size: size)
        Canvas { context, _ in work.draw(in: context) }
            .frame(width: size, height: size)
    }
}
