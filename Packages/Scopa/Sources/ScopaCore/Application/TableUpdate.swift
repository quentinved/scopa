/// What the UI observes, on both host and guest devices.
public enum TableUpdate: Hashable, Sendable {
    case lobby(Lobby)
    case joinRefused
    case view(PlayerView)
    case events([GameEvent])
    case rejected(MoveError)
    case playerLeft(PlayerID)
    case reacted(player: PlayerID, reaction: Reaction)
    /// The finished game, written down. Arrives after the events that ended it.
    case record(GameRecord)
    /// A player whose device had gone has taken their seat back.
    case playerReturned(PlayerID)
    /// The host walked out on purpose: the table is over, not waiting.
    case tableClosed
    /// A guest walked out on purpose. Heard on the host only.
    case forfeited(PlayerID)
}

enum UpdateStream {
    static func make() -> (AsyncStream<TableUpdate>, AsyncStream<TableUpdate>.Continuation) {
        AsyncStream.makeStream(of: TableUpdate.self, bufferingPolicy: .unbounded)
    }
}
