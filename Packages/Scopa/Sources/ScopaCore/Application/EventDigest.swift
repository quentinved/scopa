/// What one batch of `GameEvent`s means for the table on screen.
///
/// A batch arrives whenever a seat moves, and the screen has to decide from it what to
/// announce, what to draw flying across the cloth, and whether the round is over. That
/// reading is the same wherever the events came from, so it lives here rather than in the
/// app, and it is a value: hand it events, read the answers, nothing else happens.
public struct EventDigest: Sendable {
    /// The seat that played, and the card it put down. Nil when no card was played, which
    /// is every deal and every end of round.
    public var played: (seat: Int, card: Card)? {
        guard let playedSeat, let playedCard else { return nil }
        return (playedSeat, playedCard)
    }

    public let playedSeat: Int?
    public let playedCard: Card?
    /// What the played card took. Empty when it was laid down.
    public let captured: [Card]
    /// The seat that cleared the table, when one did.
    public let sweptSeat: Int?
    /// The round's last cards and the side that swept them up. Nobody plays these, so the
    /// screen has to carry them itself. Nil once a fresh deal has spent them, which is why
    /// the events are read in order rather than merely counted.
    public let leftovers: (side: Int, cards: [Card])?

    /// Whether this batch has anything to say about the leftovers at all. A batch that does
    /// not leaves whatever is on the cloth alone.
    public let touchesLeftovers: Bool
    public let roundScore: RoundScore?
    public let winnerSide: Int?

    /// Whether the table was cleared.
    public var sweeps: Bool { sweptSeat != nil }

    /// A deal that follows a played card tops the hands back up inside a round. A deal
    /// without one starts a round, which is the moment worth announcing.
    public let isRefill: Bool

    /// Whether a fresh round was dealt, which spends whatever the last one left behind.
    public var startsARound: Bool { wasDealt && !isRefill }

    private let wasDealt: Bool

    public init(_ events: [GameEvent]) {
        var playedSeat: Int?
        var playedCard: Card?
        var captured: [Card] = []
        var sweptSeat: Int?
        var leftovers: (side: Int, cards: [Card])?
        var touchesLeftovers = false
        var roundScore: RoundScore?
        var winnerSide: Int?
        var wasDealt = false

        // A deal only spends the leftovers when it opens a round, so whether a card was
        // played has to be known before the events are walked.
        let refills = events.contains { if case .played = $0 { true } else { false } }

        for event in events {
            switch event {
            case .dealt:
                wasDealt = true
                if !refills {
                    leftovers = nil
                    touchesLeftovers = true
                }
            case .played(let seat, let card):
                playedSeat = seat
                playedCard = card
            case .captured(_, let cards):
                captured = cards
            case .scopa(let seat):
                sweptSeat = seat
            case .leftoverSwept(let side, let cards):
                leftovers = (side, cards)
                touchesLeftovers = true
            case .roundEnded(let score):
                roundScore = score
            case .gameEnded(let side):
                winnerSide = side
            }
        }

        self.playedSeat = playedSeat
        self.playedCard = playedCard
        self.captured = captured
        self.sweptSeat = sweptSeat
        self.leftovers = leftovers
        self.touchesLeftovers = touchesLeftovers
        self.roundScore = roundScore
        self.winnerSide = winnerSide
        self.wasDealt = wasDealt
        self.isRefill = wasDealt && playedCard != nil
    }
}
