import SwiftUI
import ScopaCore

/// What the coach says at one move of a practice hand: what to do, and why.
struct PracticeLine: Equatable {
    let headline: LocalizedStringKey
    let detail: LocalizedStringKey
    /// The bots hold this move until the line has been read and "Next" tapped.
    var waits = false
}

extension RulePractice {
    /// The line for the move the hand is on, or for wherever the table is once the script
    /// has run out. Names are read off the table, seat by seat.
    func line(in view: PlayerView) -> PracticeLine {
        let names = view.configuration.players.map(\.name)
        let name = { (seat: Int) in names[safe: seat] ?? "" }
        if let beat = beat(in: view) {
            let lines = Self.lines(for: rule, name)
            if let line = lines[safe: beat] { return line }
        }
        if view.phase != .playing { return countLine }
        guard view.isMyTurn else {
            let mover = name(view.turnSeat ?? 1)
            return PracticeLine(headline: "\(mover) is thinking", detail: "Watch what the card does when it lands.")
        }
        return PracticeLine(headline: "Your turn",
                            detail: "The star marks a good card. Nothing counts here: no stars, no denari.")
    }

    /// Under the summary as it counts the round: what to look for in it.
    private var countLine: PracticeLine {
        let detail: LocalizedStringKey = switch rule {
        case .napola: "Look for the napola, on top of the usual points."
        case .assoPigliaTutto: "No scopa for the aces, but every card they took is in your pile."
        case .reBello: "Look for the re bello: a line of its own, like the settebello."
        case .scopone: "Your partner's cards and yours are counted as one pile."
        }
        return PracticeLine(headline: "Here comes the count", detail: detail)
    }

    private static func lines(for rule: HouseRule, _ name: (Int) -> String) -> [PracticeLine] {
        switch rule {
        case .napola: napola(hugo: name(1))
        case .assoPigliaTutto: asso(hugo: name(1))
        case .reBello: reBello
        case .scopone: scopone(left: name(1), partner: name(2))
        }
    }

    private static func napola(hugo: String) -> [PracticeLine] {
        [
            PracticeLine(headline: "Napola: ace, 2 and 3 of coins",
                         detail: "Get all three into your pile and they score three points. Two of them are on the table.",
                         waits: true),
            PracticeLine(headline: "Take them with your 3 of coins",
                         detail: "One and two make three, so your 3 takes the ace and the 2. That makes all three."),
            PracticeLine(headline: "Napola! Three points",
                         detail: "They count at the end of the round, on top of the usual points. And a napola can grow.",
                         waits: true),
            PracticeLine(headline: "Now take the 4 of coins",
                         detail: "\(hugo) laid it earlier. It follows on from the 3, so your napola goes up to four."),
            PracticeLine(headline: "Four points",
                         detail: "Every coin that follows on adds one. A gap stops the count: ace, 3 and 4 alone score nothing.",
                         waits: true),
            PracticeLine(headline: "Last card: take the king",
                         detail: "What is left on the table goes to whoever took last. Then the round is counted."),
        ]
    }

    private static func asso(hugo: String) -> [PracticeLine] {
        [
            PracticeLine(headline: "Asso piglia tutto: the ace takes all",
                         detail: "An ace takes everything on the table. None is ever dealt face up, so yours are in your hand.",
                         waits: true),
            PracticeLine(headline: "Play your ace of cups",
                         detail: "Five cards on the table, and your ace takes every one of them."),
            PracticeLine(headline: "All of it, and no scopa",
                         detail: "Clearing the table with an ace is not a scopa: the ace did the work, not you.",
                         waits: true),
            PracticeLine(headline: "Take that ace with yours",
                         detail: "On an empty table an ace takes nothing, so \(hugo) had to lay it down. The next ace takes it."),
            PracticeLine(headline: "Still no scopa",
                         detail: "However little an ace takes, it never sweeps. Every other card plays as usual.",
                         waits: true),
            PracticeLine(headline: "Last card: lay your 7",
                         detail: "Nothing matches it. What is left on the table goes to whoever took last: you."),
        ]
    }

    private static var reBello: [PracticeLine] {
        [
            PracticeLine(headline: "Re bello: the king of coins",
                         detail: "Like the settebello, it is a point of its own. There it is, on the table.",
                         waits: true),
            PracticeLine(headline: "Take it with your king",
                         detail: "Any king takes the king of coins, as usual. Here it is worth a point at the count."),
            PracticeLine(headline: "Re bello! One point",
                         detail: "Whoever has it in their pile at the end of the round scores it. One more point to play for.",
                         waits: true),
            PracticeLine(headline: "Now the settebello",
                         detail: "Your 7 of coins takes the 3 and the 4: three and four make seven."),
            PracticeLine(headline: "Two points in your pile",
                         detail: "The seven of coins and the king of coins, a point each when the round is counted."),
            PracticeLine(headline: "Last card: take the 2",
                         detail: "What is left on the table goes to whoever took last. Then the round is counted."),
        ]
    }

    private static func scopone(left: String, partner: String) -> [PracticeLine] {
        [
            PracticeLine(headline: "Scopone: four players, two teams",
                         detail: "Ten cards each and nothing on the table. \(partner), across from you, is your partner.",
                         waits: true),
            PracticeLine(headline: "An empty table: the first card goes down",
                         detail: "With nothing to take, \(left) had to lay the 5. Now watch your partner.",
                         waits: true),
            PracticeLine(headline: "A scopa for your team",
                         detail: "\(partner) swept the table. What either of you takes goes in one pile, and you score together.",
                         waits: true),
            PracticeLine(headline: "Your turn: sweep it again",
                         detail: "One card on the table, and your 3 matches it. Another scopa for the team."),
            PracticeLine(headline: "That is scopone",
                         detail: "Play the hand out from here. With ten cards you can plan: watch what goes, and leave your partner something.",
                         waits: true),
        ]
    }
}
