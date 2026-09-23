/// A card played from `seat`. `captures` lists the table cards taken; empty means the card is laid on the table.
public struct Move: Hashable, Codable, Sendable {
    public let seat: Int
    public let card: Card
    public let captures: [Card]

    public init(seat: Int, card: Card, captures: [Card] = []) {
        self.seat = seat
        self.card = card
        self.captures = captures
    }
}

public enum MoveError: Error, Hashable, Codable, Sendable {
    case notPlaying
    case notYourTurn(expectedSeat: Int)
    case cardNotInHand
    case captureNotOnTable
    case captureIsMandatory
    case invalidCapture
}

/// What happened as a result of applying a move or advancing the game.
public enum GameEvent: Hashable, Codable, Sendable {
    case dealt
    case played(seat: Int, card: Card)
    case captured(seat: Int, cards: [Card])
    case scopa(seat: Int)
    case leftoverSwept(side: Int, cards: [Card])
    case roundEnded(RoundScore)
    case gameEnded(winnerSide: Int)
}
