import SwiftUI

/// The patron's things on demand, for a screenshot.
///
/// `-patron` plays as an owner of the no-ads purchase (as `-adFree` does) and opens the shop
/// with the gold page up over it. `-adFree -shop` is the owner's shop without it, and
/// `-icons` opens Settings on the app icons: with `-adFree` the patron's is unlocked.
extension DebugLaunch {
    static var showsPatron: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-patron")
        #else
        false
        #endif
    }

    static var showsIcons: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-icons")
        #else
        false
        #endif
    }
}

extension View {
    /// Under `-icons`, scrolls Settings down to the app icons once it has risen. Inert without.
    func scrollsToIconsForDebugging() -> some View {
        ScrollViewReader { reader in
            task {
                #if DEBUG
                guard DebugLaunch.showsIcons else { return }
                try? await Task.sleep(for: .milliseconds(700))
                reader.scrollTo("icons", anchor: .center)
                #endif
            }
        }
    }
}
