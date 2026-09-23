/// A table played for denari.
///
/// The stake leaves the purse before the deal and the pot comes back to the winner, with
/// the table putting in half a stake of its own. Every wager therefore mints a little
/// rather than skimming, which is the opposite of the coin-trap card apps: playing for
/// denari never drains the room, and nobody is ever short *because* they played.
public enum Stake: Int, CaseIterable, Codable, Sendable, Hashable, Identifiable {
    case small = 50
    case medium = 200
    case large = 500

    public var id: Int { rawValue }
    public var amount: Denari { Denari(rawValue) }
    /// What the winner takes at a table for two: both stakes, and half of one again from
    /// the table.
    public var payout: Denari { payout(players: 2) }

    /// What the winner takes at a table of `players`: every stake, plus a quarter of the
    /// pot again from the table. Five hundred for two at 200; a thousand for four.
    public func payout(players: Int) -> Denari {
        Denari(rawValue * max(players, 2) * 5 / 4)
    }
}

public enum WagerError: Error, Hashable, Sendable {
    /// How much more was needed to sit down.
    case short(Denari)
}
