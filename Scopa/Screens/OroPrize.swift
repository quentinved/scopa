import ScopaCore
import ScopaRewards
import SwiftUI

/// What a foil album pays, shown as the thing itself: its edge on two cards of your own
/// deck for the whole of it, Bordo d'oro for Oro and Madreperla for Perla, and a pack
/// waiting in the album for each suit of foils, a Bottega in Oro and a Velluto in Perla.
///
/// A pack rather than denari for a suit, because a pack goes back into the album: its cards
/// count for the open volume and each one is another chance at a foil still missing.
struct OroPrize: View {
    /// The pages of the album, Oro's unless `album` says otherwise.
    let oro: Album
    let purse: PurseStore
    var album: FoilAlbum = .oro

    @AppStorage(CardEdge.stored) private var edge: CardEdge = .plain
    @Environment(\.tableFelt) private var felt

    private var prize: CardEdge { .prize(of: album) }
    private var owned: Bool { purse.owns(prize.shopItem) }
    private var isGold: Bool { album == .oro }
    private var metal: AnyShapeStyle { isGold ? AnyShapeStyle(GoldLeaf.board) : AnyShapeStyle(Nacre.board) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Caption(text: isGold ? "What Oro pays" : "What Perla pays")
            HStack(spacing: 16) {
                preview
                    .frame(width: 96, height: 104)
                details
                Spacer(minLength: 0)
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: GlassRadius.panel)
                    .fill(felt.plate())
                    .overlay {
                        RoundedRectangle(cornerRadius: GlassRadius.panel)
                            .strokeBorder(isGold ? AnyShapeStyle(GoldLeaf.sheet) : AnyShapeStyle(Nacre.shell),
                                          lineWidth: 1.5)
                    }
            }
            HStack(spacing: 8) {
                ForEach(Suit.allCases, id: \.self) { suit in suitPrize(suit) }
            }
        }
    }

    /// Two cards of the deck in use, finished: the edge goes with any deck.
    private var preview: some View {
        ZStack {
            CardView(card: Card(.king, of: .cups), width: 54)
                .rotationEffect(.degrees(-9))
                .offset(x: -14)
            CardView(card: .settebello, width: 54)
                .rotationEffect(.degrees(7))
                .offset(x: 14, y: 4)
        }
        .environment(\.cardEdge, prize)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 5) {
            status
            Text("Card edge")
                .textCase(.uppercase)
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1)
                .foregroundStyle(Palette.onTableSoft)
            Text(verbatim: prize.title)
                .font(.display(28))
                .foregroundStyle(album.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(isGold ? LocalizedStringKey("Gold leaf round every card, with any deck. Never sold.")
                 : "Mother-of-pearl on every card, with any deck. Never sold.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
            if owned { wear }
        }
    }

    /// Won, or how many foils are still to find.
    private var status: some View {
        Group {
            if owned {
                Label("Yours", systemImage: "checkmark.seal.fill")
            } else {
                Label("Still missing: \(Album.size - oro.found)", systemImage: "lock.fill")
            }
        }
        .font(.system(size: 10.5, weight: .heavy))
        .textCase(.uppercase)
        .tracking(0.8)
        .foregroundStyle(owned ? Palette.ink : album.tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background {
            Capsule().fill(owned ? metal : AnyShapeStyle(Palette.ink.opacity(0.35)))
        }
    }

    private var wear: some View {
        Button { edge = edge == prize ? .plain : prize } label: {
            Text(edge == prize ? "Take it off" : "Wear it")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background { Capsule().fill(isGold ? AnyShapeStyle(Palette.goldSheen) : metal) }
                .foregroundStyle(Palette.ink)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: edge)
        .padding(.top, 4)
    }

    /// A suit's ace as a foil, the pack finishing it leaves, and how far in.
    private func suitPrize(_ suit: Suit) -> some View {
        let have = 10 - oro.missing(in: suit).count
        let done = oro.isComplete(suit)
        return VStack(spacing: 7) {
            CardView(card: Card(.ace, of: suit), width: 26)
                .foil(true, in: album)
                .environment(\.cardTheme, Volume.riviera.theme)
                .saturation(done ? 1 : 0.4)
                .frame(height: 40)
            pack
            progress(have)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .glassPanel(radius: GlassRadius.control)
        .overlay(alignment: .topTrailing) {
            if done {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(album.tint)
                    .padding(6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityValue(Text(verbatim: "\(have)/10, \(album.suitPack.title)"))
    }

    private var pack: some View {
        HStack(spacing: 4) {
            PackArt(tier: album.suitPack, width: 12)
            Text(verbatim: album.suitPack.title)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(album.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func progress(_ have: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<10, id: \.self) { index in
                Capsule()
                    .fill(index < have ? metal : AnyShapeStyle(felt.shade(0.55)))
                    .frame(height: 4)
            }
        }
    }
}
