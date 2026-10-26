import Foundation
import SwiftUI
import ScopaCore
import ScopaRewards

/// The record, with something in it, on a simulator that has played nothing.
///
/// `-recordPage` opens Settings pushed on to the record, over a month and a half of sample
/// games: Marco from the room next door, Giulia online, Papà on the same phone, two ranked
/// strangers and the house's bots, on top of a tally carried over from before the log.
/// `-recordPage people` opens it scrolled down to the rivals and the bots.
/// `-recordLine` opens the end of a game won against Marco instead, the head-to-head under
/// the payout. Either plants the sample for that launch only; nothing is written to disk.
/// (`-record 27 14` is older and only plants the won-and-lost line under the name.)
extension DebugLaunch {
    static var showsRecord: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-recordPage")
        #else
        false
        #endif
    }

    static var recordOpensOnPeople: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-recordPage").flatMap { arguments[safe: $0 + 1] } == "people"
        #else
        false
        #endif
    }

    static var showsRecordLine: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-recordLine")
        #else
        false
        #endif
    }

    /// The sample book, when either flag asks for it.
    static var sampleRecord: GameLog? {
        #if DEBUG
        guard showsRecord || showsRecordLine else { return nil }
        return RecordSample.log()
        #else
        nil
        #endif
    }
}

#if DEBUG
private enum RecordSample {
    typealias Seat = LoggedGame.Seat

    static let marco = Seat(name: "Marco", isBot: false, playerID: "6F1C2A90-marco", side: 1)
    static let giulia = Seat(name: "Giulia", isBot: false, playerID: "gc:T:giulia", side: 1)
    static let papa = Seat(name: "Papà", isBot: false, side: 1)
    static let riccardo = Seat(name: "Riccardo", isBot: false, playerID: "gc:T:riccardo", side: 1)
    static let aurora = Seat(name: "Aurora", isBot: false, playerID: "gc:T:aurora", side: 1)

    static func bot(_ name: String, side: Int = 1) -> Seat { Seat(name: name, isBot: true, side: side) }

    static func log() -> GameLog {
        var log = GameLog(totals: RecordTotals(before: WonLost(won: 38, lost: 21), scope: 64, settebelli: 17,
                                               cappotti: 1))
        for game in games { log.add(game) }
        return log
    }

    /// Oldest first; the last is the win over Marco that `-recordLine` ends on.
    private static var games: [LoggedGame] {
        [
            game(44, .quick, [bot("Hugo")], 11, 7, scope: 2), game(43, .quick, [bot("Hugo")], 6, 11),
            game(41, .nearby, [marco], 11, 9, scope: 1, settebelli: 1), game(40, .daily, [bot("Hugo")], 7, 4),
            game(38, .campaign, [bot("Laurence")], 11, 1, scope: 3, settebelli: 2),
            game(37, .nearby, [marco], 8, 11), game(35, .online, [giulia], 11, 6, scope: 1),
            game(33, .passThePhone, [papa], 9, 11), game(31, .quick, [bot("Lucas")], 11, 5),
            game(30, .ranked, [riccardo], 11, 10, settebelli: 1), game(28, .room, [giulia], 7, 11),
            game(26, .nearby, [marco], 11, 4, scope: 2), game(25, .campaign, [bot("Laurence")], 5, 11),
            game(23, .daily, [bot("Hugo")], 9, 3, scope: 5, settebelli: 1), game(22, .quick, [bot("Lucas")], 11, 8),
            game(20, .passThePhone, [papa], 11, 10), game(18, .nearby, [marco], 11, 7),
            game(17, .campaign, [bot("Laurence")], 11, 6, scope: 1), game(15, .rankedHouse, [bot("Elena")], 11, 9),
            game(14, .ranked, [aurora], 8, 11), game(13, .nearby, [marco], 11, 6),
            game(12, .quick, [bot("Timothée")], 4, 11),
            game(10, .online, [giulia], 6, 11), teams(9), game(8, .passThePhone, [papa], 10, 11),
            game(6, .nearby, [marco], 9, 11), game(5, .quick, [bot("Hugo")], 11, 2, scope: 3),
            game(4, .room, [giulia], 11, 8, settebelli: 1), game(3, .daily, [bot("Hugo")], 6, 6),
            game(2, .nearby, [marco], 7, 11), game(1, .quick, [bot("Hugo")], 11, 9, scope: 1),
            game(0.02, .nearby, [marco], 11, 8, scope: 2, settebelli: 1),
        ]
    }

    private static func game(_ daysAgo: Double, _ table: LoggedGame.Table, _ against: [Seat], _ mine: Int,
                             _ theirs: Int, scope: Int = 0, settebelli: Int = 0) -> LoggedGame {
        let won = mine > theirs
        return LoggedGame(id: UUID(), date: .now.addingTimeInterval(-daysAgo * 86_400),
                          table: table, seats: [you] + against, teams: false, scores: [mine, theirs],
                          yourSide: 0, winner: won ? 0 : 1, won: won, scope: scope, settebelli: settebelli)
    }

    /// Marco beside you for once, against Giulia and a bot.
    private static func teams(_ daysAgo: Double) -> LoggedGame {
        let partner = Seat(name: "Marco", isBot: false, playerID: marco.playerID, side: 0)
        return LoggedGame(id: UUID(), date: .now.addingTimeInterval(-daysAgo * 86_400), table: .room,
                          seats: [you, giulia, partner, bot("Lucas")], teams: true, scores: [11, 7],
                          yourSide: 0, winner: 0, won: true, scope: 1)
    }

    private static let you = Seat(name: "Quentin", isBot: false, side: 0, isYou: true)
}

/// The last summary of a game won against Marco, with the sample book behind it, for
/// `-recordLine`. No contests to tell, so it gets to its foot in a couple of seconds.
struct RecordLineRehearsal: View {
    @Environment(\.locale) private var locale

    var body: some View {
        ZStack {
            TableGround().ignoresSafeArea()
            if let view = Self.view {
                RoundSummary(score: nil, view: view, home: 0, showsAction: true,
                             caption: String(localized: "Game over", locale: locale),
                             title: String(localized: "You win!", locale: locale), isFinal: true,
                             earnings: [PayoutLine(Award(.wonGame), locale: locale),
                                        PayoutLine(Award(.scopa, count: 2), locale: locale)],
                             rivalry: line, again: {}) {}
            }
        }
        .onAppear { RecordBook.shared.load() }
    }

    private var line: String? {
        let book = RecordBook.shared
        return book.log.games.last.flatMap { book.standing(after: $0.id) }?.line(locale: locale)
    }

    private static let view: PlayerView? = {
        let players = [Player(id: PlayerID(rawValue: "seat-0"), name: "Quentin"),
                       Player(id: PlayerID(rawValue: "6F1C2A90-marco"), name: "Marco")]
        guard let configuration = try? GameConfiguration(players: players) else { return nil }
        return PlayerView(seat: 0, hand: [], table: [], opponents: [], stockCount: 0, captureCounts: [0, 0],
                          scope: [2, 0], scores: [11, 8], turnSeat: nil, phase: .finished(winnerSide: 0),
                          roundNumber: 4, configuration: configuration)
    }()
}
#endif
