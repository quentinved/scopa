import SwiftUI
import ScopaCore

/// The app icons in Settings: the classic one, the patron's that only the no-ads purchase
/// gives, the Visconti the album's last volume gives, and the metals ranked has given, set
/// from here as well as from the ladder's road.
struct IconPicker: View {
    /// Whose album says whether the Visconti icon is theirs.
    let book: AlbumBook

    /// The icon on the home screen, by its name in the asset catalogue. Nil for the classic.
    @State private var current = UIApplication.shared.alternateIconName
    @Environment(\.locale) private var locale
    @Environment(\.tableFelt) private var felt
    @Environment(AdsStore.self) private var ads

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            classicTile
            patronTile
            viscontiTile
            ForEach(LadderIcon.allCases) { ladderTile($0) }
        }
        .padding(12)
        // Bought on this Apple account and later refunded: the crest goes back with it.
        .task(id: ads.pass.isOwned) {
            await PatronIcon.returnIfUnowned(owned: ads.pass.isOwned)
            current = UIApplication.shared.alternateIconName
        }
        .task(id: ViscontiIcon.isEarned(book)) {
            await ViscontiIcon.returnIfUnearned(ViscontiIcon.isEarned(book))
            current = UIApplication.shared.alternateIconName
        }
    }

    private var classicTile: some View {
        tile(name: nil, earned: true, metal: Palette.goldLight) {
            LadderIconArt(icon: nil, size: 52)
        } label: {
            Text("Classic")
        } choose: {
            await LadderIcon.use(nil)
        }
    }

    /// Shown to everyone, locked until the purchase is owned, as the metals are until their league.
    private var patronTile: some View {
        tile(name: PatronIcon.assetName, earned: ads.pass.isOwned, metal: PatronLeaf.caption) {
            PatronIconArt(size: 52)
        } label: {
            if ads.pass.isOwned { Text("Patron") } else { Text("No ads") }
        } choose: {
            await PatronIcon.use()
        }
    }

    /// Shown to everyone, locked until the tenth volume is full.
    private var viscontiTile: some View {
        let earned = ViscontiIcon.isEarned(book)
        return tile(name: ViscontiIcon.assetName, earned: earned, metal: Palette.goldLight) {
            ViscontiIconArt(size: 52)
        } label: {
            if earned { Text(verbatim: ViscontiIcon.title) } else { Text("Finish album X") }
        } choose: {
            await ViscontiIcon.use()
        }
    }

    private func ladderTile(_ icon: LadderIcon) -> some View {
        tile(name: icon.assetName, earned: LadderPrizes.isEarned(icon.league),
             metal: LeagueMetal.league(icon.league.rawValue).light) {
            LadderIconArt(icon: icon, size: 52)
        } label: {
            Text(verbatim: icon.league.title(locale: locale))
        } choose: {
            await LadderIcon.use(icon)
        }
    }

    private func tile(name: String?, earned: Bool, metal: Color,
                      @ViewBuilder art: () -> some View, @ViewBuilder label: () -> some View,
                      choose: @escaping () async -> Void) -> some View {
        let inUse = current == name
        return Button {
            guard earned else { return Audio.shared.play(.refused) }
            guard !inUse else { return }
            Task {
                await choose()
                current = UIApplication.shared.alternateIconName
            }
        } label: {
            VStack(spacing: 6) {
                art()
                    .saturation(earned ? 1 : 0)
                    .opacity(earned ? 1 : 0.45)
                    .overlay(alignment: .bottomTrailing) { if !earned { LockGlyph().offset(x: 4, y: 4) } }
                Group { if inUse { Text("In use") } else { label() } }
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(inUse ? metal : Palette.onTableSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background { plate(chosen: inUse, metal: metal) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(inUse ? .isSelected : [])
    }

    private func plate(chosen: Bool, metal: Color) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(felt.shade(0.4))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(chosen ? metal : Palette.onTableSoft.opacity(0.15), lineWidth: chosen ? 1.5 : 1)
            }
    }
}
