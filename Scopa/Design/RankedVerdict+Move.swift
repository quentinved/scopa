import SwiftUI
import ScopaCore

extension RankedVerdict {
    /// A finished ranked game, as the ladder settled it.
    struct Move: Equatable {
        /// The rating before the game and after it. `after - before` is the change applied,
        /// not always the change earned: a league once reached is a floor.
        let before: Int
        let after: Int
        let won: Bool
        /// Wins in a row including this one, as the ladder counts them now.
        var streak: Int = 0
        /// A game against the house, part of the run unless the day's ration was spent.
        var isHouse = false
        /// A loss whose run a video carried on. See `KeepRunCard`.
        var wasSaved = false
        /// In Gran Maestro, the place it leaves you in among the season's Gran Maestri, and
        /// whether that place is a Campione's. Nil below it, or before the ladder has said.
        var place: Int? = nil
        var isCampione = false

        var change: Int { after - before }
        /// A run worth saying out loud: the second win of one is where it starts paying.
        var isOnARun: Bool { won && streak >= 2 && !keepsRun }
        /// A run a house game past the ration left alone, or a video carried past a loss, said
        /// so that a win is not read as the run growing, nor a loss as the run lost. Read off the result: a counted house
        /// win always pays and a counted house loss always ends the run.
        var keepsRun: Bool { (isHouse || wasSaved) && streak > 0 && (!won || change == 0) }
        /// A loss the floor swallowed.
        var isHeld: Bool { !won && change == 0 }
    }
}

extension RankedVerdict {
    /// The run, at the far end of the line under the bar: a flame a win, the newest
    /// catching as it is shown. Part of what the game paid is the run, and this says so.
    /// After a house game past the ration the flames are banked and the words say the run
    /// was kept.
    var runTag: some View {
        HStack(spacing: 5) {
            RunFlames(count: move.streak, lit: !move.keepsRun, catches: move.isOnARun)
            Group {
                if move.keepsRun {
                    Text("RUN OF \(move.streak) KEPT")
                } else {
                    Text("\(move.streak) IN A ROW")
                }
            }
            .font(.system(size: 10, weight: .heavy))
            .tracking(1.1)
            .foregroundStyle(move.keepsRun ? Palette.onTableSoft : Palette.goldLight)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
    }
}

#Preview("What a ranked game does") {
    ScrollView {
        VStack(spacing: 16) {
            // A win inside the division, a win that promotes, an ordinary loss, a loss
            // that demotes, and a loss the floor swallowed.
            RankedVerdict(move: .init(before: 430, after: 455, won: true))
            RankedVerdict(move: .init(before: 588, after: 613, won: true))
            RankedVerdict(move: .init(before: 430, after: 456, won: true, streak: 4))
            RankedVerdict(move: .init(before: 430, after: 455, won: true, streak: 3, isHouse: true))
            RankedVerdict(move: .init(before: 455, after: 443, won: false))
            RankedVerdict(move: .init(before: 705, after: 685, won: false))
            RankedVerdict(move: .init(before: 600, after: 600, won: false))
            // Into Gran Maestro, then a house win inside it as a Campione.
            RankedVerdict(move: .init(before: 1_788, after: 1_813, won: true))
            RankedVerdict(move: .init(before: 2_125, after: 2_140, won: true, isHouse: true, place: 4, isCampione: true))
        }
        .padding(20)
    }
    .background(TableGround())
}
