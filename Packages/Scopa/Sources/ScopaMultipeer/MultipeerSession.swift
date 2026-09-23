import Foundation
import MultipeerConnectivity
import ScopaCore
import os

/// Wi-Fi and Bluetooth transport for one table. The host advertises, guests browse, everyone talks through one session.
public final class MultipeerSession: NSObject, GameTransport, TableAdvertising, TableBrowsing, @unchecked Sendable {
    /// Must be 1-15 characters of lowercase ASCII, digits and hyphens.
    public static let serviceType = "scopa"

    /// Everything the radios do, in the unified log. Read it with
    /// `log stream --predicate 'subsystem == "com.quentinvedrenne.scopa"'` on a
    /// simulator, or in Console.app with the phone plugged in. Peer names and table ids
    /// are marked public on purpose: a connection log with every name redacted to
    /// `<private>` is no help in telling two phones apart.
    static let log = Logger(subsystem: "com.quentinvedrenne.scopa", category: "multipeer")

    private enum Key {
        static let playerID = "pid"
        static let hostName = "host"
        static let seated = "seated"
        static let capacity = "cap"
    }

    public let localPlayer: Player
    public let incoming: AsyncStream<Envelope>
    public let nearbyTables: AsyncStream<[NearbyTable]>
    /// Reasons the table could not be put up, or looked for. Usually the local network
    /// prompt was refused, and without this the screen would simply wait forever.
    public let problems: AsyncStream<String>

    private let peerID: MCPeerID
    private let session: MCSession
    private let incomingContinuation: AsyncStream<Envelope>.Continuation
    private let tablesContinuation: AsyncStream<[NearbyTable]>.Continuation
    private let problemsContinuation: AsyncStream<String>.Continuation

    private let lock = NSLock()
    private var advertiser: MCNearbyServiceAdvertiser?
    /// What the running advertiser is already saying, so it is only replaced when it would
    /// actually say something different.
    private var advertisedInfo: [String: String]?
    private var browser: MCNearbyServiceBrowser?
    /// Peers we have seen, both directions.
    private var peersByPlayer: [PlayerID: MCPeerID] = [:]
    private var playersByPeer: [MCPeerID: PlayerID] = [:]
    private var discovered: [MCPeerID: NearbyTable] = [:]
    private var hostPeer: MCPeerID?
    private var pendingJoin: CheckedContinuation<Void, Error>?

    public init(localPlayer: Player) {
        self.localPlayer = localPlayer
        self.peerID = MCPeerID(displayName: String(localPlayer.name.prefix(63)))
        self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        (incoming, incomingContinuation) = AsyncStream.makeStream(of: Envelope.self, bufferingPolicy: .unbounded)
        (nearbyTables, tablesContinuation) = AsyncStream.makeStream(of: [NearbyTable].self, bufferingPolicy: .bufferingNewest(1))
        (problems, problemsContinuation) = AsyncStream.makeStream(of: String.self, bufferingPolicy: .bufferingNewest(1))
        super.init()
        session.delegate = self
        Self.log.info("Session up as \(self.peerID.displayName, privacy: .public) (player \(localPlayer.id.rawValue, privacy: .public))")
    }

    deinit {
        Self.log.info("Session torn down: \(self.peerID.displayName, privacy: .public)")
        stopAdvertising()
        stopBrowsing()
        session.disconnect()
        incomingContinuation.finish()
        tablesContinuation.finish()
        problemsContinuation.finish()
    }

    // MARK: GameTransport

