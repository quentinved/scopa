import SwiftUI
import ScopaCore
import ScopaRewards

/// One thing for sale: a preview, a name, and a price, or a tick once it is owned.
struct Swatch<Preview: View>: View {
    /// A proper name such as "Napoli", the same in every language.
    let title: String
    let detail: LocalizedStringKey
    let item: ShopItem?
    let owned: Bool
    let equipped: Bool
    let affordable: Bool
    var justBought: Bool? = nil
    /// How this one is had when it cannot be bought, such as "7-day streak". A key rather
    /// than a string: the wording inflects on the number, which only `Text` resolves.
    var earnedBy: LocalizedStringKey? = nil
    @ViewBuilder var preview: Preview

    /// How rare the thing is, which is a different question from what it costs and is why
    /// it is printed separately. An item with no grade of its own — an earned mark, say —
    /// shows none rather than showing `Comune`, because the shop has not graded it.
    private var grade: Grade? { item?.grade }

    var body: some View {
        VStack(spacing: 10) {
            preview
                .opacity(owned ? 1 : 0.75)
                .saturation(owned ? 1 : 0.6)
            VStack(spacing: 2) {
                Text(verbatim: title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(equipped ? Palette.cream : Palette.onTable)
                Text(detail)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
                    .foregroundStyle(equipped ? Palette.cream.opacity(0.85) : Palette.onTableSoft)
            }
            if let grade, grade > .comune {
                RarityTag(grade, size: 8.5, filled: grade == .leggendario)
            }
            tag
        }
        .frame(width: 128)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .glass(equipped ? .riviera(tint: Palette.terracotta.opacity(0.75), interactive: true) : .identity,
               in: .rect(cornerRadius: GlassRadius.control))
        // The dearer the grade, the more the tile is worth looking at: a common thing keeps
        // the plain hairline every tile has always had, and only the rest are dressed.
        .overlay {
            if !equipped {
                RoundedRectangle(cornerRadius: GlassRadius.control)
                    .strokeBorder(border, lineWidth: (grade ?? .comune) > .comune ? 1.5 : 1)
            }
        }
        .overlay {
            // A corner of light on the one grade there are four of in the whole shop.
            if grade == .leggendario {
                RoundedRectangle(cornerRadius: GlassRadius.control)
                    .fill(RadialGradient(colors: [Palette.goldLight.opacity(0.22), .clear],
                                         center: .topTrailing, startRadius: 0, endRadius: 96))
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if justBought == true {
                Gilding().id(justBought)
            }
        }
        .contentShape(.rect(cornerRadius: GlassRadius.control))
    }

    /// The hairline round an unequipped tile: its grade above common, and the old grey
    /// otherwise.
    private var border: AnyShapeStyle {
        guard let grade, grade > .comune else {
            return AnyShapeStyle(Palette.onTableSoft.opacity(0.28))
        }
        return Rarities.sheen(grade)
    }

    /// One line that always says where the tile stands: in use, owned, earned by playing, or a price.
    @ViewBuilder private var tag: some View {
        if equipped {
            Label("In use", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.cream)
        } else if owned {
            Label("Owned", systemImage: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
        } else if let earnedBy {
            EarnedTag(requirement: earnedBy)
        } else if let item {
            DenariLabel(amount: item.price, size: 13,
                        tint: affordable ? Palette.goldLight : Palette.onTableSoft)
                .opacity(affordable ? 1 : 0.7)
        }
    }
}

/// A thing that is never sold: a padlock, and what to do at the table to have it.
struct EarnedTag: View {
    let requirement: LocalizedStringKey

    var body: some View {
        VStack(spacing: 1) {
            Label("Earned", systemImage: "lock.fill")
                .font(.system(size: 9.5, weight: .heavy))
                .textCase(.uppercase)
                .tracking(0.6)
            Text(requirement)
                .font(.system(size: 11, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(Palette.goldLight)
    }
}

/// The table ground at swatch size, with a card on it so the tile reads against the felt behind it.
struct FeltSwatch: View {
    let felt: TableFelt

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(LinearGradient(colors: [felt.light, felt.base, felt.deep],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                RadialGradient(colors: [Palette.gold.opacity(0.22), .clear],
                               center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: 44)
            }
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.gold.opacity(0.35)) }
            .frame(width: 84, height: 58)
            .overlay { CardView(card: .settebello, width: 30).rotationEffect(.degrees(-6)) }
    }
}

/// The table in miniature, upright like the phone it is played on: the felt in use, the
/// cloth drawn the whole way round it, the opponent's cards at the top, two on the table
/// and a hand at the foot. A border cannot be judged from a corner of it.
struct TapisSwatch: View {
    let tapis: Tapis
    let felt: TableFelt
    var height: CGFloat = 132

    /// A phone's proportions, a little stouter so the tile is not a sliver.
    private var width: CGFloat { (height * 0.54).rounded() }

    var body: some View {
        ZStack {
            LinearGradient(colors: [felt.light, felt.base, felt.deep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Palette.gold.opacity(0.14), .clear],
                           center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: height * 0.5)
            // Drawn larger than a true miniature: at a phone's own proportion every rule
            // would be a fraction of a pixel.
            TapisWeave(tapis: tapis, scale: height / 520, finest: 0.8)
            dealt
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: height * 0.1, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: height * 0.1, style: .continuous)
                .strokeBorder(Palette.ink.opacity(0.55), lineWidth: 1.5)
        }
        .drawingGroup()
    }

    /// The game as it stands at the start of a hand, at the size the tile allows.
    private var dealt: some View {
        VStack(spacing: 0) {
            HStack(spacing: -height * 0.04) {
                CardBack(width: height * 0.09).rotationEffect(.degrees(-5))
                CardBack(width: height * 0.09).rotationEffect(.degrees(5))
            }
            .padding(.top, height * 0.1)
            Spacer(minLength: 0)
            HStack(spacing: height * 0.03) {
                CardView(card: .settebello, width: height * 0.12).rotationEffect(.degrees(-4))
                CardView(card: Card(.king, of: .cups), width: height * 0.12).rotationEffect(.degrees(3))
            }
            Spacer(minLength: 0)
            HStack(spacing: -height * 0.02) {
                ForEach(Array(Self.hand.enumerated()), id: \.offset) { index, card in
                    CardView(card: card, width: height * 0.13)
                        .rotationEffect(.degrees(Double(index - 1) * 6))
                        .offset(y: abs(Double(index - 1)) * height * 0.012)
                }
            }
            .padding(.bottom, height * 0.07)
        }
    }

    private static let hand: [Card] = [Card(.three, of: .swords), Card(.ace, of: .coins), Card(.five, of: .clubs)]
}

/// The companion on the cloth, awake. `nessuno` is the same tile with nothing on it.
struct CompanionSwatch: View {
    let companion: Companion
    let felt: TableFelt

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(LinearGradient(colors: [felt.light, felt.base, felt.deep],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.gold.opacity(0.35)) }
            .frame(width: 84, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .bottomLeading) {
                CardView(card: .settebello, width: 26)
                    .rotationEffect(.degrees(-8))
                    .offset(x: 5, y: -3)
            }
            .overlay(alignment: .trailing) {
                // Not interactive: a gesture here would swallow the tap on the buying button.
                CompanionView(companion: companion, size: 40, mood: .watching, interactive: false)
                    .offset(x: -3, y: 3)
            }
    }
}

/// A gold sweep across a tile, played once on appearance. Give it a fresh `.id` to replay it.
struct Gilding: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            LinearGradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: Palette.goldLight.opacity(0.75), location: 0.45),
                .init(color: .white.opacity(0.9), location: 0.5),
                .init(color: Palette.goldLight.opacity(0.75), location: 0.55),
                .init(color: .clear, location: 1.0),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            .frame(width: width * 0.7)
            .offset(x: phase * width * 1.6)
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
        .clipShape(RoundedRectangle(cornerRadius: GlassRadius.control))
        .onAppear {
            withAnimation(.easeOut(duration: 0.75)) { phase = 1 }
        }
    }
}

