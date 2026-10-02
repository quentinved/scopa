import SwiftUI
import ScopaCore
import ScopaRewards

/// One table on the map: a struck coin once won, terracotta where the road has reached,
/// dark and shut further on. The region's last table is a size up with a milled rim.
///
/// Sized to the disc, so the map can place it by its centre; the stars and the name hang
/// under it and your badge stands over the table you are at.
struct StageMedallion: View {
    let stage: CampaignStage
    let stars: Int
    let isLocked: Bool
    let isCurrent: Bool
    let isSelected: Bool
    /// The one bounce of a medallion that has just opened.
    let pops: Bool
    let you: SeatBadge?

    private var size: CGFloat { stage.isFinale ? 66 : 54 }
    private var won: Bool { stars > 0 }

    /// Room round the disc for what is flattened with it: its rings and shadow, and the
    /// widest name — "Fontana di Trevi" — hanging under it.
    private static let flat = EdgeInsets(top: 14, leading: 46, bottom: 48, trailing: 46)

    var body: some View {
        disc
            .frame(width: size, height: size)
            .scaleEffect(pops ? 1.12 : isSelected ? 1.06 : 1)
            .animation(.spring(duration: 0.45, bounce: 0.45), value: pops)
            .animation(.spring(duration: 0.3, bounce: 0.3), value: isSelected)
            .overlay(alignment: .bottom) { caption.fixedSize().offset(y: 40) }
            // Thirty of these ride the scroll with four shadows apiece. Flattened, each is one
            // texture the scroll only moves, rather than shadows composited every frame.
            .padding(Self.flat)
            .drawingGroup()
            .padding(-Self.flat)
            .overlay(alignment: .top) { you.offset(y: -30) }
            .contentShape(.circle.inset(by: -12))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "\(stage.number). \(stage.place)"))
            .accessibilityValue(isLocked ? Text("Locked") : Text("\(stars) of 3 stars"))
            .accessibilityAddTraits(.isButton)
    }

    private var disc: some View {
        ZStack {
            if isCurrent || isSelected {
                Circle().strokeBorder(Palette.cream.opacity(0.35), lineWidth: 1.5).padding(-9)
                Circle().strokeBorder(Palette.cream.opacity(0.7), lineWidth: 2).padding(-4)
            }
            Circle()
                .fill(fill)
                .shadow(color: Palette.ink.opacity(isLocked ? 0.2 : 0.5), radius: 4, y: 3)
            if stage.isFinale {
                Circle()
                    .strokeBorder(rim.opacity(0.9), style: StrokeStyle(lineWidth: 3, dash: [1.5, 2.5]))
                    .padding(2)
            }
            Circle().strokeBorder(rim, lineWidth: 1.5).padding(stage.isFinale ? 7 : 4)
            face
        }
    }

    @ViewBuilder private var face: some View {
        if isLocked {
            Image(systemName: "lock.fill")
                .font(.system(size: size * 0.3, weight: .semibold))
                .foregroundStyle(Palette.cream.opacity(0.45))
        } else {
            Text(verbatim: "\(stage.number)")
                .font(.display(size * 0.46))
                .foregroundStyle(won ? Palette.goldDeep : Palette.cream)
                .shadow(color: won ? Palette.goldLight.opacity(0.8) : .clear, radius: 0, y: 1)
        }
    }

    private var fill: AnyShapeStyle {
        if isLocked { return AnyShapeStyle(Palette.ink.opacity(0.55)) }
        if won {
            return AnyShapeStyle(RadialGradient(colors: [Palette.goldLight, Palette.gold, Palette.goldDeep],
                                                center: .init(x: 0.38, y: 0.32), startRadius: 2, endRadius: size * 0.7))
        }
        return AnyShapeStyle(LinearGradient(colors: [Palette.terracotta, Color(red: 0.58, green: 0.24, blue: 0.16)],
                                            startPoint: .top, endPoint: .bottom))
    }

    private var rim: Color {
        if isLocked { return Palette.cream.opacity(0.2) }
        return won ? Palette.goldDeep.opacity(0.7) : Palette.cream.opacity(0.75)
    }

    private var caption: some View {
        VStack(spacing: 2) {
            if !isLocked { StarRow(stars: stars, size: 11) }
            Text(verbatim: stage.place)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.onTable.opacity(isLocked ? 0.5 : 1))
                .shadow(color: Palette.ink.opacity(0.6), radius: 2, y: 1)
        }
        // A plate under the name, so the road passes behind it rather than through it.
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Palette.ink.opacity(isLocked ? 0.18 : 0.3), in: .rect(cornerRadius: 8))
    }
}

/// Three stars, the ones earned in gold.
struct StarRow: View {
    let stars: Int
    var size: CGFloat = 12

    var body: some View {
        HStack(spacing: size * 0.2) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < stars ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(index < stars ? Palette.goldLight : Palette.cream.opacity(0.35))
                    .scaleEffect(index < stars ? 1 : 0.9)
                    .animation(.spring(duration: 0.4, bounce: 0.5), value: stars)
            }
        }
        .shadow(color: Palette.ink.opacity(0.5), radius: 1.5, y: 1)
        .accessibilityHidden(true)
    }
}

/// The cartouche at the head of each region: its numeral, its name, the line under it,
/// and the stars won there.
struct RegionBanner: View {
    let region: CampaignRegion
    let stars: Int
    let isOpen: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(verbatim: region.numeral)
                .font(.display(17))
                .foregroundStyle(Palette.goldDeep)
                .frame(width: 38, height: 38)
                .background(Palette.goldSheen, in: .circle)
                .overlay { Circle().strokeBorder(Palette.goldDeep.opacity(0.5), lineWidth: 1).padding(3) }
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: region.title)
                    .font(.display(25))
                    .foregroundStyle(Palette.onTable)
                Text(region.tagline)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.onTableSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            if isOpen { tally } else { lock }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassPanel(tint: region.ground.deep.opacity(0.5))
        .opacity(isOpen ? 1 : 0.7)
        .accessibilityElement(children: .combine)
    }

    private var tally: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.goldLight)
            Text(verbatim: "\(stars)/\(CampaignRegion.perRegion * 3)")
                .font(.system(size: 14, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Palette.onTable)
        }
    }

    private var lock: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Palette.onTableSoft)
    }
}
