import ScopaCore
import ScopaRewards
import SwiftUI

/// The cards: their art, their colours and their backs.
struct ShopDeck: View {
    @Bindable var store: TableStore
    let purse: PurseStore
    let counter: ShopCounter

    var body: some View {
        ShopSection(title: "Cards", subtitle: "The deck in your hand and on the table.", anchor: "cards") {
            shelf(.cardTheme, CardStyle.options)
            shelf(.cardSkin, CardSkin.options)
            backs
        }
    }

    /// One shelf per axis of the deck's look. The swatch swaps that axis into the equipped deck.
    private func shelf<Option: DeckOption>(_ kind: ShopItem.Kind, _ options: [Option]) -> some View {
        ShopShelf(kind) {
            ForEach(options) { option in
                let preview = option.applied(to: store.cardTheme)
                Button { pick(option) } label: {
                    Swatch(title: option.title, detail: option.explanation,
                           item: option.shopItem,
                           owned: purse.owns(option),
                           equipped: store.cardTheme == preview,
                           affordable: counter.affordable(option.shopItem),
                           justBought: counter.justBought(option.shopItem)) {
                        HStack(spacing: -20) {
                            CardView(card: Card(.knight, of: .coins), width: 44)
                            CardBack(width: 44).rotationEffect(.degrees(7))
                        }
                        .environment(\.cardTheme, preview)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .reactsToPick(store.cardTheme)
    }

    /// The back is shown on a real card: the ruling, the deck's colours and the broom together.
    private var backs: some View {
        ShopShelf(.cardBack) {
            ForEach(CardBackPattern.allCases) { pattern in
                let item = Cosmetics.item(for: pattern)
                Button { pick(pattern) } label: {
                    Swatch(title: pattern.name, detail: pattern.explanation, item: item,
                           owned: purse.owns(pattern),
                           equipped: store.cardBack == pattern,
                           affordable: counter.affordable(item),
                           justBought: counter.justBought(item),
                           earnedBy: ShopEarning.fromAlbum(item)) {
                        CardBack(width: 52)
                            .environment(\.cardBack, pattern)
                            .environment(\.cardTheme, store.cardTheme)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .reactsToPick(store.cardBack)
    }

    private func pick(_ option: some DeckOption) {
        counter.buyIfNeeded(option.shopItem) { store.cardTheme = option.applied(to: store.cardTheme) }
    }

    private func pick(_ pattern: CardBackPattern) {
        counter.buyIfNeeded(Cosmetics.item(for: pattern)) { store.cardBack = pattern }
    }
}

/// How a thing that is never sold is had, in the words its tile prints.
enum ShopEarning {
    /// Which album hands this over, for a tile that has no price because it has no sale.
    static func fromAlbum(_ item: ShopItem?) -> LocalizedStringKey? {
        Volume.awarding(item).map { volume -> LocalizedStringKey in "Finish the \(volume.title) album" }
    }
}
