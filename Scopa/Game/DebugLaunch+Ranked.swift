import Foundation

/// `-holdMatch` keeps the match-found moment up for eight seconds wherever a real ranked flow
/// shows it (`-rankedHouse`, a duo taking the house), so a screenshot can catch it settled.
extension DebugLaunch {
    static var holdsMatchFound: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-holdMatch")
        #else
        false
        #endif
    }
}