    public func send(_ message: GameMessage, to recipient: Recipient) async throws {
        let envelope = Envelope(from: localPlayer.id, message: message)
        let data = try Wire.encode(envelope)
        let peers: [MCPeerID] = lock.withLock {
            switch recipient {
            case .all: session.connectedPeers
            case .host: hostPeer.map { [$0] } ?? []
            case .player(let id): peersByPlayer[id].map { [$0] } ?? []
            }
        }
        guard !peers.isEmpty else {
            if case .all = recipient {
                Self.log.debug("Nobody connected to send \(Self.name(of: message), privacy: .public) to")
                return
            }
            Self.log.error("No peer for \(String(describing: recipient), privacy: .public); could not send \(Self.name(of: message), privacy: .public)")
            throw TransportError.peerNotFound
        }
        do {
            try session.send(data, toPeers: peers, with: .reliable)
            Self.log.debug("Sent \(Self.name(of: message), privacy: .public) (\(data.count) bytes) to \(peers.map(\.displayName).joined(separator: ", "), privacy: .public)")
        } catch {
            Self.log.error("Send of \(Self.name(of: message), privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// The case name alone: `.play(card, captures)` would put the whole hand in the log.
    private static func name(of message: GameMessage) -> String {
        Mirror(reflecting: message).children.first?.label ?? String(describing: message)
    }

    // MARK: TableAdvertising

    public func advertise(_ lobby: Lobby) {
        let info = [
            Key.playerID: localPlayer.id.rawValue,
            Key.hostName: lobby.host.name,
            Key.seated: String(lobby.players.count),
            Key.capacity: String(GameConfiguration.playerRange.upperBound),
        ]
        lock.withLock {
            // The framework has no way to change the info on a running advertiser, so a
            // real change means a new one. An unchanged one is left alone: this is called
            // on every lobby publish, and each replacement drops any invitation that
            // happened to be in flight, which is a guest tapping join at the wrong moment.
            guard info != advertisedInfo else { return }
            Self.log.info("\(self.advertiser == nil ? "Advertising" : "Re-advertising", privacy: .public) table of \(lobby.host.name, privacy: .public): \(lobby.players.count) seated of \(GameConfiguration.playerRange.upperBound)")
            advertiser?.stopAdvertisingPeer()
            let advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: info, serviceType: Self.serviceType)
            advertiser.delegate = self
            advertiser.startAdvertisingPeer()
            self.advertiser = advertiser
            advertisedInfo = info
        }
    }

    public func stopAdvertising() {
        lock.withLock {
            if advertiser != nil { Self.log.info("Stopped advertising") }
            advertiser?.stopAdvertisingPeer()
            advertiser = nil
            advertisedInfo = nil
        }
    }

    // MARK: TableBrowsing

    public func startBrowsing() {
        Self.log.info("Browsing for tables")
        lock.withLock {
            browser?.stopBrowsingForPeers()
            let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
            browser.delegate = self
            browser.startBrowsingForPeers()
            self.browser = browser
        }
    }

    /// Stops the radios scanning, which is the whole point of stopping. The browser object
    /// itself is kept: an invitation is sent through it, and letting it go while the
    /// connection it started is still settling takes the connection down with it. It is
    /// inert once `stopBrowsingForPeers` has been called, and `startBrowsing` replaces it.
    public func stopBrowsing() {
        Self.log.info("Stopped browsing")
        lock.withLock {
            browser?.stopBrowsingForPeers()
            discovered.removeAll()
        }
        tablesContinuation.yield([])
    }

    /// Invites the host and waits for the connection to come up.
    public func join(_ table: NearbyTable) async throws {
        let found: (MCPeerID, MCNearbyServiceBrowser)? = lock.withLock {
            guard let browser, let peer = discovered.first(where: { $0.value.id == table.id })?.key else { return nil }
            return (peer, browser)
        }
        guard let (peer, browser) = found else {
            Self.log.error("Join of \(table.hostName, privacy: .public)'s table (\(table.id, privacy: .public)) refused: no browser, or the peer has gone")
            throw TransportError.peerNotFound
        }

        Self.log.info("Inviting \(peer.displayName, privacy: .public) to \(table.hostName, privacy: .public)'s table, 20 s timeout")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            lock.withLock {
                pendingJoin?.resume(throwing: TransportError.joinFailed)
                pendingJoin = continuation
                hostPeer = peer
            }
            browser.invitePeer(peer, to: session, withContext: localPlayer.id.rawValue.data(using: .utf8), timeout: 20)
        }
    }

    private func settleJoin(_ result: Result<Void, Error>) {
        let continuation = lock.withLock { pendingJoin.take() }
        guard let continuation else { return }
        switch result {
        case .success: Self.log.info("Join settled: connected to the host")
        case .failure(let error): Self.log.error("Join settled: failed, \(String(describing: error), privacy: .public)")
        }
        continuation.resume(with: result)
    }

    private func publishTables() {
        let tables = lock.withLock { Array(discovered.values) }
        var seen: Set<String> = []
        let unique = tables.filter { seen.insert($0.id).inserted }
        tablesContinuation.yield(unique.sorted { $0.hostName < $1.hostName })
    }
}

// MARK: - MCSessionDelegate

extension MultipeerSession: MCSessionDelegate {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Self.log.info("\(peerID.displayName, privacy: .public) is now \(Self.name(of: state), privacy: .public); \(session.connectedPeers.count) connected")
        switch state {
        case .connected:
            if lock.withLock({ hostPeer == peerID }) { settleJoin(.success(())) }
        case .notConnected:
            let (player, wasHost) = lock.withLock { () -> (PlayerID?, Bool) in
                let player = playersByPeer.removeValue(forKey: peerID)
                if let player { peersByPlayer.removeValue(forKey: player) }
                let wasHost = hostPeer == peerID
                if wasHost { hostPeer = nil }
                return (player, wasHost)
            }
            // Only the table we are trying to reach can fail our join. Any other peer
            // dropping, a guest leaving or a stale peer being cleaned up, used to fail it
            // too, refusing a join that was still on its way.
            if wasHost { settleJoin(.failure(TransportError.joinFailed)) }
            if let player { incomingContinuation.yield(Envelope(from: player, message: .leave(player))) }
        case .connecting:
            break
        @unknown default:
            break
        }
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let envelope = try? Wire.decode(data) else {
            Self.log.error("Could not decode \(data.count) bytes from \(peerID.displayName, privacy: .public)")
            return
        }
        Self.log.debug("Received \(Self.name(of: envelope.message), privacy: .public) (\(data.count) bytes) from \(peerID.displayName, privacy: .public)")
        lock.withLock {
            peersByPlayer[envelope.from] = peerID
            playersByPeer[peerID] = envelope.from
        }
        incomingContinuation.yield(envelope)
    }

