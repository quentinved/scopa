import Foundation
import ScopaCore
import UIKit

#if DEBUG
/// `-lastCard lay|take|clear`: a short round against Hugo, two hands of three with every move
/// scripted, so the end of a hand and the end of a round can be watched, and shot, the same
/// way every time. The first hand ends on a take; the round ends on a card laid down (`lay`),
/// a take that leaves cards behind (`take`) or one that clears the table (`clear`). Hugo plays
/// the last card of each hand; `-lastBy you` hands that to you. `-target 1` makes the round
/// the whole game, so its payout can be watched too.
extension DebugLaunch {
    @MainActor
    static func startLastCardTable(_ store: TableStore, with arguments: [String]) -> Bool {
        guard let index = arguments.firstIndex(of: "-lastCard") else { return false }
        let script = LastCardScript(ending: LastCardScript.Ending(rawValue: arguments[safe: index + 1] ?? "") ?? .lay)
        let youLast = arguments.firstIndex(of: "-lastBy").map { arguments[safe: $0 + 1] == "you" } ?? false
        let target = arguments.firstIndex(of: "-target").flatMap { Int(arguments[safe: $0 + 1] ?? "") } ?? 11
        // The dealer plays last at a table of two, and the dealer is the first chair.
        let you = LocalSeat.person(name: "Quentin"), hugo = LocalSeat.bot(name: "Hugo")
        let botSeat = youLast ? LastCardScript.leader : LastCardScript.dealer
        store.playOnThisDevice(seats: youLast ? [you, hugo] : [hugo, you], teams: false, targetScore: target) { table in
            await table.deal(stacked: script.deck, botMoves: script.moves.filter { $0.seat == botSeat })
        }
        // `-myMoves 3` stops your side there, so the table rests on your turn to be shot.
        let mine = arguments.firstIndex(of: "-myMoves").flatMap { Int(arguments[safe: $0 + 1] ?? "") }
        play(Array(script.moves.filter { $0.seat != botSeat }.prefix(mine ?? .max)), in: store)
        return true
    }

    /// `-eventsLag 0.4`: a move's events applied that long after the view it came with, as
    /// they reach a phone across the internet, so a table can be watched catching up.
    static func lagEvents(_ update: TableUpdate) async {
        guard case .events = update, let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-eventsLag"),
              let lag = Double(ProcessInfo.processInfo.arguments[safe: index + 1] ?? "") else { return }
        try? await Task.sleep(for: .seconds(lag))
    }

    /// `-frames /some/prefix 13.5,14,15`: what the window shows that many seconds after the
    /// deal, written beside the prefix, so a whole end of round is caught in one launch. Any
    /// table: `-lastCard`'s scripted one, or `-quickGame -autoPlay` played out.
    @MainActor
    static func captureFrames(with arguments: [String]) {
        guard let index = arguments.firstIndex(of: "-frames"), let prefix = arguments[safe: index + 1] else { return }
        let times = (arguments[safe: index + 2] ?? "").split(separator: ",").compactMap { Double($0) }
        let start = Date.now
        Task {
            for time in times.sorted() {
                try? await Task.sleep(for: .seconds(max(0, time - Date.now.timeIntervalSince(start))))
                guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                    .flatMap(\.windows).first(where: \.isKeyWindow) else { continue }
                let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
                }
                try? image.pngData()?.write(to: URL(fileURLWithPath: "\(prefix)-\(time).png"))
            }
        }
    }

    /// Your side of the script, at a person's pace once each card is yours to play.
    @MainActor
    private static func play(_ moves: [Move], in store: TableStore) {
        Task {
            for move in moves {
                while store.view?.isMyTurn != true || store.view?.hand.contains(move.card) != true {
                    guard store.route == .table else { return }
                    try? await Task.sleep(for: .milliseconds(100))
                }
                try? await Task.sleep(for: .milliseconds(2500))
                store.play(move.card, capturing: move.captures)
                // The table answers a moment later: until it does, the next card would look
                // playable while the turn has in fact passed.
                while store.view?.hand.contains(move.card) == true, store.route == .table {
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }
        }
    }
}

/// The round `-lastCard` deals. Seat 0 deals and plays last; seat 1 leads.
private struct LastCardScript {
    enum Ending: String { case lay, take, clear }

    static let dealer = 0
    static let leader = 1

    let ending: Ending

    private static let table = [Card(.king, of: .clubs), Card(.knight, of: .swords),
                                Card(.knave, of: .clubs), Card(.seven, of: .clubs)]

    /// Each hand's cards, seat by seat, in the order `Deck.stacked` wants them.
    var deck: [Card] {
        let deals = [Self.firstHand, secondHand].map { hand in
            [Self.dealer, Self.leader].map { seat in hand.filter { $0.seat == seat }.map(\.card) }
        }
        return Deck.stacked(table: Self.table, deals: deals)
    }

    var moves: [Move] { Self.firstHand + secondHand }

    /// Leader and dealer in turn, ending on the dealer's take of the knave.
    private static let firstHand: [Move] = [
        lead(.ace, .swords), deal(.three, .swords),
        lead(.two, .swords), deal(.four, .swords, taking: [(.three, .swords), (.ace, .swords)]),
        lead(.seven, .cups, taking: [(.seven, .clubs)]), deal(.knave, .cups, taking: [(.knave, .clubs)]),
    ]

    /// The table comes into it holding the king of clubs, the knight and the two of swords.
    private var secondHand: [Move] {
        let lead = Self.lead, deal = Self.deal
        switch ending {
        case .lay:
            return [lead(.ace, .clubs, []), deal(.five, .swords, []),
                    lead(.four, .clubs, []), deal(.six, .swords, [(.five, .swords), (.ace, .clubs)]),
                    lead(.six, .clubs, [(.two, .swords), (.four, .clubs)]), deal(.ace, .coins, [])]
        case .take, .clear:
            let last = ending == .take ? lead(.ace, .clubs, []) : lead(.three, .coins, [(.three, .clubs)])
            return [lead(.knight, .cups, [(.knight, .swords)]), deal(.five, .swords, []),
                    lead(.three, .clubs, []), deal(.seven, .swords, [(.five, .swords), (.two, .swords)]),
                    last, deal(.king, .coins, [(.king, .clubs)])]
        }
    }

    private static func lead(_ rank: Rank, _ suit: Suit, taking: [(Rank, Suit)] = []) -> Move {
        Move(seat: leader, card: Card(rank, of: suit), captures: taking.map { Card($0.0, of: $0.1) })
    }

    private static func deal(_ rank: Rank, _ suit: Suit, taking: [(Rank, Suit)] = []) -> Move {
        Move(seat: dealer, card: Card(rank, of: suit), captures: taking.map { Card($0.0, of: $0.1) })
    }
}
#endif
