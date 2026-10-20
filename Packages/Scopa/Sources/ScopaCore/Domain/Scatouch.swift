/// Why a card in hand could not be traded for one in the stock.
public enum SwapError: Error, Hashable, Sendable {
    case notPlaying
    case cardNotInHand
    case cardNotInStock
}

/// Liberties a table on one phone may take with its own deal, for the quick game's god mode.
/// Local only: none of this is ever sent to another device.
public extension GameState {
    /// The stock as it will be dealt, hand by hand: `[deal][seat]`, the next deal first.
    var upcomingDeals: [[[Card]]] {
        guard var round else { return [] }
        let perDeal = configuration.seatCount * configuration.handSize
        var deals: [[[Card]]] = []
        while perDeal > 0, round.stock.count >= perDeal {
            Rules.dealHands(&round, configuration)
            deals.append(round.hands)
        }
        return deals
    }

    /// `held` out of `seat`'s hand and `wanted` out of the stock, each into the other's place.
    /// Still forty cards, and nothing else at the table moves.
    func swapping(_ held: Card, inHandOf seat: Int, for wanted: Card) throws(SwapError) -> GameState {
        guard phase == .playing, var round else { throw .notPlaying }
        guard let slot = round.hands[safe: seat]?.firstIndex(of: held) else { throw .cardNotInHand }
        guard let spot = round.stock.firstIndex(of: wanted) else { throw .cardNotInStock }
        round.hands[seat][slot] = wanted
        round.stock[spot] = held
        var next = self
        next.round = round
        return next
    }
}

public extension GameRecord {
    /// The same two cards traded in the current round's deck, so the record still replays to
    /// the table a swap left behind.
    mutating func swapInLastDeck(_ one: Card, _ other: Card) {
        guard let last = rounds.indices.last,
              let first = rounds[last].deck.firstIndex(of: one),
              let second = rounds[last].deck.firstIndex(of: other) else { return }
        rounds[last].deck.swapAt(first, second)
    }
}
