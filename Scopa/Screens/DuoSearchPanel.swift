import SwiftUI

/// A ranked duo's waiting room while it looks for another pair, laid out as a search alone is
/// (see `OnlineProgressLine`): what it is looking for, the gold line running out over the
/// search, who else is in the line, and a few seconds in, the house. The leader's phone can
/// take it; the partner's phone is told that the leader can.
struct DuoSearchPanel: View {
    let store: TableStore
    let search: TableStore.DuoSearch

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.onTable)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !search.isOver {
                SearchCountdown(startedAt: search.startedAt, length: search.length, note: note)
            }
            if search.offersHouse { house.transition(.opacity.combined(with: .move(edge: .bottom))) }
        }
        .padding(14)
        .glassPanel(radius: GlassRadius.control)
        .animation(.easeInOut(duration: 0.3), value: search)
    }

    private var title: LocalizedStringKey {
        search.isOver ? "No other pair turned up" : "Looking for another pair"
    }

    /// Who else is in the line, when the queue could be asked.
    private var note: LocalizedStringKey {
        switch search.searching {
        case nil: "Another pair takes the other two chairs, or the house does."
        case 0?: "No other pair is searching yet. Any pair that starts a duo now meets you."
        default: "Another pair is searching. Pairing you now."
        }
    }

    @ViewBuilder private var house: some View {
        if search.leads {
            HouseOffer(store: store, isOver: search.isOver, asksToWait: search.isOver)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Rectangle()
                    .fill(Palette.gold.opacity(0.25))
                    .frame(height: 1)
                Text("\(search.partner) can choose to play the house instead.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.onTable)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
