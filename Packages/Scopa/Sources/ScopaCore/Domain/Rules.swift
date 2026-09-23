/// Classic Scopa rules as pure functions over `GameState`.
public enum Rules {
    // MARK: Captures

    /// Every legal set of table cards `card` may take. Empty means the card must be laid down.
    /// A single card of equal rank takes priority over any sum of smaller cards.
    public static func captureOptions(for card: Card, on table: [Card]) -> [[Card]] {
        let singles = table.filter { $0.rank == card.rank }
        if !singles.isEmpty { return singles.map { [$0] } }

        let target = card.rank.rawValue
        let smaller = table.filter { $0.rank < card.rank }
        return subsets(of: smaller, summingTo: target)
    }

    /// All subsets of `cards` whose ranks add up to `target`. Depth-first, cut once the sum
    /// is reached and once the remaining cards cannot reach it.
    static func subsets(of cards: [Card], summingTo target: Int) -> [[Card]] {
        guard !cards.isEmpty, target > 0 else { return [] }

        var reachable = [Int](repeating: 0, count: cards.count + 1)
        for index in stride(from: cards.count - 1, through: 0, by: -1) {
            reachable[index] = reachable[index + 1] + cards[index].rank.rawValue
        }

        var result: [[Card]] = []
        var current: [Card] = []
        current.reserveCapacity(cards.count)

        func walk(_ index: Int, _ sum: Int) {
            // Ranks are all positive, so no superset of a finished subset can also match.
            if sum == target { result.append(current); return }
            guard index < cards.count, sum < target, sum + reachable[index] >= target else { return }
            current.append(cards[index])
            walk(index + 1, sum + cards[index].rank.rawValue)
            current.removeLast()
            walk(index + 1, sum)
        }
        walk(0, 0)
        return result
    }

    // MARK: Validation

    public static func validate(_ move: Move, in state: GameState) throws(MoveError) {
        guard state.phase == .playing, let round = state.round else { throw .notPlaying }
        guard round.turnSeat == move.seat else { throw .notYourTurn(expectedSeat: round.turnSeat) }
        guard round.hands[move.seat].contains(move.card) else { throw .cardNotInHand }

        let taken = Set(move.captures)
        guard taken.count == move.captures.count, taken.isSubset(of: round.table) else { throw .captureNotOnTable }

        let options = captureOptions(for: move.card, on: round.table)
        if taken.isEmpty {
            guard options.isEmpty else { throw .captureIsMandatory }
        } else {
            guard options.contains(where: { Set($0) == taken }) else { throw .invalidCapture }
        }
    }

    // MARK: Transitions

    /// Shuffles and deals a new round.
    public static func startRound(_ state: GameState, using rng: inout some RandomNumberGenerator) -> (GameState, [GameEvent]) {
        deal(shuffledDeck(using: &rng), into: state)
    }

    /// A shuffled deck, reshuffled while three or more kings would land on the table.
    public static func shuffledDeck(using rng: inout some RandomNumberGenerator) -> [Card] {
        var deck: [Card]
        repeat {
            deck = Deck.shuffled(using: &rng)
        } while deck.suffix(GameConfiguration.tableSize).count { $0.rank == .king } >= 3
        return deck
    }

    /// Deals a round from a deck already in order: the table from the top, then the hands.
    /// Pure, so a recorded deck deals the same round again for a replay.
    public static func deal(_ deck: [Card], into state: GameState) -> (GameState, [GameEvent]) {
        var state = state
        let config = state.configuration
        var deck = deck

        let table = Array(deck.suffix(GameConfiguration.tableSize))
        deck.removeLast(GameConfiguration.tableSize)

        var round = Round(
            stock: deck,
            table: table,
            hands: Array(repeating: [], count: config.seatCount),
            captures: Array(repeating: [], count: config.sideCount),
            scope: Array(repeating: 0, count: config.sideCount),
            turnSeat: config.nextSeat(after: state.dealerSeat),
            lastCaptureSide: nil
        )
        dealHands(&round, seatCount: config.seatCount)

        state.round = round
        state.phase = .playing
        state.roundNumber += 1
        return (state, [.dealt])
    }

    static func dealHands(_ round: inout Round, seatCount: Int) {
        for seat in 0..<seatCount {
            round.hands[seat] = Array(round.stock.suffix(GameConfiguration.handSize))
            round.stock.removeLast(GameConfiguration.handSize)
        }
    }

    /// Applies a validated move and moves the game forward: deals the next hand, ends the round, or ends the game.
    public static func apply(_ move: Move, to state: GameState) throws(MoveError) -> (GameState, [GameEvent]) {
        try validate(move, in: state)
        return applyLegal(move, to: state)
    }

    /// The same without validation, for a search whose moves came from `captureOptions` a
    /// line earlier. Anything from a person or off the wire goes through `apply`.
    static func applyLegal(_ move: Move, to state: GameState) -> (GameState, [GameEvent]) {
        var state = state
        var round = state.round!
        let config = state.configuration
        let isLastCard = round.isOnLastCard
        var events: [GameEvent] = [.played(seat: move.seat, card: move.card)]

        round.hands[move.seat].removeAll { $0 == move.card }
        if move.captures.isEmpty {
            round.table.append(move.card)
        } else {
            events += capture(move, in: &round, side: config.side(ofSeat: move.seat), isLastCard: isLastCard)
        }
        round.turnSeat = config.nextSeat(after: move.seat)

        if round.handsAreEmpty {
            if round.stock.isEmpty {
                return finishRound(state, round, events)
            }
            dealHands(&round, seatCount: config.seatCount)
            events.append(.dealt)
        }

        state.round = round
        return (state, events)
    }

    /// Moves the taken cards and the played card to `side`'s pile. Clearing the table
    /// scores a scopa, except on the last card of the round.
    private static func capture(_ move: Move, in round: inout Round, side: Int, isLastCard: Bool) -> [GameEvent] {
        let taken = Set(move.captures)
        round.table.removeAll { taken.contains($0) }
        round.captures[side] += move.captures + [move.card]
        round.lastCaptureSide = side
        var events: [GameEvent] = [.captured(seat: move.seat, cards: move.captures)]
        if round.table.isEmpty && !isLastCard {
            round.scope[side] += 1
            events.append(.scopa(seat: move.seat))
        }
        return events
    }

    static func finishRound(_ state: GameState, _ round: Round, _ events: [GameEvent]) -> (GameState, [GameEvent]) {
        var state = state
        var round = round
        var events = events

        if !round.table.isEmpty, let side = round.lastCaptureSide {
            round.captures[side] += round.table
            events.append(.leftoverSwept(side: side, cards: round.table))
            round.table.removeAll()
        }

        let score = Scoring.score(captures: round.captures, scope: round.scope,
                                  primiera: state.configuration.primiera, ties: state.configuration.ties)
        for side in state.scores.indices { state.scores[side] += score.points[side] }
        state.round = round
        state.dealerSeat = state.configuration.nextSeat(after: state.dealerSeat)
        events.append(.roundEnded(score))

        if let winner = winner(of: state) {
            state.phase = .finished(winnerSide: winner)
            events.append(.gameEnded(winnerSide: winner))
        } else {
            state.phase = .roundOver(score)
        }
        return (state, events)
    }

    /// The side that reached the target with a strict lead, if any.
    public static func winner(of state: GameState) -> Int? {
        guard state.scores.contains(where: { $0 >= state.configuration.targetScore }) else { return nil }
        return Scoring.uniqueMax(state.scores)
    }
}
