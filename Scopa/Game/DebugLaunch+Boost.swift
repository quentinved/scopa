import Foundation

/// The run of doubled games in a known state, on a simulator whose ledger has seen anything.
///
/// `-boostLeft 7` leaves seven doubled games in the run, `-boostLeft 0` none, so the shop's
/// ticket can be seen either way and the last summary offers one. `-boostOffer` asks for the
/// run once the summary offers it, as a tap would; `-boostOffer buy` buys it outright. With
/// `-lastCard take -target 1` a game is over, and paid, in under a minute.
extension DebugLaunch {
    static var boostLeft: Int? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-boostLeft").flatMap { Int(arguments[safe: $0 + 1] ?? "") }
        #else
        return nil
        #endif
    }

    /// Takes the summary's offer a beat after it shows: asks, or buys with `-boostOffer buy`.
    @MainActor
    static func takeBoostOffer(ask: () -> Void, buy: () -> Void) async {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-boostOffer") else { return }
        try? await Task.sleep(for: .seconds(1.5))
        guard !Task.isCancelled else { return }
        if arguments[safe: index + 1] == "buy" { buy() } else { ask() }
        #endif
    }
}
