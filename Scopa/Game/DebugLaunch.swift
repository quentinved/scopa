import Foundation
import UIKit
import ScopaCore
import ScopaRewards

/// Jumps straight into a screen so a build can be previewed or screenshotted without tapping through.
/// Pass `-startTable` (optionally with `-seats 4` and `-teams`) as a launch argument.
enum DebugLaunch {
    /// `-autoPlay` plays random legal moves and deals the next round, so a whole game can be
    /// watched out to its winner and its payout.
    static var playsItself: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-autoPlay")
        #else
        false
        #endif
    }

    /// `-again`, with `-autoPlay`: once a game ends, sits straight down at the same table again.
    static var playsAgain: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-again")
        #else
        false
        #endif
    }

    /// `-waiting` opens the waiting room. Pair it with `-bots 2` for chairs the host has
    /// filled, `-invited` for a table of invited friends, or `-room` for a real table.
    static var showsWaitingRoom: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-waiting")
        #else
        false
        #endif
    }

    /// `-verdict` opens the ladder's answer to a ranked game five ways: a win in the division,
    /// a promotion, a loss, a demotion, and a loss the league floor absorbed.
    static var showsVerdict: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-verdict")
        #else
        false
        #endif
    }

    /// `-verdict end` opens that sheet scrolled to its foot, where the runs and the house are.
    static var verdictOpensAtEnd: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-verdict").flatMap { arguments[safe: $0 + 1] } == "end"
        #else
        false
        #endif
    }

    /// `-cardSheet` opens the deck sheet instead of the game.
    static var showsCardSheet: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-cardSheet")
        #else
        false
        #endif
    }

    /// `-showAd` opens the full screen ad straight away.
    static var showsAd: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-showAd")
        #else
        false
        #endif
    }

    /// `-placeholderAds` draws stand-ins instead of calling AdMob, for a simulator with no
    /// account and no connection.
    static var usesPlaceholderAds: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-placeholderAds")
        #else
        false
        #endif
    }

    /// `-liveAds` points a debug build at the real ad units instead of Google's test ones. Only
    /// safe on a phone registered as a test device in the AdMob console.
    static var usesLiveAds: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-liveAds")
        #else
        false
        #endif
    }

    /// `-adInspector` opens Google's own request log over the app. Needs a registered test device.
    static var showsAdInspector: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-adInspector")
        #else
        false
        #endif
    }

    /// `-resetConsent` forgets what the player answered, so the consent form comes up again.
    static var resetsConsent: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-resetConsent")
        #else
        false
        #endif
    }

    /// `-consentEEA` and `-consentNotEEA` tell the consent SDK where to pretend this device is,
    /// so both the form and the launch that skips it can be checked from one desk.
    enum ConsentRegion { case europe, elsewhere }

    static var consentRegion: ConsentRegion? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-consentEEA") { return .europe }
        if arguments.contains("-consentNotEEA") { return .elsewhere }
        return nil
        #else
        return nil
        #endif
    }

    /// `-review` opens the review of the game as soon as it has been read back.
    static var showsReview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-review")
        #else
        false
        #endif
    }

    /// `-reviewAsk` lays the "Enjoying Scopa?" card over the lobby, whatever `ReviewPrompt`
    /// would say.
    static var asksReview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-reviewAsk")
        #else
        false
        #endif
    }

    /// `-settings` opens the settings sheet.
    static var showsSettings: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-settings")
        #else
        false
        #endif
    }

    /// `-rules` opens the how-to-play walkthrough without clearing defaults for a first launch.
    static var showsRules: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-rules")
        #else
        false
        #endif
    }

    /// `-friends` opens the sheet with every way to play people you know.
    static var showsFriends: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-friends")
        #else
        false
        #endif
    }

    /// `-scorePad` opens the score pad for a game played with real cards. `-scorePad board`
    /// opens it on three hands already counted.
    static var showsScorePad: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-scorePad")
        #else
        false
        #endif
    }

    static var scorePadSample: ScorePad? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.firstIndex(of: "-scorePad").flatMap({ arguments[safe: $0 + 1] }) == "board" else { return nil }
        var pad = ScorePad(sides: ["Quentin", "Giulia", "Marco"])
        for (cards, coins, settebello, primiera, scope) in [(0, 1, 0, 2, [1, 0, 0]), (1, 1, 2, 1, [0, 2, 0]),
                                                             (2, 0, 1, 0, [0, 0, 1])] {
            var hand = ScorePad.Hand(sides: 3)
            (hand.cards, hand.coins, hand.settebello, hand.primiera, hand.scope) = (cards, coins, settebello, primiera, scope)
            pad.add(hand)
        }
        return pad
        #else
        nil
        #endif
    }

    /// `-online` opens the Online sheet, where the league panel lives. Pair it with `-rank`.
    static var showsOnlineSheet: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-online")
        #else
        false
        #endif
    }

    /// `-searching` (or `-rankedSearch`) opens the Online sheet with a ranked search part-way
    /// through it and the house on offer, without Game Center and without waiting for it.
    static var showsRankedSearch: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-searching") || arguments.contains("-rankedSearch")
        #else
        false
        #endif
    }

    /// `-rankedSearch over`: the same search, run out with nobody found.
    static var rankedSearchIsOver: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-rankedSearch") else { return false }
        return arguments[safe: index + 1] == "over"
        #else
        false
        #endif
    }

    /// `-season` opens the season's ranked board over the ranked sheet, filled with a sample
    /// board rather than the Worker's, so it can be judged with nobody on the ladder.
    static var showsSeasonBoard: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-season")
        #else
        false
        #endif
    }

    /// `-season friends` opens that board on the friends' tab.
    static var seasonOpensOnFriends: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-season").flatMap { arguments[safe: $0 + 1] } == "friends"
        #else
        false
        #endif
    }

    /// `-road` opens the ranked ladder's road over the ranked sheet: the six leagues, where
    /// `-rank` stands on them, and what each one gives.
    static var showsRoad: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-road")
        #else
        false
        #endif
    }

    /// `-rankUp` plays the new-league ceremony for the league `-rank` plants, whatever has
    /// been celebrated already, and even under `-noGameCenter`.
    static var forcesRankUp: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-rankUp")
        #else
        false
        #endif
    }

    /// `-stakes` opens the sheet with the three stakes, so it can be judged with `-denari`.
    static var showsStakes: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-stakes")
        #else
        false
        #endif
    }

    /// `-joinCode` opens the page where a code somebody sent is typed in.
    static var showsJoinCode: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-joinCode")
        #else
        false
        #endif
    }

    /// `-onThisPhone` opens the page that seats friends and bots on this phone.
    static var showsLocalTable: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-onThisPhone")
        #else
        false
        #endif
    }

    /// `-shop` opens the shop straight away.
    static var showsShop: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-shop") || promoCode != nil || shelf != nil || confirmsPurchase
        #else
        false
        #endif
    }

    /// `-confirmBuy` opens the shop with a purchase waiting on a yes.
    static var confirmsPurchase: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-confirmBuy")
        #else
        false
        #endif
    }

    /// `-shelf tapis` opens the shop scrolled to that shelf, so it can be photographed.
    static var shelf: String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-shelf").flatMap { arguments[safe: $0 + 1] }
        #else
        nil
        #endif
    }

    /// `-promoCode` opens the shop at its foot with the code panel up. `-promoCode row` leaves
    /// the panel down, to see the row it opens from; `-promoCode paid` shows a sample reward.
    static var promoCode: String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-promoCode") else { return nil }
        return arguments[safe: index + 1].flatMap { $0.hasPrefix("-") ? nil : $0 } ?? ""
        #else
        nil
        #endif
    }

    /// `-companion gatto` sits that animal beside your hand without buying one. The purse is
    /// left alone.
    static var companion: Companion? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-companion")
            .flatMap { arguments[safe: $0 + 1] }
            .flatMap(Companion.init(rawValue:))
        #else
        nil
        #endif
    }

    /// `-sweep` announces a sweep as soon as the table is up and every few seconds after,
    /// so a flourish can be watched without waiting for a real one. Pair it with
    /// `-flourish aureola` and `-startTable`.
    static var repeatsSweep: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-sweep")
        #else
        false
        #endif
    }

    /// `-highlight settebello` puts that plate on the cloth every few seconds, as `-sweep`
    /// does the band. Also `reBello`, `napola` and `asso`.
    static var highlight: TableHighlight? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        switch arguments.firstIndex(of: "-highlight").flatMap({ arguments[safe: $0 + 1] }) {
        case "settebello": return .settebello
        case "reBello": return .reBello
        case "napola": return .napola(points: 4)
        case "asso": return .assoPigliaTutto(Card(.ace, of: .cups))
        default: return nil
        }
        #else
        return nil
        #endif
    }

    /// `-theirs` plays `-sweep` and `-highlight` as an opponent's, the smaller version.
    static var showsTheirMoment: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-theirs")
        #else
        false
        #endif
    }

    /// `-tapis velluto` lays that cloth on the table without buying it, so a cloth can be
    /// judged at the size it is actually drawn at rather than in a swatch.
    static var tapis: Tapis? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-tapis")
            .flatMap { arguments[safe: $0 + 1] }
            .flatMap(Tapis.init(named:))
        #else
        nil
        #endif
    }

    /// `-flourish aureola` plays that flourish on your sweeps without buying it. Pair it
    /// with `-autoPlay` to get a sweep to look at.
    static var flourish: Flourish? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-flourish")
            .flatMap { arguments[safe: $0 + 1] }
            .flatMap(Flourish.init(rawValue:))
        #else
        nil
        #endif
    }

    /// `-denari 500` puts denari in the purse. Debug builds only: nothing else in the app
    /// grants denari.
    static var grantedDenari: Denari? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-denari")
            .flatMap { Int(arguments[safe: $0 + 1] ?? "") }
            .map { Denari($0) }
        #else
        nil
        #endif
    }

    /// `-purse 120` moves the purse to exactly that, up or down. `-denari` only ever adds,
    /// which cannot get you to a screen that has to be looked at while short — the wager
    /// tables out of reach, the shop item you cannot afford.
    static var exactPurse: Denari? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-purse")
            .flatMap { Int(arguments[safe: $0 + 1] ?? "") }
            .map { Denari($0) }
        #else
        nil
        #endif
    }

    /// `-wager 200` sits you at a wager table for that stake, taken from the purse as the lobby
    /// would take it. Pair it with `-denari` so there is something to stake.
    static var wager: Stake? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-wager")
            .flatMap { Int(arguments[safe: $0 + 1] ?? "") }
            .flatMap(Stake.init(rawValue:))
        #else
        nil
        #endif
    }

    /// `-coach` deals the hand the walkthrough offers, with the coach on and the easy bot
    /// across the table.
    static var startsCoached: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-coach")
        #else
        false
        #endif
    }

    /// `-coachChoice` puts up the first launch's Coached-or-Normal question over the lobby.
    static var showsCoachChoice: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-coachChoice")
        #else
        false
        #endif
    }

    /// `-noAds` starts as though the ads had been bought out: no strip, no interruption, and
    /// neither the consent form nor the tracking prompt in front of a screenshot.
    static var hidesAds: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-noAds")
        #else
        false
        #endif
    }

    /// `-adFree` plays as though the no-ads pass had been bought: no strip and no
    /// interruption, but the opt-in video is still offered. Nothing is written down.
    static var ownsAdFree: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-adFree")
        #else
        false
        #endif
    }

    /// `-adFreeSheet` opens the no-ads purchase from the lobby on arrival.
    static var showsAdFree: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-adFreeSheet")
        #else
        false
        #endif
    }

    /// `-noGameCenter` keeps the app from signing in at launch, so Apple's sign-in sheet does
    /// not sit in front of a screenshot.
    static var staysSignedOut: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-noGameCenter")
        #else
        false
        #endif
    }

    /// `-challenge 11` puts the week's challenge that far along. A number at or past the goal
    /// shows the badge; pair it with `-weekWon` for the card that hands the laurel over.
    static var challengeCount: Int? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-challenge").flatMap { Int(arguments[safe: $0 + 1] ?? "") }
        #else
        nil
        #endif
    }

    /// `-weekWon` plants the week as just finished, which is the one state that cannot be
    /// reached without playing a week: the card is shown on the walk back into the lobby.
    static var showsWeekWon: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-weekWon")
        #else
        false
        #endif
    }

    /// `-ladder` opens the board.
    static var showsLadder: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-ladder")
        #else
        false
        #endif
    }

    /// `-album` opens the album straight from the settings, where it is pushed from.
    /// Pair it with `-collected 18` and `-packs 2` for a page with something on it.
    static var showsAlbum: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-album")
        #else
        false
        #endif
    }

    /// `-albumEnd` opens the album scrolled to the bottom, where the last suits are, so a
    /// volume's own drawing can be looked at without a finger on the glass.
    static var showsAlbumEnd: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-albumEnd")
        #else
        false
        #endif
    }

    /// `-albumZoom 7d` lifts that card off the album's page as it opens, named the way
    /// `Card.description` writes it. Pair it with `-album`.
    static var albumZoom: Card? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-albumZoom")
            .flatMap { arguments[safe: $0 + 1] }
            .flatMap { name in Deck.standard.first { $0.description == name } }
        #else
        return nil
        #endif
    }

    /// `-openPack` opens one the moment the album appears, which is the only way to see
    /// the cards turn over without tapping. `-openPack reliquia` opens a bought tier
    /// instead, and for nothing: the dear packs are the ones worth looking at and nobody
    /// should have to earn fourteen hundred denari to see one come apart.
    static var opensPack: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-openPack")
        #else
        false
        #endif
    }

    /// The tier `-openPack` opens, or nil for the earned one.
    static var packTier: PackTier? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-openPack")
            .flatMap { arguments[safe: $0 + 1] }
            .flatMap(PackTier.init(rawValue:))
        #else
        return nil
        #endif
    }

    /// `-packStep new` starts an opening on its first new card, already turned over;
    /// `-packStep spare` on its first one already owned, `-packStep 3` on that place, and
    /// `-packStep done` on what it all came to. Pair it with `-album -openPack`.
    static var packStep: String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-packStep").flatMap { arguments[safe: $0 + 1] }
        #else
        return nil
        #endif
    }

    /// `-packHold` keeps a `-packStep` card face down, gathering itself, so the wait before
    /// a rare card turns over can be looked at. `-packHold 8.5` turns it over that many
    /// seconds after launch instead, for catching the sparks in a timed screenshot.
    static var packHolds: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-packHold")
        #else
        false
        #endif
    }

    static var packHoldSeconds: Double? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-packHold").flatMap { arguments[safe: $0 + 1] }.flatMap(Double.init)
        #else
        return nil
        #endif
    }

    /// `-packCards 7d,Kc,3s` rigs the next pack opened to hold exactly those cards, named
    /// the way `Card.description` writes them, so the settebello can be seen turning over
    /// without opening thirty packs for it.
    static var packCards: [Card]? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let list = arguments.firstIndex(of: "-packCards").flatMap({ arguments[safe: $0 + 1] })
        else { return nil }
        let cards = list.split(separator: ",").compactMap { name in
            Deck.standard.first { $0.description == name }
        }
        return cards.isEmpty ? nil : cards
        #else
        return nil
        #endif
    }

    /// `-packFinale cups` has the next pack opened finish that suit, whatever it held, and
    /// `-packFinale deck` the whole deck, so the ending can be looked at. Nothing is paid
    /// for it: only the opening is told.
    static var packFinale: String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-packFinale").flatMap { arguments[safe: $0 + 1] }
        #else
        return nil
        #endif
    }

    /// `-packAutoplay` taps through an opening by itself every 2.2 seconds and starts it
    /// again once it is counted, so a reveal can be measured for minutes without hands.
    static var packAutoplay: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-packAutoplay")
        #else
        false
        #endif
    }

    /// `-ladder week` opens the ladder on the week's board rather than today's.
    static var ladderOpensOnTheWeek: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-ladder").flatMap { arguments[safe: $0 + 1] } == "week"
        #else
        false
        #endif
    }

    /// How `-updateGift` shows the parcel.
    enum UpdateGift { case update, welcome, opened }

    /// `-updateGift` puts the parcel up over the lobby, as after an update; `-updateGift
    /// welcome` as on a first launch, and `-updateGift opened` already open. It pays only
    /// what the ledger has not paid before.
    static var updateGift: UpdateGift? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-updateGift") else { return nil }
        switch arguments[safe: index + 1] {
        case "welcome": return .welcome
        case "opened": return .opened
        default: return .update
        }
        #else
        return nil
        #endif
    }

    /// `-whatsNew` turns the pages of this version's news over the lobby; `-whatsNew 3`
    /// opens on the fourth.
    static var whatsNewPage: Int? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-whatsNew") else { return nil }
        return Int(arguments[safe: index + 1] ?? "") ?? 0
        #else
        return nil
        #endif
    }

    /// `-landscape` and `-portrait` turn the window on arrival. `simctl` cannot rotate a
    /// simulator, so this is how a layout on its side is screenshotted with nobody sitting
    /// in front of the Simulator app.
    ///
    /// A phone obeys. An iPad ignores a geometry request while it supports being run beside
    /// another app, which it does — to shoot an iPad on its side, set
    /// `INFOPLIST_KEY_UIRequiresFullScreen = YES` on the target for as long as it takes and
    /// then put it back.
    @MainActor
    static func rotateIfRequested() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let wanted: UIInterfaceOrientationMask
        if arguments.contains("-landscape") { wanted = .landscapeRight }
        else if arguments.contains("-portrait") { wanted = .portrait }
        else { return }
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: wanted))
        }
        #endif
    }

    /// `-selectFirst` picks the first card in hand on arrival, for the action bar.
    static var selectsFirstCard: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-selectFirst")
        #else
        false
        #endif
    }

    @MainActor
    static func applyIfRequested(to store: TableStore) {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        dress(store, with: arguments)
        guard !openTable(store, with: arguments) else { return }
        startLocalTable(store, with: arguments)
        #endif
    }

    #if DEBUG
    /// Flags that change what a screen shows without deciding which screen opens.
    @MainActor
    private static func dress(_ store: TableStore, with arguments: [String]) {
        applyRank(store, with: arguments)
        // `-record 27 14` plants a won-and-lost tally under the name in the settings.
        if let index = arguments.firstIndex(of: "-record"),
           let wins = Int(arguments[safe: index + 1] ?? ""), let losses = Int(arguments[safe: index + 2] ?? "") {
            Achievements.pretend(wins: wins, losses: losses)
        }
        // `-level 1290` plants a lifetime of experience under the bar.
        if let index = arguments.firstIndex(of: "-level"), let total = Int(arguments[safe: index + 1] ?? "") {
            Experience.pretend(total: total)
        }
        plantAlbum(store.albumBook, with: arguments)
        // `-mark coins` wears a mark without earning it first.
        if let index = arguments.firstIndex(of: "-mark"),
           let mark = arguments[safe: index + 1].flatMap(SeatMark.init(rawValue:)) {
            store.seatMark = mark
        }
        if let count = challengeCount { store.challenges.pretend(count: count) }
        // `-challenges 12 3 40` sets each task on its own, so a week part done can be seen.
        if let index = arguments.firstIndex(of: "-challenges") {
            let counts = arguments.dropFirst(index + 1).prefix(WeeklyChallenge.tasksPerWeek).compactMap { Int($0) }
            store.challenges.pretend(counts: counts)
        }
        // `-savedGame` puts a dealt quick game behind the lobby's resume door, on no disk;
        // `-savedGame none` shows the lobby as if nothing were saved.
        if let index = arguments.firstIndex(of: "-savedGame") {
            store.pretendSavedGame(none: arguments[safe: index + 1] == "none")
        }
        if showsWeekWon { store.pretendChallengeFinished() }
        // `-tieRules` turns the house rule on for the pages that set a table.
        if arguments.contains("-tieRules") { store.pretendTieRules() }
        if let index = arguments.firstIndex(of: "-assist"),
           let level = arguments[safe: index + 1].flatMap(AssistLevel.init(rawValue:)) {
            store.assist = level
        }
        // `-solo headsUp` sets the shape a ranked game played alone is dealt in, so both can be
        // seen on a phone that has only ever picked one.
        if let index = arguments.firstIndex(of: "-solo"),
           let format = arguments[safe: index + 1].flatMap(RankedSolo.init(rawValue:)) {
            store.rankedSolo = format
        }
    }

    /// `-collected 18 -packs 2` plants an album part way through, with packs waiting, and
    /// `-volume napoli` has every volume before that one full and the cards in that one.
    /// `-giftPacks forziere,reliquia` leaves those gifts waiting too, each on its own shelf:
    /// the shop's in the shop, the cards in the album.
    @MainActor
    private static func plantAlbum(_ book: AlbumBook, with arguments: [String]) {
        let collected = arguments.firstIndex(of: "-collected").flatMap { Int(arguments[safe: $0 + 1] ?? "") }
        let volume = arguments.firstIndex(of: "-volume").flatMap { Volume(rawValue: arguments[safe: $0 + 1] ?? "") }
        let packs = arguments.firstIndex(of: "-packs").flatMap { Int(arguments[safe: $0 + 1] ?? "") }
        if collected != nil || packs != nil || volume != nil {
            book.pretend(packs: packs ?? 0, found: collected ?? 0, in: volume ?? .riviera)
        }
        if let list = arguments.firstIndex(of: "-giftPacks").flatMap({ arguments[safe: $0 + 1] }) {
            book.pretend(gifts: list.split(separator: ",").compactMap { PackTier(rawValue: String($0)) })
        }
    }

    /// `-rank 1240` puts a league under the wordmark. `-rankGames 0` gives the rosette of
    /// somebody who has never played ranked, `-rankChange 25` plants the last game's swing,
    /// `-rankStreak 4` plants a run to be paid for, `-housePlayed 10` spends the day's games
    /// against the house, and `-seasonEnd 745` plants a finished season not paid out.
    @MainActor
    private static func applyRank(_ store: TableStore, with arguments: [String]) {
        guard let index = arguments.firstIndex(of: "-rank"),
              let rating = Int(arguments[safe: index + 1] ?? "") else { return }
        let games = arguments.firstIndex(of: "-rankGames").flatMap { Int(arguments[safe: $0 + 1] ?? "") } ?? 20
        let change = arguments.firstIndex(of: "-rankChange").flatMap { Int(arguments[safe: $0 + 1] ?? "") }
        let finished = arguments.firstIndex(of: "-seasonEnd").flatMap { Int(arguments[safe: $0 + 1] ?? "") }
        let streak = arguments.firstIndex(of: "-rankStreak").flatMap { Int(arguments[safe: $0 + 1] ?? "") } ?? 0
        let housePlayed = arguments.firstIndex(of: "-housePlayed").flatMap { Int(arguments[safe: $0 + 1] ?? "") } ?? 3
        store.pretendRank(rating: rating, games: games, change: change, finished: finished, streak: streak,
                          housePlayed: housePlayed)
    }

    /// The flags that open a table outright. True when one of them took over.
    @MainActor
    private static func openTable(_ store: TableStore, with arguments: [String]) -> Bool {
        if startsCoached { store.playCoached(); return true }
        if showsWaitingRoom { openWaitingRoom(store, with: arguments); return true }
        // `-joinFirst` browses and sits down at the first table it finds, so a join can be
        // watched end to end from two devices with no tapping.
        if arguments.contains("-joinFirst") { store.joinFirstTableFound(); return true }
        // `-quickGame` deals a quick table at whichever size the lobby's pills are set to.
        if arguments.contains("-quickGame") { store.playQuickGame(); return true }
        if arguments.contains("-dailyDeal") { store.playTodaysDeal(); return true }
        // `-resume` picks the saved game back up without going through the lobby card.
        if arguments.contains("-resume") { store.loadSavedGame(); store.resumeSavedGame(); return true }
        // `-rankedHouse` sits down at a ranked table against the house, which a simulator with no
        // Game Center account cannot reach on its own. `-target 2` ends the game in a round, and
        // `-solo headsUp` or `-solo teams` picks the shape the table is dealt in.
        if arguments.contains("-rankedHouse") {
            let target = arguments.firstIndex(of: "-target").flatMap { Int(arguments[safe: $0 + 1] ?? "") } ?? 11
            store.pretendRankedHouse(targetScore: target)
            return true
        }
        return false
    }

    /// `-room` opens a real table on the Worker, code and all. Anything else is a nearby table,
    /// which needs nothing but this phone.
    @MainActor
    private static func openWaitingRoom(_ store: TableStore, with arguments: [String]) {
        if arguments.contains("-room") { store.openRoom() } else { store.host(teams: false) }
        store.pretendsInvited = arguments.contains("-invited")
        let seated = arguments.firstIndex(of: "-bots").flatMap { Int(arguments[safe: $0 + 1] ?? "") } ?? 0
        for _ in 0..<seated { store.addBot() }
    }

    /// `-startTable`, taking `-seats`, `-bots`, `-teams`, `-clock`, `-target` and
    /// `-house scopone,napola` (the raw names, comma separated).
    @MainActor
    private static func startLocalTable(_ store: TableStore, with arguments: [String]) {
        guard arguments.contains("-startTable") else { return }
        let seats = arguments.firstIndex(of: "-seats").flatMap { Int(arguments[safe: $0 + 1] ?? "") } ?? 3
        let names = (0..<min(max(seats, 2), 4)).map { (["Quentin"] + BotNames.all)[$0] }
        // `-bots n` seats the machine in the last n chairs. The first chair is always yours.
        let bots = arguments.firstIndex(of: "-bots").flatMap { Int(arguments[safe: $0 + 1] ?? "") } ?? 0
        let chairs = names.enumerated().map { seat, name in
            seat >= names.count - min(bots, names.count - 1) ? LocalSeat.bot(name: name) : .person(name: name)
        }
        let clock = arguments.firstIndex(of: "-clock").flatMap { TurnClock(rawValue: arguments[safe: $0 + 1] ?? "") } ?? .default
        let target = arguments.firstIndex(of: "-target").flatMap { Int(arguments[safe: $0 + 1] ?? "") } ?? 11
        let house = arguments.firstIndex(of: "-house").map { index in
            Set((arguments[safe: index + 1] ?? "").split(separator: ",").compactMap { HouseRule(rawValue: String($0)) })
        } ?? []
        store.playOnThisDevice(
            seats: chairs,
            teams: arguments.contains("-teams") && names.count == 4,
            turnClock: clock,
            targetScore: target,
            house: house
        )
    }
    #endif
}
