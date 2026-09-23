/// How a game was played, recorded on every entry it earns.
///
/// A hot seat game is trivial to farm: deal, sweep, repeat. There is no reason to police
/// that while the purse never leaves the device and buys nothing but colours. The day it
/// lives on a server, a policy has to be written against what actually happened rather than
/// against a guess.
/// Hence: cost nothing now, know everything later.
public enum TableMode: Hashable, Codable, Sendable {
    /// Everyone on their own device, over the local network.
    case multipeer(players: Int)
    /// One device passed around the table.
    case hotSeat(seats: Int)
    /// One device, with some of the seats played by the machine.
    case withBots(seats: Int, bots: Int)
    /// One round against the bot on the deck everybody gets that day, named by the day.
    case dailyDeal(day: String)

    /// How many people were at the table, however they were sitting.
    public var players: Int {
        switch self {
        case .multipeer(let players): players
        case .hotSeat(let seats): seats
        case .withBots(let seats, _): seats
        case .dailyDeal: 2
        }
    }
}

public extension TableMode {
    var isDailyDeal: Bool {
        if case .dailyDeal = self { true } else { false }
    }
}
