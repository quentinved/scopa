import Foundation
import Observation
import os
import ScopaCore
import ScopaRewards
import UserNotifications

/// At most one local notification a day, at the hour this player usually plays, about the
/// most pressing thing waiting that day: the week's tasks or the season closing, a run of
/// daily deals, or the wheel and the day's deal. Besides those, one comeback three days after
/// the app was last in front and one after seven. `NudgePlanner` decides; this words and plans.
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

    /// What the last plan was drawn from. Kept so a switch turned on in the settings plans
    /// the same week `refresh` would.
    private var inputs: Inputs?

    private static let onKey = "reminders.on"
    private static let offeredKey = "reminders.offered"

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
    func turnOn() async -> Bool {
        wasOffered = true
        UserDefaults.standard.set(true, forKey: Self.offeredKey)
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        isBlocked = !granted
        guard granted else { return false }
        isOn = true
        UserDefaults.standard.set(true, forKey: Self.onKey)
        await plan()
        return true
    }

    func turnOff() {
        isOn = false
        UserDefaults.standard.set(false, forKey: Self.onKey)
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Plans the week again from now. Called when the app comes to the front, which moves the
    /// comebacks along, and whenever something the plan reads changes: the wheel turned, the
    /// deal played, a task moved, a pack opened.
    func refresh(_ inputs: Inputs) async {
        self.inputs = inputs
        #if DEBUG
        if DebugLaunch.firesRemindersNow {
            await fireForDebugging(inputs)
            return
        }
        #endif
        guard isOn else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isBlocked = settings.authorizationStatus != .authorized
        guard !isBlocked else { return }
        await plan()
    }

    private func plan() async {
        guard let inputs else { return }
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let calendar = Calendar.current
        for planned in NudgePlanner.plan(inputs.facts, now: .now, calendar: calendar) {
            let content = Self.content(planned, locale: inputs.locale)
            let when = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: planned.fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
            let day = DailyDeal.day(for: planned.fire, calendar: calendar)
            try? await center.add(UNNotificationRequest(identifier: "reminder/\(day)", content: content, trigger: trigger))
            Self.log(planned, content)
        }
    }

    private static func content(_ planned: NudgePlanner.Planned, locale: Locale) -> UNMutableNotificationContent {
        let words = ReminderCopy.words(for: planned.nudge, variant: planned.variant, locale: locale)
        let content = UNMutableNotificationContent()
        content.title = words.title
        content.body = words.body
        content.sound = .default
        return content
    }

    private static func log(_ planned: NudgePlanner.Planned, _ content: UNNotificationContent) {
        let fire = planned.fire.formatted(date: .abbreviated, time: .shortened)
        Log.reminders.info("\(fire, privacy: .public) \(content.title, privacy: .public) | \(content.body, privacy: .public)")
    }
}

extension Reminders {
    /// Everything a plan is drawn from, the language included, so a change to any of it
    /// plans the week again.
    struct Inputs: Hashable {
        let facts: NudgeFacts
        let locale: Locale
    }

    /// Read off the books once the ledger and the daily book are both loaded: before that,
    /// the wheel would look unturned and the usual hour unknown.
    static func inputs(_ store: TableStore, purse: PurseStore) -> Inputs? {
        guard purse.isReady, store.dailyBook.isLoaded else { return nil }
        let today = store.today
        var facts = NudgeFacts()
        facts.lastDeal = store.dailyBook.results.map(\.playedAt).max()
        facts.wheelSpentToday = purse.purse.keys.contains(DailyWheel.Ticket.free.key(on: today))
        facts.dealPlayedToday = store.dailyBook.hasPlayed(today)
        facts.streak = store.dailyStreak
        facts.weekEnds = store.challenges.endsAt
        facts.weeklyLeft = store.challenges.goals.count - store.challenges.tasksDone
        facts.weeklyStarted = store.challenges.steps > 0
        facts.packs = store.albumBook.waiting(on: .album)
        if let rank = store.rank, rank.games > 0 {
            facts.seasonEnds = rank.seasonEnds
            facts.league = rank.standing.league
            facts.division = rank.standing.division
        }
        return Inputs(facts: facts, locale: store.language.locale ?? .autoupdatingCurrent)
    }
}

#if DEBUG
extension Reminders {
    private static var firedForDebugging = false

    /// The week as planned, five seconds apart from five seconds on, shown over the app too
    /// and whatever the switch says. Once per launch, so a later refresh does not restart it.
    private func fireForDebugging(_ inputs: Inputs) async {
        guard !Self.firedForDebugging else { return }
        Self.firedForDebugging = true
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        center.delegate = ForegroundBanners.shared
        center.removeAllPendingNotificationRequests()
        for (index, planned) in NudgePlanner.plan(inputs.facts, now: .now).enumerated() {
            let content = Self.content(planned, locale: inputs.locale)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(index + 1) * 5, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "debug/\(index)", content: content, trigger: trigger))
            Self.log(planned, content)
        }
    }
}

/// Lets a notification show while the app is open, which iOS otherwise keeps quiet.
private final class ForegroundBanners: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ForegroundBanners()

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
#endif

extension DebugLaunch {
    /// `-remindersNow` sends the planned week five seconds apart, starting five seconds in,
    /// and logs each one under `Log.reminders`.
    static var firesRemindersNow: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-remindersNow")
        #else
        false
        #endif
    }
}
