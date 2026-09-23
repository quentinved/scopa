import Foundation

/// One shared deck per day, so every player's daily game is decided by play rather than
/// by the deal. The seed is derived from the day's name, so no server is involved.
public enum DailyDeal {
    /// The player against one bot.
    public static let seats = 2

    /// "2026-09-08" in the player's own calendar, so the deal changes at local midnight.
    public static func day(for date: Date = .now, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// FNV-1a over the day's name. Stable across app versions.
    public static func seed(for day: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in day.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return hash
    }

    /// Seeds both the deck and the bot's tie-breaks, so every phone plays the same table.
    public static func generator(for day: String) -> SeededGenerator {
        SeededGenerator(seed: seed(for: day))
    }
}
