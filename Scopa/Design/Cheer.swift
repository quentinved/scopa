import ScopaRewards
import SwiftUI

/// What a sweep sounds like when you are the one who made it.
///
/// The house sound is the room reacting: a nylon guitar answering in the key the table
/// music is already in. A bought cheer replaces it, and only for your own sweeps — the
/// people across the table keep hearing the house one, because a cheer is your voice and
/// not theirs. It is the one cosmetic in the shop nobody can see.
///
/// Every cheer keeps the cards leaving the cloth at the front of it. That part is the move
/// rather than a decoration, and a cheer that dropped it would sound like a sound effect
/// played over a card game instead of the card game making a noise.
enum Cheer: String, CaseIterable, Codable, Sendable, Identifiable {
    /// The guitar, which is what the game shipped with.
    case casa
    /// A church bell, tolling long past the cards.
    case campana
    /// An accordion and a tambourine.
    case festa
    /// Thunder, and no metal at all.
    case tuono
    /// A purse emptied across the table.
    case oro

    var id: String { rawValue }

    static let stored = "cheer"

    /// The ones the shop sells. `casa` is never locked.
    static let forSale: [Cheer] = allCases.filter { $0 != .casa }

    /// The recording this one plays in place of a scopa.
    var sound: Sound {
        switch self {
        case .casa: .scopa
        case .campana: .cheerCampana
        case .festa: .cheerFesta
        case .tuono: .cheerTuono
        case .oro: .cheerOro
        }
    }

    var title: String {
        switch self {
        case .casa: "Casa"
        case .campana: "Campana"
        case .festa: "Festa"
        case .tuono: "Tuono"
        case .oro: "Oro"
        }
    }

    /// Written into the ledger with a purchase, so it stays in one language.
    var detail: String {
        switch self {
        case .casa: "The guitar answering"
        case .campana: "A church bell"
        case .festa: "An accordion and a tambourine"
        case .tuono: "Thunder"
        case .oro: "A purse emptied on the table"
        }
    }

    var explanation: LocalizedStringKey {
        switch self {
        case .casa: "The guitar answers"
        case .campana: "The village hears about it"
        case .festa: "The band strikes up"
        case .tuono: "The room goes dark"
        case .oro: "Coins, everywhere"
        }
    }

    /// The symbol on its tile. A cheer cannot be shown, so the shop draws what it is of.
    var symbol: String {
        switch self {
        case .casa: "guitars.fill"
        case .campana: "bell.fill"
        case .festa: "music.note.list"
        case .tuono: "cloud.bolt.rain.fill"
        case .oro: "sparkles"
        }
    }

    var grade: Grade {
        switch self {
        case .casa: .comune
        case .campana, .festa: .raro
        case .tuono: .prezioso
        case .oro: .leggendario
        }
    }

    var price: Denari? {
        switch self {
        case .casa: nil
        case .campana: 240
        case .festa: 240
        case .tuono: 500
        case .oro: 950
        }
    }
}
