import SwiftUI
import ScopaCore
import ScopaRewards

/// A division's bar with its road on it: a coin at each stop still ahead that pays denari,
/// and the pack at the far end. A passed coin leaves the bar: dimmed on the fill, it read
/// as a grey knob.
///
/// In Gran Maestro there are no divisions: the bar is the hundred points to the next stop of
/// `GrandGifts`, with that stop's coin or pack at its end.
struct DivisionRoad: View {
    @Environment(\.lift) private var lift
    @Environment(\.tableFelt) private var felt
    let rating: Int
    let metal: LeagueMetal

    private var grandNext: (points: Int, pack: PackTier?)? { GrandGifts.next(after: rating) }

    private var progress: Double {
        if let grandNext { return 1 - Double(grandNext.points) / Double(GrandGifts.stride) }
        return Double(Ranking.standing(for: rating).progress) / Double(Ranking.pointsPerDivision)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width - packRoom
            ZStack(alignment: .leading) {
                bar.frame(width: width)
                if grandNext == nil {
                    ForEach(1..<DivisionGifts.stopsPerDivision, id: \.self) { stop in
                        let at = Double(stop) / Double(DivisionGifts.stopsPerDivision)
                        if progress < at {
                            DenariMark(size: 13 * lift)
                                .position(x: width * at, y: proxy.size.height / 2)
                        }
                    }
                }
                end.position(x: proxy.size.width - packRoom / 2, y: proxy.size.height / 2)
            }
        }
        .frame(height: 14 * lift)
        .animation(.snappy, value: progress)
        .accessibilityHidden(true)
    }

    /// What the far end pays: a pack at the top of every division, and in Gran Maestro the
    /// next stop's coin, or its pack on every fifth.
    @ViewBuilder private var end: some View {
        if let grandNext, grandNext.pack == nil {
            DenariMark(size: 13 * lift)
        } else {
            Image(systemName: "gift.fill")
                .font(.system(size: 12 * lift, weight: .bold))
                .foregroundStyle(Palette.goldLight)
        }
    }

    private var packRoom: CGFloat { 18 * lift }

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
        if let grand = GrandGifts.next(after: rating) {
            return (grand.points, grand.pack.map(DivisionGifts.Reward.pack) ?? .denari(GrandGifts.denari))
        }
        let stop = DivisionGifts.stop(for: rating) + 1
        return (stop * DivisionGifts.stride - max(rating, 0), DivisionGifts.reward(at: stop))
    }
}

/// The division in one line, as the lobby says it: how far the next division is, then what
/// the next stop pays. Gran Maestro has its own line in `GrandPoints`.
struct DivisionPoints: View {
    @Environment(\.lift) private var lift
    @Environment(\.locale) private var locale
    let rating: Int

    var body: some View {
        HStack(spacing: 6 * lift) {
            Text(verbatim: Ranking.climb(from: rating, locale: locale))
                .font(.system(size: 11.5 * lift, weight: .semibold))
                .foregroundStyle(Palette.onTable)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            NextStop(rating: rating)
        }
    }
}

/// Gran Maestro in plain numbers: its points and its place in the house voice, then the
/// laurel for a Campione, or what a place in the top ten still wants to be one.
struct GrandPoints: View {
    @Environment(\.lift) private var lift
    @Environment(\.locale) private var locale
    let points: Int
    let place: Int?
    let campione: Bool

    init(points: Int, place: Int?, campione: Bool) {
        self.points = points
        self.place = place
        self.campione = campione
    }

    /// From a ladder answer, which counts the points the way the Worker does where it can.
    init?(_ rank: Ladder.RankAnswer) {
        guard let points = rank.grand?.points ?? Ranking.standing(for: rank.rating).points else { return nil }
        self.init(points: points, place: rank.grand?.place, campione: rank.isCampione)
    }

    var body: some View {
        HStack(spacing: 6 * lift) {
            Text(verbatim: GrandWords.line(points: points, place: place, locale: locale))
                .textCase(.uppercase)
                .font(.system(size: 12.5 * lift, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Palette.onTable)
            Spacer(minLength: 0)
            if campione {
                CampioneTag(size: 11 * lift)
            } else if let wanted {
                Text(verbatim: wanted)
                    .font(.system(size: 11.5 * lift, weight: .semibold))
                    .foregroundStyle(Palette.onTableSoft)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    /// A place in the top ten without the points for the title yet: how many more it wants.
    private var wanted: String? {
        guard let place, place <= Ranking.campioni, points < Ranking.campionePoints else { return nil }
        return String(localized: "\(Ranking.campionePoints - points) more for Campione", locale: locale)
    }
}
