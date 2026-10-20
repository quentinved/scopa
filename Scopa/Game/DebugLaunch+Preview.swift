import ScopaRewards
import Foundation

extension DebugLaunch {
    /// `-packPreview bottega` opens that pack's preview as the album appears, as a tap on
    /// its row would. Pair it with `-album`.
    static var packPreview: PackTier? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-packPreview")
            .flatMap { arguments[safe: $0 + 1] }
            .flatMap(PackTier.init(rawValue:))
        #else
        return nil
        #endif
    }

    /// `-oddsSheet` opens the album shelf's odds as the album appears; with `-albumEnd` it
    /// opens at its foot, where Oro's are.
    static var showsOddsSheet: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-oddsSheet")
        #else
        false
        #endif
    }
}
