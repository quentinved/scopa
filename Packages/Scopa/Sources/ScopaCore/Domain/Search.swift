/// The hard bot's engine. The other hands are hidden, so it samples ways of dealing the
/// unseen cards (worlds), plays each to the end of the round with every seat maximising
/// its own points, and picks the move that averages best. In the last hand of a round for
/// two there is one world, and the search is exact.
enum Search {
    /// How much thinking one move gets. Sized for a phone answering inside the bot's pause.
    struct Effort {
        /// How many cards deep each world is played.
        let depth: Int
        /// A hard stop on nodes. Past it the rest of the line is estimated.
        let nodes: Int
    }

    // MARK: Choosing

    /// The move to play, or nil when the caller should fall back to weighing the table.
    static func move(for view: PlayerView, using rng: inout some RandomNumberGenerator) -> Move? {
        guard view.isMyTurn, !view.hand.isEmpty else { return nil }
        guard let opinions = opinions(for: view, using: &rng) else { return nil }
        guard opinions.count > 1 else { return opinions.first?.move }

        // Worlds are sampled, so moves within a rounding error are treated as level and chosen between at random.
        let best = opinions.map(\.value).max()!
        return opinions.filter { $0.value > best - 1e-9 }.randomElement(using: &rng)?.move
    }

    /// What every legal move is worth to this seat, in points, averaged over the sampled
    /// worlds. Nil when the deck cannot be counted from this view (a view from a build
    /// that did not carry the piles).
    static func opinions(for view: PlayerView,
                         using rng: inout some RandomNumberGenerator) -> [(move: Move, value: Double)]? {
        let candidates = moves(seat: view.seat, hand: view.hand, table: view.table)
        guard !candidates.isEmpty else { return nil }
        guard candidates.count > 1 else { return [(candidates[0], 0)] }
        let worlds = worlds(for: view, using: &rng)
        guard !worlds.isEmpty else { return nil }

        let effort = effort(for: view, worlds: worlds.count)
        let side = view.mySide
        let sides = view.configuration.sideCount
        var totals = [Double](repeating: 0, count: candidates.count)
        for world in worlds {
            for (index, move) in candidates.enumerated() {
                var budget = effort.nodes
                let (next, _) = Rules.applyLegal(move, to: world)
                let value = value(of: next, depth: effort.depth - 1, budget: &budget)
                totals[index] += margin(value, for: side, of: sides)
            }
        }
        return candidates.indices.map { (candidates[$0], totals[$0] / Double(worlds.count)) }
    }

    /// Deeper the less is left to guess about, which is where the round is decided and
    /// where the tree is small. Tuned so the worst case stays inside the bot's pause.
    static func effort(for view: PlayerView, worlds: Int) -> Effort {
        let left = view.stockCount + view.cardsInPlay
        // One world means nothing is guessed: play every remaining card.
        if worlds == 1 { return Effort(depth: left, nodes: 30_000) }
        if left <= 6 { return Effort(depth: left, nodes: 3_000) }
        if view.configuration.seatCount <= 2 { return Effort(depth: 6, nodes: 2_000) }
        return Effort(depth: 5, nodes: 1_500)
    }

    // MARK: Worlds

    /// How many ways of dealing the unseen cards to try.
    static func worldCount(for view: PlayerView) -> Int {
        let hidden = view.opponents.count { $0.cardsInHand > 0 }
        // Empty stock and one hidden hand: that hand is the unseen cards, so one world is exact.
        if view.stockCount == 0, hidden <= 1 { return 1 }
        return view.configuration.seatCount <= 2 ? 16 : 12
    }

    /// The unseen cards dealt out, `worldCount` ways, as full game states. Empty when the
    /// view's piles do not account for the deck.
    static func worlds(for view: PlayerView, using rng: inout some RandomNumberGenerator) -> [GameState] {
        guard let hidden = hiddenCards(in: view) else { return [] }
        return (0..<worldCount(for: view)).map { _ in
            world(for: view, dealing: hidden.pool.shuffled(using: &rng), handCounts: hidden.handCounts)
        }
    }

    /// The cards this seat cannot see and how many each seat holds, or nil when the
    /// counts do not add up.
    private static func hiddenCards(in view: PlayerView) -> (pool: [Card], handCounts: [Int])? {
        let config = view.configuration
        guard view.capturedBySide.count == config.sideCount else { return nil }

        var seen = Set(view.hand)
        seen.formUnion(view.table)
        for pile in view.capturedBySide { seen.formUnion(pile) }
        let pool = Deck.standard.filter { !seen.contains($0) }

        var handCounts = [Int](repeating: 0, count: config.seatCount)
        handCounts[view.seat] = view.hand.count
        for opponent in view.opponents where opponent.seat < config.seatCount {
            handCounts[opponent.seat] = opponent.cardsInHand
        }
        let dealt = handCounts.enumerated().reduce(0) { $1.offset == view.seat ? $0 : $0 + $1.element }
        guard pool.count == dealt + view.stockCount else { return nil }
        return (pool, handCounts)
    }

