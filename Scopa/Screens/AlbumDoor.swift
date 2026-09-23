import ScopaRewards
import SwiftUI

/// The way into the album, from the lobby: a pill rather than a panel.
///
/// It was a full-width row with a sentence in it, one more slab on a lobby that already
/// had too many to tap. A pill that hugs what it says is the right weight for a place you
/// visit rather than a way to play. It still changes shape rather than a number: with packs
/// waiting it is gold and says so, with none it is quiet glass with how far the deck has
/// been collected. Both are one line, so the lobby does not jump when a game finishes.
///
/// The red count is on `unannounced` rather than on `waiting`: it is there to say *this is
/// new*, and once the album has been opened the packs are still there but the news is not.
struct AlbumDoor: View {
    let book: AlbumBook
    let action: () -> Void

    @Environment(\.lift) private var lift

    private var waiting: Int { book.waiting }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10 * lift) {
                PackArt(tier: book.nextTier, width: 20 * lift, alive: waiting > 0)
                    .opacity(waiting > 0 ? 1 : 0.6)
                    .grayscale(waiting > 0 ? 0 : 0.75)
                    .overlay(alignment: .topTrailing) { badge }
                    .frame(width: 26 * lift, height: 28 * lift)
                Text(waiting > 0
                     ? LocalizedStringKey("^[\(waiting) pack](inflect: true) to open")
                     : LocalizedStringKey("The album"))
                    .font(.system(size: 15 * lift, weight: waiting > 0 ? .bold : .semibold))
                    .foregroundStyle(waiting > 0 ? Palette.ink : Palette.onTable)
                    .lineLimit(1)
                Text(verbatim: "\(book.album.found)/\(Album.size)")
                    .font(.system(size: 13 * lift, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(waiting > 0 ? Palette.ink.opacity(0.7) : Palette.onTableSoft)
                progress
            }
            .padding(.leading, 12 * lift)
            .padding(.trailing, 14 * lift)
            .padding(.vertical, 7 * lift)
            .background {
                if waiting > 0 { Capsule().fill(Palette.goldSheen) }
            }
            .glassCapsule(interactive: true)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .animation(.spring(duration: 0.4, bounce: 0.2), value: waiting)
        .accessibilityLabel(Text("The album"))
        .accessibilityValue(waiting > 0
                            ? Text("^[\(waiting) pack](inflect: true) to open")
                            : Text("\(book.album.found) of \(Album.size) cards found"))
    }

    /// The unread count. Red rather than gold: gold is the tile, and a badge the same
    /// colour as what it sits on is not a badge.
    @ViewBuilder private var badge: some View {
        if book.unannounced > 0 {
            Text(verbatim: "\(book.unannounced)")
                .font(.system(size: 10 * lift, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Palette.cream)
                .padding(.horizontal, 5 * lift)
                .padding(.vertical, 1.5 * lift)
                .frame(minWidth: 17 * lift)
                .background {
                    Capsule()
                        .fill(Palette.terracotta)
                        .overlay { Capsule().strokeBorder(Palette.cream.opacity(0.9), lineWidth: 1.2) }
                }
                .offset(x: 2 * lift, y: -3 * lift)
                .transition(.scale(scale: 0.4).combined(with: .opacity))
        }
    }

    /// How full the album is, as a ring. Small enough to be furniture and precise enough
    /// to be worth glancing at, which a bar this short would not be.
    private var progress: some View {
        ZStack {
            Circle()
                .strokeBorder((waiting > 0 ? Palette.ink : Palette.onTableSoft).opacity(0.25),
                              lineWidth: 3 * lift)
            Circle()
                .trim(from: 0, to: max(book.album.fraction, 0.02))
                .stroke(waiting > 0 ? Palette.ink.opacity(0.85) : Palette.goldLight,
                        style: StrokeStyle(lineWidth: 3 * lift, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 18 * lift, height: 18 * lift)
    }
}
