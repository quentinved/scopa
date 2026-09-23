import SwiftUI
import ScopaCore

// MARK: Shapes

struct BroomMark: View {
    var size: CGFloat
    /// A single colour for use on coloured grounds. Left off, the mark is drawn in full colour.
    var tint: Color?

    init(size: CGFloat, tint: Color? = nil) {
        self.size = size
        self.tint = tint
    }

    private var straw: Color { tint ?? Palette.gold }
    private var band: Color { tint ?? Palette.terracotta }
    private var handle: Color { tint ?? Palette.ink }

    private static let slatCount = 11
    private static let spread = 40.0

    var body: some View {
        ZStack {
            Capsule()
                .fill(handle)
                .frame(width: size * 0.09, height: size * 0.44)
                .offset(y: -size * 0.31)
            bristles
            RoundedRectangle(cornerRadius: size * 0.025)
                .fill(band)
                .frame(width: size * 0.30, height: size * 0.09)
                .offset(y: -size * 0.09)
        }
        .frame(width: size, height: size)
    }

    /// Straw slats hinged just under the collar, with the ground showing between them.
    private var bristles: some View {
        ForEach(0..<Self.slatCount, id: \.self) { index in
            let position = Double(index) / Double(Self.slatCount - 1) * 2 - 1
            Capsule()
                .fill(straw)
                .frame(width: size * 0.075, height: size * (0.50 - abs(position) * 0.07))
                .offset(y: size * 0.20)
                .rotationEffect(.degrees(position * Self.spread))
        }
    }
}

// MARK: Suits

/// A suit, drawn the way the chosen deck draws it.
struct SuitMark: View {
    let suit: Suit
    var size: CGFloat
    var tint: Color?

    @Environment(\.cardTheme) private var theme

    init(_ suit: Suit, size: CGFloat, tint: Color? = nil) {
        self.suit = suit
        self.size = size
        self.tint = tint
    }

    var body: some View {
        let face = theme.face
        SuitArt(
            style: theme.style,
            suit: suit,
            size: size,
            colour: tint ?? face.colour(of: suit),
            accent: tint ?? face.accent,
            ink: tint ?? face.ink
        )
    }
}

/// The court, in whichever hand the deck is drawn.
struct FigureMark: View {
    let rank: Rank
    let suit: Suit
    /// The square a badge-sized figure is drawn in.
    var size: CGFloat
    /// The card's own width, which is what a full-bleed plate is measured against.
    var cardWidth: CGFloat

    @Environment(\.cardTheme) private var theme

    var body: some View {
        let face = theme.face
        if theme.style.fillsTheCard {
            CourtPlate(rank: rank, suit: suit, width: plate.width, height: plate.height)
        } else {
            CourtArt(style: theme.style, rank: rank, suit: suit, size: size,
                     colour: face.colour(of: suit), accent: face.accent, ink: face.ink)
        }
    }

    /// A full-bleed plate keeps the card's two-to-three ratio, inset to clear the corner
    /// indices.
    private var plate: CGSize {
        CGSize(width: cardWidth * 0.86, height: cardWidth * 1.30)
    }
}

/// Pips laid out the way a real deck does: rows that stay symmetric as the rank climbs.
struct PipField: View {
    let suit: Suit
    let count: Int
    var area: CGSize
    var tint: Color?

    @Environment(\.cardTheme) private var theme

    /// Only the lithographed sheet crosses its pips, and only swords and clubs cross.
    private var interlaces: Bool {
        theme.style.interlacesPips && (suit == .swords || suit == .clubs) && count > 1
    }

    /// Rows of pips per rank. Seven reads as two, three, two.
    private static let rows: [Int: [Int]] = [
        1: [1], 2: [1, 1], 3: [1, 1, 1], 4: [2, 2], 5: [2, 1, 2], 6: [2, 2, 2], 7: [2, 3, 2],
    ]

    var body: some View {
        let rows = Self.rows[count] ?? [count]
        let widest = CGFloat(rows.map(\.self).max() ?? 1)
        let lines = CGFloat(rows.count)
        let pip = min(area.width / (widest + (widest - 1) * 0.28),
                      area.height / (lines + (lines - 1) * 0.22))
        VStack(spacing: interlaces ? -pip * 0.06 : pip * 0.22) {
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: interlaces ? -pip * 0.24 : pip * 0.28) {
                    ForEach(0..<rows[row], id: \.self) { column in
                        // Mirrored, not just tilted: a blade already leans, so tilting
                        // alone never closes the trellis. Parity runs on row plus column so
                        // ranks laid out one to a row still alternate down the card.
                        let flipped = interlaces && !(row + column).isMultiple(of: 2)
                        SuitMark(suit, size: pip, tint: tint)
                            .rotationEffect(.degrees(interlaces ? (flipped ? 12 : -12) : 0))
                            .scaleEffect(x: flipped ? -1 : 1)
                    }
                }
            }
        }
        .frame(width: area.width, height: area.height)
    }
}

/// Whatever belongs in the middle of a card: pips for numbers, a figure for the court.
struct CardCentre: View {
    @Environment(\.cardTheme) private var theme

    let card: Card
    var area: CGSize
    /// A court that fills the card is measured against the card, not the pip column.
    var cardWidth: CGFloat

    var body: some View {
        if card.rank.isFace {
            // A standing figure wants the card's height, not the pip column's width.
            FigureMark(rank: card.rank, suit: card.suit,
                       size: min(area.width * 1.34, area.height * 0.96),
                       cardWidth: cardWidth)
        } else {
            // Pips grow with a full-bleed court, or the eight would dwarf the seven.
            PipField(suit: card.suit, count: card.rank.rawValue,
                     area: theme.style.fillsTheCard
                         ? CGSize(width: area.width * 1.16, height: area.height * 1.08)
                         : area)
        }
    }
}
