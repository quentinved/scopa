import ScopaRewards
import SwiftUI

/// The packs waiting on one shelf, at the top of the page that sells that shelf: a gold
/// slab with the next one on it, and a tap opens it.
///
/// Card packs wait in the album and the shop's own wait in the shop, so a pack is torn
/// where its kind is sold. Absent rather than greyed out when there are none: a disabled
/// button for a thing you cannot do yet is furniture.
struct WaitingPacks: View {
    let book: AlbumBook
    let shelf: PackTier.Shelf
    let open: () -> Void

    var body: some View {
        if let next = book.next(on: shelf) {
            Button(action: open) { slab(next, count: book.waiting(on: shelf)) }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Open"))
        }
    }

    private func slab(_ next: PackTier, count: Int) -> some View {
        HStack(spacing: 16) {
            PackArt(tier: next, width: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text("^[\(count) pack](inflect: true) waiting")
                    .font(.display(24))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(next == .mazzetto
                     ? "Three cards, whatever the deck gives you"
                     : "\(next.title) first · a gift")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Palette.ink.opacity(0.72))
            }
            Spacer(minLength: 0)
            Text("Open")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.cream)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background { Capsule().fill(Palette.ink.opacity(0.85)) }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: GlassRadius.panel).fill(Palette.goldSheen)
        }
    }
}

/// The shop's packs that were handed over rather than bought — the house's gift, the
/// wheel's gran premio, a code — waiting under the purse to be torn where they are sold.
struct ShopWaitingPacks: View {
    let book: AlbumBook
    let purse: PurseStore
    let till: PackTill

    var body: some View {
        if book.waiting(on: .shop) > 0 {
            VStack(alignment: .leading, spacing: 10) {
                Caption(text: "Waiting for you")
                WaitingPacks(book: book, shelf: .shop, open: open)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func open() {
        guard let opened = book.openOne(on: .shop, owned: purse.purse.owned) else { return }
        till.show(opened, purse: purse)
    }
}

extension PackTier.Shelf {
    /// Where a pack on this shelf waits once it is handed over, for the lines that say so.
    var waitsIn: LocalizedStringKey {
        switch self {
        case .album: "Waiting for you in the album"
        case .shop: "Waiting for you in the shop"
        }
    }
}
