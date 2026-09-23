public extension Rules {
    /// The move the table makes when someone runs out of time: the best capture available,
    /// otherwise the least useful card laid down.
    static func automaticMove(in state: GameState) -> Move? {
        guard state.phase == .playing, let round = state.round else { return nil }
        let seat = round.turnSeat
        let hand = round.hands[seat]
        guard !hand.isEmpty else { return nil }

        let captures = hand.flatMap { card in
            captureOptions(for: card, on: round.table).map { option in
                (Move(seat: seat, card: card, captures: option), captureValue(card, option, round))
            }
        }
        if let best = captures.max(by: { $0.1.lexicographicallyPrecedes($1.1) }) {
            return best.0
        }

        let card = hand.min { layValue($0).lexicographicallyPrecedes(layValue($1)) }
        return card.map { Move(seat: seat, card: $0) }
    }

    /// The same choice from a single seat's view, for a device that does not hold the game state.
    static func automaticMove(for view: PlayerView) -> Move? {
        guard view.isMyTurn, !view.hand.isEmpty else { return nil }

        let captures = view.hand.flatMap { card in
            captureOptions(for: card, on: view.table).map { option in
                (Move(seat: view.seat, card: card, captures: option),
                 captureValue(card, option, tableCount: view.table.count, isOnLastCard: view.isOnLastCard))
            }
        }
        if let best = captures.max(by: { $0.1.lexicographicallyPrecedes($1.1) }) { return best.0 }

        let card = view.hand.min { layValue($0).lexicographicallyPrecedes(layValue($1)) }
        return card.map { Move(seat: view.seat, card: $0) }
    }

    /// Ranked highest first: a sweep, then the settebello, then coins, then card count.
    private static func captureValue(_ card: Card, _ option: [Card], _ round: Round) -> [Int] {
        captureValue(card, option, tableCount: round.table.count, isOnLastCard: round.isOnLastCard)
    }

    private static func captureValue(_ card: Card, _ option: [Card], tableCount: Int, isOnLastCard: Bool) -> [Int] {
        let taken = option + [card]
        return [
            option.count == tableCount && !isOnLastCard ? 1 : 0,
            taken.contains(.settebello) ? 1 : 0,
            taken.count { $0.suit == .coins },
            taken.count,
        ]
    }

    /// Ranked lowest first, so the settebello and coins stay in hand and small cards go down.
    private static func layValue(_ card: Card) -> [Int] {
        [card == .settebello ? 1 : 0, card.suit == .coins ? 1 : 0, card.rank.rawValue]
    }
}
