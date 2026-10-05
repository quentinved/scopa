import ScopaRewards
import SwiftUI

/// The table: the felt's colour and the cloth drawn across it.
struct ShopTable: View {
    @Bindable var store: TableStore
    let purse: PurseStore
    let counter: ShopCounter

    var body: some View {
        ShopSection(title: "Table", subtitle: "What the cards are played on. Only you see your table.",
                    anchor: "table") {
            felts
            cloths
        }
    }

    private var felts: some View {
        ShopShelf(.felt) {
            ForEach(TableFelt.allCases) { felt in
                let item = Cosmetics.item(for: felt)
                Button { pick(felt) } label: {
                    Swatch(title: felt.title, detail: felt.explanation, item: item,
                           owned: purse.owns(felt),
                           equipped: store.tableFelt == felt,
                           affordable: counter.affordable(item),
                           justBought: counter.justBought(item),
                           earnedBy: Streaks.milestone(for: felt).map { milestone -> LocalizedStringKey in
                               "Play \(milestone.days) days in a row"
                           }) {
                        FeltSwatch(felt: felt)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .reactsToPick(store.tableFelt)
    }

    /// Each cloth is previewed on the felt currently in use.
    private var cloths: some View {
        ShopShelf(.tapis) {
            ForEach(Tapis.allCases) { tapis in
                let item = Cosmetics.item(for: tapis)
                Button { pick(tapis) } label: {
                    Swatch(title: tapis.title, detail: tapis.explanation, item: item,
                           owned: purse.owns(tapis),
                           equipped: store.tapis == tapis,
                           affordable: counter.affordable(item),
                           justBought: counter.justBought(item)) {
                        TapisSwatch(tapis: tapis, felt: store.tableFelt)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .reactsToPick(store.tapis)
        .id("tapis")
    }

    private func pick(_ felt: TableFelt) {
        // The streak felt is priced at zero but must not be sold: the streak is the only way in.
        if Streaks.milestone(for: felt) != nil, !purse.owns(felt) {
            Audio.shared.play(.refused)
            return
        }
        counter.buyIfNeeded(Cosmetics.item(for: felt)) { store.tableFelt = felt }
    }

    private func pick(_ tapis: Tapis) {
        counter.buyIfNeeded(Cosmetics.item(for: tapis)) { store.tapis = tapis }
    }
}
