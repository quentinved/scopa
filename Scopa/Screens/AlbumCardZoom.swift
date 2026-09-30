import ScopaCore
import ScopaRewards
import SwiftUI

/// Where a card on the album's page can be drawn: in its own slot, or lifted into the middle.
/// The zoom moves between the two by trading one for the other, so the card that grows is
/// the card that was tapped rather than a second one fading in over it.
enum AlbumSpot: Hashable {
    case slot(Card)
    case lifted
}

/// One card lifted off the album's page to be looked at: drawn large in its volume's deck,
/// with its name and its rarity under it, and the page dimmed behind.
///
/// The spectacle is the card's, not the lettering's. A court or a seven gets the rays it
/// turned over with in the pack, the settebello its gold, and a numeral only the card
/// itself, because a numeral is not an event here any more than it was in the pack.
///
/// A card not found yet opens too, as the ghost the page shows: knowing what the gap is
/// waiting for is half the reason to keep opening packs.
struct AlbumCardZoom: View {
    let card: Card
    let volume: Volume
    let album: Album
    let page: Namespace.ID
    /// Called once the card is back in its slot.
    let onClose: () -> Void

    /// Up in the middle, or still (or again) in its slot on the page.
    @State private var lifted = false
    /// How far the card has been pushed: down puts it back, sideways leans it.
    @State private var drag: CGSize = .zero
    /// Where the band of light is across the card: -1 off one side, 1 off the other.
    @State private var sweep: CGFloat = -1
    @AccessibilityFocusState private var focused: Bool

    @Environment(\.locale) private var locale
    @Environment(\.tableFelt) private var felt
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The card's width in the middle. Big enough for a court figure's face to be read.
    static let width: CGFloat = 220

    private var rarity: Rarity { card.rarity }
    private var isFound: Bool { album.has(card) }
    /// How far a push down has got towards putting it back, 0 to 1.
    private var letGo: Double { min(max(drag.height, 0) / 320, 1) }

    var body: some View {
        ZStack {
            shade
            // Clear of the rays, which reach a little past the card's foot.
            VStack(spacing: 36) {
                Spacer(minLength: 0)
                stage
                caption
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(name)
            .accessibilityValue(Text(verbatim: Rarities.title(rarity, locale: locale) + ", ") + status)
            .accessibilityAction(named: Text("Close"), close)
            .accessibilityFocused($focused)
        }
        .contentShape(.rect)
        .onTapGesture(perform: close)
        .gesture(handling)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, close)
        .onAppear(perform: lift)
    }

    // MARK: The room

    /// The page, dimmed in the table's own shadow, with the rarity's colour pooled in the
    /// middle where the card is going.
    private var shade: some View {
        ZStack {
            Color.black.opacity(0.45)
            felt.shade(0.95)
            RadialGradient(colors: [Rarities.tint(rarity).opacity(pool), .clear],
                           center: .center, startRadius: 0, endRadius: 400)
        }
        .ignoresSafeArea()
        .opacity(lifted ? 1 - letGo * 0.6 : 0)
        .accessibilityHidden(true)
    }

    private var pool: Double {
        guard isFound else { return 0.06 }
        switch rarity {
        case .plain: return 0.08
        case .court: return 0.18
        case .prime: return 0.2
        case .settebello: return 0.28
        }
    }

    // MARK: The card

