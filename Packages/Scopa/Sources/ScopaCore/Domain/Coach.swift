/// The voice at your shoulder while the game is on: what each card in your hand would do,
/// and what the player before you just did to the table.
///
/// It weighs moves with the same `Bot` the review judges a finished game with, so the coach
/// mid-game and the reading afterwards never say different things about the same move.
/// Everything it knows comes out of a `PlayerView`: the table, the piles taken face up and
/// its own hand. So it can be handed to a player without showing them a card they are not
/// allowed to see, and its warnings are counted against the deck rather than guessed at.
///
/// It names things rather than writing them. The words belong to the interface, in whatever
/// language it is speaking. What belongs here is which thing is worth saying, and in what
/// order.
public enum Coach {
    /// How a move stands against the best one in the hand.
    public enum Standing: String, Hashable, Sendable, CaseIterable {
        /// Nothing else in the hand does better.
        case best
        /// Within a card or two of the best, which is not a mistake.
        case sound
        /// Costs something worth having.
        case costly
    }

    /// One thing worth knowing about a move, either for it or against it.
    public enum Note: Hashable, Sendable {
        // What a take is worth.
        /// Clears the table: a point, there and then.
        case sweeps
        case takesSettebello
        /// Coins coming over, the settebello counted among them.
        case takesCoins(Int)
        /// Cards coming over, the card played counted among them. Only said when the pile
        /// is big enough to matter.
        case takesCards(Int)
        /// The last card of the round takes whatever is still lying there as well.
        case takesTheLeftovers
        /// The rules left no choice, so there is nothing to weigh.
        case onlyMove

        // What laying costs.
        /// Nothing on the table matches it and nothing adds up to it.
        case nothingMatches
        /// Of the cards that cannot take, this is the one worth the least to give up.
        case cheapestToLose
        case givesTheSettebello
        case givesACoin
        /// A seven, a six or an ace: the cards the primiera is counted from.
        case givesAGoodCard(Rank)

        // What the table is left offering, whichever way the move went.
        /// Anyone holding this rank sweeps what is left behind.
        case leavesASweep(Rank)
        /// The seven of coins stays on the cloth for whoever can reach it.
        case leavesTheSettebello
    }

    /// One card in the hand, and what playing it would do. `captures` empty is a lay.
    public struct Counsel: Hashable, Sendable, Identifiable {
        public let card: Card
        public let captures: [Card]
        public let sweeps: Bool
        public let standing: Standing
        /// Why the move is worth making, best reason first.
        public let reasons: [Note]
        /// What it costs or leaves behind, worst first. Never empty of meaning: a card
        /// with nothing against it has none of these.
        public let warnings: [Note]

        public var id: Card { card }
        public var takes: Bool { !captures.isEmpty }

        public init(card: Card, captures: [Card], sweeps: Bool, standing: Standing,
                    reasons: [Note], warnings: [Note]) {
            self.card = card
            self.captures = captures
            self.sweeps = sweeps
            self.standing = standing
            self.reasons = reasons
            self.warnings = warnings
        }
    }

    /// Somebody else's move, told back from your chair: what they played, what it took,
    /// and what the table they left is worth to you.
    public struct Reading: Hashable, Sendable {
        public let card: Card
        public let captures: [Card]
        public let sweeps: Bool
        /// What the move did, in the order worth hearing.
        public let notes: [Note]
        /// Your best answer to the table they left, when it is your turn to make one.
        public let answer: Counsel?

        public var takes: Bool { !captures.isEmpty }
    }

    // MARK: Your hand

    /// Every card in hand, weighed, in the order they are held. A card with more than one
    /// way to take is counselled on its best one, which is the take the interface fills in
    /// for a beginner, so the advice and the tap agree.
    public static func hand(_ view: PlayerView) -> [Counsel] {
        let scored = Bot().evaluate(view)
        guard let top = scored.map(\.score).max() else { return [] }
        // What laying costs is only worth mentioning against the other cards that have to
        // be laid: "the cheapest to give up" means nothing when it is the only lay going.
        let lays = scored.filter { $0.move.captures.isEmpty }
        let cheapest = lays.count > 1 ? lays.max { $0.score < $1.score }?.move.card : nil

        return view.hand.compactMap { card in
            let forCard = scored.filter { $0.move.card == card }
            guard let pick = forCard.max(by: { isWeaker($0, than: $1, in: view) }) else { return nil }
            let gap = top - pick.score
            let standing: Standing = gap == 0 ? .best : (gap <= Reviewer.fineGap ? .sound : .costly)
            return Counsel(
                card: card,
                captures: pick.move.captures,
                sweeps: view.isScopa(taking: pick.move.captures),
                standing: standing,
                reasons: reasons(for: pick.move, in: view, alone: scored.count == 1, cheapest: cheapest),
                warnings: warnings(after: pick.move, in: view)
            )
        }
    }

    /// The counsel for one card, or nil when it is not in hand.
    public static func counsel(for card: Card, in view: PlayerView) -> Counsel? {
        hand(view).first { $0.card == card }
    }

