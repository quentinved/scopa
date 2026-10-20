import ScopaRewards
import SwiftUI

/// What the edge of every card is finished in.
///
/// The plain edge is the deck's own. Bordo d'oro is gold leaf, and there is one way to it:
/// filling Oro, the gold album. Madreperla is mother-of-pearl, a pearl frame and a light
/// sheen over the face, and the one way to it is filling Perla. Either goes with any deck,
/// the way a card back does. A build that knows no Madreperla reads it as the plain edge.
enum CardEdge: String, CaseIterable, Identifiable {
    case plain, oro, madreperla

    var id: String { rawValue }

    /// Where the choice is kept, and the name it travels between devices under.
    static let stored = "cardEdge"

    /// A name, and Italian in every language.
    var title: String {
        switch self {
        case .plain: "Liscio"
        case .oro: "Bordo d'oro"
        case .madreperla: "Madreperla"
        }
    }

    var explanation: LocalizedStringKey {
        switch self {
        case .plain: "The deck's own edge"
        case .oro: "Gold leaf on every card"
        case .madreperla: "Mother-of-pearl on every card"
        }
    }

    /// The foil album that pays it, and the only way to it.
    var album: FoilAlbum? {
        switch self {
        case .plain: nil
        case .oro: .oro
        case .madreperla: .perla
        }
    }

    /// What filling a foil album pays.
    static func prize(of album: FoilAlbum) -> CardEdge {
        switch album {
        case .oro: .oro
        case .perla: .madreperla
        }
    }

    /// Earned, never sold: the zero price lets the ledger record it and the shop refuse it.
    var shopItem: ShopItem? {
        guard self != .plain else { return nil }
        return ShopItem(id: ShopItem.ID("edge.\(rawValue)"), kind: .cardEdge, title: title,
                        detail: "card edge \(rawValue)", price: .zero, grade: .leggendario)
    }

    /// The edge a won item is, for the card that shows it.
    static func of(_ id: ShopItem.ID) -> CardEdge? {
        allCases.first { $0.shopItem?.id == id }
    }
}

extension EnvironmentValues {
    /// The edge the cards on this phone are finished in.
    @Entry var cardEdge: CardEdge = .plain
}

/// Gold leaf, as a gilded edge: laid in sheets, so it is not one even colour but runs from
/// deep to bright and catches the light at two corners.
enum GoldLeaf {
    static let sheet = AngularGradient(stops: [
        .init(color: Palette.goldDeep, location: 0),
        .init(color: Palette.gold, location: 0.07),
        .init(color: Palette.goldLight, location: 0.12),
        .init(color: Palette.cream, location: 0.145),
        .init(color: Palette.goldLight, location: 0.18),
        .init(color: Palette.gold, location: 0.29),
        .init(color: Palette.goldDeep, location: 0.38),
        .init(color: Palette.gold, location: 0.47),
        .init(color: Palette.goldLight, location: 0.6),
        .init(color: Palette.cream, location: 0.635),
        .init(color: Palette.goldLight, location: 0.67),
        .init(color: Palette.gold, location: 0.8),
        .init(color: Palette.goldDeep, location: 0.92),
        .init(color: Palette.goldDeep, location: 1),
    ], center: .center, angle: .degrees(-40))

    /// The same leaf laid flat across a board, for a cover or a bar: one glint, corner to corner.
    static let board = LinearGradient(stops: [
        .init(color: Palette.goldDeep, location: 0),
        .init(color: Palette.gold, location: 0.22),
        .init(color: Palette.goldLight, location: 0.4),
        .init(color: Palette.cream, location: 0.47),
        .init(color: Palette.goldLight, location: 0.54),
        .init(color: Palette.gold, location: 0.74),
        .init(color: Palette.goldDeep, location: 1),
    ], startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// A card's edge in gold leaf: the leaf, and a darker hairline where it meets the paper.
/// Two strokes and no animation, so a table of gilded cards costs what a plain one does.
struct GildedEdge: View {
    let width: CGFloat
    let radius: CGFloat
    /// Laid over a deck that paints its own frame, Mosaico's navy and gold first: the thin
    /// leaf was lost on it, and a gold card there read as a plain one.
    var wide = false

    private var band: CGFloat { wide ? max(2.4, width * 0.05) : max(1.8, width * 0.028) }

    var body: some View {
        if wide { framed } else { leaf }
    }

    private var leaf: some View {
        RoundedRectangle(cornerRadius: radius)
            .strokeBorder(GoldLeaf.sheet, lineWidth: band)
            .overlay {
                RoundedRectangle(cornerRadius: max(radius - band, 0))
                    .strokeBorder(Palette.goldDeep.opacity(0.55), lineWidth: max(0.5, band * 0.3))
                    .padding(band)
            }
            .allowsHitTesting(false)
    }

    /// Gold between two dark lines, for a face that is itself gold: Mosaico's courts stand
    /// on gold tesserae, and leaf laid on leaf vanished. The dark is what makes it read.
    private var framed: some View {
        let dark = max(1.2, width * 0.022)
        return RoundedRectangle(cornerRadius: radius)
            .strokeBorder(Palette.ink.opacity(0.9), lineWidth: dark)
            .overlay {
                RoundedRectangle(cornerRadius: max(radius - dark, 0))
                    .strokeBorder(GoldLeaf.sheet, lineWidth: band)
                    .padding(dark)
            }
            .overlay {
                RoundedRectangle(cornerRadius: max(radius - dark - band, 0))
                    .strokeBorder(Palette.ink.opacity(0.75), lineWidth: max(0.8, dark * 0.6))
                    .padding(dark + band)
            }
            .allowsHitTesting(false)
    }
}
