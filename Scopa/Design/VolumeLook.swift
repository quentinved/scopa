import ScopaRewards
import SwiftUI

/// What each volume of the album looks like and what finishing it pays.
///
/// `ScopaRewards` knows a volume only by its place in the order. Which deck it is printed in
/// and what it hands over are decided here, beside the decks and the shelves they come from.
///
/// One volume per drawing the game already has, so every volume looks unlike the last, and
/// each pays a different kind of thing: a mark, a card back, a flourish, a companion. None of
/// the four is sold. Finishing a volume also hands over the deck it was printed in.
extension Volume {
    /// The deck the forty cards are printed in.
    var theme: CardTheme {
        switch self {
        case .riviera: CardTheme(style: .moderna, skin: .riviera)
        case .napoli: CardTheme(style: .classica, skin: .napoletana)
        case .pergamena: CardTheme(style: .antica, skin: .pergamena)
        case .notturna: CardTheme(style: .litografia, skin: .notturna)
        }
    }

    /// The colourway's name, which is the same word in every language.
    var title: String { theme.skin.title }

    /// As the cover prints it.
    var numeral: String {
        switch self {
        case .riviera: "I"
        case .napoli: "II"
        case .pergamena: "III"
        case .notturna: "IV"
        }
    }

    /// What finishing it pays beyond the denari.
    enum Prize: Equatable {
        case mark(SeatMark)
        case back(CardBackPattern)
        case flourish(Flourish)
        case companion(Companion)
    }

    var prize: Prize {
        switch self {
        case .riviera: .mark(.settebello)
        case .napoli: .back(.golfo)
        case .pergamena: .flourish(.sigillo)
        case .notturna: .companion(.civetta)
        }
    }

    /// The prize as the ledger knows it. Nil for the Settebello mark, which is worn off the
    /// album itself rather than recorded as owned.
    var prizeItem: ShopItem? {
        switch prize {
        case .mark: nil
        case .back(let back): Cosmetics.item(for: back)
        case .flourish(let flourish): Cosmetics.item(for: flourish)
        case .companion(let companion): Cosmetics.item(for: companion)
        }
    }

    /// Everything the ledger records as owned once the volume is full: the prize, and the
    /// drawing and colourway it was printed in. The house deck has nothing to record.
    var unlocks: [ShopItem] {
        [prizeItem, theme.style.shopItem, theme.skin.shopItem].compactMap { $0 }
    }

    /// The volume whose prize this is, for a shelf that has to say where it comes from.
    static func awarding(_ item: ShopItem?) -> Volume? {
        guard let item else { return nil }
        return allCases.first { $0.prizeItem?.id == item.id }
    }

    /// What its prize is called.
    var prizeTitle: String {
        switch prize {
        case .mark(let mark): mark.name
        case .back(let back): back.name
        case .flourish(let flourish): flourish.title
        case .companion(let companion): companion.title
        }
    }

    /// What kind of thing its prize is, as a caption over the name.
    var prizeKind: LocalizedStringKey {
        switch prize {
        case .mark: "Seat mark"
        case .back: "Card back"
        case .flourish: "Scopa flourish"
        case .companion: "Companion"
        }
    }

    /// The line under the prize's name.
    var prizeLine: LocalizedStringKey {
        switch self {
        case .riviera: "Every card in the deck, and the rarest mark in the game"
        case .napoli: "The bay's waves, on the back of every card"
        case .pergamena: "A wax seal, pressed on every scopa"
        case .notturna: "An owl who wakes when it is your turn"
        }
    }

    /// The cover's cloth and its lettering, off the back of the deck it holds.
    var cloth: Color { theme.skin.face.backGround }
    var lettering: Color { theme.skin.face.backTrim }
}

extension PurseStore {
    /// Hands over what a full volume pays beyond its denari: the prize, and the deck it was
    /// printed in, whichever of them is not owned yet. Keyed per thing, so a volume finished
    /// on two phones, or settled again when the album is next opened, records each once.
    func award(_ volume: Volume) async {
        for item in volume.unlocks where !owns(item) {
            await win(item, key: "album/\(volume.rawValue)/\(item.id.rawValue)")
        }
    }
}
