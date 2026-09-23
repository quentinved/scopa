import Foundation
import GameKit
import ScopaCore

/// Internet transport for one table, over a Game Center real-time match.
///
/// Apple relays the traffic, so there is no server to run and nobody's address is ever
/// known to anybody. The match is flat, every device talking to every other, and the game
/// keeps its host-and-guests shape on top: an invited table is hosted by the friend who sent
/// the invitation, any other by the player whose Game Center id sorts first.
public final class GameCenterSession: NSObject, GameTransport, @unchecked Sendable {
    public let localPlayer: Player
    public let incoming: AsyncStream<Envelope>
    /// Anything that went wrong with the match after it was made: a drop, a failure to send.
    public let problems: AsyncStream<String>

    /// Apple's match under the table. The host reaches for it to invite one more friend
    /// into a table that already exists; nothing else needs it, everything else the table
    /// does goes through the transport.
    public let match: GKMatch
    private let incomingContinuation: AsyncStream<Envelope>.Continuation
    private let problemsContinuation: AsyncStream<String>.Continuation
    private let lock = NSLock()
    /// The other people in the match, by the id they will sign their envelopes with.
    private var remote: [PlayerID: GKPlayer] = [:]
    /// Who deals, when the table already knows. An invited table does: the friend who sent
    /// the invitation hosts it, and every phone is told so rather than working it out.
    private let declaredHost: PlayerID?

    public init(match: GKMatch, localPlayer: Player, host: PlayerID? = nil) {
        self.match = match
        self.localPlayer = localPlayer
        self.declaredHost = host
        (incoming, incomingContinuation) = AsyncStream.makeStream(of: Envelope.self, bufferingPolicy: .unbounded)
        (problems, problemsContinuation) = AsyncStream.makeStream(of: String.self, bufferingPolicy: .bufferingNewest(1))
        super.init()
        for player in match.players { remote[GameCenter.id(of: player)] = player }
        match.delegate = self
    }

    deinit {
        match.delegate = nil
        match.disconnect()
        incomingContinuation.finish()
        problemsContinuation.finish()
    }

    /// Everyone at the table, this device included.
    public var players: [Player] {
        [localPlayer] + lock.withLock { remote.values.map(GameCenter.player(for:)) }
    }

    /// The Game Center account behind one seat, for opening their profile. Nil for a seat
    /// nobody has heard from, and for this phone's own, which is not in the match.
    public func account(for id: PlayerID) -> GKPlayer? {
        lock.withLock { remote[id] }
    }

    /// The id that hosts.
    ///
    /// Named outright where the table knows it, since an invitation names its sender, and
    /// otherwise the smallest id at the table, which every device works out for itself.
    /// The named one matters: a match arrives before everyone has finished
    /// connecting, so two phones reading the smallest id at that moment can each see a
    /// different table and both decide they are the host, or that neither is, and then sit
    /// waiting for a join that is never coming.
    public var hostID: PlayerID {
        if let declaredHost { return declaredHost }
        return players.map(\.id).min { $0.rawValue < $1.rawValue } ?? localPlayer.id
    }

    public var isHost: Bool { hostID == localPlayer.id }

    /// How many the match was made for. The host starts the game when this many are seated.
    public var expectedPlayerCount: Int { match.expectedPlayerCount + match.players.count + 1 }

    public func disconnect() {
        match.disconnect()
    }

    // MARK: GameTransport

    public func send(_ message: GameMessage, to recipient: Recipient) async throws {
        let data = try Wire.encode(Envelope(from: localPlayer.id, message: message))
        // Read before the lock is taken, never inside it. `hostID` can go on to read
        // `players`, which takes the same lock, and `NSLock` is not recursive, so taking it
        // twice on one thread wedges that thread for good.
        let host = hostID
        let targets: [GKPlayer] = lock.withLock {
            switch recipient {
            case .all: Array(remote.values)
            // The declared host by id, and failing that the only other device at the table,
            // which at a table of two can only be the host. The id an invitation names its
            // sender by and the
            // id that same player arrives in the match under are not always spelled the
            // same, and a join dropped here leaves the guest in a waiting room that never
            // fills: the one thing a guest ever sends the host is the join that seats them.
            case .host:
                if let seat = remote[host] { [seat] } else if remote.count == 1 { Array(remote.values) } else { [] }
            case .player(let id): remote[id].map { [$0] } ?? []
            }
        }
        guard !targets.isEmpty else {
            if case .all = recipient { return }
            throw TransportError.peerNotFound
        }
        try match.send(data, to: targets, dataMode: .reliable)
    }
}

// MARK: - GKMatchDelegate

extension GameCenterSession: GKMatchDelegate {
    public func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        guard let envelope = try? Wire.decode(data) else { return }
        lock.withLock { remote[envelope.from] = player }
        incomingContinuation.yield(envelope)
    }

    public func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        let id = GameCenter.id(of: player)
        switch state {
        case .connected:
            lock.withLock { remote[id] = player }
        case .disconnected:
            lock.withLock { _ = remote.removeValue(forKey: id) }
            // Told the way Multipeer tells it, so the host covers the seat the same way.
            incomingContinuation.yield(Envelope(from: id, message: .leave(id)))
        case .unknown:
            break
        @unknown default:
            break
        }
    }

    public func match(_ match: GKMatch, didFailWithError error: Error?) {
        problemsContinuation.yield("The connection to the table was lost")
    }

    /// Asked when somebody drops: keeping the match going is always right, the host plays
    /// the empty seat until they are back.
    public func match(_ match: GKMatch, shouldReinviteDisconnectedPlayer player: GKPlayer) -> Bool { true }
}