    /// The frame the card grows into, with the rays behind it and the card itself laid over
    /// it — pinned to its slot on the page until it is lifted, and to this frame after.
    private var stage: some View {
        Color.clear
            .frame(width: Self.width, height: Self.width * 1.5)
            .matchedGeometryEffect(id: AlbumSpot.lifted, in: page)
            .background {
                if lifted && isFound {
                    RarityBurst(count: Rarities.rays(rarity), tint: Rarities.tint(rarity),
                                size: Self.width * 1.7)
                }
            }
            .overlay {
                face
                    .matchedGeometryEffect(id: lifted ? AlbumSpot.lifted : .slot(card), in: page,
                                           isSource: false)
                    .rotation3DEffect(.degrees(lean.back), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                    .rotation3DEffect(.degrees(lean.side), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                    .offset(y: max(drag.height, 0))
                    .onTapGesture(perform: shine)
            }
    }

    /// Tipped back a little at rest, as a card held up to be looked at is; pushed, it leans
    /// the way the finger goes.
    private var lean: (back: Double, side: Double) {
        let rest = lifted && !reduceMotion ? 7.0 : 0
        let back = rest + min(max(-drag.height / 10, 0), 16)
        let side = min(max(drag.width / 6, -20), 20)
        return (back, side)
    }

    /// The card drawn at the size it is looked at, and shrunk to whatever frame it is given,
    /// so it can travel between the page and the middle without being redrawn on the way.
    private var face: some View {
        GeometryReader { proxy in
            drawn
                .frame(width: Self.width, height: Self.width * 1.5)
                .scaleEffect(proxy.size.width / Self.width)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(2 / 3, contentMode: .fit)
    }

    @ViewBuilder private var drawn: some View {
        if isFound {
            CardView(card: card, width: Self.width)
                .overlay { light }
                .overlay { rim }
                .shadow(color: felt.shade(lifted ? 0.55 : 0), radius: 22, y: 14)
        } else {
            MissingCard(card: card, width: Self.width, ghost: 0.22)
                // On the page the gap is laid on the cloth; up here there is only the
                // dimmed page behind it, so it brings a piece of cloth with it.
                .background {
                    RoundedRectangle(cornerRadius: Self.width * 0.12).fill(felt.plate())
                }
                .overlay { rim }
        }
    }

    /// The rarity's hairline from the page, drawn to the card's new size. The settebello's
    /// is gold and lit, as it was when it came out of the pack.
    @ViewBuilder private var rim: some View {
        if rarity > .plain {
            let lit = rarity == .settebello && isFound && lifted
            RoundedRectangle(cornerRadius: Self.width * 0.12)
                .strokeBorder(Rarities.tint(rarity).opacity(isFound ? 0.95 : 0.45),
                              lineWidth: rarity == .settebello ? 3 : 2.4)
                .shadow(color: lit ? Palette.goldLight.opacity(0.9) : .clear, radius: 10)
        }
    }

    /// A band of light crossing the card once as it comes up, and again at every tap: the
    /// card tipped towards a window. Brighter the rarer the card.
    private var light: some View {
        LinearGradient(colors: [.white.opacity(0), .white.opacity(gleam), .white.opacity(0)],
                       startPoint: .leading, endPoint: .trailing)
            .frame(width: Self.width * 0.5, height: Self.width * 2.4)
            .rotationEffect(.degrees(24))
            .offset(x: sweep * Self.width * 1.3)
            .frame(width: Self.width, height: Self.width * 1.5)
            .clipShape(RoundedRectangle(cornerRadius: Self.width * 0.12))
            .allowsHitTesting(false)
    }

    private var gleam: Double {
        switch rarity {
        case .plain: 0.22
        case .court: 0.34
        case .prime: 0.36
        case .settebello: 0.5
        }
    }

    // MARK: What it is

    /// The volume, the card's name, its rarity, and whether it is in the album.
    private var caption: some View {
        VStack(spacing: 10) {
            Caption(verbatim: "\(volume.numeral) · \(volume.title)")
            name
                .font(.display(32))
                .foregroundStyle(Palette.onTable)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            RarityTag(rarity, locale: locale, size: 12, filled: isFound && rarity > .plain)
            status
                .textCase(.uppercase)
                .font(.system(size: 12.5, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(isFound ? Palette.onTable : Palette.onTableSoft)
        }
        .opacity(lifted ? 1 - letGo * 1.6 : 0)
        .offset(y: lifted ? 0 : 18)
    }

    /// The card as the table names it: the rank in Italian, the suit in the player's own
    /// language, the same words VoiceOver reads for it in a hand.
    private var name: Text {
        Text("\(card.rank.italianName) of \(Text(card.suit.name))")
    }

    /// Found, found more than once, or still a gap.
    private var status: Text {
        let count = album.count(of: card)
        if count > 1 { return Text("Found \(count) times") }
        if count == 1 { return Text("Found", comment: "A card that is in the album") }
        return Text("Not found yet")
    }

    // MARK: Picking it up and putting it back

    /// Down puts it back, at the speed it was thrown; any other way only leans it.
    private var handling: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard lifted else { return }
                drag = value.translation
            }
            .onEnded { value in
                guard lifted else { return }
                if value.translation.height > 110 || value.predictedEndTranslation.height > 260 {
                    close()
                } else {
                    withAnimation(.spring(duration: 0.45, bounce: 0.4)) { drag = .zero }
                }
            }
    }

    private func lift() {
        Audio.shared.play(.pick)
        withAnimation(.spring(duration: 0.55, bounce: 0.26)) { lifted = true }
        focused = true
        guard isFound, !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.1).delay(0.3)) { sweep = 1 }
    }

    /// The light crosses back the way it came, which is what tipping a card does.
    private func shine() {
        guard isFound, lifted, !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.9)) { sweep = -sweep }
    }

    private func close() {
        guard lifted else { return }
        withAnimation(.spring(duration: 0.45, bounce: 0.16)) {
            lifted = false
            drag = .zero
        } completion: {
            onClose()
        }
    }
}
