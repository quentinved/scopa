import ScopaRewards
import SwiftUI

/// What each volume of the album looks like and what finishing it pays.
///
/// `ScopaRewards` knows a volume only by its place in the order. Which deck it is printed in
/// and what it hands over are decided here, beside the decks and the shelves they come from.
///
/// The first four are printed in drawings the game already had, the later ones in drawings
/// made for them, so every volume looks unlike the last, and each pays a different kind of
/// thing: a mark, a card back, a flourish, a companion, a song, a frame for the badge, things
/// to say, a cloth, a colour for the badge and an app icon. None of them is sold. Finishing a
/// volume also hands over the deck it was printed in.
extension Volume {
    /// The deck the forty cards are printed in.
    var theme: CardTheme {
        switch self {
        case .riviera: CardTheme(style: .moderna, skin: .riviera)
        case .napoli: CardTheme(style: .classica, skin: .napoletana)
        case .pergamena: CardTheme(style: .antica, skin: .pergamena)
        case .notturna: CardTheme(style: .litografia, skin: .notturna)
        // Bergamo's cobalt back is the glaze round a Vietri tile.
        case .maiolica: CardTheme(style: .maiolica, skin: .bergamasca)
        // Piacenza's navy and gold is Galla Placidia's starry vault.
        case .mosaico: CardTheme(style: .mosaico, skin: .piacentina)
        // The lagoon on the back, the band's crimson and gold on the paper.
        case .carnevale: CardTheme(style: .carnevale, skin: .veneziana)
        // Walnut for the back and lemonwood for the paper, the woods the cards are laid in.
        case .intarsio: CardTheme(style: .intarsio, skin: .sorrentina)
        // The island's painted houses for the suits, the dark the lace is laid on for the back.
        case .merletto: CardTheme(style: .merletto, skin: .buranella)
        // Ultramarine and gold leaf, what a Visconti painter spent the most on.
        case .tarocchi: CardTheme(style: .tarocchi, skin: .milanese)
        }
    }

    /// The name on the cover, the same word in every language: the colourway's for the four
    /// printed in drawings the shop already sold, the drawing's from the one drawn for it.
    var title: String { self < .maiolica ? theme.skin.title : theme.style.title }

    /// As the cover prints it.
    var numeral: String {
        switch self {
        case .riviera: "I"
        case .napoli: "II"
        case .pergamena: "III"
        case .notturna: "IV"
        case .maiolica: "V"
        case .mosaico: "VI"
        case .carnevale: "VII"
        case .intarsio: "VIII"
        case .merletto: "IX"
        case .tarocchi: "X"
        }
    }

    /// What finishing it pays beyond the denari.
    enum Prize: Equatable {
        case mark(SeatMark)
        case back(CardBackPattern)
        case flourish(Flourish)
        case companion(Companion)
        case song(Song)
        case cornice(Cornice)
        case phrases(Cosmetics.ReactionPack)
        case tapis(Tapis)
        case livery(SeatLivery)
        /// The Visconti app icon. Like the Settebello mark, worn off the album itself.
        case icon
    }

    var prize: Prize {
        switch self {
        case .riviera: .mark(.settebello)
        case .napoli: .back(.golfo)
        case .pergamena: .flourish(.sigillo)
        case .notturna: .companion(.civetta)
        case .maiolica: .song(.faenza)
        case .mosaico: .cornice(.tessere)
        case .carnevale: .phrases(Cosmetics.maschere)
        case .intarsio: .tapis(.cubi)
        case .merletto: .livery(.trina)
        case .tarocchi: .icon
        }
    }

    /// The prize as the ledger knows it. Nil for the Settebello mark and the Visconti icon,
    /// which are worn off the album itself rather than recorded as owned.
    var prizeItem: ShopItem? {
        switch prize {
        case .mark, .icon: nil
        case .back(let back): Cosmetics.item(for: back)
        case .flourish(let flourish): Cosmetics.item(for: flourish)
        case .companion(let companion): Cosmetics.item(for: companion)
        case .song(let song): Cosmetics.item(for: song)
        case .cornice(let cornice): Cosmetics.item(for: cornice)
        case .phrases(let pack): pack.item
        case .tapis(let tapis): Cosmetics.item(for: tapis)
        case .livery(let livery): Cosmetics.item(for: livery)
        }
    }

    /// Everything the ledger records as owned once the volume is full: the prize, and the
    /// drawing and colourway it was printed in. The house deck has nothing to record.
    var unlocks: [ShopItem] {
        [prizeItem, theme.style.shopItem, theme.skin.shopItem].compactMap { $0 }
    }

    /// The volume whose prize this is, for a shelf that has to say where it comes from.
    /// A deck or colourway that is never sold names the album it comes with too.
    static func awarding(_ item: ShopItem?) -> Volume? {
        guard let item else { return nil }
        return allCases.first { $0.prizeItem?.id == item.id }
            ?? allCases.first { volume in item.price == .zero && volume.unlocks.contains { $0.id == item.id } }
    }

    /// What its prize is called.
    var prizeTitle: String {
        switch prize {
        case .mark(let mark): mark.name
        case .back(let back): back.name
        case .flourish(let flourish): flourish.title
        case .companion(let companion): companion.title
        case .song(let song): song.title
        case .cornice(let cornice): cornice.title
        case .phrases(let pack): pack.title
        case .tapis(let tapis): tapis.title
        case .livery(let livery): livery.title
        case .icon: ViscontiIcon.title
        }
    }

    /// What kind of thing its prize is, as a caption over the name.
    var prizeKind: LocalizedStringKey {
        switch prize {
        case .mark: "Seat mark"
        case .back: "Card back"
        case .flourish: "Scopa flourish"
        case .companion: "Companion"
        case .song: "Table song"
        case .cornice: "Badge frame"
        case .phrases: "Phrases"
        case .tapis: "Table cloth"
        case .livery: "Badge colour"
        case .icon: "App icon"
        }
    }

    /// The line under the prize's name.
    var prizeLine: LocalizedStringKey {
        switch self {
        case .riviera: "Every card in the deck, and the rarest mark in the game"
        case .napoli: "The bay's waves, on the back of every card"
        case .pergamena: "A wax seal, pressed on every scopa"
        case .notturna: "An owl who wakes when it is your turn"
        case .maiolica: "A mazurka from the town that named faience"
        case .mosaico: "Gold and lapis round your badge, stone by stone"
        case .carnevale: "Four lines to say from behind a mask"
        case .intarsio: "Cubes of inlaid wood, under every hand"
        case .merletto: "Needle lace round your badge, thread by thread"
        case .tarocchi: "Your home screen icon in gold leaf, tooled by hand"
        }
    }

    /// How far into the volumes that hold their good cards back this one is: none for the
    /// first six, then one more for each after. The cover prints a lozenge for each.
    var holdsBack: Int {
        Volume.allCases.count { $0 <= self && $0.scarcity > 1 }
    }

    /// Said on the page of a volume that holds its good cards back, a little drier each
    /// volume. Nil for the first six.
    var scarcityLine: LocalizedStringKey? {
        switch holdsBack {
        case 0: nil
        case 1: "The good cards hide better in this one"
        case 2: "The good cards hide better still in this one"
        case 3: "The good cards are playing hide and seek, and winning"
        default: "The good cards have gone to the seaside. No postcard"
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