    /// One game consistent with the view: `cards` dealt into the other hands, the rest as stock.
    private static func world(for view: PlayerView, dealing cards: [Card], handCounts: [Int]) -> GameState {
        let config = view.configuration
        var cards = cards
        var hands = [[Card]](repeating: [], count: config.seatCount)
        hands[view.seat] = view.hand
        for seat in 0..<config.seatCount where seat != view.seat {
            hands[seat] = Array(cards.suffix(handCounts[seat]))
            cards.removeLast(handCounts[seat])
        }
        var state = GameState(configuration: config)
        state.scores = view.scores
        state.roundNumber = view.roundNumber
        state.phase = .playing
        state.round = Round(stock: cards, table: view.table, hands: hands,
                            captures: view.capturedBySide, scope: view.scope,
                            turnSeat: view.seat, lastCaptureSide: view.lastCaptureSide)
        return state
    }

    // MARK: The tree

    /// What the game is worth to each side from here, in points. Every seat plays for
    /// itself against the best of the others, which is minimax for two and each-for-itself for four.
    static func value(of state: GameState, depth: Int, budget: inout Int) -> SIMD4<Double> {
        guard state.phase == .playing, let round = state.round else { return settled(state) }
        guard depth > 0, budget > 0 else { return estimate(state, round) }
        budget -= 1

        let seat = round.turnSeat
        let side = state.configuration.side(ofSeat: seat)
        let sides = state.configuration.sideCount
        var best: SIMD4<Double>?
        var bestMargin = -Double.infinity
        for move in moves(seat: seat, hand: round.hands[seat], table: round.table) {
            let (next, _) = Rules.applyLegal(move, to: state)
            let value = value(of: next, depth: depth - 1, budget: &budget)
            let margin = margin(value, for: side, of: sides)
            if margin > bestMargin {
                bestMargin = margin
                best = value
            }
        }
        return best ?? estimate(state, round)
    }

    /// A round played out and scored.
    private static func settled(_ state: GameState) -> SIMD4<Double> {
        var value = SIMD4<Double>()
        for side in state.scores.indices where side < 4 { value[side] = Double(state.scores[side]) }
        return value
    }

    /// A round stopped part-way: the score so far, plus the odds of each of the four points from the piles.
    static func estimate(_ state: GameState, _ round: Round) -> SIMD4<Double> {
        let config = state.configuration
        let sides = config.sideCount
        var value = settled(state)
        for side in 0..<min(sides, 4) { value[side] += Double(round.scope[side]) }

        // What is left to win in a category is the whole of it less what is already in a pile.
        let piles = round.captures
        let cards = piles.map(\.count)
        value += odds(cards, left: Deck.standard.count - cards.reduce(0, +), of: sides)
        let coins = piles.map { $0.count { $0.suit == .coins } }
        value += odds(coins, left: Rank.allCases.count - coins.reduce(0, +), of: sides)
        value += settebelloOdds(piles, of: sides)
        value += primieraOdds(piles, rule: config.primiera, of: sides)
        return value
    }

    /// The settebello point: whole to whoever holds it, otherwise split evenly.
    private static func settebelloOdds(_ piles: [[Card]], of sides: Int) -> SIMD4<Double> {
        var out = SIMD4<Double>()
        if let holder = piles.firstIndex(where: { $0.contains(.settebello) }), holder < 4 {
            out[holder] = 1
        } else {
            for side in 0..<min(sides, 4) { out[side] = 1 / Double(sides) }
        }
        return out
    }

    private static func primieraOdds(_ piles: [[Card]], rule: PrimieraRule, of sides: Int) -> SIMD4<Double> {
        switch rule {
        case .mostSevens:
            let sevens = piles.map { $0.count { $0.rank == .seven } }
            return odds(sevens, left: Suit.allCases.count - sevens.reduce(0, +), of: sides)
        case .classic:
            // A seven is worth 21, so a lead of one seven's worth is treated as settled.
            let totals = piles.map(Scoring.primiera)
            return odds(totals, left: Scoring.primieraValue(.seven), of: sides)
        }
    }

    /// How likely each side is to end up ahead in one category: 0.5 when level, certain
    /// once the lead exceeds everything still to be won.
    private static func odds(_ values: [Int], left: Int, of sides: Int) -> SIMD4<Double> {
        var out = SIMD4<Double>()
        for side in 0..<min(sides, 4) {
            let bestOther = values.indices.filter { $0 != side }.map { values[$0] }.max() ?? 0
            let lead = Double(values[side] - bestOther) / Double(max(left, 1))
            out[side] = min(max(0.5 + lead / 2, 0), 1)
        }
        return out
    }

    /// One side's points against the best anybody else has.
    private static func margin(_ value: SIMD4<Double>, for side: Int, of sides: Int) -> Double {
        var bestOther = -Double.infinity
        for other in 0..<min(sides, 4) where other != side { bestOther = max(bestOther, value[other]) }
        return value[side] - (bestOther.isFinite ? bestOther : 0)
    }

    // MARK: Moves

    /// Every legal move from one hand over one table. A card that can take must take.
    static func moves(seat: Int, hand: [Card], table: [Card]) -> [Move] {
        hand.flatMap { card -> [Move] in
            let options = Rules.captureOptions(for: card, on: table)
            guard !options.isEmpty else { return [Move(seat: seat, card: card)] }
            return options.map { Move(seat: seat, card: card, captures: $0) }
        }
    }
}
