import Foundation

/// The lobby's moods, without a Worker or a game left half played.
///
/// `-ladderEmpty` has the day's board answer with nobody on it, today and yesterday;
/// `-ladderFull` with a made-up room, so the strip can be looked at either way offline.
/// `-noResume` keeps a saved game's door off the lobby, for the column at its shortest.
extension DebugLaunch {
    /// The board to show instead of asking the Worker, or nil to ask it.
    static func plantedLadder(day: String) -> Ladder.Board? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ladderEmpty") { return Ladder.Board(day: day, top: [], you: nil) }
        if arguments.contains("-ladderFull") { return Ladder.Board(day: day, top: sampleRows, you: nil) }
        return nil
        #else
        return nil
        #endif
    }

    static var hidesResume: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-noResume")
        #else
        false
        #endif
    }

    private static let sampleRows: [Ladder.Board.Row] = [
        ("Giulia", 6, 11, 5, 2), ("Marco", 4, 11, 7, 1), ("Sofia", 3, 11, 8, 0),
        ("Luca", 1, 11, 10, 1), ("Anna", -2, 9, 11, 0),
    ].map { name, margin, mine, theirs, scope in
        Ladder.Board.Row(id: "G:\(name.lowercased())", name: name, margin: margin, mine: mine,
                         theirs: theirs, scope: scope, accuracy: nil)
    }
}

extension TableStore {
    /// The day's board, or the one a debug launch planted in its place.
    func boardToShow(day: String) async -> Ladder.Board? {
        if let planted = DebugLaunch.plantedLadder(day: day) { return planted }
        return await ladderBoard(day: day)
    }
}
