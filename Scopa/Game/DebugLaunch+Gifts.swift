import Foundation
import ScopaCore
import ScopaRewards

/// A card given to a friend, and one arriving from a friend, without a second phone.
///
/// `-giftCard 7c` opens the album lifted on that card with a spare of it, and the give flow
/// open on a few made-up friends; giving it pretends the Worker said yes and writes nothing.
/// `-giftCard 7c confirm` goes straight to the question, `-giftCard 7c sent` to the thanks.
/// `-giftReceived Marco 7c` turns over a card from Marco as the app opens, and
/// `-giftReceived Marco 7c spare` one already in the album. Neither touches the album.
extension DebugLaunch {
    static var giftCard: Card? {
        #if DEBUG
        card(after: "-giftCard", skipping: 0)
        #else
        nil
        #endif
    }

    /// How far into the give flow `-giftCard` starts: nil for the friends, "confirm", "sent".
    static var giftStep: String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-giftCard").flatMap { arguments[safe: $0 + 2] }
        #else
        nil
        #endif
    }

    /// Friends to give to when there is no Game Center to ask.
    static let giftFriends: [GiftFriend] = [
        GiftFriend(id: "G:marco", name: "Marco"), GiftFriend(id: "G:giulia", name: "Giulia"),
        GiftFriend(id: "G:hugo", name: "Hugo"),
    ]

    static var giftReceived: GiftArrival? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let at = arguments.firstIndex(of: "-giftReceived"),
              let name = arguments[safe: at + 1], let card = card(after: "-giftReceived", skipping: 1)
        else { return nil }
        let found: Album.Found = arguments[safe: at + 3] == "spare" ? .spare(card, card.rarity.spare) : .new(card)
        let opening = AlbumBook.Opening(volume: .riviera, tier: .mazzetto, found: [found],
                                        suits: [], deck: false, won: [])
        return GiftArrival(id: "debug", from: name, opening: opening)
        #else
        return nil
        #endif
    }

    /// The card named after a flag, past `skipping` other words, as `Card.description` writes it.
    private static func card(after flag: String, skipping: Int) -> Card? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let at = arguments.firstIndex(of: flag), let name = arguments[safe: at + 1 + skipping] else { return nil }
        return Deck.standard.first { $0.description == name }
    }
}
