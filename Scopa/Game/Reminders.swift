import Foundation
import Observation
import ScopaCore
import UserNotifications

/// Two local notifications a day while the deal is unplayed: one at the hour this player
/// usually plays, and a last call in the evening counting down to midnight, when the forty
/// cards turn over and the streak breaks.
///
/// Permission is asked for after the second daily deal, never on a first launch, because iOS
/// only allows the prompt once. Everything is planned on the device, a week at a time.
@MainActor
@Observable
final class Reminders {
    private(set) var isOn: Bool
    /// Whether the offer has been made. It is not made twice.
    private(set) var wasOffered: Bool
    /// Notifications are off in iOS Settings, so the switch here cannot be turned on.
    private(set) var isBlocked = false

    private static let onKey = "reminders.on"
    private static let offeredKey = "reminders.offered"
    /// How many days ahead are planned.
    private static let horizon = 7

    init() {
        isOn = UserDefaults.standard.bool(forKey: Self.onKey)
        wasOffered = UserDefaults.standard.bool(forKey: Self.offeredKey)
    }

    /// Reads both switches again, after `AccountSync` has merged them with the player's other
    /// device. Only the answer travels, never the permission: iOS grants that per device, and
    /// `refresh` is what finds out whether this one has it before planning anything.
    func readStoredAgain() {
        isOn = UserDefaults.standard.bool(forKey: Self.onKey)
        wasOffered = UserDefaults.standard.bool(forKey: Self.offeredKey)
    }

    /// Whether to put the offer in front of the player: two deals played, nothing decided yet.
    func offerIsDue(_ book: DailyDealBook) -> Bool {
        !wasOffered && !isOn && book.results.count >= 2
    }

    func decline() {
        wasOffered = true
        UserDefaults.standard.set(true, forKey: Self.offeredKey)
    }

    /// Asks iOS for permission and plans the week if it is granted.
    @discardableResult
    func turnOn(_ book: DailyDealBook) async -> Bool {
        wasOffered = true
        UserDefaults.standard.set(true, forKey: Self.offeredKey)
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        isBlocked = !granted
        guard granted else { return false }
        isOn = true
        UserDefaults.standard.set(true, forKey: Self.onKey)
        await plan(book)
        return true
    }

    func turnOff() {
        isOn = false
        UserDefaults.standard.set(false, forKey: Self.onKey)
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Plans the week again from today. Called when the app comes to the front and after each
    /// deal, so a played day loses its nudge and tomorrow's streak figure is right.
    func refresh(_ book: DailyDealBook) async {
        guard isOn else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isBlocked = settings.authorizationStatus != .authorized
        guard !isBlocked else { return }
        await plan(book)
    }

    private func plan(_ book: DailyDealBook) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let calendar = Calendar.current
        let knocks = Self.knocks(book, calendar: calendar)
        let streak = book.streak(endingOn: DailyDeal.day())
        // Only the first unplayed day can promise the streak: miss it and there is none left.
        var streakStillStands = streak > 0
        for offset in 0..<Self.horizon {
            guard let date = calendar.date(byAdding: .day, value: offset, to: .now) else { continue }
            let day = DailyDeal.day(for: date, calendar: calendar)
            if book.hasPlayed(day) { continue }
            var planned = false
            for knock in knocks {
                var when = calendar.dateComponents([.year, .month, .day], from: date)
                when.hour = knock.hour
                when.minute = 0
                guard let fire = calendar.date(from: when), fire > .now else { continue }
                let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
                let content = Self.content(knock, streak: streakStillStands ? streak : nil)
                let request = UNNotificationRequest(identifier: "daily/\(day)/\(knock.kind.rawValue)", content: content, trigger: trigger)
                try? await center.add(request)
                planned = true
            }
            if planned { streakStillStands = false }
        }
    }

    private struct Knock {
        enum Kind: String { case nudge, lastCall }
        let kind: Kind
        let hour: Int
    }

    /// When to knock. The nudge lands at the player's own hour; the last call waits for the
    /// evening, late enough to be the evening and early enough to leave a couple of hours of
    /// table. A nudge on the last call's heels is nagging rather than reminding, so a player
    /// who already plays late gets the last call alone.
    private static func knocks(_ book: DailyDealBook, calendar: Calendar) -> [Knock] {
        let usual = usualHour(book, calendar: calendar)
        let lastCall = Knock(kind: .lastCall, hour: usual >= 19 ? 22 : 20)
        guard usual + 2 <= lastCall.hour else { return [lastCall] }
        return [Knock(kind: .nudge, hour: usual), lastCall]
    }

    private static func content(_ knock: Knock, streak: Int?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        switch knock.kind {
        case .nudge:
            content.title = String(localized: "Today's deal is ready")
            content.body = streak.map { String(localized: "Your \($0) day streak is waiting at the table.") }
                ?? String(localized: "The same forty cards for everyone, one round against Hugo.")
        case .lastCall:
            let left = 24 - knock.hour
            content.title = String(localized: "\(left) hours left")
            content.body = streak.map { String(localized: "Your \($0) day streak ends at midnight. Hugo is still at the table.") }
                ?? String(localized: "Today's forty cards go back in the box at midnight.")
        }
        content.sound = .default
        return content
    }

    /// The hour of the last deal played, or early evening when there is none.
    private static func usualHour(_ book: DailyDealBook, calendar: Calendar) -> Int {
        guard let last = book.results.max(by: { $0.playedAt < $1.playedAt }) else { return 18 }
        return calendar.component(.hour, from: last.playedAt)
    }
}
