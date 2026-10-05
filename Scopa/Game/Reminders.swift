import Foundation
import Observation
import ScopaCore
import UserNotifications

/// One local notification a day, and only about the wheel: its free turn is back, at the hour
/// this player usually plays. A day whose turn is already taken gets nothing.
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

    /// Whether today's turn is gone, as last heard from the ledger. Kept so a switch turned on
    /// in the settings plans the same week `refresh` would.
    private var wheelSpentToday = false

    private static let onKey = "reminders.on"
    private static let offeredKey = "reminders.offered"
    /// How many days ahead are planned.
    private static let horizon = 7
    /// No knock in the small hours or late at night, whenever the last deal was played.
    private static let hours = 10...21

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

    /// Plans the week again from today. Called when the app comes to the front and whenever
    /// the wheel is turned, so a day whose turn is taken loses its knock.
    func refresh(_ book: DailyDealBook, wheelSpentToday: Bool) async {
        self.wheelSpentToday = wheelSpentToday
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
        let hour = Self.usualHour(book, calendar: calendar)
        for offset in (wheelSpentToday ? 1 : 0)..<Self.horizon {
            guard let date = calendar.date(byAdding: .day, value: offset, to: .now) else { continue }
            var when = calendar.dateComponents([.year, .month, .day], from: date)
            when.hour = hour
            when.minute = 0
            guard let fire = calendar.date(from: when), fire > .now else { continue }
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
            let day = DailyDeal.day(for: date, calendar: calendar)
            try? await center.add(UNNotificationRequest(identifier: "wheel/\(day)", content: Self.content, trigger: trigger))
        }
    }

    private static var content: UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "The wheel is ready")
        content.body = String(localized: "Your free turn of the day is waiting in the lobby.")
        content.sound = .default
        return content
    }

    /// The hour of the last deal played, kept to the daytime, or early evening when there is none.
    private static func usualHour(_ book: DailyDealBook, calendar: Calendar) -> Int {
        guard let last = book.results.max(by: { $0.playedAt < $1.playedAt }) else { return 18 }
        return min(max(calendar.component(.hour, from: last.playedAt), hours.lowerBound), hours.upperBound)
    }
}
