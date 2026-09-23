import Foundation
import ScopaCore
import ScopaRewards
import SwiftUI

/// The language the game speaks, independent of the phone's.
///
/// `system` follows the phone. The rest override it for this app alone.
enum Language: String, CaseIterable, Codable, Sendable, Identifiable {
    case system, english, french, italian

    static let `default` = Language.system

    var id: String { rawValue }

    /// `nil` leaves the environment alone, so the phone's own language wins.
    var locale: Locale? {
        switch self {
        case .system: nil
        case .english: Locale(identifier: "en")
        case .french: Locale(identifier: "fr")
        case .italian: Locale(identifier: "it")
        }
    }

    /// Named in its own language, the way language pickers are.
    var title: String {
        switch self {
        case .system: "System"
        case .english: "English"
        case .french: "Français"
        case .italian: "Italiano"
        }
    }
}

// MARK: - Translating what the core says

/// `ScopaCore` returns plain `String`s for these, which `Text` renders verbatim. Restating
/// them as `LocalizedStringKey` here lets the string catalogue reach them.
extension AssistLevel {
    var label: LocalizedStringKey {
        switch self {
        case .coached: "Coached"
        case .beginner: "Beginner"
        case .normal: "Normal"
        }
    }

    var explanation: LocalizedStringKey {
        switch self {
        case .coached: "Talks you through your three cards, and through what the bot just did"
        case .beginner: "Outlines what you can take and fills in the obvious ones"
        case .normal: "You work out the take yourself, with no warning before a wrong one"
        }
    }
}

extension PrimieraRule {
    var label: LocalizedStringKey {
        switch self {
        case .classic: "Classic"
        case .mostSevens: "Most sevens"
        }
    }

    var explanation: LocalizedStringKey {
        switch self {
        case .classic: "Your best card in each suit, added up: 7 is best, then 6, then the ace"
        case .mostSevens: "Whoever took more sevens. Level is nobody's point"
        }
    }
}

extension TieRule {
    var label: LocalizedStringKey {
        switch self {
        case .classic: "Regular"
        case .shared: "Shared"
        }
    }

    var explanation: LocalizedStringKey {
        switch self {
        case .classic: "A category you end level on is nobody's point"
        case .shared: "A category you end level on is a point for each of you"
        }
    }
}

/// The four suits under their Italian names, except where a language has its own word:
/// `Spade` are `Épées` in French, not spades.
extension Suit {
    var name: LocalizedStringKey {
        switch self {
        case .coins: "Denari"
        case .cups: "Coppe"
        case .swords: "Spade"
        case .clubs: "Bastoni"
        }
    }

    /// The same word, resolved, for somewhere a `LocalizedStringKey` will not go.
    var spokenName: String {
        switch self {
        case .coins: String(localized: "Denari")
        case .cups: String(localized: "Coppe")
        case .swords: String(localized: "Spade")
        case .clubs: String(localized: "Bastoni")
        }
    }
}

extension Card {
    /// What VoiceOver reads for one card. The faces are drawn as shapes, so without this a
    /// hand is announced as nothing at all.
    var spoken: String {
        String(localized: "\(rank.italianName) of \(suit.spokenName)")
    }
}

// MARK: - The tally

/// `ScopaRewards` names each earning in English for the ledger. Said again here so the
/// catalogue can reach it for the payout card.
extension Earning {
    func tally(count: Int, locale: Locale) -> String {
        switch self {
        case .wonGame: String(localized: "Game won", locale: locale)
        case .lostGame: String(localized: "Game finished", locale: locale)
        case .scopa:
            count == 1 ? String(localized: "Scopa", locale: locale)
                       : String(localized: "\(count) scope", locale: locale)
        case .settebello:
            count == 1 ? String(localized: "Settebello", locale: locale)
                       : String(localized: "Settebello ×\(count)", locale: locale)
        case .cappotto:
            count == 1 ? String(localized: "Cappotto", locale: locale)
                       : String(localized: "Cappotto ×\(count)", locale: locale)
        case .firstOfDay: String(localized: "First game today", locale: locale)
        case .dailyDeal: String(localized: "Today's deal", locale: locale)
        case .dailyDealWon: String(localized: "Beat the bot", locale: locale)
        }
    }
}

extension Award {
    func line(locale: Locale) -> String { earning.tally(count: count, locale: locale) }
}

// MARK: - The shelves

/// Names like Riviera and Napoli are the same word at any table and stay as they are. The
/// line under each swatch is prose, so it is said here where the catalogue reaches it.
/// `detail` stays English because it goes into the ledger with the purchase.
extension CardStyle {
    var explanation: LocalizedStringKey {
        switch self {
        case .moderna: "Flat and geometric, the house hand"
        case .classica: "The court drawn out, in full"
        case .antica: "A woodcut: outline and hatching"
        case .litografia: "A lithographed sheet, in full colour"
        }
    }
}

extension CardSkin {
    var explanation: LocalizedStringKey {
        switch self {
        case .riviera: "Cream and bottle green, the house colours"
        case .napoletana: "Warm cream on red"
        case .piacentina: "Cool paper on navy"
        case .bergamasca: "Bright, on cobalt"
        case .pergamena: "Aged paper and brown ink"
        case .notturna: "Bone and gold on black, printed in reverse"
        }
    }
}

