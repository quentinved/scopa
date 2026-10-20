import Foundation
import Observation
import ScopaCore
import ScopaGameCenter
import ScopaRewards

/// Spare cards given to friends, and the ones friends gave.
///
/// A card leaves only once the Worker has it: the leaving is a line in the ledger keyed on
/// the gift, written after the Worker said yes, so a gift that never got there takes nothing
/// and one answered twice leaves once. See `Departures` for why it is not a lower count.
///
/// A card arriving is claimed in the ledger before it goes in the album, keyed on the gift,
/// so the phone and the iPad collecting the same gift put it in once between them.
@MainActor @Observable
final class CardGifts {
    /// Cards that came in and have not been turned over yet, oldest first.
    private(set) var arrivals: [GiftArrival] = []
    /// A gift sent with no answer yet. Sent again on the next collect, under the same id.
    private(set) var outgoing: GiftPost.Outgoing?

    private var isCollecting = false
    private static let outgoingKey = "gifts.outgoing"

    init() {
        outgoing = UserDefaults.standard.data(forKey: Self.outgoingKey)
            .flatMap { try? JSONDecoder().decode(GiftPost.Outgoing.self, from: $0) }
        #if DEBUG
        if let arrival = DebugLaunch.giftReceived { arrivals = [arrival] }
        #endif
    }

    /// Gifts on the sender's day, sent or still on their way, read off the ledger.
    func givenToday(_ book: AlbumBook, today: String) -> Int {
        book.departures.gifts(on: today) + (outgoing?.day == today ? 1 : 0)
    }

    // MARK: Giving

    /// Sends one card, and takes it out of the album once the Worker has it.
    func give(_ card: Card, from volume: Volume, to friend: GiftFriend, day: String,
              book: AlbumBook, purse: PurseStore) async -> GiftPost.Sent {
        let gift = GiftPost.Outgoing(to: friend.id, name: friend.name, card: card, volume: volume, day: day)
        remember(gift)
        let sent = await GiftPost.send(gift)
        await settle(gift, sent, book: book, purse: purse)
        return sent
    }

    private func settle(_ gift: GiftPost.Outgoing, _ sent: GiftPost.Sent, book: AlbumBook, purse: PurseStore) async {
        switch sent {
        case .sent:
            let key = Departures.giftKey(gift.card, from: gift.volume, day: gift.day, id: gift.id)
            _ = await purse.claim(key)
            book.noteDepartures(in: purse.purse)
            remember(nil)
        // No answer: the Worker may have it, so it is asked again under the same id.
        case .offline, .unreachable: break
        default: remember(nil)
        }
    }

    private func remember(_ gift: GiftPost.Outgoing?) {
        outgoing = gift
        let data = gift.flatMap { try? JSONEncoder().encode($0) }
        UserDefaults.standard.set(data, forKey: Self.outgoingKey)
    }

    // MARK: Collecting

    /// Sends anything still unanswered, then puts whatever friends sent in the album. `tell`
    /// posts the news, or holds it while a hand is being played.
    func collect(book: AlbumBook, purse: PurseStore, locale: Locale, tell: (Toast) -> Void) async {
        guard Ladder.isOn, GameCenter.isSignedIn, purse.isReady, !isCollecting else { return }
        isCollecting = true
        defer { isCollecting = false }
        await resend(book: book, purse: purse, locale: locale, tell: tell)
        guard let waiting = try? await GiftPost.collect(taken: []), !waiting.isEmpty else { return }
        var taken: [String] = []
        for gift in waiting {
            switch await receive(gift, book: book, purse: purse) {
            case .arrived(let arrival):
                arrivals.append(arrival)
                tell(Self.toast(for: arrival, locale: locale))
                taken.append(gift.id)
            case .already: taken.append(gift.id)
            case .failed: continue
            }
        }
        if !taken.isEmpty { _ = try? await GiftPost.collect(taken: taken) }
    }

    /// The card has been turned over.
    func showed(_ arrival: GiftArrival) {
        arrivals.removeAll { $0.id == arrival.id }
    }

    private enum Received {
        case arrived(GiftArrival)
        /// Already in the album from another device, or not a card this build can read.
        case already
        /// Not saved: left with the Worker for the next collect.
        case failed
    }

    /// Puts one card in the open volume, like a pack's: a spare pays what a spare pays.
    private func receive(_ gift: GiftPost.Waiting, book: AlbumBook, purse: PurseStore) async -> Received {
        guard let card = gift.playingCard else { return .already }
        switch await purse.claim("gift/in/\(gift.id.lowercased())") {
        case true?:
            let opened = book.openCard(card, odds: .mazzetto)
            await purse.awardPack(opened.denari, key: opened.key)
            if opened.deck { await purse.award(opened.volume) }
            return .arrived(GiftArrival(id: gift.id, from: gift.from, opening: opened))
        case false?: return .already
        case nil: return .failed
        }
    }

    /// A gift that had no answer, sent again. Told only when it lands.
    private func resend(book: AlbumBook, purse: PurseStore, locale: Locale, tell: (Toast) -> Void) async {
        guard let gift = outgoing else { return }
        let sent = await GiftPost.send(gift)
        await settle(gift, sent, book: book, purse: purse)
        guard sent == .sent else { return }
        tell(Toast(symbol: "gift.fill", tint: Palette.terracotta,
                   title: String(localized: "Your card reached \(gift.name)", locale: locale),
                   detail: gift.card.named(in: locale)))
    }

    static func toast(for arrival: GiftArrival, locale: Locale) -> Toast {
        Toast(symbol: "gift.fill", tint: Palette.terracotta,
              title: String(localized: "\(arrival.from) sent you a card", locale: locale),
              detail: arrival.card.map { String(localized: "\($0.named(in: locale)) is in your album", locale: locale) })
    }
}

extension Card {
    /// "7 of Coppe" in the player's own language, for a line that has to be a `String`.
    func named(in locale: Locale) -> String {
        let suit = switch suit {
        case .coins: String(localized: "Denari", locale: locale)
        case .cups: String(localized: "Coppe", locale: locale)
        case .swords: String(localized: "Spade", locale: locale)
        case .clubs: String(localized: "Bastoni", locale: locale)
        }
        return String(localized: "\(rank.italianName) of \(suit)", locale: locale)
    }
}
