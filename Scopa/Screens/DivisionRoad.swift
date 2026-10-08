import SwiftUI
import ScopaCore
import ScopaRewards

/// A division's bar with its road on it: a coin at each stop that pays denari and the pack
/// at the far end. A stop already passed this season keeps its coin, dimmed, so the bar
/// says what is behind as well as what is ahead.
struct DivisionRoad: View {
    @Environment(\.lift) private var lift
    @Environment(\.tableFelt) private var felt
    let rating: Int
    let metal: LeagueMetal

    private var progress: Double {
        Double(Ranking.standing(for: rating).progress) / Double(Ranking.pointsPerDivision)
    }

    /// The last division has no pack at its end: the ladder stops a point short of it.
    private var atTop: Bool { (Ranking.standing(for: rating).step + 1) * Ranking.pointsPerDivision > Ranking.top }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width - packRoom
            ZStack(alignment: .leading) {
                bar.frame(width: width)
                ForEach(1..<DivisionGifts.stopsPerDivision, id: \.self) { stop in
                    let at = Double(stop) / Double(DivisionGifts.stopsPerDivision)
                    DenariMark(size: 13 * lift)
                        .opacity(progress >= at ? 0.4 : 1)
                        .saturation(progress >= at ? 0.2 : 1)
                        .position(x: width * at, y: proxy.size.height / 2)
                }
                if !atTop {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 12 * lift, weight: .bold))
                        .foregroundStyle(Palette.goldLight)
                        .position(x: proxy.size.width - packRoom / 2, y: proxy.size.height / 2)
                }
            }
        }
        .frame(height: 14 * lift)
        .animation(.snappy, value: progress)
        .accessibilityHidden(true)
    }

    private var packRoom: CGFloat { atTop ? 0 : 18 * lift }

    private var bar: some View {
        Capsule()
            .fill(felt.shade(0.45))
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule().fill(metal.sheen)
                        .frame(width: max(proxy.size.width * min(max(progress, 0), 1), progress > 0 ? 6 : 0))
                }
            }
            .overlay { Capsule().strokeBorder(metal.dark.opacity(0.5), lineWidth: 0.5) }
            .frame(height: 6 * lift)
    }
}

/// What the next stop on the road pays and how far it is: "+30 in 15".
struct NextStop: View {
    @Environment(\.lift) private var lift
    let rating: Int

    var body: some View {
        if let (points, reward) = next {
            HStack(spacing: 4 * lift) {
                switch reward {
                case .denari(let amount):
                    DenariMark(size: 11 * lift)
                    Text("+\(amount.coins) in \(points)")
                case .pack:
                    Image(systemName: "gift.fill").font(.system(size: 10 * lift, weight: .bold))
                    Text("Pack in \(points)")
                }
            }
            .font(.system(size: 11.5 * lift, weight: .semibold))
            .foregroundStyle(Palette.goldLight.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }

    private var next: (Int, DivisionGifts.Reward)? {
        let stop = DivisionGifts.stop(for: rating) + 1
        guard stop * DivisionGifts.stride <= Ranking.top else { return nil }
        return (stop * DivisionGifts.stride - max(rating, 0), DivisionGifts.reward(at: stop))
    }
}

/// The division in plain numbers: the points in it out of a hundred, and how many more the
/// next division wants. At the very top there is no next one, and it says so.
struct DivisionPoints: View {
    @Environment(\.lift) private var lift
    @Environment(\.locale) private var locale
    let rating: Int

    var body: some View {
        HStack(spacing: 6 * lift) {
            Text("\(Ranking.standing(for: rating).progress)/\(Ranking.pointsPerDivision) points")
                .foregroundStyle(Palette.onTable)
            Spacer(minLength: 0)
            Text(verbatim: ahead)
                .foregroundStyle(Palette.onTableSoft)
        }
        .font(.system(size: 11.5 * lift, weight: .semibold))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var ahead: String {
        let next = (Ranking.standing(for: rating).step + 1) * Ranking.pointsPerDivision
        guard next <= Ranking.top else { return String(localized: "Top of the ladder", locale: locale) }
        let title = Ranking.standing(for: next).leagueTitle(locale: locale)
        return String(localized: "\(next - max(rating, 0)) more for \(title)", locale: locale)
    }
}
