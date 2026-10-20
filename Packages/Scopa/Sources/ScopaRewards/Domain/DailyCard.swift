import ScopaCore

/// What today's deal hands over besides its denari: a card for the album every day it is
/// played to the end, and a whole pack every seventh day of a run.
///
/// The card is drawn the way a pack's cards are, from the same deck by the same weights:
/// one card at a pack tier's odds, the earned pack's for finishing and the next tier's for
/// beating the bot. No promise comes with it, so the odds printed for it are the odds. It
/// goes into the volume being collected, and is as hard to find there as a pack's card.
public enum DailyCard {
    /// The pack whose odds the day's card is drawn at.
    public static func odds(won: Bool) -> PackTier { won ? .bottega : .mazzetto }

    /// The day's card, for the volume it goes into.
    public static func draw(won: Bool, volume: Volume = .riviera,
                            using generator: inout some RandomNumberGenerator) -> Card {
        Pack.drawOne(luck: Pack.luck(odds(won: won), volume), using: &generator)
    }

    /// The chance the day's card is at least this good. There is only the one card, so this
    /// is per card rather than per pack.
    public static func chance(ofAtLeast rarity: Rarity, won: Bool, volume: Volume = .riviera) -> Double {
        Rarity.allCases.filter { $0 >= rarity }
            .reduce(0.0) { $0 + Pack.chance(of: $1, in: odds(won: won), volume: volume) }
    }

    /// How many days in a row bring a pack round.
    public static let packEvery = 7

    /// The pack a run pays on the day it reaches this length, if any: a Bottega for the
    /// first week, then a Velluto for the second and every week after it.
    public static func pack(onStreak days: Int) -> PackTier? {
        guard days > 0, days % packEvery == 0 else { return nil }
        return days == packEvery ? .bottega : .velluto
    }

    /// The next run length that pays a pack.
    public static func nextPack(after days: Int) -> Int {
        (max(days, 0) / packEvery + 1) * packEvery
    }

    /// The ledger's name for the day's card: one a day, whichever device played the deal.
    /// Beside the deal's own `daily/<day>/...` keys, so the day reads as one block.
    public static func cardKey(day: String) -> String { "daily/\(day)/card" }

    /// The ledger's name for a run's pack, kept on the day the run reached it.
    public static func packKey(day: String) -> String { "daily/\(day)/pack" }
}
