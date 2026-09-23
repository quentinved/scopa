import Foundation

/// Turns an AdMob failure into a line for the log.
///
/// Codes are read off the `NSError` rather than through the SDK's `RequestError` enum,
/// whose Swift names were renamed across a major version. The domain and numbers are stable.
enum AdTrouble {
    /// The AdMob error domain, `GADErrorDomain`.
    private static let domain = "com.google.admob"

    /// One line for a failure: AdMob's code, what it means, and the SDK's own description.
    static func words(for error: Error) -> String {
        let error = error as NSError
        guard error.domain == Self.domain else {
            return "\(error.domain) \(error.code): \(error.localizedDescription)"
        }
        var words = "\(name(of: error.code)) (\(error.code)): \(error.localizedDescription)"
        if let reason = error.localizedFailureReason { words += ". \(reason)" }
        return words
    }

    /// `GADErrorCode` spelled out. Unlisted codes are reported by number.
    private static func name(of code: Int) -> String {
        switch code {
        case 0: "invalid request: no ad unit id, or no root view controller"
        case 1: "no fill: the request was valid, AdMob had nothing to serve"
        case 2: "network error"
        case 3: "server error"
        case 5: "timed out"
        case 7: "mediation data error"
        case 8: "mediation adapter error"
        case 10: "mediation invalid ad size"
        case 11: "internal error"
        case 12: "invalid argument"
        case 19: "ad already used"
        case 20: "GADApplicationIdentifier missing from Info.plist"
        case 21: "invalid ad string"
        default: "unrecognised"
        }
    }
}
