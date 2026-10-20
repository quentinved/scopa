import Foundation
import ScopaCore
import ScopaRewards

/// The album's trade and its road, shown without collecting for them.
///
/// `-scambio` opens the album with a trade asked for: the rarest card the spares can bring
/// in, or `-scambio 10b` that one, named the way `Card.description` writes it. Spares are
/// planted first when there are none to trade with; pair it with `-collected 30`. Add `now`
/// to make the trade without asking, and watch the card come in.
///
/// `-albumMilestone 40` shows that stop on the album's road being paid, without paying it;
/// `-albumMilestone 90 late` with the note an album older than the road gets.
extension DebugLaunch {
    static var scambio: (card: Card?, now: Bool)? {
        #if DEBUG
        guard let words = words(after: "-scambio") else { return nil }
        let card = words.lazy.compactMap { name in Deck.standard.first { $0.description == name } }.first
        return (card, words.contains("now"))
        #else
        return nil
        #endif
    }

    static var albumMilestone: (stop: Int, late: Bool)? {
        #if DEBUG
        guard let words = words(after: "-albumMilestone"), let stop = words.first.flatMap(Int.init),
              AlbumRoad.stops.contains(stop) else { return nil }
        return (stop, words.contains("late"))
        #else
        return nil
        #endif
    }

    /// The words after a flag up to the next one, or nil when the flag was not passed.
    private static func words(after flag: String) -> [String]? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        return Array(arguments.dropFirst(index + 1).prefix { !$0.hasPrefix("-") })
    }

    #if DEBUG
    /// Three more of every card the open volume has, so there is something to trade.
    @MainActor
    static func plantSpares(in book: AlbumBook) {
        guard book.offers.isEmpty else { return }
        let found = Deck.standard.filter { book.openAlbum.has($0) && $0 != .settebello }
        for card in found {
            for _ in 0..<3 { _ = book.openCard(card, odds: .mazzetto) }
        }
    }
    #endif
}
