import SwiftUI

/// How many seats a quick game deals, and whether four players score as two sides. The
/// lobby's own tile picks it and the answer is remembered. Every option here is one phone
/// against bots: a table of people is set up on the pass-the-phone page instead.
enum QuickTable: String, CaseIterable, Identifiable, Sendable {
    case two, three, four, fourInTeams

    static let `default` = QuickTable.two

    var id: String { rawValue }

    /// Rebuilds the case from the seat count and teams flag the sheet holds.
    init(seats: Int, teams: Bool) {
        switch (seats, teams) {
        case (2, _): self = .two
        case (3, _): self = .three
        case (_, true): self = .fourInTeams
        default: self = .four
        }
    }

    /// Chairs at the table, yours among them.
    var seatCount: Int {
        switch self {
        case .two: 2
        case .three: 3
        case .four, .fourInTeams: 4
        }
    }

    /// Whether the four score as two sides rather than four.
    var teams: Bool { self == .fourInTeams }

    /// The pill on the lobby's quick tile. Numbers, because four pills of words would not
    /// fit across half a phone — "2v2" is the one that has to say more than a count.
    var pillLabel: String {
        switch self {
        case .two: "2"
        case .three: "3"
        case .four: "4"
        case .fourInTeams: "2v2"
        }
    }

    /// The same pill, said out loud, where "2v2" is not a word.
    var spokenLabel: LocalizedStringKey {
        switch self {
        case .two: "Two players"
        case .three: "Three players"
        case .four: "Four players"
        case .fourInTeams: "Four players, in teams"
        }
    }

    /// Who takes the seats after yours, in seat order. Partners sit opposite, so in teams the
    /// dealer moves across from you and the four-hander is you and Hugo against the other two.
    var botNames: [String] {
        var names = Array(BotNames.all.prefix(seatCount - 1))
        if teams { names.swapAt(0, 1) }
        return names
    }
}
