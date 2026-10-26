import Foundation
import ScopaCore
import ScopaRewards

extension RecordBook {
    /// The game on the table, written down. Called the moment the last summary appears and
    /// before anything is awaited: leaving the table meanwhile clears what it reads.
    func record(_ tally: RewardTally, at store: TableStore) {
        guard let game = LoggedGame(tally, at: store) else { return }
        record(game)
    }
}

extension LoggedGame {
    /// Nil for a game not finished, and for a ranked game somebody left in its first minutes,
    /// which the ladder counts for nobody and neither does the record.
    @MainActor
    init?(_ tally: RewardTally, at store: TableStore, on date: Date = .now) {
        guard let outcome = tally.outcome, let view = store.view, !(store.isRanked && store.isCalledOff) else { return nil }
        let configuration = view.configuration
        let you = store.homeSeat
        // A phone's own table numbers its chairs, so only a table across devices has ids.
        let keepsIDs = if case .multipeer = tally.mode { true } else { false }
        let seats = configuration.players.enumerated().map { seat, player in
            Seat(name: player.name, isBot: player.isBot,
                 playerID: keepsIDs && !player.isBot ? player.id.rawValue : nil,
                 side: configuration.side(ofSeat: seat), isYou: seat == you)
        }
        let won = outcome == .won
        self.init(id: tally.gameID, date: date, table: Self.table(for: tally, at: store), seats: seats,
                  teams: configuration.teams, scores: view.scores, yourSide: tally.side,
                  winner: Self.winner(of: view, won: won, side: tally.side), won: won, scope: tally.scope,
                  settebelli: tally.settebelli, cappotti: tally.cappotti, primiere: tally.primiere)
    }

    /// Today's deal is one round and ends on its points, so it has no winner of its own.
    private static func winner(of view: PlayerView, won: Bool, side: Int) -> Int? {
        if case .finished(let winner) = view.phase { return winner }
        if won { return side }
        return view.scores.indices.filter { $0 != side }.max { view.scores[$0] < view.scores[$1] }
    }

    @MainActor
    private static func table(for tally: RewardTally, at store: TableStore) -> Table {
        if store.campaignStage != nil { return .campaign }
        if store.isRanked { return store.ladderTable == .house ? .rankedHouse : .ranked }
        if store.stake != nil { return .wager }
        switch tally.mode {
        case .dailyDeal: return .daily
        case .hotSeat: return .passThePhone
        case .withBots(let seats, let bots): return seats - bots > 1 ? .passThePhone : .quick
        case .multipeer: return store.isRoomTable ? .room : store.isOnline ? .online : .nearby
        }
    }
}
