import Foundation
import ScopaCore

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

/// Gran Maestro, for screenshots. `-season grand` opens the season's board on its Gran
/// Maestro tab, filled with a sample. `-rank 2140` already plants a Gran Maestro at 340
/// points; `-rankPlace 4` gives it a place on the season's board, which makes it a Campione
/// at 300 points or more, and the sample board pins the reader at that place.
extension DebugLaunch {
    static var seasonOpensOnGrand: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-season").flatMap { arguments[safe: $0 + 1] } == "grand"
        #else
        false
        #endif
    }

    static var grandPlace: Int? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-rankPlace").flatMap { Int(arguments[safe: $0 + 1] ?? "") }
        #else
        nil
        #endif
    }
}

#if DEBUG
extension Ladder.RankAnswer.Grand {
    /// Gran Maestro's points for a planted rating, at the place `-rankPlace` names. Nil below it.
    static func pretend(rating: Int) -> Self? {
        guard let points = Ranking.standing(for: rating).points else { return nil }
        let place = DebugLaunch.grandPlace
        return .init(points: points, place: place, campione: Ranking.isCampione(place: place, points: points))
    }
}
#endif

extension DebugLaunch {
    /// `-road grand` opens the road scrolled to its last stop.
    static var roadOpensAtGrand: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-road").flatMap { arguments[safe: $0 + 1] } == "grand"
        #else
        false
        #endif
    }
}
