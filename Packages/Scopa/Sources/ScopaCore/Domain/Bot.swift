/// Chooses a move for a seat nobody is sitting in. It sees only a `PlayerView`, so it is
/// never shown the deck. `strength` decides whether it hands the position to `Search`
/// or weighs the table one move ahead, and how often it follows its own advice.
public struct Bot: Hashable, Sendable {
    public let strength: BotStrength

    public init(strength: BotStrength) {
        self.strength = strength
    }

    public init(level: BotLevel = .default) {
        self.init(strength: level.strength)
    }

    public func move(for view: PlayerView, using rng: inout some RandomNumberGenerator) -> Move? {
        guard view.isMyTurn, !view.hand.isEmpty else { return nil }
        // The search declines a view whose piles it cannot count. The weighing below answers instead.
        if strength.searches {
            if strength.isExact, let searched = Search.move(for: view, using: &rng) { return searched }
            if !strength.isExact, let opinions = Search.opinions(for: view, using: &rng) {
                return chosen(opinions.map { ($0.move, $0.value) }, using: &rng)
            }
        }

        let moves = evaluate(view)
        guard !moves.isEmpty else { return nil }
        if strength.isExact {
            // Ties are common, and breaking them at random stops two bots replaying the same game.
            let best = moves.map(\.score).max()!
            return moves.filter { $0.score == best }.randomElement(using: &rng)?.move
        }
        return chosen(moves.map { ($0.move, Double($0.score)) }, using: &rng)
    }

    /// Usually the best move, otherwise the next one down, and so on. Only reached below
    /// `isExact`, so an exact bot never draws on the generator here.
    private func chosen(_ moves: [(move: Move, value: Double)],
                        using rng: inout some RandomNumberGenerator) -> Move? {
        let ranked = moves.sorted { $0.value > $1.value }
        guard !ranked.isEmpty else { return nil }
        var index = 0
        while index < ranked.count - 1, Double.random(in: 0..<1, using: &rng) > strength.follows { index += 1 }
        // Sampled values land a hair apart, so equal means within a rounding error.
        let value = ranked[index].value
        return ranked.filter { abs($0.value - value) < 1e-9 }.randomElement(using: &rng)?.move
    }

    // MARK: Candidates

    /// One legal move and what the bot thinks it is worth.
    public struct ScoredMove: Hashable, Sendable {
        public let move: Move
        public let score: Int
    }

    /// Every legal move from `view`, scored, whether or not it is this seat's turn. A card
    /// with no take may always be laid, even while another card could capture.
    public func evaluate(_ view: PlayerView) -> [ScoredMove] {
        view.hand.flatMap { card -> [ScoredMove] in
            let options = Rules.captureOptions(for: card, on: view.table)
            guard !options.isEmpty else {
                return [ScoredMove(move: Move(seat: view.seat, card: card), score: layScore(card, view))]
            }
            return options.map { option in
                ScoredMove(move: Move(seat: view.seat, card: card, captures: option),
                           score: captureScore(card, option, view))
            }
        }
    }

    private func captureScore(_ card: Card, _ option: [Card], _ view: PlayerView) -> Int {
        let taken = option + [card]
        var score = Weight.take
        if view.isScopa(taking: option) { score += Weight.scopa }
        if taken.contains(.settebello) { score += Weight.settebello }
        score += taken.count { $0.suit == .coins } * Weight.coin
        score += taken.count * Weight.card
        score += taken.reduce(0) { $0 + Scoring.primieraValue($1.rank) } / 2

        let left = view.table.filter { !Set(option).contains($0) }
        // The last capture of a round also sweeps up whatever is still on the table.
        if view.isOnLastCard {
            score += left.count * Weight.card + left.count { $0.suit == .coins } * Weight.coin
            if left.contains(.settebello) { score += Weight.settebello }
        }
        score -= Self.exposure(of: left, in: view)
        return score
    }

    /// Laying costs whatever the card was worth to keep, plus whatever it offers the table.
    private func layScore(_ card: Card, _ view: PlayerView) -> Int {
        let cost = Self.layCost(card, in: view)
        return -(cost.card + cost.exposure)
    }

    /// The two halves of what laying a card costs, kept apart because a review names them
    /// as different lessons.
    static func layCost(_ card: Card, in view: PlayerView) -> (card: Int, exposure: Int) {
        var value = 0
        if card == .settebello { value += Weight.settebello }
        if card.suit == .coins { value += Weight.coin * 2 }
        // Sevens, sixes and aces are what the primiera pays for.
        value += Scoring.primieraValue(card.rank) / 2
        return (value, exposure(of: view.table + [card], in: view))
    }

    /// What the table left behind is worth to whoever plays next: every rank they could
    /// hold is tried against it, the best pile priced, and the total averaged.
    static func exposure(of table: [Card], in view: PlayerView) -> Int {
        // Nothing is left to answer with once the last card of the round is down.
        guard !table.isEmpty, !view.isOnLastCard else { return 0 }
        let sweepScores = !(view.stockCount == 0 && view.cardsInPlay <= 2)

        let total = Rank.allCases.reduce(0) { total, rank in
            let best = Rules.captureOptions(for: Card(rank, of: .cups), on: table).map { option -> Int in
                var value = option.count * Weight.card
                value += option.count { $0.suit == .coins } * Weight.coin
                if option.contains(.settebello) { value += Weight.settebello }
                if sweepScores, option.count == table.count { value += Weight.scopa }
                return value
            }
            return total + (best.max() ?? 0)
        }
        return total / Weight.unseenHand
    }

    /// Tuned so that any take beats any lay, and a scopa beats every other take.
    enum Weight {
        static let take = 40
        static let scopa = 120
        static let settebello = 60
        static let coin = 10
        static let card = 4
        /// Ten ranks could answer and a hand holds three, so a threat priced against every rank is divided by something between.
        static let unseenHand = 6
    }
}
