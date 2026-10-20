import os

/// The app's loggers, one per concern, all under the bundle id so one predicate reads them
/// all: `subsystem == "com.quentinvedrenne.scopa"`. See `Tools/peer-log.sh`.
enum Log {
    static let table = Logger(subsystem: "com.quentinvedrenne.scopa", category: "table")

    /// Every AdMob request and its result. A release build shows nothing on screen when an ad
    /// fails, so this is the only way to tell "no fill" from "misconfigured". See `Tools/ad-log.sh`.
    static let ads = Logger(subsystem: "com.quentinvedrenne.scopa", category: "ads")

    /// The App Store: the denari bags' prices and every purchase of one.
    static let shop = Logger(subsystem: "com.quentinvedrenne.scopa", category: "shop")

    /// Each reminder as it is planned: when it goes out and what it says.
    static let reminders = Logger(subsystem: "com.quentinvedrenne.scopa", category: "reminders")

    /// Every change to the audio session: its category, and when it is claimed and let go.
    /// `nonisolated` because the claim is made off the main actor.
    nonisolated static let audio = Logger(subsystem: "com.quentinvedrenne.scopa", category: "audio")
}
