import ScopaCore
import SwiftUI

/// The face of a deck that paints its card whole — ground, frame, index and colours — in
/// place of the shared parts `CardArt` puts together and the colourway tints.
struct PaintedFace: View {
    let style: CardStyle
    let card: Card
    let width: CGFloat

    var body: some View {
        switch style {
        case .maiolica:
            MaiolicaFace(card: card, width: width)
                .clipShape(RoundedRectangle(cornerRadius: width * 0.12))
        case .mosaico:
            // Set inside its own rounded frame, so it needs no clip.
            MosaicoFace(card: card, width: width)
        case .carnevale:
            // Printed square to the edge; it strokes its own rounded edge on top.
            CarnevaleFace(card: card, width: width)
                .clipShape(RoundedRectangle(cornerRadius: width * 0.12))
        case .intarsio:
            // Clips itself to the card's corner, inside its own canvas.
            IntarsioFace(card: card, width: width)
        case .merletto:
            // Clips itself to the card's corner, inside its own canvas.
            MerlettoFace(card: card, width: width)
        case .tarocchi:
            // Clips itself to the card's corner, inside its own canvas.
            TarocchiFace(card: card, width: width)
        case .moderna, .classica, .antica, .litografia:
            EmptyView()
        }
    }
}

/// A suit in a painted deck's own colours.
struct PaintedSuit: View {
    let style: CardStyle
    let suit: Suit
    let size: CGFloat

    var body: some View {
        switch style {
        case .maiolica: MaiolicaSuit(suit: suit, size: size, unit: size * 2.6)
        case .mosaico: MosaicoSuit(suit: suit, size: size)
        case .carnevale: CarnevalePip(suit: suit, size: size)
        case .intarsio: IntarsioSuit(suit: suit, size: size)
        case .merletto: MerlettoSuit(suit: suit, size: size)
        case .tarocchi: TarocchiSuit(suit: suit, size: size)
        case .moderna, .classica, .antica, .litografia: EmptyView()
        }
    }
}