    private static func name(of state: MCSessionState) -> String {
        switch state {
        case .notConnected: "not connected"
        case .connecting: "connecting"
        case .connected: "connected"
        @unknown default: "in state \(state.rawValue)"
        }
    }

    public func session(_: MCSession, didReceive _: InputStream, withName _: String, fromPeer _: MCPeerID) {}
    public func session(_: MCSession, didStartReceivingResourceWithName _: String, fromPeer _: MCPeerID, with _: Progress) {}
    public func session(_: MCSession, didFinishReceivingResourceWithName _: String, fromPeer _: MCPeerID, at _: URL?, withError _: Error?) {}
}

// MARK: - Advertiser and browser

extension MultipeerSession: MCNearbyServiceAdvertiserDelegate {
    public func advertiser(_: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Self.log.info("Invitation from \(peerID.displayName, privacy: .public); accepting")
        if let context, let raw = String(data: context, encoding: .utf8) {
            let id = PlayerID(rawValue: raw)
            lock.withLock {
                peersByPlayer[id] = peerID
                playersByPeer[peerID] = id
            }
        }
        invitationHandler(true, session)
    }

    public func advertiser(_: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Self.log.error("Could not start advertising: \(String(describing: error), privacy: .public)")
        problemsContinuation.yield(Self.explain(error, doing: "put your table up"))
    }
}

extension MultipeerSession: MCNearbyServiceBrowserDelegate {
    public func browser(_: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let table = NearbyTable(
            id: info?[Key.playerID] ?? peerID.displayName,
            hostName: info?[Key.hostName] ?? peerID.displayName,
            seated: Int(info?[Key.seated] ?? "") ?? 1,
            capacity: Int(info?[Key.capacity] ?? "") ?? GameConfiguration.playerRange.upperBound
        )
        Self.log.info("Found \(peerID.displayName, privacy: .public): \(table.hostName, privacy: .public)'s table \(table.id, privacy: .public), \(table.seated)/\(table.capacity) seated")
        lock.withLock {
            // One table can be found more than once: over Wi-Fi and over Bluetooth, or
            // again under a fresh peer after the host's advertiser was replaced. They are
            // the same table, and only the newest peer is still listening. Keeping the
            // older one put the table in the list twice, and left `join` free to invite the
            // peer that had already gone, so the guest tapped a table and never arrived.
            discovered = discovered.filter { $0.value.id != table.id }
            discovered[peerID] = table
        }
        publishTables()
    }

    public func browser(_: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Self.log.info("Lost \(peerID.displayName, privacy: .public)")
        lock.withLock { _ = discovered.removeValue(forKey: peerID) }
        publishTables()
    }

    public func browser(_: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Self.log.error("Could not start browsing: \(String(describing: error), privacy: .public)")
        problemsContinuation.yield(Self.explain(error, doing: "look for tables"))
    }

    /// The framework's own wording is not for players, and the usual cause is one thing.
    private static func explain(_ error: Error, doing what: String) -> String {
        let code = (error as NSError).code
        // -72008 is the local network entitlement being refused on the device.
        if code == -72008 || code == -72000 {
            return "Turn on Local Network for this app in Settings, then try again"
        }
        return "Could not \(what)"
    }
}

private extension Optional {
    /// Reads and clears in one step, under a lock held by the caller.
    mutating func take() -> Wrapped? {
        defer { self = nil }
        return self
    }
}
