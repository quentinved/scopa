import SwiftUI
import ScopaCore

/// The Maiolica deck's face: a painted tile from Vietri or Caltagirone. Tin-white ground
/// with a fine craquelure, a cobalt edge, a lemon garland round the band, and the pips or
/// the court in the same loose brush. The index sits in a stepped corner block, cobalt.
struct MaiolicaFace: View {
    let card: Card
    let width: CGFloat

    private var height: CGFloat { width * 1.5 }
    private var isSettebello: Bool { card == .settebello }
    private var isCoins: Bool { card.suit == .coins }
    /// The garland and rosettes. Below this width the band is left plain.
    private var dressed: Bool { width >= 56 }
    private var seed: Int { (Suit.allCases.firstIndex(of: card.suit) ?? 0) * 11 + card.rank.rawValue }
    /// Coins take the gold on their line, as every other deck edges them.
    private var lineTint: Color { isCoins ? MaiolicaPaint.ochre : MaiolicaPaint.cobalt }
    private var lineWidth: CGFloat { max(0.7, width * 0.014) }

    var body: some View {
        ZStack {
            ground
            if dressed { garland }
            MaiolicaBrushed(shape: MaiolicaFieldLine(unit: width), wander: width * 0.004, seed: seed &+ 2)
                .stroke(lineTint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            centre
            corner
            corner.rotationEffect(.degrees(180))
            rim
        }
        .frame(width: width, height: height)
    }

    // MARK: Ground and frame

    private var ground: some View {
        ZStack {
            Rectangle().fill(MaiolicaPaint.tin)
            crackle
        }
    }

    private var crackle: some View {
        MaiolicaCrackle(cell: width * 0.12, seed: seed)
            .stroke(MaiolicaPaint.manganese.opacity(dressed ? 0.11 : 0.07), lineWidth: max(0.3, width * 0.004))
    }

    private var garland: some View {
        let hair = max(0.35, width * 0.005)
        return ZStack {
            MaiolicaGarland(part: .stem, unit: width)
                .stroke(MaiolicaPaint.copper, lineWidth: max(0.5, width * 0.008))
            MaiolicaGarland(part: .leaves, unit: width).fill(MaiolicaPaint.copper)
            MaiolicaGarland(part: .lemons, unit: width).fill(MaiolicaPaint.lemon)
            MaiolicaGarland(part: .lemons, unit: width).stroke(MaiolicaPaint.ochre, lineWidth: hair)
            MaiolicaRosettes(part: .leaves, unit: width).fill(MaiolicaPaint.copper)
            MaiolicaRosettes(part: .petals, unit: width).fill(MaiolicaPaint.cobalt)
            MaiolicaRosettes(part: .petals, unit: width).stroke(MaiolicaPaint.cobaltDeep, lineWidth: hair)
            MaiolicaRosettes(part: .eyes, unit: width).fill(MaiolicaPaint.saffron)
        }
    }

    /// The cobalt edge, saffron on the settebello, pooled darker along its freehand side.
    private var rim: some View {
        let tint: MaiolicaTint = isSettebello ? .saffron : .cobalt
        let inset = width * MaiolicaFrame.rim
        return ZStack {
            MaiolicaRim(unit: width).fill(tint.body, style: FillStyle(eoFill: true))
            MaiolicaBrushed(shape: RoundedRectangle(cornerRadius: width * 0.075), wander: width * 0.006, seed: 5)
                .stroke(tint.pool.opacity(0.55), lineWidth: max(0.5, width * 0.012))
                .padding(inset)
        }
    }

    /// The top-left block and its index. A court gets a tin patch so the figure passes
    /// behind the number rather than through it.
    private var corner: some View {
        ZStack {
            if card.rank.isFace {
                MaiolicaBlock(unit: width, patch: true).fill(MaiolicaPaint.tin)
                crackle.clipShape(MaiolicaBlock(unit: width, patch: true))
            }
            MaiolicaBrushed(shape: MaiolicaBlock(unit: width, patch: false), wander: width * 0.004, seed: seed &+ 4)
                .stroke(lineTint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            index
        }
        .frame(width: width, height: height)
    }

    /// The number centred in its block. Placed by hand rather than stacked, since the text
    /// box carries ascender and descender room the block has no space for.
    private var index: some View {
        // A six and a nine read as each other upside down, so they get a rule under them.
        let ruled = card.rank == .six || card.rank == .knight
        return ZStack {
            Text(verbatim: card.rank.label)
                .font(.display(width * 0.26))
                .foregroundStyle(MaiolicaPaint.cobaltDeep)
                .position(x: width * 0.184, y: width * (ruled ? 0.165 : 0.180))
            if ruled {
                Capsule()
                    .fill(MaiolicaPaint.cobaltDeep)
                    .frame(width: width * 0.13, height: max(1, width * 0.018))
                    .position(x: width * 0.184, y: width * 0.257)
            }
        }
    }

    // MARK: Centre

    @ViewBuilder private var centre: some View {
        if card.rank.isFace {
            MaiolicaCourt(rank: card.rank, suit: card.suit, width: width)
        } else if isSettebello {
            settebello
        } else if card.rank == .ace {
            ace
        } else {
            MaiolicaPips(suit: card.suit, count: card.rank.rawValue,
                         area: CGSize(width: width * 0.60, height: width * 0.94), unit: width)
        }
    }

    /// An ace stands between two lemon boughs.
    private var ace: some View {
        ZStack {
            bough.position(x: width * 0.32, y: width * 0.865)
            bough.scaleEffect(x: -1).position(x: width * 0.68, y: width * 0.865)
            MaiolicaSuit(suit: card.suit, size: width * 0.64, unit: width, seed: 1)
                .position(x: width * 0.5, y: width * 0.75)
        }
        .frame(width: width, height: height)
    }

    private var bough: some View {
        ZStack {
            MaiolicaBough(part: .stem, unit: width)
                .stroke(MaiolicaPaint.copperDeep, style: StrokeStyle(lineWidth: max(0.8, width * 0.017), lineCap: .round))
            MaiolicaBough(part: .leaves, unit: width).fill(MaiolicaPaint.copper)
            MaiolicaBough(part: .leaves, unit: width).stroke(MaiolicaPaint.copperDeep, lineWidth: max(0.35, width * 0.005))
            MaiolicaBough(part: .lemons, unit: width).fill(MaiolicaPaint.lemon)
            MaiolicaBough(part: .lemons, unit: width).stroke(MaiolicaPaint.ochre, lineWidth: max(0.4, width * 0.007))
        }
        .frame(width: width * 0.36, height: width * 0.53)
    }

    /// The settebello: its seven coins on a cobalt roundel inside a Della Robbia wreath, with
    /// its name on a ribbon across the foot, and the card's edge run in saffron.
    private var settebello: some View {
        ZStack {
            MaiolicaGlazed(shape: Ellipse(), tint: .cobalt, unit: width, line: MaiolicaPaint.cobaltDeep, seed: 9)
                .frame(width: width * 0.60, height: width * 0.70)
            wreath.frame(width: width * 0.66, height: width * 0.76)
            MaiolicaPips(suit: .coins, count: 7, area: CGSize(width: width * 0.54, height: width * 0.54), unit: width)
            if width >= 70 { caption.offset(y: width * 0.39) }
        }
        .position(x: width * 0.5, y: width * 0.72)
    }

    private var wreath: some View {
        let hair = max(0.35, width * 0.005)
        return ZStack {
            MaiolicaWreath(part: .leaves, unit: width).fill(MaiolicaPaint.copper)
            MaiolicaWreath(part: .leaves, unit: width).stroke(MaiolicaPaint.copperDeep, lineWidth: hair)
            MaiolicaWreath(part: .lemons, unit: width).fill(MaiolicaPaint.lemon)
            MaiolicaWreath(part: .lemons, unit: width).stroke(MaiolicaPaint.ochre, lineWidth: hair * 1.4)
        }
    }

    private var caption: some View {
        ZStack {
            MaiolicaGlazed(shape: MaiolicaScroll(tails: true), tint: .saffron, unit: width, seed: 3)
            MaiolicaGlazed(shape: MaiolicaScroll(tails: false), tint: .tin, unit: width,
                           line: MaiolicaPaint.cobalt, seed: 4)
            Text(verbatim: "SETTEBELLO")
                .font(.system(size: width * 0.068, weight: .bold, design: .serif))
                .tracking(width * 0.006)
                .foregroundStyle(MaiolicaPaint.cobaltDeep)
        }
        .frame(width: width * 0.60, height: width * 0.10)
    }
}
