import SwiftUI
import ScopaCore

/// Decks being drawn for the album's next volumes, before they become a `CardStyle`.
/// Maiolica (volume V) and Mosaico (VI) already have, and stay here so their sheets can be
/// laid beside the rest. `-deckDraft carnevale` shows one, `-deckDraft carnevale 2` its
/// second half.
enum DeckDraft: String, CaseIterable {
    case maiolica, mosaico, carnevale, intarsio
    case tarocchi
    case merletto

    @ViewBuilder func face(_ card: Card, width: CGFloat) -> some View {
        switch self {
        case .maiolica: MaiolicaFace(card: card, width: width)
        case .mosaico: MosaicoFace(card: card, width: width)
        case .carnevale: CarnevaleFace(card: card, width: width)
        case .intarsio: IntarsioFace(card: card, width: width)
        case .tarocchi: TarocchiFace(card: card, width: width)
        case .merletto: MerlettoFace(card: card, width: width)
        }
    }
}

/// Twenty cards of a draft deck and three of them large, for judging the drawing.
struct DeckDraftSheet: View {
    let draft: DeckDraft
    /// 1: coins and cups. 2: swords and clubs.
    var page = 1

    private var suits: [Suit] { page == 1 ? [.coins, .cups] : [.swords, .clubs] }
    private var showcase: [Card] {
        page == 1
            ? [.settebello, Card(.king, of: .coins), Card(.knave, of: .cups)]
            : [Card(.king, of: .swords), Card(.knight, of: .clubs), Card(.ace, of: .swords)]
    }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(verbatim: draft.rawValue.uppercased())
                .font(.display(32))
                .foregroundStyle(Palette.onTable)
            HStack(alignment: .top, spacing: 10) {
                ForEach(showcase, id: \.self) { framed($0, width: 108) }
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Deck.standard.filter { suits.contains($0.suit) }, id: \.self) { framed($0, width: 62) }
            }
            #if DEBUG
            if DebugLaunch.deckBench {
                if draft == .intarsio || draft == .tarocchi || draft == .merletto { IntarsioBench() } else { DeckBench() }
            }
            #endif
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { TableGround() }
    }

    private func framed(_ card: Card, width: CGFloat) -> some View {
        draft.face(card, width: width)
            .frame(width: width, height: width * 1.5)
            .clipShape(RoundedRectangle(cornerRadius: width * 0.12))
            .drawingGroup()
    }
}
