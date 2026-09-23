import os

/// The app's loggers, one per concern, all under the bundle id so one predicate reads them
/// all: `subsystem == "com.quentinvedrenne.scopa"`. See `Tools/peer-log.sh`.
enum Log {
    static let table = Logger(subsystem: "com.quentinvedrenne.scopa", category: "table")

    /// Every AdMob request and its result. A release build shows nothing on screen when an ad
    /// fails, so this is the only way to tell "no fill" from "misconfigured". See `Tools/ad-log.sh`.
    static let ads = Logger(subsystem: "com.quentinvedrenne.scopa", category: "ads")
}
