import Foundation

/// Who deals at a table of phones that met with nobody in charge.
///
/// Named outright where the table knows it: an invitation names its sender, and a room says who
/// opened it. Otherwise the smallest id among everyone at the table, which every phone works out
/// for itself and gets the same answer to, so long as each is looking at the same table.
public enum TableHost {
    public static func elect(declared: PlayerID?, local: PlayerID, others: [PlayerID]) -> PlayerID {
        if let declared { return declared }
        return ([local] + others).min { $0.rawValue < $1.rawValue } ?? local
    }
}

/// Where the partner's phone stands while it follows a duo's search: whether to sit down at the
/// room the queue paired the pair at, keep following, or give up because the leader has gone.
///
/// The leader leaves the held table the moment it is paired, so its leaving is the usual sign
/// that a pairing is waiting. Only an answer asked for after it left can say there is none: one
/// already on its way when it left was asked before the pairing existed.
public enum DuoFollow: Equatable, Sendable {
    case sitDown
    case keepFollowing
    case abandon

    public static func verdict(paired: Bool, leaderLeftBeforeAsking: Bool, leaderLeftNow: Bool) -> DuoFollow {
        if paired { return .sitDown }
        return leaderLeftNow && leaderLeftBeforeAsking ? .abandon : .keepFollowing
    }
}

/// What a phone does when somebody's connection to the table goes.
///
/// One answer for every carrier, so a host dropping is handled the same over the Worker, Game
/// Center and the Wi-Fi, and only how long it is waited for differs (see `TableLink`).
public enum Departure: Equatable, Sendable {
    /// A duo waiting at its held table before the deal: the pair is broken, and the search with it.
    case pairBroke
    /// The host's phone went mid-game. The game is on that phone, so this one waits for it.
    case waitForHost
    /// The host went from a table that cannot wait for it: the waiting room, or a phone with
    /// nothing watching the line.
    case leave
    /// Anybody else went, or the game was already over: their chair is the house's, and a
    /// finished game keeps its summary.
    case coverSeat

    public static func of(hostWent: Bool, thisPhoneHosts: Bool, heldDuo: Bool, dealt: Bool, finished: Bool,
                          watched: Bool) -> Departure {
        if heldDuo, !dealt { return .pairBroke }
        guard hostWent, !thisPhoneHosts, !finished else { return .coverSeat }
        return dealt && watched ? .waitForHost : .leave
    }
}

/// The first minutes of a ranked game, when walking out of it or dropping off it costs nobody
/// anything: the game is called off rather than lost, and nobody's run is broken.
///
/// The phone walking out judges by its own clock from the deal. Every other phone hears of it
/// late — a dropped line can take minutes to be noticed — so it judges by the last card or
/// reaction it saw from the empty chair, which is when that phone was last surely there.
public enum EarlyExit {
    /// How long after the deal a ranked game can be left for nothing.
    public static let window: TimeInterval = 120
    /// Given on top to a chair heard from another phone: the host's clock starts before a
    /// guest's, which only sees the deal once it arrives.
    public static let allowance: TimeInterval = 10

    /// Whether this phone walking out at `moment` leaves the ladder out of it. A game whose deal
    /// this phone never saw, picked up again after a relaunch, is past its first minutes.
    public static func isFree(dealtAt: Date?, at moment: Date) -> Bool {
        guard let dealtAt else { return false }
        return moment.timeIntervalSince(dealtAt) < window
    }

    /// Whether a chair emptying calls the game off. `lastSeen` is the last card or reaction
    /// from it, nil when it had not been heard from since the deal.
    public static func callsOff(dealtAt: Date?, lastSeen: Date?) -> Bool {
        guard let dealtAt else { return false }
        return (lastSeen ?? dealtAt).timeIntervalSince(dealtAt) < window + allowance
    }
}
