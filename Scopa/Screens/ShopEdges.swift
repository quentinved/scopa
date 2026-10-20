import ScopaCore
import ScopaRewards
import SwiftUI

/// The card edges: the deck's own, Bordo d'oro, which only a full Oro hands over, and
/// Madreperla, which only a full Perla does. The shop shows them so they can be put on here
/// like anything else, and refuses to sell them.
struct EdgeShelf: View {
    let purse: PurseStore
    let counter: ShopCounter

    @AppStorage(CardEdge.stored) private var edge: CardEdge = .plain

    var body: some View {
        ShopShelf(.cardEdge) {
            ForEach(CardEdge.allCases) { option in
                let item = option.shopItem
                Button { counter.buyIfNeeded(item) { edge = option } } label: {
                    Swatch(title: option.title, detail: option.explanation, item: item,
                           owned: purse.owns(item),
                           equipped: edge == option,
                           affordable: counter.affordable(item),
                           justBought: counter.justBought(item),
                           earnedBy: option.album.map { "Finish the \($0.title) album" }) {
                        CardView(card: Card(.king, of: .coins), width: 44)
                            .environment(\.cardEdge, option)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .reactsToPick(edge)
        // What `-shelf cardEdge` scrolls to, for a screenshot, run out to its last tile.
        .defaultScrollAnchor(DebugLaunch.shelf == "cardEdge" ? .trailing : nil)
        .id("cardEdge")
    }
}
