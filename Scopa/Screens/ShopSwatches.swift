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

    @ViewBuilder private var tag: some View {
        if equipped {
            Text("In use")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.cream)
        } else if owned {
            Text("Yours")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
        } else if let earnedBy {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill").font(.system(size: 10, weight: .semibold))
                Text(earnedBy).font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Palette.goldLight)
        } else if let item {
            DenariLabel(amount: item.price, size: 13,
                        tint: affordable ? Palette.goldLight : Palette.onTableSoft)
                .opacity(affordable ? 1 : 0.7)
        }
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

/// The weave the table draws, over the felt in use, with a card so the tile is not a green
/// smudge on a green ground.
struct TapisSwatch: View {
    let tapis: Tapis
    let felt: TableFelt

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(LinearGradient(colors: [felt.light, felt.base, felt.deep],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay { TapisWeave(tapis: tapis, scale: 0.34) }
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.gold.opacity(0.35)) }
            .frame(width: 84, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            // Off to one side so the card does not cover the border a bordo or merletto draws.
            .overlay(alignment: .bottomTrailing) {
                CardView(card: .settebello, width: 26)
                    .rotationEffect(.degrees(-8))
                    .offset(x: -6, y: -4)
            }
    }
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
                // Scaled down rather than re-drawn small: the flourish is sized off the
                // space it is given, and a tile is a small table.
                FlourishView(flourish: flourish, origin: .center)
                    .id(run)
                    .scaleEffect(0.5)
            }
            .overlay(alignment: .bottomLeading) {
                CardBack(width: 22).rotationEffect(.degrees(-8)).offset(x: 6, y: -5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .task {
                guard !reduceMotion, flourish != .stendardo else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(2600))
                    guard !Task.isCancelled else { return }
                    run += 1
                }
            }
    }
}

/// A cheer, which cannot be shown. The tile draws what it is of and says to tap it.
struct CheerSwatch: View {
    let cheer: Cheer
    let owned: Bool

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
                    if owned {
                        HStack(spacing: 3) {
                            Image(systemName: "play.fill").font(.system(size: 7, weight: .bold))
                            Text("Hear it").font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(Palette.onTableSoft)
                    }
                }
            }
    }
}
