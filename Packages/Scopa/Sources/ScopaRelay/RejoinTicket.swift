import Foundation
import ScopaCore

/// A seat at a room this phone was playing at, kept until the game is over, so a player whose
/// app was closed mid-game can sit back down from the lobby.
///
/// Only a guest keeps one. The game lives on the host's phone, so a host whose app was closed
/// has nothing to come back to; a guest's chair is still there, held by the room and kept warm
/// by the host's bot until the same id asks for it again.
public struct RejoinTicket: Codable, Sendable, Hashable {
    public let code: String
    /// Who sat down, exactly as the room and the host know them. The id is the seat.
    public let player: Player
    public let hostName: String
    public let ranked: Bool
    public let duo: Bool
    /// The ranked shape the table was dealt in, as the app spells it. Nil at a friends' room.
    public let format: String?
    /// The people the table was made for, which a ranked room deals as soon as it has.
    public let humans: Int
    public let seatedAt: Date

    public init(code: String, player: Player, hostName: String, ranked: Bool = false, duo: Bool = false,
                format: String? = nil, humans: Int = 2, seatedAt: Date = .now) {
        self.code = code
        self.player = player
        self.hostName = hostName
        self.ranked = ranked
        self.duo = duo
        self.format = format
        self.humans = humans
        self.seatedAt = seatedAt
    }

    /// How long after sitting down a seat is still worth offering. A game to eleven is well
    /// inside it, and past it the table is all but certainly over.
    public static let shelfLife: TimeInterval = 3 * 60 * 60

    /// Whether to offer the seat at `now`. A clock that has gone backwards reads as stale
    /// rather than as a seat from the future.
    public func isFresh(at now: Date = .now) -> Bool {
        let age = now.timeIntervalSince(seatedAt)
        return age > -60 && age < Self.shelfLife
    }
}
