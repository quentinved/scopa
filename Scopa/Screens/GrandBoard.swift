import SwiftUI
import ScopaCore

/// Gran Maestro's own board, as the season's board shows it on its third tab: every Gran
/// Maestro of the season, best first, with their points, which are the one number the ladder
/// shows anywhere. The Campioni lead it under their own caption, each place struck on a plate.
struct GrandBoardRows: View {
    let board: Ladder.SeasonBoard
    /// The reader as a row of the board, for when their place is past the end of it.
    let mine: Ladder.SeasonBoard.Row?

    @Environment(\.locale) private var locale

    /// Gran Maestri only: a Worker from before the tier sends the whole season instead.
    private var top: [Ladder.SeasonBoard.Row] { board.top.filter(\.standing.isGrand) }
    private var hasCampioni: Bool { top.first?.campione == true }

    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(Array(top.enumerated()), id: \.element.id) { index, row in
                let place = row.place ?? index + 1
                if index == 0, hasCampioni { caption("Campioni") }
                if hasCampioni, row.campione != true, top[safe: index - 1]?.campione == true {
                    caption("Gran Maestri").padding(.top, 8)
                }
                GrandRow(place: place, row: row, isYou: board.you?.rank == place)
            }
            // A hundred rows come back. A reader placed below them gets their own, pinned.
            if let rank = board.you?.rank, rank > top.count, let mine {
                GrandRow(place: rank, row: mine, isYou: true)
                    .padding(.top, 6)
            }
            footnote
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private func caption(_ words: String) -> some View {
        Caption(verbatim: words)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
    }

    private var footnote: some View {
        VStack(spacing: 4) {
            Text("The season's \(Ranking.campioni) best Gran Maestri with \(Ranking.campionePoints) points or more are its Campioni.")
            if board.you?.rank == nil {
                Text("Past Maestro I, a ranked game this season puts you here.")
                    .foregroundStyle(Palette.goldLight.opacity(0.9))
            }
            if let days = board.daysLeft {
                Text(days == 0 ? "Season ends today" : "Season ends in \(days) days")
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Palette.onTableSoft)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 14)
    }
}

/// One Gran Maestro: place, medal and name, the season's wins and losses under the name, and
/// the points on the right where a division's bar would be.
struct GrandRow: View {
    let place: Int
    let row: Ladder.SeasonBoard.Row
    let isYou: Bool

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 8) {
            GrandPlace(place: place, isCampione: row.campione == true)
                .frame(width: 30)
            // Struck smaller than on the season's board: every row here wears the same medal,
            // and at full size its rays pressed on the plate and the name either side.
            LeagueMedal(league: row.standing.league, size: 25)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: row.name)
                    .font(.system(size: 15, weight: isYou ? .bold : .semibold))
                    .foregroundStyle(Palette.onTable)
                    .lineLimit(1)
                Text("\(row.wins) won · \(row.games - row.wins) lost")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Palette.onTableSoft)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(verbatim: GrandWords.points(row.standing.progress, locale: locale))
                .font(.system(size: 15, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Palette.onTable)
                .lineLimit(1)
                .fixedSize()
        }
        .ladderPanel(isYou: isYou)
        .accessibilityElement(children: .combine)
    }
}

/// A place on Gran Maestro's board. A Campione's is struck on a small plate of the league's
/// gold, so the title is told by the object and not by lit type; every other place is
/// written plainly, as on the season's board.
struct GrandPlace: View {
    let place: Int
    let isCampione: Bool

    private var metal: LeagueMetal { .granMaestro }

    var body: some View {
        if isCampione {
            Text(verbatim: "\(place)")
                .font(.system(size: 13, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .frame(width: 26, height: 21)
                .background { plate }
                .accessibilityLabel(Text(verbatim: "\(place), Campione"))
        } else {
            Text(verbatim: "\(place)")
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Palette.onTableSoft)
        }
    }

    /// Struck gold with a sunk line inside its edge, like the medal's face.
    private var plate: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(metal.sheen)
            .overlay {
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .strokeBorder(metal.dark.opacity(0.45), lineWidth: 0.75)
                    .padding(2)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(metal.dark.opacity(0.8), lineWidth: 1)
            }
    }
}

extension Ladder.SeasonBoard.Row {
    /// The reader, as a row of a board they are past the end of.
    init(you rank: Ladder.RankAnswer, name: String, place: Int) {
        self.init(id: rank.playerID ?? "you", name: name, rating: rank.rating, games: rank.games, wins: rank.wins,
                  standing: rank.standing, place: place, campione: rank.isCampione)
    }
}

#if DEBUG
extension Ladder.SeasonBoard {
    /// A dozen Gran Maestri, four of them Campioni, a Campione short of the points for it,
    /// and the reader placed past the end, for `-season grand`.
    static var grandSample: Self {
        let names = ["Giulia", "Marco", "Élodie", "Salvo", "Nonna Pina", "Luca",
                     "Chiara", "Théo", "Ada", "Renzo", "Bea", "Tommaso"]
        let points = [1_240, 860, 515, 302, 288, 240, 190, 150, 96, 64, 30, 0]
        let top = zip(names, points).enumerated().map { index, pair in
            let standing = Ranking.standing(for: Ranking.grandFloor + pair.1)
            return Row(id: "grand-\(index)", name: pair.0, rating: Ranking.grandFloor + pair.1, games: 90 - index * 5,
                       wins: 60 - index * 4,
                       standing: .init(league: standing.league.rawValue, division: standing.division,
                                       progress: standing.progress, step: standing.step, title: standing.title),
                       place: index + 1, campione: Ranking.isCampione(place: index + 1, points: pair.1))
        }
        return .init(season: "2026-10", seasonEndsAt: "2026-11-01T00:00:00.000Z", top: top,
                     you: .init(played: 23, rank: DebugLaunch.grandPlace ?? 17, percentile: nil))
    }
}
#endif
