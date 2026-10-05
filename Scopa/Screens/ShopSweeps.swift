import ScopaRewards
import SwiftUI

/// What happens when you sweep the table clean: what it looks like, and what you hear.
struct ShopSweeps: View {
    @Bindable var store: TableStore
    let purse: PurseStore
    let counter: ShopCounter

    var body: some View {
        ShopSection(title: "Scopa", subtitle: "Your moment when you sweep the table clean.", anchor: "sweeps") {
            flourishes
            cheers
        }
    }

    /// Each flourish is previewed running, on a scrap of the cloth. A still picture of
    /// confetti is a picture of dots.
    private var flourishes: some View {
        ShopShelf(.flourish) {
            ForEach(Flourish.allCases) { flourish in
                let item = Cosmetics.item(for: flourish)
                Button { counter.buyIfNeeded(item) { store.flourish = flourish } } label: {
                    Swatch(title: flourish.title, detail: flourish.explanation, item: item,
                           owned: purse.owns(flourish),
                           equipped: store.flourish == flourish,
                           affordable: counter.affordable(item),
                           justBought: counter.justBought(item),
                           earnedBy: ShopEarning.fromAlbum(item)) {
                        FlourishSwatch(flourish: flourish, felt: store.tableFelt)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .reactsToPick(store.flourish)
    }

    /// A cheer plays on every tap, bought or not: a sound nobody can hear before paying for
    /// it is a sound nobody buys. The purchase question comes up over it.
    private var cheers: some View {
        ShopShelf(.cheer) {
            ForEach(Cheer.allCases) { cheer in
                let item = Cosmetics.item(for: cheer)
                Button {
                    Audio.shared.play(cheer.sound)
                    counter.buyIfNeeded(item) { store.cheer = cheer }
                } label: {
                    Swatch(title: cheer.title, detail: cheer.explanation, item: item,
                           owned: purse.owns(cheer),
                           equipped: store.cheer == cheer,
                           affordable: counter.affordable(item),
                           justBought: counter.justBought(item)) {
                        CheerSwatch(cheer: cheer)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .reactsToPick(store.cheer)
    }
}
