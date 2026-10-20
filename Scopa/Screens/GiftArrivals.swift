import ScopaRewards
import SwiftUI

extension View {
    /// Cards between friends, for the whole app: the gifts handed down to the album's zoom,
    /// collected on launch and on every return to the front, and turned over in the lobby.
    func cardGifts(_ gifts: CardGifts, store: TableStore, purse: PurseStore, toaster: Toaster) -> some View {
        modifier(GiftArrivals(gifts: gifts, store: store, purse: purse, toaster: toaster))
    }
}

/// A card from a friend is told as a toast where it lands, held while a hand is played, and
/// turned over once the player is back in the lobby. Over the lobby, under any sheet on it,
/// so a page somebody is reading is never taken away from them.
private struct GiftArrivals: ViewModifier {
    let gifts: CardGifts
    let store: TableStore
    let purse: PurseStore
    let toaster: Toaster

    @Environment(\.scenePhase) private var scenePhase

    private var canCollect: Bool { store.isSignedIn && purse.isReady }

    func body(content: Content) -> some View {
        content
            .environment(gifts)
            .overlay { reveal }
            .animation(.easeInOut(duration: 0.35), value: shown?.id)
            .task(id: canCollect) { await collect() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await collect() } }
            }
            // What left the album is the ledger's, so it is read again whenever that grows:
            // on launch, after a gift, and when the other device's ledger arrives.
            .task(id: purse.purse.keys.count) { store.albumBook.noteDepartures(in: purse.purse) }
    }

    private var shown: GiftArrival? { store.route == .lobby ? gifts.arrivals.first : nil }

    @ViewBuilder private var reveal: some View {
        if let arrival = shown {
            GiftReveal(arrival: arrival, name: store.playerName) { gifts.showed(arrival) }
                .id(arrival.id)
                .transition(.opacity)
        }
    }

    private func collect() async {
        guard canCollect else { return }
        let locale = store.language.locale ?? .autoupdatingCurrent
        await gifts.collect(book: store.albumBook, purse: purse, locale: locale) { toast in
            if store.route == .table { toaster.hold(toast) } else { toaster.post(toast) }
        }
    }
}