    /// Ties are common, two cards taking the same pile, and showing the smaller of two
    /// equal takes looks careless. Sweeps first, then the bigger pile, then more coins.
    private static func isWeaker(_ lhs: Bot.ScoredMove, than rhs: Bot.ScoredMove, in view: PlayerView) -> Bool {
        if lhs.score != rhs.score { return lhs.score < rhs.score }
        let sweeps = (view.isScopa(taking: lhs.move.captures), view.isScopa(taking: rhs.move.captures))
        if sweeps.0 != sweeps.1 { return !sweeps.0 }
        if lhs.move.captures.count != rhs.move.captures.count {
            return lhs.move.captures.count < rhs.move.captures.count
        }
        return lhs.move.captures.count { $0.suit == .coins } < rhs.move.captures.count { $0.suit == .coins }
    }

    // MARK: Somebody else's move

    /// The move just played, read from this seat. `view` is the table as it stands now, with
    /// the captured cards already gone, so what it took is passed in rather than worked out.
    public static func reading(of card: Card, taking captures: [Card], sweeps: Bool,
                               in view: PlayerView) -> Reading {
        var notes: [Note] = []
        if sweeps { notes.append(.sweeps) }
        if (captures + [card]).contains(.settebello), !captures.isEmpty { notes.append(.takesSettebello) }
        if captures.isEmpty {
            notes.append(.nothingMatches)
            if card == .settebello { notes.append(.givesTheSettebello) }
            else if card.suit == .coins { notes.append(.givesACoin) }
        } else {
            let coins = (captures + [card]).count { $0.suit == .coins }
            if coins > 0 { notes.append(.takesCoins(coins)) }
            if captures.count + 1 >= 3 { notes.append(.takesCards(captures.count + 1)) }
        }
        if !sweeps, view.table.contains(.settebello) { notes.append(.leavesTheSettebello) }

        // The answer is what your own hand makes of what they left, which is only advice
        // while it is actually your move: at a table for three or four the next chair is
        // somebody else's, and telling you what you would play from there teaches nothing.
        let answer = view.isMyTurn ? hand(view).max(by: { rank($0) < rank($1) }) : nil
        return Reading(card: card, captures: captures, sweeps: sweeps, notes: notes, answer: answer)
    }

    private static func rank(_ counsel: Counsel) -> Int {
        (counsel.standing == .best ? 2 : 0) + (counsel.sweeps ? 4 : 0) + (counsel.takes ? 1 : 0)
    }

    // MARK: Reasons

    private static func reasons(for move: Move, in view: PlayerView, alone: Bool, cheapest: Card?) -> [Note] {
        // Said first and then talked through anyway: "your only move" is the answer to
        // "which card?", and what it does is still worth knowing.
        var notes: [Note] = alone ? [.onlyMove] : []
        guard !move.captures.isEmpty else {
            notes.append(.nothingMatches)
            if move.card == cheapest { notes.append(.cheapestToLose) }
            return notes
        }
        let taken = move.captures + [move.card]
        if view.isScopa(taking: move.captures) { notes.append(.sweeps) }
        if taken.contains(.settebello) { notes.append(.takesSettebello) }
        if view.isOnLastCard, view.table.count > move.captures.count { notes.append(.takesTheLeftovers) }
        let coins = taken.count { $0.suit == .coins }
        if coins > 0 { notes.append(.takesCoins(coins)) }
        if taken.count >= 3 { notes.append(.takesCards(taken.count)) }
        return notes
    }

    /// What the move hands over: the card it gives up, and the table it leaves behind.
    private static func warnings(after move: Move, in view: PlayerView) -> [Note] {
        var notes: [Note] = []
        if move.captures.isEmpty {
            if move.card == .settebello { notes.append(.givesTheSettebello) }
            else if move.card.suit == .coins { notes.append(.givesACoin) }
            else if Scoring.primieraValue(move.card.rank) >= Scoring.primieraValue(.ace) {
                notes.append(.givesAGoodCard(move.card.rank))
            }
        }
        let taken = Set(move.captures)
        var left = view.table.filter { !taken.contains($0) }
        if move.captures.isEmpty { left.append(move.card) }
        // Nothing is left to answer with once the last card of the round is down, and a
        // table cleared to nothing offers nobody anything.
        guard !left.isEmpty, view.cardsInPlay > 1, !view.isOnLastCard else { return notes }
        if let rank = sweepingRank(over: left, in: view) { notes.append(.leavesASweep(rank)) }
        else if left.contains(.settebello) { notes.append(.leavesTheSettebello) }
        return notes
    }

    /// The rank that would sweep `table`, if anybody could still be holding one. The lowest
    /// such rank, because a table a 2 sweeps is in far more hands than one only a king does.
    static func sweepingRank(over table: [Card], in view: PlayerView) -> Rank? {
        Rank.allCases.first { rank in
            guard view.unseen(rank) > 0 else { return false }
            return Rules.captureOptions(for: Card(rank, of: .cups), on: table)
                .contains { $0.count == table.count }
        }
    }

}
