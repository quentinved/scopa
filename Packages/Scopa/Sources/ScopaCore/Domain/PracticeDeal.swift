/// A hand laid out to teach one house rule: the deck in dealing order and the moves that
/// play it out, so everything the rule does happens in front of the learner, the same way
/// every time. The learner sits in seat 0 and the dealer is seat 0, so seat 1 leads.
///
/// Heads-up rules are taught on a short deck of one hand, so the round is counted as soon
/// as the lesson is over. Scopone needs the whole deck for ten cards each, so its moves
/// stop after the first sweeps and the rest of the hand is played freely.
public struct PracticeDeal: Hashable, Sendable {
    public let rule: HouseRule
    public let seats: Int
    public let deck: [Card]
    /// Every scripted move of the hand in turn order, the learner's and the bots' alike.
    public let moves: [Move]

    public var teams: Bool { seats == 4 }
    /// What the table's bots are told to play.
    public var botMoves: [Move] { moves.filter { $0.seat != Self.learner } }

    public static let learner = 0

    /// How many cards of this deal have been played so far, read off a view of it.
    public func played(in view: PlayerView) -> Int {
        deck.count - view.configuration.tableSize - view.stockCount - view.cardsInPlay
    }
}

public extension HouseRule {
    var practice: PracticeDeal {
        switch self {
        case .napola: PracticeDeal.napola
        case .assoPigliaTutto: PracticeDeal.asso
        case .reBello: PracticeDeal.reBello
        case .scopone: PracticeDeal.scopone
        }
    }
}

private func c(_ rank: Rank, _ suit: Suit) -> Card { Card(rank, of: suit) }

private func you(_ card: Card, _ captures: Card...) -> Move { Move(seat: 0, card: card, captures: captures) }

private func seat(_ seat: Int, _ card: Card, _ captures: Card...) -> Move {
    Move(seat: seat, card: card, captures: captures)
}

extension PracticeDeal {
    /// The 3 of coins takes the ace and the 2 for a napola of three, then the 4 makes it four.
    static let napola = PracticeDeal(
        rule: .napola, seats: 2,
        deck: Deck.stacked(table: [c(.ace, .coins), c(.two, .coins), c(.six, .cups), c(.king, .swords)],
                           deals: [[[c(.three, .coins), c(.four, .cups), c(.king, .cups)],
                                    [c(.four, .coins), c(.six, .clubs), c(.five, .swords)]]]),
        moves: [
            seat(1, c(.four, .coins)),
            you(c(.three, .coins), c(.ace, .coins), c(.two, .coins)),
            seat(1, c(.six, .clubs), c(.six, .cups)),
            you(c(.four, .cups), c(.four, .coins)),
            seat(1, c(.five, .swords)),
            you(c(.king, .cups), c(.king, .swords)),
        ])

    /// No ace on the table; yours takes all five cards, and no scopa. Then an ace laid on an
    /// empty table, taken by the next.
    static let asso = PracticeDeal(
        rule: .assoPigliaTutto, seats: 2,
        deck: Deck.stacked(table: [c(.five, .coins), c(.king, .clubs), c(.three, .swords), c(.six, .cups)],
                           deals: [[[c(.ace, .cups), c(.ace, .clubs), c(.seven, .swords)],
                                    [c(.two, .cups), c(.ace, .swords), c(.four, .clubs)]]]),
        moves: [
            seat(1, c(.two, .cups)),
            you(c(.ace, .cups), c(.five, .coins), c(.king, .clubs), c(.three, .swords), c(.six, .cups),
                c(.two, .cups)),
            seat(1, c(.ace, .swords)),
            you(c(.ace, .clubs), c(.ace, .swords)),
            seat(1, c(.four, .clubs)),
            you(c(.seven, .swords)),
        ])

    /// Any king takes the king of coins, then the settebello beside it: a point each.
    static let reBello = PracticeDeal(
        rule: .reBello, seats: 2,
        deck: Deck.stacked(table: [.reBello, c(.three, .cups), c(.five, .swords), c(.two, .clubs)],
                           deals: [[[c(.king, .cups), .settebello, c(.two, .swords)],
                                    [c(.five, .clubs), c(.four, .swords), c(.knave, .clubs)]]]),
        moves: [
            seat(1, c(.five, .clubs), c(.five, .swords)),
            you(c(.king, .cups), .reBello),
            seat(1, c(.four, .swords)),
            you(.settebello, c(.three, .cups), c(.four, .swords)),
            seat(1, c(.knave, .clubs)),
            you(c(.two, .swords), c(.two, .clubs)),
        ])

    /// An empty table, so the lead is laid; your partner sweeps it, and so do you.
    static let scopone = PracticeDeal(
        rule: .scopone, seats: 4,
        deck: Deck.stacked(table: [], deals: [tenEach(opening: [[c(.three, .coins)],
                                                                [c(.five, .cups), c(.knight, .cups)],
                                                                [c(.five, .swords)],
                                                                [c(.three, .clubs)]])]),
        moves: [
            seat(1, c(.five, .cups)),
            seat(2, c(.five, .swords), c(.five, .cups)),
            seat(3, c(.three, .clubs)),
            you(c(.three, .coins), c(.three, .clubs)),
            seat(1, c(.knight, .cups)),
        ])

    /// Four hands of ten: the cards each seat must hold, then the rest of the deck dealt
    /// round the table one at a time.
    private static func tenEach(opening: [[Card]]) -> [[Card]] {
        var hands = opening
        var seat = 0
        for card in Deck.standard where !opening.joined().contains(card) {
            while hands[seat].count == 10 { seat = (seat + 1) % hands.count }
            hands[seat].append(card)
            seat = (seat + 1) % hands.count
        }
        return hands
    }
}
