/// How this phone's hold on an online table is doing, as the reconnect banner tells it.
///
/// Pure, so when to wait and when to give up can be tested without a network: the app feeds
/// it what the transport saw and draws whatever state comes out.
///
/// What can be waited for depends on what carries the table. Our own room on the Worker keeps
/// every seat, so a phone that drops can always come back to it. Game Center only tries to
/// bring a dropped phone back at a table of two, and Multipeer never does.
public struct TableLink: Equatable, Sendable {
    public enum Carrier: Equatable, Sendable {
        /// A room on the Worker.
        case relay
        /// A Game Center match, and how many phones are in it.
        case gameCenter(phones: Int)
        /// Multipeer, in the same room.
        case nearby
    }

    public enum State: Equatable, Sendable {
        case steady
        /// This phone's own connection dropped, and is being remade on its own.
        case reconnecting
        /// This phone's own connection was given up on.
        case lost
        /// The host's phone dropped, and may yet come back. Named, for the banner.
        case hostAway(String)
        /// The host's phone is not coming back over this carrier, or has not for a long while.
        case hostGone(String)
    }

    public enum Event: Equatable, Sendable {
        case dropped
        case restored
        case gaveUp
        case hostLeft(String)
        /// The host answered: a lobby or a view arrived from it.
        case hostBack
        /// The host was waited for as long as `hostPatience`.
        case waitedOut
        /// The player chose to wait longer for a host who has not come back.
        case keepWaiting
    }

    public private(set) var carrier: Carrier
    public private(set) var state: State = .steady

    public init(carrier: Carrier) {
        self.carrier = carrier
    }

    /// The phones at the table now, counted when somebody drops. Game Center mends a table of
    /// two and no other, and a table is not always the size it was when it was sat at: a third
    /// friend arrives, or one leaves.
    public mutating func count(phones: Int) {
        if case .gameCenter = carrier { carrier = .gameCenter(phones: phones) }
    }

    /// How long a host who dropped is waited for before the banner says they have not come
    /// back. A room keeps their seat for as long as anybody likes, so the wait there is only
    /// when the question is first put; a match Apple will not mend is not waited on at all.
    public var hostPatience: Duration {
        switch carrier {
        case .relay: .seconds(120)
        case .gameCenter(let phones): phones == 2 ? .seconds(20) : .zero
        case .nearby: .zero
        }
    }

    /// Whether this phone can try again itself. Only a room can be walked back into.
    public var canReconnect: Bool { carrier == .relay }

    /// Whether a host who has gone quiet can still come back to this table.
    public var hostCanReturn: Bool { hostPatience > .zero }

    public mutating func apply(_ event: Event) {
        state = next(after: event)
    }

    private func next(after event: Event) -> State {
        switch event {
        case .dropped: canReconnect ? .reconnecting : state
        // This phone's own line is back, which says nothing about a host already being waited
        // for: the line and the host are heard on two streams, in either order.
        case .restored: isAboutHost ? state : .steady
        case .gaveUp: .lost
        case .hostLeft(let name): hostCanReturn ? .hostAway(name) : .hostGone(name)
        case .hostBack: isAboutHost ? .steady : state
        case .waitedOut:
            if case .hostAway(let name) = state { .hostGone(name) } else { state }
        case .keepWaiting:
            if case .hostGone(let name) = state, hostCanReturn { .hostAway(name) } else { state }
        }
    }

    private var isAboutHost: Bool {
        switch state {
        case .hostAway, .hostGone: true
        case .steady, .reconnecting, .lost: false
        }
    }
}