/// A flourish playing on a scrap of the cloth, over and over.
///
/// A still picture of confetti is a picture of dots, so the tile runs the real thing on a
/// loop at a fraction of its size. Restarted by a `.id` that changes on a timer, which is
/// the same trick `Gilding` uses to replay itself and needs no state per mote.
struct FlourishSwatch: View {
    let flourish: Flourish
    let felt: TableFelt

    @State private var run = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(LinearGradient(colors: [felt.light, felt.base, felt.deep],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.gold.opacity(0.35)) }
            .frame(width: 84, height: 58)
            .overlay {
                // Laid out on a table twice the tile's size and scaled down onto it, so the
                // cannons sit in the tile's own corners and the fireworks open inside it.
                FlourishView(flourish: flourish, origin: .center)
                    .frame(width: 168, height: 116)
                    .id(run)
                    .scaleEffect(0.5)
                    // A thumbnail at half size: thirty frames a second reads the same.
                    .environment(\.flourishFrameGap, 1.0 / 30.0)
            }
            .overlay(alignment: .bottomLeading) {
                CardBack(width: 22).rotationEffect(.degrees(-8)).offset(x: 6, y: -5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .task {
                guard !reduceMotion, flourish != .stendardo else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(FlourishView.length + 0.5))
                    guard !Task.isCancelled else { return }
                    run += 1
                }
            }
    }
}

/// A cheer, which cannot be shown. The tile draws what it is of and says to tap it.
struct CheerSwatch: View {
    let cheer: Cheer

    /// The cloth under it, so the glass is tinted with the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(felt.shade(0.45))
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.gold.opacity(0.35)) }
            .frame(width: 84, height: 58)
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: cheer.symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Palette.goldLight)
                    HStack(spacing: 3) {
                        Image(systemName: "play.fill").font(.system(size: 7, weight: .bold))
                        Text("Hear it").font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(Palette.onTableSoft)
                }
            }
    }
}
