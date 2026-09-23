/// Why denari were earned. Every value in the economy is on this one page, so re-balancing
/// it is a single edit and never a hunt.
///
/// The list deliberately pays for the *moments* rather than only the win. Scopa is a game
/// you often play against people sitting next to you, and someone who loses four in a row
/// should still leave the table with something to spend.
public enum Earning: String, CaseIterable, Codable, Sendable, Hashable {
    /// Reaching the target score first.
    case wonGame
    /// Sitting a losing game out to the end. Quitting early earns nothing, which is the
    /// only nudge in here and the one worth having.
    case lostGame
    /// Each table swept clean. The signature move, so it pays every time.
    case scopa
    /// Each round finished holding the seven of coins.
    case settebello
    /// Each round where one side took all four categories.
    case cappotto
    /// The first game finished on a given day.
    case firstOfDay
    /// Today's deal played out to the end. Once a day, whatever the result.
    case dailyDeal
    /// Today's deal finished with more points than the bot.
    case dailyDealWon

    /// What one of these is worth.
    public var unitValue: Denari {
        switch self {
        case .wonGame: 25
        case .lostGame: 10
        case .scopa: 3
        case .settebello: 5
        case .cappotto: 15
        case .firstOfDay: 20
        case .dailyDeal: 20
        case .dailyDealWon: 15
        }
    }

    /// How it reads on the end-of-game screen, given how many of them there were.
    public func title(count: Int) -> String {
        switch self {
        case .wonGame: "Game won"
        case .lostGame: "Game finished"
        case .scopa: count == 1 ? "Scopa" : "\(count) scope"
        case .settebello: count == 1 ? "Settebello" : "Settebello ×\(count)"
        case .cappotto: count == 1 ? "Cappotto" : "Cappotto ×\(count)"
        case .firstOfDay: "First game today"
        case .dailyDeal: "Today's deal"
        case .dailyDealWon: "Beat the bot"
        }
    }
}

/// One line of the end-of-game tally: something that happened, how often, and what it paid.
public struct Award: Hashable, Codable, Sendable {
    public let earning: Earning
    public let count: Int

    public init(_ earning: Earning, count: Int = 1) {
        self.earning = earning
        self.count = count
    }

    public var value: Denari { earning.unitValue * count }
    public var title: String { earning.title(count: count) }
}
