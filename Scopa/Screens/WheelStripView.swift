import ScopaRewards
import SwiftUI

/// Under the wheel: what the last day's turns paid other players, friends first, and how
/// often the gran premio came up this week. Just who won what, never a tally or a rank.
struct WheelStripView: View {
    let strip: Ladder.WheelStrip

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("Today at the wheel")
                    .font(.system(size: 12, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(Palette.goldLight)
                if strip.jackpotsThisWeek > 0 {
                    Text("Gran premio won \(strip.jackpotsThisWeek) times this week")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.onTableSoft)
                }
            }
            if !strip.turns.isEmpty {
                VStack(spacing: 10) {
                    ForEach(strip.turns) { turn in
                        row(turn)
                    }
                }
                .padding(16)
                .glassPanel(radius: GlassRadius.control)
            }
        }
    }

    private func row(_ turn: Ladder.WheelStrip.Turn) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(verbatim: turn.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.onTable)
                        .lineLimit(1)
                    if turn.friend {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Palette.goldLight)
                            .accessibilityLabel(Text("Friend"))
                    }
                }
                Text(turn.at.formatted(.relative(presentation: .named).locale(locale)))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.onTableSoft)
            }
            Spacer(minLength: 8)
            prize(turn.prize)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func prize(_ prize: Ladder.WheelStrip.Prize) -> some View {
        switch prize {
        case .denari(let amount):
            DenariLabel(amount: Denari(amount), size: 14)
        case .pack:
            Text("\(Self.packTier.title) pack").stripPrize
        case .item(let id):
            if let item = Cosmetics.catalogue[ShopItem.ID(id)] {
                Text(verbatim: item.title).stripPrize.lineLimit(1)
            } else {
                Text("Something from the shop").stripPrize
            }
        case .jackpot:
            Text(verbatim: "Gran premio!")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Palette.goldLight)
        }
    }

    /// The pack on the wheel's own slice: a turn that paid nothing at all paid this.
    private static var packTier: PackTier {
        for segment in DailyWheel.segments {
            if case .pack(let tier) = segment.prize { return tier }
        }
        return .bottega
    }
}

private extension Text {
    var stripPrize: Text {
        font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.onTable)
    }
}
