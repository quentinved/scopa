import ScopaCore
import ScopaRewards
import SwiftUI

/// A thing off the shelves, drawn at the size a card is drawn at so a pack of cards and a
/// felt read as the same kind of prize.
///
/// The preview is the real cosmetic wherever there is one to draw — the actual felt, the
/// actual badge, the actual deck — because a name on a plate is a receipt and the thing
/// itself is a reward.
struct WonItemCard: View {
    let item: ShopItem
    /// Whose it now is, so a won mark or livery is previewed wearing their own initial
    /// rather than a placeholder.
    var name: String = "?"

    /// The cloth under it, so the glass is tinted with the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        VStack(spacing: 14) {
            preview
                .frame(height: 104)
            VStack(spacing: 3) {
                Text(verbatim: item.title)
                    .font(.display(26))
                    .foregroundStyle(Palette.onTable)
                Text(Cosmetics.title(of: item.kind))
                    .font(.system(size: 12, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.onTableSoft)
            }
        }
        .padding(22)
        .frame(width: 236)
        // All but opaque: the rays are behind this card, and at anything translucent they
        // show through the tile and turn the prize into a smear.
        .background {
            RoundedRectangle(cornerRadius: GlassRadius.panel)
                .fill(felt.shade(0.96))
        }
        .overlay {
            RoundedRectangle(cornerRadius: GlassRadius.panel)
                .strokeBorder(Rarities.sheen(item.grade), lineWidth: 2)
        }
    }

    @ViewBuilder private var preview: some View {
        switch item.kind {
        case .felt:
            if let felt = Cosmetics.felt(of: item.id) { FeltSwatch(felt: felt) }
        case .tapis:
            if let tapis = Tapis.allCases.first(where: { Cosmetics.item(for: $0)?.id == item.id }) {
                TapisSwatch(tapis: tapis, felt: .riviera, height: 112)
            }
        case .mark:
            if let mark = Cosmetics.mark(of: item.id) {
                SeatBadge(name: name, tint: Palette.seat(0), size: 72, mark: mark)
            }
        case .cornice:
            if let cornice = Cornice.allCases.first(where: { Cosmetics.item(for: $0)?.id == item.id }) {
                SeatBadge(name: name, tint: Palette.seat(0), size: 60, cornice: cornice)
            }
        case .companion:
            if let companion = Companion.allCases.first(where: { Cosmetics.item(for: $0)?.id == item.id }) {
                CompanionSwatch(companion: companion, felt: .riviera)
            }
        case .livery:
            if let livery = Cosmetics.livery(of: item.id) {
                SeatBadge(name: name, tint: Palette.seat(0), size: 72, livery: livery)
            }
        case .cardBack:
            if let back = CardBackPattern.allCases.first(where: { Cosmetics.item(for: $0)?.id == item.id }) {
                CardBack(width: 68).environment(\.cardBack, back)
            }
        case .cardTheme, .cardSkin:
            deckPreview
        case .flourish:
            if let flourish = Cosmetics.flourish(of: item.id) {
                FlourishSwatch(flourish: flourish, felt: .riviera)
            }
        case .cheer:
            Image(systemName: Cosmetics.cheer(of: item.id)?.symbol ?? "speaker.wave.2.fill")
                .font(.system(size: 66, weight: .semibold))
                .foregroundStyle(Rarities.tint(item.grade))
        case .song:
            Image(systemName: "music.note")
                .font(.system(size: 66, weight: .semibold))
                .foregroundStyle(Rarities.tint(item.grade))
        case .reactions:
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 62, weight: .semibold))
                .foregroundStyle(Rarities.tint(item.grade))
        }
    }

    /// The won deck, drawn in its own art rather than in whatever is equipped.
    @ViewBuilder private var deckPreview: some View {
        let theme = wonTheme
        HStack(spacing: -22) {
            CardView(card: Card(.knight, of: .coins), width: 60)
            CardBack(width: 60).rotationEffect(.degrees(8))
        }
        .environment(\.cardTheme, theme)
    }

    private var wonTheme: CardTheme {
        if let style = CardStyle.options.first(where: { $0.shopItem?.id == item.id }) {
            return CardTheme(style: style, skin: .riviera)
        }
        if let skin = CardSkin.options.first(where: { $0.shopItem?.id == item.id }) {
            return CardTheme(style: .moderna, skin: skin)
        }
        return CardTheme(style: .moderna, skin: .riviera)
    }
}
