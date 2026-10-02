import SwiftUI
import ScopaCore

/// The house, offered in the middle of a ranked search: what a game against it would pay
/// today, a way to sit down with it now, and a way to keep waiting for somebody real.
///
/// The price is `RankedStakes.houseOdds`, the same sum the banner over the deal shows, so
/// the offer cannot promise what the table then does not pay.
struct HouseOffer: View {
    let store: TableStore
    /// The search has run its length. Its own header says so, so the card does not.
    let isOver: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(Palette.gold.opacity(0.25))
                .frame(height: 1)
            if !isOver {
                Text("Nobody is free to play just now")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.onTable)
            }
            pays
            Button("Play the house") { store.playTheHouse() }
                .buttonStyle(FilledButtonStyle(minHeight: 48))
                .padding(.top, 2)
            Button("Keep looking") { store.keepLooking() }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.onTableSoft)
                .frame(maxWidth: .infinity, minHeight: 32)
        }
    }

    /// What the ladder would make of a game against the house. Nil until the Worker has said
    /// where this player stands.
    private var odds: RankedStakes.Odds? {
        guard let rank = store.rank else { return nil }
        return RankedStakes.houseOdds(mine: rank.rating, theirs: nil, counting: rank.house?.isCounting ?? true,
                                      win: rank.house?.win ?? Ranking.houseWin,
                                      loss: rank.house?.loss ?? Ranking.houseLoss)
    }

    @ViewBuilder private var pays: some View {
        if let odds, odds.isSpent {
            note("No house games left on the ladder today, so this one would be just for fun.")
        } else if let odds {
            if odds.isSafe {
                note("Counts for the ladder: +\(odds.win) to win, and your league holds if you lose.")
            } else {
                note("Counts for the ladder: +\(odds.win) to win, −\(abs(odds.loss)) to lose.")
            }
            allowance
        } else {
            note("A win counts for the ladder, up to \(Ranking.houseGamesPerDay) house games a day.")
        }
    }

    /// The day's ration, in the words the league panel uses for it.
    @ViewBuilder private var allowance: some View {
        if let house = store.rank?.house {
            HStack(spacing: 5) {
                Image(systemName: "hourglass")
                Text("\(max(house.perDay - house.playedToday, 0)) of \(house.perDay) house games left today")
            }
            .font(.system(size: 12))
            .foregroundStyle(Palette.onTableSoft)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }

    private func note(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Palette.onTableSoft)
            .fixedSize(horizontal: false, vertical: true)
    }
}
