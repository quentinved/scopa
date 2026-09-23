import SwiftUI

/// How a ranked game played alone is dealt: heads-up against the one opponent the search
/// finds, or the table of four where a house partner sits behind each of you.
///
/// Solo used to mean the four either way, which made it the same game as a duo with a
/// stranger for a partner: the button said solo and dealt a team game. Heads-up is what the
/// word means, and it is the honest shape for a rated game — nobody's rating moves on hands
/// a bot played. The four stays for anyone who likes the fuller table.
///
/// Both formats look for the same thing, one other phone, but they cannot share a queue:
/// two players who found each other and disagreed about the seats would have nothing to
/// play. See `TableStore.findRankedMatch`, where the format names its own pool.
enum RankedSolo: String, CaseIterable, Identifiable, Sendable {
    case headsUp, teams

    static let `default` = RankedSolo.headsUp

    var id: String { rawValue }

    /// Chairs at the table, yours among them.
    var seatCount: Int {
        switch self {
        case .headsUp: 2
        case .teams: 4
        }
    }

    /// Whether the four score as two sides. A heads-up table is two sides already.
    var teams: Bool { self == .teams }

    /// The segment on the ranked door. Numbers, the way a table size is said out loud at
    /// one: "1v1" is shorter than any phrase for it and needs no translating.
    var pillLabel: String {
        switch self {
        case .headsUp: "1v1"
        case .teams: "2v2"
        }
    }

    /// The same segment, said out loud, where "1v1" is not a word.
    var spokenLabel: LocalizedStringKey {
        switch self {
        case .headsUp: "One against one"
        case .teams: "Two against two"
        }
    }

    /// What the door says this deals, under the picker.
    var detail: LocalizedStringKey {
        switch self {
        case .headsUp: "You and the one opponent the search finds. No house at the table."
        case .teams: "Four seats: one opponent near your league, with the house behind each of you."
        }
    }

    /// The part of the matchmaking pool that keeps the two formats apart. The four keeps the
    /// name it always had, so a phone that has not been updated still meets one that has.
    var pool: String {
        switch self {
        case .headsUp: "ranked/1v1"
        case .teams: "ranked"
        }
    }
}
