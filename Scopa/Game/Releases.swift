import Foundation
import SwiftUI
import ScopaRewards

/// What each version of the game brought, and what it hands over to say thank you.
///
/// The one place a release is declared. For the next one, add a `Release` at the top of
/// `all` with its version as `MARKETING_VERSION` spells it, the pages for "What's new", and
/// a gift if it has one; the lobby does the rest, once per player.
enum Releases {
    static let all: [Release] = [
        Release(version: "1.1", gift: nil, notes: [
            ReleaseNote(art: .journey, title: "A journey through Italy",
                        body: "The new solo campaign: region by region, stage by stage, against players who get better as you go. Up to three stars a stage, and a prize at the end of every region."),
            ReleaseNote(art: .lobby, title: "A new lobby",
                        body: "Ranked has the big door now, with your medal, your win rate and how far to the next division. The campaign sits just under it, and Quick game turns into Resume when a game is waiting."),
            ReleaseNote(art: .volumes, title: "Four volumes of the album",
                        body: "Fill Riviera and the album goes on: Napoli, Pergamena and Notturna, the same forty cards in another deck each, and each with a prize of its own."),
            ReleaseNote(art: .wheel, title: "A wheel to spin each day",
                        body: "One free spin a day from the little wheel in the lobby: denari, a pack, something from the shop, and now and then the gran premio of 2,500."),
            ReleaseNote(art: .medals, title: "Prizes for the ladder",
                        body: "Every league you reach in ranked gives you its medal to wear at your seat, and from Silver up an app icon struck in that metal. Yours for good."),
            ReleaseNote(art: .board, title: "The season's ladder",
                        body: "Who leads the month in ranked, among everyone or just your friends, and how often each of them wins. Before a game, the banner shows who you face, what a win or a loss is worth, and your winning run."),
            ReleaseNote(art: .house, title: "Nobody about? Play the house",
                        body: "Five seconds into a ranked search, the house offers to play you. Take the game, or keep looking while the search goes on."),
            ReleaseNote(art: .cloths, title: "New cloths for the table",
                        body: "Fresh felts and weaves in the shop, to dress the table the way you like it."),
            ReleaseNote(art: .oneTap, title: "Play with one tap",
                        body: "Turn it on in Settings, and a card with only one move goes down the moment you touch it."),
            ReleaseNote(art: .videos, title: "More for a video",
                        body: "A short video in the shop now pays at least 100 denari, as many times a day as you like."),
            ReleaseNote(art: .codes, title: "Have a code?",
                        body: "Type a coupon or a friend's code at the foot of the shop, and whatever it holds is yours."),
        ]),
    ]

    /// What every player is given once, new or old: two of the dearest card packs and two of
    /// the shop's. It stands in for 1.1's own gift, the release that brought it in.
    static let welcome = ReleaseGift(key: "gift/welcome", packs: [.reliquia, .reliquia, .forziere, .forziere])

    /// This build's version, as the App Store prints it.
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// This build's entry, if it has one.
    static var current: Release? { all.first { $0.version == version } }

    /// The newest pages there are, for Settings: this build's, or the last that had any.
    static var latestNotes: Release? {
        current.flatMap { $0.notes.isEmpty ? nil : $0 } ?? all.first { !$0.notes.isEmpty }
    }
}

/// One version: what it says about itself, and what it gives.
struct Release: Identifiable {
    let version: String
    /// Handed over on the first launch after updating to it. Nil for a release with nothing
    /// to give beyond the welcome.
    var gift: ReleaseGift?
    var notes: [ReleaseNote]

    var id: String { version }
}

/// A present from the house, paid once per player. Its key names it in the ledger, which
/// is what stops it paying twice, on this device or the player's other one.
struct ReleaseGift: Equatable {
    let key: String
    var denari: Denari = .zero
    /// Left waiting like a level's pack: card packs in the album, the shop's own in the shop.
    var packs: [PackTier] = []

    /// A version's own gift, keyed on the version.
    init(version: String, denari: Denari = .zero, packs: [PackTier] = []) {
        self.init(key: "gift/\(version)", denari: denari, packs: packs)
    }

    init(key: String, denari: Denari = .zero, packs: [PackTier] = []) {
        self.key = key
        self.denari = denari
        self.packs = packs
    }

    /// Several gifts owed at once, shown as one parcel.
    static func together(_ gifts: [ReleaseGift]) -> ReleaseGift {
        ReleaseGift(key: gifts.map(\.key).joined(separator: "+"),
                    denari: gifts.reduce(.zero) { $0 + $1.denari },
                    packs: gifts.flatMap(\.packs))
    }
}

/// One page of "What's new": a drawing, a title, and a sentence or two.
struct ReleaseNote {
    let art: ReleaseNoteArt.Kind
    let title: LocalizedStringKey
    let body: LocalizedStringKey
}
