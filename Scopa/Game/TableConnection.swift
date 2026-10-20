import Foundation
import Observation
import ScopaCore
import ScopaRelay

/// The reconnect banner's side of an online table: how the line is, what can be done about it,
/// and the seat kept on the phone for coming back after the app was closed.
///
/// What to wait for and when to give up is `TableLink`'s, which is pure and tested. This only
/// feeds it what the transport saw, keeps its clocks, and keeps asking a missing host for the
/// seat back, since that is how a guest finds out the host has returned.
@MainActor
@Observable
final class TableConnection {
    /// Nil away from an online table.
    private(set) var link: TableLink?
    /// What the banner draws. A drop shows a beat late, so one that heals at once never flashes.
    private(set) var shown: TableLink.State = .steady
    /// A seat at a room this phone can go back to, offered by the lobby after a relaunch.
    private(set) var ticket: RejoinTicket?

    @ObservationIgnored private weak var relay: RelaySession?
    @ObservationIgnored private var askHost: (@MainActor () async -> Void)?
    @ObservationIgnored private var lineWatch: Task<Void, Never>?
    @ObservationIgnored private var hostWatch: Task<Void, Never>?
    @ObservationIgnored private var showing: Task<Void, Never>?
    /// The table the kept ticket is for, so it is written once a table rather than every move.
    @ObservationIgnored private var keptCode: String?
    /// The other end of a Game Center match left on purpose, or there is nobody left at it:
    /// Apple failing the match after that is the goodbye, not a line this phone lost.
    @ObservationIgnored private var expectsGoodbye = false

    /// How long a drop has to last before the banner says so.
    static let showDelay: Duration = .milliseconds(1500)
    /// How often a missing host is asked for the seat again.
    static let askEvery: Duration = .milliseconds(2500)
    private static let ticketKey = "rejoinTicket"

    init() {
        ticket = Self.storedTicket()
    }

    // MARK: A table's line

    /// Starts watching a table that has just been sat at. `askHost` sends the join again.
    func begin(_ carrier: TableLink.Carrier, askHost: @escaping @MainActor () async -> Void) {
        stopWatching()
        link = TableLink(carrier: carrier)
        shown = .steady
        expectsGoodbye = false
        self.askHost = askHost
    }

    /// Follows a room's own line: down, back, or given up on.
    func watch(_ session: RelaySession) {
        relay = session
        lineWatch?.cancel()
        lineWatch = Task { [weak self] in
            for await state in session.link {
                guard let self, !Task.isCancelled else { return }
                switch state {
                case .up: self.apply(.restored)
                case .down: self.apply(.dropped)
                case .lost: self.apply(.gaveUp)
                }
            }
        }
    }

    /// Follows a Game Center match, which can only fail: Apple mends nothing once it gives up.
    func watch(failures: AsyncStream<Void>) {
        lineWatch?.cancel()
        lineWatch = Task { [weak self] in
            for await _ in failures {
                guard let self, !Task.isCancelled else { return }
                if !self.expectsGoodbye { self.apply(.gaveUp) }
            }
        }
    }

    /// Leaves the table behind, with nothing left to watch.
    ///
    /// Leaving a room this phone kept a seat at is a choice, so the seat goes with it. A seat
    /// kept from before the app was last closed stays on offer until it is used, put away or
    /// stale: a quick game in between is no reason to lose the way back.
    func end() {
        stopWatching()
        link = nil
        shown = .steady
        relay = nil
        askHost = nil
        if keptCode != nil { forgetTicket() }
    }

    /// The host's phone dropped. A host that can come back is asked for the seat until it does.
    /// `phones` is how many were at the table as it went, the host's included, which is what
    /// decides whether Game Center tries to bring it back.
    func hostLeft(_ name: String, phones: Int) {
        link?.count(phones: phones)
        apply(.hostLeft(name))
        if case .hostAway = link?.state { startWaitingForHost() }
    }

    /// See `expectsGoodbye`: the match failing from here on says nothing about this phone.
    func expectGoodbye() {
        expectsGoodbye = true
    }

    /// Something came from the host, so whatever kept it away is over.
    func hostHeard() {
        guard let state = link?.state, state != .steady else { return }
        apply(.hostBack)
    }

    /// The banner's Reconnect: the same room tried again from the top.
    func reconnect() {
        guard link?.canReconnect == true, let relay else { return }
        relay.reconnect()
        apply(.dropped)
    }