extension TableFelt {
    var explanation: LocalizedStringKey {
        switch self {
        case .riviera: "The house table, bottle green"
        case .notte: "Deep blue, after closing"
        case .vigna: "Wine, poured on the cloth"
        case .pietra: "Grey stone, for a quiet room"
        case .festa: "Deep teal, seven evenings in a row"
        }
    }
}

// MARK: - The coach

extension Coach.Standing {
    var label: LocalizedStringKey {
        switch self {
        case .best: "The move to make"
        case .sound: "Playable"
        case .costly: "It costs you"
        }
    }

    /// Gold for the best move, terracotta for the one that costs. The same two colours the
    /// review uses for praise and for a lesson.
    var tint: Color {
        switch self {
        case .best: Palette.gold
        case .sound: Palette.steel
        case .costly: Palette.terracotta
        }
    }
}

extension Coach.Note {
    /// Said about a card in your own hand, before you play it.
    var advice: LocalizedStringKey {
        switch self {
        case .sweeps: "It clears the table — a scopa, and a point on the spot."
        case .takesSettebello: "The seven of coins comes over with it."
        case .takesCoins(let count):
            count == 1 ? "A coin comes over, and the coins are a point."
                       : "\(count) coins come over, and the coins are a point."
        case .takesCards(let count): "That is \(count) cards into your pile."
        case .takesTheLeftovers: "Last card of the round: what is left on the table comes with it."
        case .onlyMove: "It is the only move the rules leave you."
        case .nothingMatches: "Nothing there matches it and nothing adds up to it, so it goes down."
        case .cheapestToLose: "Of the cards you have to give up, this one costs you least."
        case .givesTheSettebello: "It hands over the seven of coins, which is a point on its own."
        case .givesACoin: "It gives away a coin, and the coins are a point."
        case .givesAGoodCard(let rank): "The \(rank.label) is a card the primiera counts. Keep it if you can."
        case .leavesASweep(let rank): "Careful: anyone holding a \(rank.label) sweeps what you leave."
        case .leavesTheSettebello: "It leaves the seven of coins lying there."
        }
    }

    /// The same note, about the move somebody else has just made.
    func telling(_ name: String) -> LocalizedStringKey? {
        switch self {
        case .sweeps: "The table was cleared: that is a point to \(name)."
        case .takesSettebello: "The seven of coins has gone to \(name)."
        case .takesCoins(let count):
            count == 1 ? "A coin went with it." : "\(count) coins went with it."
        case .takesCards(let count): "\(count) cards to \(name)."
        case .nothingMatches: "Nothing on the table matched it, so it stays there."
        case .givesTheSettebello: "The seven of coins is on the table. Take it if you can."
        case .givesACoin: "That coin is there for the taking."
        case .leavesTheSettebello: "The seven of coins is still lying there."
        default: nil
        }
    }
}

extension BotLevel {
    var label: LocalizedStringKey {
        switch self {
        case .easy: "Easy"
        case .normal: "Normal"
        case .hard: "Hard"
        }
    }

    var explanation: LocalizedStringKey {
        switch self {
        case .easy: "Takes what it sees and misses the rest"
        case .normal: "Weighs the table and what a move leaves behind"
        case .hard: "Counts the deck and plays the round out before it moves"
        }
    }
}

extension TurnClock {
    var label: LocalizedStringKey {
        switch self {
        case .off: "No clock"
        case .relaxed: "30 seconds"
        case .brisk: "15 seconds"
        }
    }

    var explanation: LocalizedStringKey {
        switch self {
        case .off: "Take as long as you like"
        case .relaxed: "Enough time to count, but the game keeps moving"
        case .brisk: "Think fast"
        }
    }
}

extension Verdict {
    var label: LocalizedStringKey {
        switch self {
        case .scopa: "Scopa!"
        case .settebello: "Settebello"
        case .best: "Best move"
        case .forced: "Only move"
        case .fine: "Fine"
        case .missedScopa: "Missed scopa"
        case .settebelloGiven: "Gave away the settebello"
        case .settebelloMissed: "Left the settebello"
        case .missedTake: "Missed a take"
        case .weakTake: "Took the smaller pile"
        case .tookTheWrongCards: "Took the wrong cards"
        case .exposedTable: "Opened the table"
        case .gaveAwayAGoodCard: "Gave away a good card"
        }
    }

    /// Gold for praise, terracotta for a lesson, and the quiet grade for the rest.
    var tint: Color {
        if isPraise { return Palette.gold }
        if isLesson { return Palette.terracotta }
        return Palette.steel
    }
}

extension Ladder.RankAnswer.Standing {
    /// "Silver II", in the interface's language.
    func leagueTitle(locale: Locale) -> String {
        let names: [String] = [
            String(localized: "Bronze", locale: locale), String(localized: "Silver", locale: locale),
            String(localized: "Gold", locale: locale), String(localized: "Platinum", locale: locale),
            String(localized: "Diamond", locale: locale), String(localized: "Maestro", locale: locale),
        ]
        let name = names[safe: league] ?? names[0]
        return "\(name) \(["I", "II", "III"][safe: division - 1] ?? "")"
    }
}

/// A margin with its sign already on it: "+4", "0", "-4". The sign belongs to the number,
/// not to the sentence around it, which printed "+-4" for a negative margin.
func signed(_ margin: Int) -> String {
    margin > 0 ? "+\(margin)" : "\(margin)"
}
