import Foundation
import ScopaCore
import ScopaRewards

/// Oro and Perla without a season of packs behind them.
///
/// `-oro` opens the album on the gold book; `-oro 23` with that many foils in it, in deck
/// order. `-perla` opens it on the pearl book, locked with `-oro 23` beside it; `-perla 23`
/// with Oro full and that many pearl foils. `-packFoil` has every card of the next pack come out foil, and `-packFoil 7d` only
/// that one, so with `-album -openPack bottega -packCards 3c,7d` the foil reveal can be looked
/// at, in pearl once Oro is full. `-cardEdge madreperla` wears Madreperla, owned or not.
extension DebugLaunch {
    static var showsOro: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-oro")
        #else
        false
        #endif
    }

    /// The foils `-oro` plants, or nil to leave Oro as it is.
    static var oroFound: Int? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-oro").flatMap { arguments[safe: $0 + 1] }.flatMap { Int($0) }
        #else
        return nil
        #endif
    }

    static var packFoil: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-packFoil")
        #else
        false
        #endif
    }

    /// Whether `-packFoil` makes this card foil: every card, or only those it names.
    static func rigsFoil(_ card: Card) -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard let names = arguments.firstIndex(of: "-packFoil").flatMap({ arguments[safe: $0 + 1] }),
              !names.hasPrefix("-") else { return true }
        return names.split(separator: ",").contains { $0 == card.description }
    }

    static var showsPerla: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-perla")
        #else
        false
        #endif
    }

    /// The pearl foils `-perla` plants over a full Oro, or nil to leave both as they are.
    static var perlaFound: Int? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-perla").flatMap { arguments[safe: $0 + 1] }.flatMap { Int($0) }
        #else
        return nil
        #endif
    }

    /// The foil album the album opens on, if a flag asked for one.
    static var shownFoilAlbum: FoilAlbum? {
        showsPerla ? .perla : showsOro ? .oro : nil
    }

    /// `-cardEdge madreperla` is read as the stored preference; in a debug build it is also worn
    /// before the ledger owns it, so a table can be dealt in it for a screenshot.
    static var wornEdge: CardEdge? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-cardEdge").flatMap { arguments[safe: $0 + 1] }.flatMap(CardEdge.init(rawValue:))
        #else
        return nil
        #endif
    }
}