    /// The banner's Keep waiting, for a host who has not come back yet.
    func keepWaiting() {
        apply(.keepWaiting)
        if case .hostAway = link?.state { startWaitingForHost() }
    }

    private func apply(_ event: TableLink.Event) {
        guard var next = link else { return }
        next.apply(event)
        link = next
        if !isAboutHost(next.state) { hostWatch?.cancel() }
        show(next.state)
    }

    /// Shown at once, except a drop of the line, which waits to see if it mends itself.
    private func show(_ state: TableLink.State) {
        showing?.cancel()
        guard state == .reconnecting, shown == .steady else { shown = state; return }
        showing = Task { [weak self] in
            try? await Task.sleep(for: Self.showDelay)
            guard !Task.isCancelled, let self, self.link?.state == .reconnecting else { return }
            self.shown = .reconnecting
        }
    }

    /// Asks for the seat every few seconds while the host is away, and says they have not come
    /// back once the carrier's patience is spent. Asking goes on after that: a room keeps the
    /// host's chair, and the first join after they return is the one that brings the table back.
    private func startWaitingForHost() {
        hostWatch?.cancel()
        let patience = link?.hostPatience ?? .zero
        hostWatch = Task { [weak self] in
            let start = ContinuousClock.now
            while !Task.isCancelled, let self, let state = self.link?.state, self.isAboutHost(state) {
                await self.askHost?()
                try? await Task.sleep(for: Self.askEvery)
                guard !Task.isCancelled else { return }
                if case .hostAway = self.link?.state, ContinuousClock.now - start >= patience {
                    self.apply(.waitedOut)
                }
            }
        }
    }

    private func isAboutHost(_ state: TableLink.State) -> Bool {
        switch state {
        case .hostAway, .hostGone: true
        case .steady, .reconnecting, .lost: false
        }
    }

    private func stopWatching() {
        lineWatch?.cancel(); lineWatch = nil
        hostWatch?.cancel(); hostWatch = nil
        showing?.cancel(); showing = nil
    }

    // MARK: The seat kept for later

    /// Keeps a guest's seat on the phone, once per table.
    func keep(_ ticket: RejoinTicket) {
        guard keptCode != ticket.code else { return }
        keptCode = ticket.code
        if let data = try? JSONEncoder().encode(ticket) { UserDefaults.standard.set(data, forKey: Self.ticketKey) }
    }

    /// The game is over, or was walked out of: nothing to come back to.
    func forgetTicket() {
        keptCode = nil
        ticket = nil
        UserDefaults.standard.removeObject(forKey: Self.ticketKey)
    }

    /// Puts a seat back on the lobby's offer, after a try at it could not reach the room.
    func offer(_ ticket: RejoinTicket) {
        keep(ticket)
        self.ticket = ticket
    }

    /// Asks the room whether it is still there, and drops the offer if it is not. A phone that
    /// cannot reach the Worker keeps it: the room may well be there, and the tap will find out.
    func confirmTicket(with rooms: Relay?) async {
        #if DEBUG
        guard !pretendsTicket else { return }
        #endif
        guard let ticket, let rooms else { return }
        do {
            _ = try await rooms.status(of: ticket.code)
        } catch RelayError.noSuchTable {
            forgetTicket()
        } catch {
            // Offline, or the Worker is down: the offer stays.
        }
    }

    private static func storedTicket() -> RejoinTicket? {
        guard let data = UserDefaults.standard.data(forKey: ticketKey),
              let ticket = try? JSONDecoder().decode(RejoinTicket.self, from: data) else { return nil }
        guard ticket.isFresh() else {
            UserDefaults.standard.removeObject(forKey: ticketKey)
            return nil
        }
        return ticket
    }

    #if DEBUG
    /// Puts the banner up in `state` without a network, for `-reconnect`.
    func pretend(_ state: TableLink.State, carrier: TableLink.Carrier) {
        var link = TableLink(carrier: carrier)
        switch state {
        case .steady: break
        case .reconnecting: link.apply(.dropped)
        case .lost: link.apply(.gaveUp)
        case .hostAway(let name), .hostGone(let name):
            link.apply(.hostLeft(name))
            if case .hostGone = state { link.apply(.waitedOut) }
        }
        self.link = link
        shown = link.state
    }

    /// Offers a seat on the lobby without a game behind it, for `-reconnect rejoin`. The room
    /// is made up, so the Worker is not asked about it.
    func pretend(_ ticket: RejoinTicket) {
        pretendsTicket = true
        self.ticket = ticket
    }

    @ObservationIgnored private var pretendsTicket = false
    #endif
}
