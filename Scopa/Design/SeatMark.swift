import ScopaCore
import SwiftUI

/// The mark on a seat: the initial of the name unless the player chose something else.
/// It travels inside `Player`, so the phones across the table draw it too.
enum SeatMark: String, CaseIterable, Identifiable {
    // In the order they are earned, which is the order the picker shows them. The bought
    // ones come last so they do not read as a shortcut past the earned ones.
    case initial, leaf, heart, star, moon, sun, bolt, flame, broom, crown
    // One per suit, worn by whoever has collected all ten of it in the album.
    case coins, cups, swords, clubs
    // All forty: the album's own prize, and the only mark struck in sovereign metal that
    // is not the crown.
    case settebello
    case sail, wine, dice, espresso

    /// The marks that are bought rather than played for.
    static let forSale: [SeatMark] = [.sail, .wine, .dice, .espresso]

    var isForSale: Bool { Self.forSale.contains(self) }

    /// What it takes to wear one. Nil for the mark everybody starts with.
    enum Requirement: Hashable {
        case wins(Int)
        case scope(Int)
        case streak(Int)
        /// Every card of one suit, found in the album.
        case suit(Suit)
        /// Every card in the deck, found in the album.
        case deck

        var label: LocalizedStringKey {
            switch self {
            case .wins(let n): "^[\(n) win](inflect: true)"
            case .scope(let n): "\(n) scope"
            case .streak(let n): "\(n)-day streak"
            // Spelled out one suit at a time rather than interpolated: a key with a noun
            // dropped into it is a key no translator can put a case ending on.
            case .suit(.coins): "All ten coins"
            case .suit(.cups): "All ten cups"
            case .suit(.swords): "All ten swords"
            case .suit(.clubs): "All ten clubs"
            case .deck: "All forty cards"
            }
        }

        func isMet(by progress: MarkProgress) -> Bool {
            switch self {
            case .wins(let n): progress.wins >= n
            case .scope(let n): progress.scope >= n
            case .streak(let n): progress.streak >= n
            case .suit(let suit): progress.suits.contains(suit)
            case .deck: progress.deck
            }
        }
    }

    /// What it takes to wear each mark. Nil where there is nothing to meet.
    var requirement: Requirement? {
        switch self {
        case .initial: nil
        case .leaf: .wins(1)
        case .heart: .wins(5)
        case .star: .wins(15)
        case .moon: .wins(30)
        case .sun: .wins(50)
        case .bolt: .scope(25)
        case .flame: .streak(7)
        case .broom: .wins(100)
        case .crown: .wins(250)
        // Collected rather than won: the album is the only way to these four.
        case .coins: .suit(.coins)
        case .cups: .suit(.cups)
        case .swords: .suit(.swords)
        case .clubs: .suit(.clubs)
        case .settebello: .deck
        // Bought, so there is nothing to meet.
        case .sail, .wine, .dice, .espresso: nil
        }
    }

    /// Whether playing has earned it. A mark that is for sale is never earned this way:
    /// buying is the only route to one.
    func isUnlocked(by progress: MarkProgress) -> Bool {
        guard !isForSale else { return false }
        return requirement?.isMet(by: progress) ?? true
    }

    /// The metal round the circle, one tier more for every tier of wins. Marks earned
    /// another way sit at studded.
    var prestige: Prestige {
        switch self {
        case .initial: .none
        case .leaf: .ring
        case .heart, .bolt, .flame: .studded
        // A suit is ten cards' patience rather than a run of wins, and the metal says so
        // without claiming a rung on a ladder it was never climbing.
        case .coins, .cups, .swords, .clubs: .studded
        // Forty cards, the settebello among them, is a season's patience at the least: the
        // same metal as two hundred and fifty wins, which is about what it takes.
        case .settebello: .sovereign
        case .star: .bezel
        case .moon: .plated
        case .sun: .armoured
        case .broom: .royal
        case .crown: .sovereign
        // The lowest metal there is: a bought mark must not look hard-won.
        case .sail, .wine, .dice, .espresso: .ring
        }
    }

    var id: String { rawValue }

    /// Where the phone keeps its owner's choice.
    static let stored = "seatMark"

    init(_ player: Player) {
        self = player.mark.flatMap(SeatMark.init(rawValue:)) ?? .initial
    }

    /// What goes on the wire. Nothing for the default, so an older build reads it as before.
    var wireValue: String? { self == .initial ? nil : rawValue }

    /// The suit this mark is, for the four the album pays out. Nil for every other mark.
    var suit: Suit? {
        switch self {
        case .coins: .coins
        case .cups: .cups
        case .swords: .swords
        case .clubs: .clubs
        default: nil
        }
    }

    var symbol: String? {
        switch self {
        case .initial, .broom, .coins, .cups, .swords, .clubs, .settebello: nil
        case .star: "star.fill"
        case .crown: "crown.fill"
        case .moon: "moon.fill"
        case .sun: "sun.max.fill"
        case .heart: "heart.fill"
        case .bolt: "bolt.fill"
        case .leaf: "leaf.fill"
        case .flame: "flame.fill"
        case .sail: "sailboat.fill"
        case .wine: "wineglass.fill"
        case .dice: "die.face.5.fill"
        case .espresso: "cup.and.saucer.fill"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .initial: "Your initial"
        case .broom: "Broom"
        case .coins: "Coins"
        case .cups: "Cups"
        case .swords: "Swords"
        case .clubs: "Clubs"
        case .settebello: "Settebello"
        case .star: "Star"
        case .crown: "Crown"
        case .moon: "Moon"
        case .sun: "Sun"
        case .heart: "Heart"
        case .bolt: "Bolt"
        case .leaf: "Leaf"
        case .flame: "Flame"
        case .sail: "Sail"
        case .wine: "Wine"
        case .dice: "Dice"
        case .espresso: "Espresso"
        }
    }

    /// The same name as a plain string, for the shop's swatch.
    var name: String {
        switch self {
        case .initial: String(localized: "Your initial")
        case .broom: String(localized: "Broom")
        case .coins: String(localized: "Coins")
        case .cups: String(localized: "Cups")
        case .swords: String(localized: "Swords")
        case .clubs: String(localized: "Clubs")
        case .settebello: String(localized: "Settebello")
        case .star: String(localized: "Star")
        case .crown: String(localized: "Crown")
        case .moon: String(localized: "Moon")
        case .sun: String(localized: "Sun")
        case .heart: String(localized: "Heart")
        case .bolt: String(localized: "Bolt")
        case .leaf: String(localized: "Leaf")
        case .flame: String(localized: "Flame")
        case .sail: String(localized: "Sail")
        case .wine: String(localized: "Wine")
        case .dice: String(localized: "Dice")
        case .espresso: String(localized: "Espresso")
        }
    }

    /// What the shop says about it, under the name.
    var explanation: LocalizedStringKey {
        switch self {
        case .sail: "The Riviera, on your seat"
        case .wine: "For the evening games"
        case .dice: "Fortune, acknowledged"
        case .espresso: "One before the last hand"
        default: requirement?.label ?? "Yours from the start"
        }
    }
}

/// Where the player stands against the marks' requirements, read off the same counters
/// the achievements are reported from.
struct MarkProgress: Hashable {
    /// The suits collected in full, for the four marks the album pays out.
    var suits: Set<Suit> = []
    /// The whole album found, for the mark it pays on top of the four.
    var deck = false
    var wins: Int
    var scope: Int
    var streak: Int
}
