import ScopaRewards
import SwiftUI

/// ORO on a plate of gold leaf, struck in ink, or PERLA on mother-of-pearl. The word stays
/// plain: the metal is the plate.
struct OroTag: View {
    var size: CGFloat = 17
    var album: FoilAlbum = .oro

    var body: some View {
        Text(verbatim: album.title.uppercased())
            .font(.system(size: size, weight: .heavy, design: .serif))
            .tracking(size * 0.18)
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(album == .oro ? Palette.ink : Nacre.graphite)
            .padding(.horizontal, size * 0.62)
            .padding(.vertical, size * 0.26)
            .background { plate }
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.28)
                    .strokeBorder(album == .oro ? Palette.goldDeep : Nacre.silverDeep, lineWidth: max(size * 0.08, 1))
            }
    }

    @ViewBuilder private var plate: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.28)
        if album == .oro {
            shape.fill(GoldLeaf.board)
        } else {
            // Pearl with a hairline of silver inside the rim, the frame the cards wear.
            shape.fill(Nacre.board)
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.2)
                        .strokeBorder(Nacre.silverDeep.opacity(0.5), lineWidth: max(size * 0.03, 0.5))
                        .padding(size * 0.14)
                }
        }
    }
}

/// ORO pressed onto a card the moment it turns over foil: down from above, a thump, once.
/// It lands after NEW when the card is new as well, so the two never arrive as one.
struct OroStamp: View {
    /// The card is new to its volume too, and NEW lands first.
    var afterNew = false
    var album: FoilAlbum = .oro

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tableFelt) private var felt
    @State private var landed = false

    var body: some View {
        OroTag(album: album)
            .shadow(color: felt.shade(0.45), radius: 6, y: 3)
            .scaleEffect(landed || reduceMotion ? 1 : 2.4)
            .rotationEffect(.degrees(landed || reduceMotion ? 8 : 24))
            .opacity(landed ? 1 : 0)
            .sensoryFeedback(Haptic.stamp, trigger: landed)
            .task { await land() }
    }

    private func land() async {
        let wait = reduceMotion ? 120 : (afterNew ? 640 : 340)
        try? await Task.sleep(for: .milliseconds(wait))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(duration: 0.3, bounce: 0.4)) { landed = true }
        Audio.shared.play(.shine)
    }
}

/// What a foil did, under the card: new in its album, or a spare and what it paid.
struct OroFoundLine: View {
    let found: Album.Found
    var album: FoilAlbum = .oro

    var body: some View {
        switch found {
        case .new:
            Text(album == .oro ? LocalizedStringKey("New in Oro") : "New in Perla")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(album == .oro ? Palette.goldLight : Nacre.glow)
        case .spare(_, let paid):
            HStack(spacing: 6) {
                Text(album == .oro ? LocalizedStringKey("Oro already has it") : "Perla already has it")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.onTableSoft)
                DenariMark(size: 14)
                Text(verbatim: "+\(paid.coins)")
                    .font(.system(size: 15, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.goldLight)
            }
        }
    }
}
