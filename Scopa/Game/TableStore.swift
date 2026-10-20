import Foundation
import os
import Observation
import ScopaCore
import GameKit
import ScopaGameCenter
import ScopaMultipeer
import ScopaRelay
import ScopaRewards
import UIKit

/// One object behind every screen. Hosting, joining and pass-and-play all reduce to the same
/// `TableUpdate` stream, so the views never learn which one is running.
@MainActor
@Observable
final class TableStore {
    enum Route: Hashable { case lobby, waiting, table }

    struct SeenReaction: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let reaction: Reaction
    }

    /// One card played, as the table screen tells it back. Events arrive after the view they
    /// came from, so by then the captured cards are gone from the table and only this still
    /// says what was played and what it took.
    struct Play: Equatable, Identifiable {
        let id = UUID()
        let seat: Int
        let name: String
        let mark: SeatMark
        /// Wearing this week's badge. Read once, when the play happened, so the callout does
        /// not ask the table who everybody is while it is being drawn.
        let isHonoured: Bool
        /// Drawn with the machine's face rather than an initial. Read once, like `isHonoured`.
        let isBot: Bool
        let card: Card
        let captures: [Card]
        let sweeps: Bool

        var tookSettebello: Bool { captures.contains(.settebello) || (card == .settebello && !captures.isEmpty) }
    }

    enum Notice: Equatable {
        case scopa(String)
        /// Hands were empty and the stock dealt three more to everyone.
        case dealt
        case rejected(String)
        case playerLeft(String)
        /// Somebody whose phone had dropped is back in their chair.
        case playerBack(String)
        /// Somebody left a ranked game in its first minutes, so it counts for nobody. Nil when
        /// it was this phone.
        case calledOff(String?)
        case joinRefused
    }

    private enum Backend {
        case none
        case host(HostCoordinator)
        case guest(GuestClient)
        case hotSeat(HotSeatTable)
    }

    private(set) var route: Route = .lobby
    private(set) var lobby: Lobby?
    private(set) var view: PlayerView?
    private(set) var nearby: [NearbyTable] = []
    private(set) var notice: Notice?
    /// The last card anyone played. Replaced on every move, so the screen keys its callout on
    /// the id rather than the value.
    private(set) var lastPlay: Play?
    /// How the last round scored. The finished-game summary needs it, because the phase there
    /// carries the winner rather than the breakdown.
    private(set) var lastRoundScore: RoundScore?
    /// The cards still on the table when the round ended, and the side that took them, which
    /// is whoever captured last. Shown on the summary, because the rule surprises everyone the
    /// first time.
    struct Leftovers: Equatable {
        let side: Int
        let cards: [Card]
    }
    private(set) var leftovers: Leftovers?
    /// Reactions people have sent, newest last. The table screen drains these as it shows them.
    private(set) var reactions: [SeenReaction] = []
    private(set) var isHost = false
    private(set) var isBrowsing = false

    /// The table an invitation is out to. No second table can be tapped while it is set: two
    /// invitations at once is one connection too many.
    private(set) var joining: NearbyTable?
    /// The nearby table the last join could not reach, explained on the sheet itself: the
    /// notice bar slides in behind a sheet, where nobody saw it.
    private(set) var unreachedTable: NearbyTable?
    /// People whose device left mid-game. The host's bot plays their cards, and the table
    /// shows them as a bot until they come back.
    private(set) var departed: Set<PlayerID> = []
    /// The local game that was under way when the app was last closed, and the one being
    /// written down as the current game goes.
    private(set) var savedGame: SavedGame?
    private var hasLookedForSavedGame = false
    private var saveTask: Task<Void, Never>?

    static let defaultName = "Player"

    /// The mark on your seat, seen by everyone at the table.
    var seatMark: SeatMark {
        didSet { UserDefaults.standard.set(seatMark.rawValue, forKey: SeatMark.stored) }
    }

    var playerName: String {
        didSet { UserDefaults.standard.set(playerName, forKey: Self.nameKey) }
    }

    /// How much the table helps you. Kept on the device, never sent to other players.
    var assist: AssistLevel {
        didSet { UserDefaults.standard.set(assist.rawValue, forKey: Self.assistKey) }
    }

    /// A tap plays a card that has one move only, rather than picking it up for a second.
    /// Off until asked for, so nobody's double tap starts playing cards it never used to.
    var oneTapPlays: Bool {
        didSet { UserDefaults.standard.set(oneTapPlays, forKey: Self.oneTapKey) }
    }

    /// The tag in the cloth's top corner that recaps the last move. On until turned off.
    var showsLastMove: Bool {
        didSet { UserDefaults.standard.set(showsLastMove, forKey: Self.lastMoveKey) }
    }

    /// How hard the bots play at the tables this phone sets up. Today's deal and a wager
    /// ignore it and use `Self.contestLevel`, so everybody plays the same opponent.
    var botLevel: BotLevel {
        didSet { UserDefaults.standard.set(botLevel.rawValue, forKey: Self.botLevelKey) }
    }

    /// How many sit down at the quick game, and whether four play as two sides. Kept so the
    /// size you play most is the size the next game deals.
    var quickTable: QuickTable {
        didSet { UserDefaults.standard.set(quickTable.rawValue, forKey: Self.quickTableKey) }
    }

    /// How a ranked game played alone is dealt: heads-up, or the table of four. Kept, like
    /// `quickTable`, so the shape you play is the shape the next search looks for.
    var rankedSolo: RankedSolo {
        didSet { UserDefaults.standard.set(rankedSolo.rawValue, forKey: Self.rankedSoloKey) }
    }

    /// The bot behind today's deal and every empty seat at a wager table. Fixed so the ladder
    /// compares like with like and nobody can turn the opposition down and farm the pot.
    ///
    /// Ranked does not use it. A wager and today's deal are one table everybody is compared
    /// on, while a ranked table is dealt for one person. See `houseStrength`.
    static let contestLevel = BotLevel.hard

    /// The house's game at a ranked table, pitched at the division this phone stands in.
    ///
    /// A division either way is about four points of how often the bot takes its own best
    /// advice. See `BotStrength.house`. Unranked and Bronze III come out the same, so a phone
    /// that has never played ranked does not meet the hardest opponent in the app.
    var houseStrength: BotStrength { BotStrength.house(atStep: ownStep) }

    /// The division this phone stands in, Bronze III before the ladder has said.
    var ownStep: Int { rank?.standing.step ?? 0 }

    /// The division the house plays at the table on screen, which is the league its chairs
    /// wear: the host's choice off the lobby at a table over the network, so every phone shows
    /// the same, or what this phone dealt at its own. See `Ranking.houseStep`.
    var tableHouseStep: Int { lobby?.houseStep ?? dealtHouseStep ?? ownStep }

    /// The step a ranked table on this phone was dealt at. Nil anywhere else.
    private(set) var dealtHouseStep: Int?

    /// Which deck you like looking at. Yours alone: nothing about it crosses the wire.
    var cardTheme: CardTheme {
        didSet {
            UserDefaults.standard.set(cardTheme.style.rawValue, forKey: Self.styleKey)
            UserDefaults.standard.set(cardTheme.skin.rawValue, forKey: Self.skinKey)
            if cardTheme.style != oldValue.style { tryOn.yield(.cardTheme) }
            if cardTheme.skin != oldValue.skin { tryOn.yield(.cardSkin) }
        }
    }

    /// A deck or a cloth from the shop worn for a game, over the ones above. See `TryOn`.
    let tryOn = TryOn()

    /// The language the game speaks. Kept on the device like the rest of the preferences.
    var language: Language {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey) }
    }

    /// The colour of the table under the cards. Yours alone, like the deck.
    var tableFelt: TableFelt {
        didSet {
            UserDefaults.standard.set(tableFelt.rawValue, forKey: Self.feltKey)
            tryOn.yield(.felt)
        }
    }

    /// The weave of the cloth, where `tableFelt` is its colour. Yours alone, like the felt.
    var tapis: Tapis {
        didSet {
            UserDefaults.standard.set(tapis.rawValue, forKey: Self.tapisKey)
            tryOn.yield(.tapis)
        }
    }

    /// What is printed on the back of the cards. Yours alone, like the deck and the felt.
    var cardBack: CardBackPattern {
        didSet {
            UserDefaults.standard.set(cardBack.rawValue, forKey: CardBackPattern.stored)
            tryOn.yield(.cardBack)
        }
    }

    /// Who sits by your hand and watches you play. Unlike the deck and the felt this goes on
    /// the wire, so the rest of the table sees it.
    var companion: Companion {
        didSet { UserDefaults.standard.set(companion.rawValue, forKey: Companion.stored) }
    }

    /// What is drawn round your seat mark. Goes on the wire, like the mark itself.
    var cornice: Cornice {
        didSet { UserDefaults.standard.set(cornice.rawValue, forKey: Cornice.stored) }
    }

    /// The colour your seat mark is struck in. Goes on the wire: it is your icon, and the
    /// first thing the rest of the table sees of you.
    var livery: SeatLivery {
        didSet { UserDefaults.standard.set(livery.rawValue, forKey: SeatLivery.stored) }
    }

    /// What the table does when you sweep it, on every phone at the table: it travels with
    /// your seat like the badge frame, so the others see your sweep the way you bought it.
    var flourish: Flourish {
        didSet { UserDefaults.standard.set(flourish.rawValue, forKey: Flourish.stored) }
    }

    /// What your own sweep sounds like. Yours alone, and inaudible to anyone else.
    var cheer: Cheer {
        didSet { UserDefaults.standard.set(cheer.rawValue, forKey: Cheer.stored) }
    }

    /// Whether the rules have been read. The walkthrough shows itself on a first launch, and
    /// after that only when it is asked for.
    var hasSeenRules: Bool {
        didSet { UserDefaults.standard.set(hasSeenRules, forKey: Self.rulesKey) }
    }

    /// Whether the house tie rule is offered on the tables this phone sets up. Hidden until
    /// the phrase has been said in the settings, because it is not a rule anybody looking up
    /// Scopa would recognise.
    var knowsTieRules: Bool {
        #if DEBUG
        if pretendsTieRules { return true }
        #endif
        return wasToldTieRules
    }

    private var wasToldTieRules: Bool {
        didSet { UserDefaults.standard.set(wasToldTieRules, forKey: Self.tieRulesKey) }
    }

    /// Hears the phrase said in the settings. True when it was the right one, and from then
    /// on the choice stays available.
    @discardableResult
    func hearTieRules(_ phrase: String) -> Bool {
        guard Passphrase.isRight(phrase) else { return false }
        wasToldTieRules = true
        return true
    }

    #if DEBUG
    /// `-tieRules` says the phrase for this launch only. Nothing is written down.
    private var pretendsTieRules = false
    #endif

    /// What this game has earned so far, tallied from the events every device already receives.
    /// No denari cross the wire: each device counts its own side from its own copy.
    private(set) var tally: RewardTally?
    /// The finished game written down, and what the reviewer made of it. The record lands with
    /// the game's last events, and the review follows once it has been read back.
    private(set) var record: GameRecord?
    private(set) var review: GameReview?
    private var reviewTask: Task<Void, Never>?
    /// Every daily deal played on this phone.
    let dailyBook = DailyDealBook()
    /// The day whose deal is on the table. Nil at any other table.
    private(set) var dailyDay: String?
    /// How today's deal went, once its round has ended.
    private(set) var dailyResult: DailyDealResult?
    /// The day whose deal was played out just now. Unlike `dailyDay` it survives leaving the
    /// table, so the lobby can make something of the card that has just changed. Cleared when
    /// the lobby is left again.
    private(set) var freshDailyDay: String?

    func clearFreshDaily() { freshDailyDay = nil }

    /// What is riding on this game. The stake is already out of the purse by the time the
    /// table exists, and the pot comes back through `wagerID`.
    private(set) var stake: Stake?
    private(set) var wagerID = UUID()
    /// A wager whose table never opened. The stake is already out of the purse, and the purse
    /// lives a floor up, so this is how it hears that it has to go back.
    struct RefusedStake: Equatable, Identifiable {
        let id = UUID()
        let stake: Stake
        let gameID: UUID
    }
    private(set) var refusedStake: RefusedStake?

    /// Called once the refund has been written, so the same stake is never handed back twice.
    func clearRefusedStake() { refusedStake = nil }
    /// A ranked table: real people only, the result reported to the ladder.
    private(set) var isRanked = false
    /// A ranked duo: this phone and a friend against two others, in teams, rated together.
    private(set) var isRankedDuo = false
    /// The shape the ranked table on screen was dealt in. Read when the table fills, which is
    /// long after the button that set it, and by the house fallback.
    private(set) var rankedFormat = RankedSolo.teams
    private(set) var rankedID = UUID()
    /// The league as last heard from the ladder. Kept on the phone so the lobby can show it
    /// before Game Center is awake.
    private(set) var rank: Ladder.RankAnswer? {
        didSet {
            if let rank, let data = try? JSONEncoder().encode(rank) { UserDefaults.standard.set(data, forKey: Self.rankKey) }
            LadderPrizes.remember(rank)
        }
    }
    /// What the last ranked game did, for the summary. Nil until the ladder answers.
    private(set) var rankChange: Int?
    /// The last ranked game this phone told the ladder about. See `reportRanked`.
    private var reportedGameID: UUID?
    /// When this phone saw the ranked game on screen dealt, for `EarlyExit`. The distant past
    /// for a game picked up again after a relaunch, whose deal it never saw.
    private var rankedDealtAt: Date?
    /// The last card or reaction from each person at a ranked table this phone hosts. When a
    /// chair empties, that is when it was last surely there. See `EarlyExit`.
    private var lastSeen: [PlayerID: Date] = [:]
    /// True while this phone waits for the ladder to settle the game just played, so the
    /// summary can say it is counting rather than show nothing.
    private(set) var isAwaitingLadder = false
    /// Where everyone else at a ranked table stands, by bare Game Center id.
    ///
    /// Asked of the ladder rather than carried on the wire beside the seat mark, because a
    /// self-reported league is worth nothing.
    private(set) var opponentRanks: [String: Ladder.RankAnswer] = [:]
    private static let rankKey = "rank"

    /// The top of yesterday's ladder, kept so the lobby has a number to show before the Worker
    /// answers, and one to keep if it never does.
    private(set) var bestYesterday: Ladder.Best? {
        didSet {
            if let bestYesterday, let data = try? JSONEncoder().encode(bestYesterday) {
                UserDefaults.standard.set(data, forKey: Self.bestKey)
            }
        }
    }
    private static let bestKey = "bestYesterday"

    /// The week's tasks, their progress and the badge they hand over. The lobby, the table
    /// and the board all read it from here.
    let challenges = ChallengeBook()

    /// The deck as a thing to collect: what has been found, and the packs waiting to be
    /// opened. Its own book for the same reason the week has one — the album is counted
    /// off finished games and nothing else, and the summary, the settings and the page
    /// itself all read the same numbers from here.
    let albumBook = AlbumBook()

    /// The solo campaign's stars, and the way back to its map after a game.
    let campaignBook = CampaignBook()
    /// How the line to an online table is, for the reconnect banner, and the seat kept on the
    /// phone for coming back to a room after the app was closed. See `TableConnection`.
    let connection = TableConnection()
    /// The campaign table being played. Nil at any other table.
    private(set) var campaignStage: CampaignStage?
    /// The practice table for a house rule being played, which counts for nothing. Set by
    /// `playPractice`, nil at any other table.
    var practice: RulePractice?
    /// The quick game being played with Scatouch on, which counts for nothing either. Nil at
    /// any other table. See `ScatouchTable`.
    private(set) var scatouch: ScatouchTable?

    /// The week's tasks, once the game that finished the last of them has ended, for the card
    /// that hands the laurel over. Cleared once shown, like `freshDailyDay`.
    private(set) var finishedChallenge: [WeeklyChallenge.Goal]?

    func clearFinishedChallenge() { finishedChallenge = nil }

    #if DEBUG
    /// Plants the week as just finished, for the debug launch. The real one is set by the
    /// game that finishes it, which is a week of play away.
    func pretendChallengeFinished() {
        challenges.pretend(count: .max)
        finishedChallenge = challenges.goals
    }
    #endif

    private static let nameKey = "playerName"
    private static let assistKey = "assistLevel"
    private static let oneTapKey = "oneTapPlays"
    private static let lastMoveKey = "showsLastMove"
    private static let botLevelKey = "botLevel"
    private static let quickTableKey = "quickTable"
    private static let rankedSoloKey = "rankedSolo"
    /// The old single key holding one of five regional names. `CardTheme.migrated(from:)`
    /// carries a pick stored under it across to the style and skin keys.
    private static let themeKey = "cardTheme"
    private static let styleKey = "cardStyle"
    private static let skinKey = "cardSkin"
    private static let languageKey = "language"
    private static let feltKey = "tableFelt"
    private static let tapisKey = "tapis"
    private static let rulesKey = "hasSeenRules"
    private static let tieRulesKey = "knowsTieRules"
    private var backend: Backend = .none
    /// Which seats on this phone the machine is playing, and which one the owner sits in.
    /// Only the local table has either. Both are empty for a networked game.
    private var botSeats: Set<Int> = []
    private(set) var deviceSeat = 0
    private var multipeer: MultipeerSession?
    private var gameCenter: GameCenterSession?
    private var relay: RelaySession?
    /// The four letters at the top of the waiting room, and the link that shares them. Set the
    /// moment a table is opened, so the code can be sent on while the table stands empty.
    private(set) var room: Relay.Table?
    /// Where an online game has got to before there is a lobby to show. Nil at any other table,
    /// and again once the seats are taken.
    private(set) var onlineStatus: OnlineStatus?
    /// Who a search has just found, while the moment that says so plays. See `MatchFound`.
    private(set) var matchFound: MatchFound?
    /// How many the online match was made for. The table waits until they are all seated.
    private var onlineSize: Int?
    /// Whether the host says when to deal, rather than the table dealing itself once everyone
    /// is seated. True for a table of invited friends, whose empty chairs the host fills first.
    private var hostDeals = false
    private var searchTask: Task<Void, Never>?

    enum OnlineStatus: Equatable {
        case signingIn
        case searching
        /// Asking the Worker for a table of our own.
        case opening
        case seating
    }

    /// A ranked search while it runs, for the bar in the sheet. Nil when nothing is being
    /// looked for.
    ///
    /// A ranked search has a known length — `rankedSearchTime` — so what the sheet shows can
    /// be how much of it is left rather than a spinner that says only that something is
    /// happening. Nothing else in the app knows its own length, which is why this is ranked's
    /// alone.
    struct RankedSearch: Equatable {
        let startedAt: Date
        /// How long the whole search runs before it gives up.
        let length: TimeInterval
        /// The house is on offer: a few seconds in, and again once the search has run out.
        /// "Keep looking" puts it away while the search still has time.
        var offersHouse = false
        /// The search ran its length and found nobody. Nothing is being looked for, and the
        /// offer waits for an answer rather than sitting the house down unasked.
        var isOver = false
        /// Other players in the ranked queue right now. Nil when the queue could not be reached.
        var searching: Int?
    }

    private(set) var rankedSearch: RankedSearch?

    /// A ranked duo looking for another pair, both phones held at their Game Center table
    /// meanwhile. Nil at any other time. See `searchAsPair` and `followLeader`.
    struct DuoSearch: Equatable {
        let startedAt: Date
        /// How long the search runs, for the line that runs out over it, as a search alone has.
        var length: TimeInterval = TableStore.duoSearchTime
        /// This phone invited the other: it searches, and only it can take the house.
        let leads: Bool
        /// The other phone of the pair.
        let partner: String
        /// Other pairs searching right now. Nil until the queue has answered.
        var searching: Int?
        /// The house is on offer, a few seconds in.
        var offersHouse = false
        /// The search ran its length and found no pair.
        var isOver = false
    }

    private(set) var duoSearch: DuoSearch?
    /// The leader walked out of the held table while this phone followed its search.
    private var duoLeaderLeft = false
    private var pump: Task<Void, Never>?
    private var browsePump: Task<Void, Never>?
    private var problemPump: Task<Void, Never>?
    private var reconnectPump: Task<Void, Never>?
    /// The invitation sheet for a friend named at a table that is already open. Its own task,
    /// because `searchTask` is for finding a table and this one goes out from a standing one.
    private var inviteTask: Task<Void, Never>?

    init(playerName: String? = nil, assist: AssistLevel? = nil) {
        self.playerName = playerName ?? DebugLaunch.playerName
            ?? UserDefaults.standard.string(forKey: Self.nameKey) ?? Self.defaultName
        self.assist = assist ?? Self.stored(Self.assistKey, or: .default)
        self.oneTapPlays = UserDefaults.standard.bool(forKey: Self.oneTapKey)
        self.showsLastMove = UserDefaults.standard.object(forKey: Self.lastMoveKey) as? Bool ?? true
        self.botLevel = Self.stored(Self.botLevelKey, or: .default)
        self.quickTable = Self.stored(Self.quickTableKey, or: .default)
        self.rankedSolo = Self.stored(Self.rankedSoloKey, or: .default)
        self.cardTheme = Self.storedTheme()
        self.language = Self.stored(Self.languageKey, or: .default)
        self.tableFelt = Self.stored(Self.feltKey, or: .default)
        self.tapis = DebugLaunch.tapis ?? Self.stored(Self.tapisKey, or: .default)
        self.cardBack = Self.stored(CardBackPattern.stored, or: .free)
        self.companion = DebugLaunch.companion ?? Self.stored(Companion.stored, or: .default)
        self.cornice = Self.stored(Cornice.stored, or: Cornice.none)
        self.livery = Self.stored(SeatLivery.stored, or: .tavolo)
        self.flourish = DebugLaunch.flourish ?? Self.stored(Flourish.stored, or: .stendardo)
        self.cheer = Self.stored(Cheer.stored, or: .casa)
        self.seatMark = Self.stored(SeatMark.stored, or: .initial)
        self.hasSeenRules = UserDefaults.standard.bool(forKey: Self.rulesKey)
        // Buying the ads out and this rule share one phrase, so anyone who said it before the
        // rule existed is not made to say it again.
        self.wasToldTieRules = UserDefaults.standard.bool(forKey: Self.tieRulesKey) || AdsStore.wasSwept
        self.rank = Self.decoded(Self.rankKey)
        self.bestYesterday = Self.decoded(Self.bestKey)
    }

    /// Reads every stored preference again, for a table already on screen.
    ///
    /// The one caller is `AccountSync`, which writes the merged account into `UserDefaults`
    /// and then needs the live store to catch up. It reads exactly what `init` reads, and is
    /// beside it so the two cannot drift: a preference added to one and not the other is a
    /// preference that syncs and never appears, or appears and never syncs.
    ///
    /// The saved game, the rank and the ladder's cached answers are not here. They are not
    /// preferences, and nothing merges them.
    func readStoredAgain() {
        playerName = UserDefaults.standard.string(forKey: Self.nameKey) ?? Self.defaultName
        assist = Self.stored(Self.assistKey, or: .default)
        oneTapPlays = UserDefaults.standard.bool(forKey: Self.oneTapKey)
        showsLastMove = UserDefaults.standard.object(forKey: Self.lastMoveKey) as? Bool ?? true
        botLevel = Self.stored(Self.botLevelKey, or: .default)
        quickTable = Self.stored(Self.quickTableKey, or: .default)
        rankedSolo = Self.stored(Self.rankedSoloKey, or: .default)
        cardTheme = Self.storedTheme()
        language = Self.stored(Self.languageKey, or: .default)
        tableFelt = Self.stored(Self.feltKey, or: .default)
        tapis = DebugLaunch.tapis ?? Self.stored(Self.tapisKey, or: .default)
        cardBack = Self.stored(CardBackPattern.stored, or: .free)
        companion = DebugLaunch.companion ?? Self.stored(Companion.stored, or: .default)
        cornice = Self.stored(Cornice.stored, or: Cornice.none)
        livery = Self.stored(SeatLivery.stored, or: .tavolo)
        flourish = DebugLaunch.flourish ?? Self.stored(Flourish.stored, or: .stendardo)
        cheer = Self.stored(Cheer.stored, or: .casa)
        seatMark = Self.stored(SeatMark.stored, or: .initial)
        hasSeenRules = UserDefaults.standard.bool(forKey: Self.rulesKey)
        wasToldTieRules = UserDefaults.standard.bool(forKey: Self.tieRulesKey) || AdsStore.wasSwept
        challenges.readStoredAgain()
        albumBook.readStoredAgain()
    }

    /// One stored preference, by its raw value.
    private static func stored<T: RawRepresentable>(_ key: String, or fallback: T) -> T where T.RawValue == String {
        UserDefaults.standard.string(forKey: key).flatMap(T.init(rawValue:)) ?? fallback
    }

    /// One stored answer from the ladder, or nil if there is none to read.
    private static func decoded<T: Decodable>(_ key: String) -> T? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    /// The deck, from the drawing and the colourway, or carried across from the single key
    /// that used to hold one of five regional names.
    private static func storedTheme() -> CardTheme {
        let defaults = UserDefaults.standard
        guard let style = defaults.string(forKey: Self.styleKey).flatMap(CardStyle.init(rawValue:)),
              let skin = defaults.string(forKey: Self.skinKey).flatMap(CardSkin.init(rawValue:))
        else { return CardTheme.migrated(from: defaults.string(forKey: Self.themeKey)) }
        return CardTheme(style: style, skin: skin)
    }

    private var localPlayer: Player {
        Player(id: PlayerID(rawValue: Device.id), name: playerName, mark: seatMark.wireValue,
               honour: challenges.honourOnWire, cornice: cornice.wireValue,
               companion: companion.wireValue, livery: livery.wireValue, flourish: flourish.wireValue)
    }

    // MARK: Hosting

    func host(teams: Bool = false) {
        reset()
        isHost = true
        Log.table.info("Hosting a table as \(self.playerName, privacy: .public)")
        let session = MultipeerSession(localPlayer: localPlayer)
        multipeer = session
        let coordinator = HostCoordinator(transport: session, advertising: session, teams: teams, strength: botLevel.strength)
        backend = .host(coordinator)
        route = .waiting
        watchForProblems(session.problems)
        Task {
            consume(await coordinator.updates)
            await coordinator.start()
        }
    }

    /// Multipeer can refuse to advertise or browse, most often because the local network
    /// prompt was turned down, and a Game Center match can drop. Without this the screen waits
    /// for a table that is never going up.
    private func watchForProblems(_ problems: AsyncStream<String>) {
        problemPump?.cancel()
        problemPump = Task { [weak self] in
            for await problem in problems {
                guard !Task.isCancelled else { return }
                Log.table.error("Transport problem: \(problem, privacy: .public)")
                self?.notice = .rejected(problem)
            }
        }
    }

    /// Teams, as the host's tab sets them. A friend at a table of bots is sat across from the
    /// host when teams come on, since that is who somebody invited a friend to play with. The
    /// chairs can still be swapped after; see `teamUp(with:)`.
    func setTeams(_ teams: Bool) {
        guard case .host(let coordinator) = backend else { return }
        let friend = teams ? defaultPartner : nil
        Task {
            await coordinator.setTeams(teams)
            if let friend { await coordinator.teamUp(with: friend) }
        }
    }

    /// The first person at the table, when a bot holds the chair across from the host.
    private var defaultPartner: PlayerID? {
        guard let players = lobby?.players, players.count == 4, players[2].isBot else { return nil }
        return players.dropFirst().first { !$0.isBot }?.id
    }

    /// Sits `id` across from the host, which is who the host plays with at a table in teams.
    func teamUp(with id: PlayerID) {
        guard isSettingTheTable, case .host(let coordinator) = backend else { return }
        Task { await coordinator.teamUp(with: id) }
    }

    func setTurnClock(_ clock: TurnClock) {
        guard case .host(let coordinator) = backend else { return }
        Task { await coordinator.setTurnClock(clock) }
    }

    func setPrimiera(_ rule: PrimieraRule) {
        guard case .host(let coordinator) = backend else { return }
        Task { await coordinator.setPrimiera(rule) }
    }

    func setTies(_ rule: TieRule) {
        guard case .host(let coordinator) = backend else { return }
        Task { await coordinator.setTies(rule) }
    }

    func setHouse(_ rules: Set<HouseRule>) {
        guard case .host(let coordinator) = backend else { return }
        Task { await coordinator.setHouse(rules) }
    }

    func setTargetScore(_ score: Int) {
        guard case .host(let coordinator) = backend else { return }
        Task { await coordinator.setTargetScore(score) }
    }

    /// Whether this phone is setting the table, with the cards still to be dealt. The seats
    /// are the host's to arrange only until then. Never at a ranked table, a duo's included:
    /// its empty chairs wait for another pair, and the house only fills them on the leader's word.
    var isSettingTheTable: Bool {
        guard case .host = backend, !isRanked else { return false }
        return isHost && route == .waiting
    }

    /// Whether there is still an empty chair for the host to sit a bot at.
    var canSeatBots: Bool { isSettingTheTable && lobby?.isFull == false }

    /// Somebody who accepted is still on their way to their chair. Dealing now would start the
    /// game without them.
    var isWaitingForInvited: Bool {
        guard let onlineSize, let lobby else { return false }
        return lobby.players.filter { !$0.isBot }.count < onlineSize
    }

    /// Seats one bot at the table being set. The host's device plays it.
    func addBot() {
        guard case .host(let coordinator) = backend else { return }
        Task { await coordinator.addBot(names: BotNames.all) }
    }

    /// Frees a bot's chair again, for a friend still on their way or for a smaller table.
    func removeBot(_ id: PlayerID) {
        guard case .host(let coordinator) = backend else { return }
        Task { await coordinator.removeBot(id) }
    }

    /// Whether one more friend can be asked to this table.
    ///
    /// Only a table of invited friends can: it is a Game Center match, so there is an
    /// invitation to send, and it waits for the host rather than dealing itself once it fills.
    /// Friends find a nearby table through "Join a friend's table → Nearby" instead, and ranked and code tables
    /// are made for the people already at them.
    var canInviteFriends: Bool {
        #if DEBUG
        if pretendsInvited { return isSettingTheTable && lobby?.isFull == false }
        #endif
        return isSettingTheTable && hostDeals && gameCenter != nil && lobby?.isFull == false
    }

    #if DEBUG
    /// `-invited` draws the waiting room as a table of invited friends, without needing two
    /// Game Center accounts. The invitation needs a real match, so tapping it does nothing.
    var pretendsInvited = false
    #endif

    /// Apple's invitation sheet, for a chair at a table that already exists. The friend accepts
    /// on their own phone and the lobby grows a player. If bots took the last chairs meanwhile,
    /// the last of them stands up.
    func inviteFriendToTable() {
        guard canInviteFriends, let session = gameCenter else { return }
        Task {
            await GameCenter.invite(to: session.match,
                                    seats: GameConfiguration.playerRange.upperBound) { controller in
                Self.present(controller)
            }
        }
    }

    /// Whether a Game Center friend can be asked to a chair at this table by name.
    ///
    /// A table of ours can, because a code is all the invitation has to carry. Unlike
    /// `canInviteFriends` this needs Game Center only on the asking phone: what arrives at the
    /// other end is a room, and a room asks nobody to sign in.
    var canInviteToRoom: Bool { isSettingTheTable && room != nil && lobby?.isFull == false }

    /// Apple's invitation sheet, for a friend to be named rather than sent a code.
    ///
    /// The table is not touched and the host stays in the waiting room. The friend's phone
    /// reads the code out of the invitation and walks to the room, and the match Game Center
    /// makes on the way is dropped at both ends. See `GameCenter.inviteToRoom`.
    func inviteFriendToRoom() {
        guard canInviteToRoom, let room, let group = Relay.inviteGroup(for: room.code) else { return }
        inviteTask?.cancel()
        inviteTask = Task {
            do {
                _ = try await GameCenter.signIn { controller in Self.present(controller) }
                guard !Task.isCancelled else { return }
                let match = try await sheetUntilSomebodyArrives {
                    try await GameCenter.inviteToRoom(group: group) { controller in Self.present(controller) }
                }
                Log.table.info("Asked a friend by name to table \(room.code, privacy: .public)")
                GameCenter.leave(match)
            } catch GameCenterError.cancelled {
                // The sheet was closed. Nothing was promised and nothing has to be undone.
            } catch GameCenterError.notSignedIn {
                notice = .rejected("Sign in to Game Center to ask a friend by name")
            } catch {
                Log.table.error("Could not ask a friend by name: \(String(describing: error), privacy: .public)")
                notice = .rejected("Could not send the invitation. Send the code instead.")
            }
        }
    }

    /// Runs Apple's invitation sheet for a room, and takes it down if somebody walks in while it
    /// is up. The friend's phone goes to the room by the code and only rings the sheet's
    /// doorbell on the way, and a sheet still waiting for that ring once they are sitting there
    /// is a sheet the host has to close by hand.
    private func sheetUntilSomebodyArrives(_ sheet: @escaping @MainActor () async throws -> GKMatch) async throws -> GKMatch {
        let seated = lobby?.players.filter { !$0.isBot }.count ?? 0
        let watch = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, !Task.isCancelled else { return }
                if (self.lobby?.players.filter { !$0.isBot }.count ?? 0) > seated { return GameCenter.takeDownMatchmaker() }
            }
        }
        defer { watch.cancel() }
        return try await sheet()
    }

    /// Whether the people at this table are in the room or across the country. The waiting
    /// room asks, to say where the others are coming from.
    var isNearbyTable: Bool { multipeer != nil }

    func startGame() {
        guard case .host(let coordinator) = backend else { return }
        Task {
            do {
                try await coordinator.startGame()
                route = .table
            } catch {
                Log.table.error("Could not start the game: \(String(describing: error), privacy: .public)")
                notice = .rejected(message(forHost: error))
            }
        }
    }

    // MARK: Joining

    func browse() {
        reset()
        isHost = false
        Log.table.info("Looking for tables as \(self.playerName, privacy: .public)")
        let session = MultipeerSession(localPlayer: localPlayer)
        multipeer = session
        session.startBrowsing()
        isBrowsing = true
        unreachedTable = nil
        watchForProblems(session.problems)
        browsePump = Task { [weak self] in
            for await tables in session.nearbyTables {
                guard let self else { return }
                Log.table.info("Nearby: \(tables.map { "\($0.hostName) \($0.seated)/\($0.capacity)" }.joined(separator: ", "), privacy: .public)")
                self.nearby = tables
            }
        }
    }

    func stopBrowsing() {
        browsePump?.cancel()
        browsePump = nil
        multipeer?.stopBrowsing()
        isBrowsing = false
        nearby = []
        unreachedTable = nil
    }

    /// Whether "Play again" belongs on the last summary: a table this phone can deal again by
    /// itself, with nothing at stake. A guest waits for the host, a wager needs a new stake,
    /// and today's deal is one a day.
    ///
    /// Not at a ranked table of people either, where dealing again would put somebody else's
    /// rating at stake on this phone's tap. Against the house there is nobody to ask, so the
    /// button stands.
    var canPlayAgain: Bool {
        guard view?.isFinished == true, stake == nil, dailyDay == nil, campaignStage == nil else { return false }
        if isRanked, seatedTable == .people { return false }
        switch backend {
        case .host, .hotSeat: return true
        case .guest, .none: return false
        }
    }

    /// The same table again. On a hosted table the coordinator deals afresh, and on this phone
    /// the table is set again with the same seats and the same target.
    ///
    /// A ranked table deals again ranked, which has to be put back by hand here because
    /// setting the table clears it. The new game gets a new id either way: the ladder settles
    /// a game once, and a second report under the first game's name moves nothing.
    func playAgain() {
        let ranked = isRanked, format = rankedFormat, step = ownStep
        let again = UUID()
        switch backend {
        case .host(let coordinator):
            if ranked {
                rankedID = again
                rankChange = nil
                rankedDealtAt = nil
            }
            Task { try? await coordinator.playAgain(gameID: ranked ? again.uuidString : nil) }
        case .hotSeat:
            guard let configuration = view?.configuration else { return }
            let seats = configuration.players.map { $0.isBot ? LocalSeat.bot(name: $0.name) : .person(name: $0.name) }
            let scatouched = scatouch != nil
            leaveTable()
            // The house plays a ranked game at its ranked strength, whatever the settings say,
            // and at the division the last game left this phone in.
            playOnThisDevice(seats: seats, teams: configuration.teams,
                             turnClock: configuration.turnClock, targetScore: configuration.targetScore,
                             primiera: configuration.primiera, ties: configuration.ties,
                             house: configuration.house, strength: ranked ? .house(atStep: step) : nil)
            if scatouched { beginScatouch() }
            if ranked {
                isRanked = true
                rankedID = again
                rankedFormat = format
                dealtHouseStep = step
                rankChange = nil
            }
        case .guest, .none:
            break
        }
    }

    #if DEBUG
    /// Debug only. Browses, and sits down at the first table that appears.
    func joinFirstTableFound() {
        browse()
        Task { [weak self] in
            for _ in 0..<120 {
                guard let self else { return }
                if let table = nearby.first { join(table); return }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }
    #endif

    func join(_ table: NearbyTable) {
        guard let session = multipeer, joining == nil else { return }
        let client = GuestClient(transport: session)
        backend = .guest(client)
        connection.begin(.nearby) { [weak self] in await self?.askHostAgain() }
        // The waiting room comes after the seat. Going there on the tap left a guest whose
        // invitation was quietly timing out staring at an empty table for twenty seconds.
        joining = table
        unreachedTable = nil
        Log.table.info("Joining \(table.hostName, privacy: .public)'s table")
        Task { await sit(at: table, through: session, as: client) }
    }

    private func sit(at table: NearbyTable, through session: MultipeerSession, as client: GuestClient) async {
        consume(await client.updates)
        await client.start()
        do {
            try await session.join(table)
            Log.table.info("Connected; asking the host for a seat")
            try await client.join()
            Log.table.info("Seated at \(table.hostName, privacy: .public)'s table")
            joining = nil
            route = .waiting
            // Left running, the browser kept Wi-Fi and Bluetooth scanning for the length of
            // the game. It stops here rather than the moment the peer connects: pulling the
            // radios out from under a handshake that is still settling breaks the join.
            stopBrowsing()
        } catch {
            Log.table.error("Join failed: \(String(describing: error), privacy: .public)")
            joining = nil
            backend = .none
            unreachedTable = table
            notice = .rejected("Could not reach that table")
        }
    }

    // MARK: Online

    /// A table over the internet against strangers, through Game Center. Apple finds the others
    /// and relays the cards, and the game runs exactly as it does over Wi-Fi. Anybody looking
    /// for a table of the same size will do. To meet a named friend, see `openRoom`.
    func playOnline(players: Int) {
        reset()
        onlineStatus = .signingIn
        searchTask = Task {
            do {
                let me = try await GameCenter.signIn { controller in Self.present(controller) }
                guard !Task.isCancelled else { return }
                onlineStatus = .searching
                let match = try await GameCenter.findMatch(players: players)
                guard !Task.isCancelled else { GameCenter.leave(match); return }
                await seatOnline(match, as: me, players: players)
            } catch {
                // Superseded, by an invitation said yes to: whatever cancelled this owns the screen.
                guard !Task.isCancelled else { return }
                onlineStatus = nil
                switch error {
                case GameCenterError.cancelled: break
                case GameCenterError.notSignedIn: notice = .rejected("Sign in to Game Center to play online")
                default: notice = .rejected("Could not find a table online")
                }
            }
        }
    }

    /// Signs in if need be, then the friends a partner can be picked from.
    func loadFriends() async throws -> [GKPlayer] {
        _ = try await GameCenter.signIn { controller in Self.present(controller) }
        do {
            return try await GameCenter.loadFriends()
        } catch {
            Log.table.error("Game Center friends did not load: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    /// Apple's friends page, where a friend request is sent. `done` runs when the page comes
    /// down, so the partner picker can look again.
    ///
    /// Signs in first, because the page is Game Center's own and signed out it is empty.
    func showGameCenterFriends(done: (@MainActor @Sendable () -> Void)? = nil) {
        Task {
            do {
                _ = try await GameCenter.signIn { controller in Self.present(controller) }
            } catch {
                Log.table.error("Game Center did not sign in for friends: \(String(describing: error), privacy: .public)")
                notice = .rejected("Sign in to Game Center to see your friends")
                return
            }
            GameCenter.showFriends(present: { controller in Self.present(controller) }, done: done)
        }
    }

    /// A ranked duo: one friend invited by name, then another pair looked for through the
    /// ranked queue, with the house on offer for the other two chairs a few seconds in.
    /// Partners sit opposite either way.
    ///
    /// Apple's sheet with the friend already named on it, exactly as "Invite someone else"
    /// opens it with nobody: see `GameCenter.inviteDuo` for why the invitation without a sheet
    /// never reached a table.
    func playRankedDuo(with friend: GKPlayer) {
        beginRankedDuo { _ in try await GameCenter.inviteDuo(friend) { controller in Self.present(controller) } }
    }

    /// The same duo, asked for through Apple's invitation sheet instead of by name.
    ///
    /// The partner picker only lists friends who already play Scopa and have let it see them.
    /// Apple's sheet lists every friend, so this is the only way to invite the rest.
    func inviteRankedDuo() {
        beginRankedDuo { _ in try await GameCenter.inviteDuo { controller in Self.present(controller) } }
    }

    /// Everything a duo needs around the invitation itself, which `making` sends.
    private func beginRankedDuo(making: @escaping @MainActor @Sendable (Player) async throws -> GKMatch) {
        reset()
        isRanked = true
        isRankedDuo = true
        rankedFormat = .teams
        // Two people, and the house takes the other two chairs if no pair comes.
        fillsTo = Self.duoSeats
        rankedID = UUID()
        rankChange = nil
        onlineStatus = .signingIn
        searchTask = Task { await seatDuo(making: making) }
    }

    private func seatDuo(making: @escaping @MainActor @Sendable (Player) async throws -> GKMatch) async {
        do {
            let me = try await GameCenter.signIn { controller in Self.present(controller) }
            guard !Task.isCancelled else { return }
            onlineStatus = .searching
            Log.table.info("Duo invitation going out")
            let match = try await making(me)
            guard !Task.isCancelled else { GameCenter.leave(match); return }
            Log.table.info("Duo partner said yes — seating the table")
            let id = rankedID
            // The host is named rather than worked out: the invited phone sits down at a table
            // of two while this one is still filling chairs, so the smallest id at the table
            // differs on each and both would wait for a join the other never sends. Held rather
            // than dealt: the search for another pair decides who takes the other chairs.
            await seatOnline(match, as: me, players: 2, hostDeals: true, host: me.id)
            guard !Task.isCancelled else { return }
            isRanked = true
            isRankedDuo = true
            rankedFormat = .teams
            rankedID = id
            await searchAsPair()
        } catch {
            // Superseded, by an invitation said yes to: whatever cancelled this owns the screen.
            guard !Task.isCancelled else { return }
            // Nothing was sat at, so nothing is left saying this is a ranked duo.
            closeConnections()
            switch error {
            case GameCenterError.cancelled: break
            case GameCenterError.notSignedIn: notice = .rejected("Sign in to Game Center to play ranked")
            default: notice = .rejected("Could not set the duo up")
            }
        }
    }

    /// Apple's sheet for inviting friends to a table of up to `players`. Once everyone invited
    /// has accepted the table waits in the waiting room, because the empty chairs are the
    /// host's to fill with bots before dealing.
    ///
    /// `naming` is the friends picked in the Games app before it opened Scopa, already invited
    /// on the sheet. Whatever this phone was doing is left properly first, as for an invitation.
    func inviteFriends(players: Int = GameConfiguration.playerRange.upperBound, naming friends: [GKPlayer] = []) {
        leaveForInvitation()
        reset()
        onlineStatus = .signingIn
        searchTask = Task {
            do {
                let me = try await GameCenter.signIn { controller in Self.present(controller) }
                guard !Task.isCancelled else { return }
                onlineStatus = .searching
                let match = try await GameCenter.inviteFriends(players: 2...players, naming: friends) { controller in
                    Self.present(controller)
                }
                guard !Task.isCancelled else { GameCenter.leave(match); return }
                await seatOnline(match, as: me, players: match.players.count + 1, hostDeals: true, host: me.id)
            } catch {
                // Superseded, by an invitation said yes to: whatever cancelled this owns the screen.
                guard !Task.isCancelled else { return }
                onlineStatus = nil
                switch error {
                case GameCenterError.cancelled: break
                case GameCenterError.notSignedIn: notice = .rejected("Sign in to Game Center to play online")
                default: notice = .rejected("Could not set the table up")
                }
            }
        }
    }

    /// Somebody invited this player and they said yes, from a notification or from Messages,
    /// with the app closed or open. Whatever was on screen gives way to the table.
    func accept(_ invite: GKInvite) {
        leavingStake { [weak self] in self?.takeUp(invite) }
    }

    /// An invitation said yes to in the middle of a wager game, waiting on the player's word:
    /// leaving leaves the stake behind, which nothing else in the app does without asking.
    struct InvitationOverStake: Identifiable {
        let id = UUID()
        fileprivate let go: @MainActor () -> Void
    }

    private(set) var invitationOverStake: InvitationOverStake?

    /// Runs `go` at once, or once the player has said so when it would walk out of a wager game.
    private func leavingStake(then go: @escaping @MainActor () -> Void) {
        guard stake != nil, view?.isFinished == false else { return go() }
        invitationOverStake = InvitationOverStake(go: go)
    }

    /// "Leave": the invitation taken up, the stake left on the table as the X would leave it.
    func leaveStakeForInvitation() {
        guard let asked = invitationOverStake else { return }
        invitationOverStake = nil
        asked.go()
    }

    /// "Stay": the invitation let go. Game Center has no way to turn one down once it has been
    /// said yes to, so the friend's sheet waits until they close it.
    func stayAtStake() {
        invitationOverStake = nil
    }

    private func takeUp(_ invite: GKInvite) {
        let moving = route != .lobby
        leaveForInvitation()
        // An invitation to a table of ours carries its four letters in the player group, and
        // there is nothing to be seated in at this end: the room is the table.
        if let code = Relay.code(inGroup: invite.playerGroup) {
            Log.table.info("Asked to table \(code, privacy: .public) by name")
            Task { await GameCenter.acknowledge(invite) }
            joinRoom(code: code)
            return
        }
        reset()
        // Whoever sent the invitation is the host; this phone is a guest until it is seated.
        isHost = false
        let duo = GameCenter.isRankedDuo(invite)
        Log.table.info("Invited by \(invite.sender.displayName, privacy: .public) — duo: \(duo, privacy: .public)")
        // Apple's sheet goes up over whatever is on screen, and the waiting room follows once
        // it has found the table: the sheet itself says it is joining. Going to the waiting
        // room on the tap took the lobby's sheets down just as Apple's went up on top of one,
        // and it went down with them without a word, leaving this phone in "joining" until the
        // app was killed while the friend who asked gave up. A table that was on screen gives
        // way to the lobby, and the sheet waits for it to finish going.
        route = .lobby
        onlineStatus = .signingIn
        searchTask = Task { await acceptMatch(invite, settling: moving) }
    }

    /// Whatever this phone was doing when an invitation was said yes to, left properly: a game
    /// under way as the X would leave it (kept for the Resume door, reported if ranked, its
    /// guests told if hosted), and a ranked search's Game Center half called off, which
    /// cancelling the task alone does not reach.
    private func leaveForInvitation() {
        // A table looked for through Game Center's matchmaker as much as a ranked one: left
        // running, it goes on searching under the invitation's own sheet.
        if rankedSearch != nil || onlineStatus == .searching { GameCenter.cancelSearch() }
        // A stake put down for a wager table nobody has been dealt at yet goes back, as it does
        // when the table refuses it: there was no game for it to stay behind at.
        if let stake, view == nil { refusedStake = RefusedStake(stake: stake, gameID: wagerID) }
        if view != nil { leaveTable() }
    }

    private func acceptMatch(_ invite: GKInvite, settling: Bool = false) async {
        if settling { try? await Task.sleep(for: .milliseconds(600)) }
        do {
            var me = try await GameCenter.signIn { controller in Self.present(controller) }
            onlineStatus = .seating
            let duo = GameCenter.isRankedDuo(invite)
            // The friend who asked is the partner, and the host seats them opposite.
            if duo { me.partner = GameCenter.id(of: invite.sender).rawValue }
            // Apple's own sheet, for a duo as much as for a friendly table.
            //
            // A duo used to be accepted quietly, through `GKMatchmaker.match(for:)`. That is
            // the programmatic half of a handshake whose other half — `inviteDuo` — is a
            // `GKMatchmakerViewController`, and those two are the one pairing Apple does not
            // make: the sheet on the sending phone waits for its match one way, the
            // programmatic accept waits for its match another, and neither ever hears from
            // the other. Both phones sat there until they gave up. The friendly table has
            // always used the sheet at both ends, which is why it has always worked.
            let match = try await GameCenter.accept(invite) { controller in Self.present(controller) }
            // A second invitation said yes to meanwhile owns the screen now.
            guard !Task.isCancelled else { GameCenter.leave(match); return }
            Log.table.info("Invitation accepted — \(match.players.count + 1, privacy: .public) at the table")
            // The sender deals, and naming them beats reading the smallest id at the table:
            // the match arrives before everyone has connected, so two phones can read
            // different tables and pick the same chair.
            if duo {
                // Before seating, so the leader walking out of the held table is read as a duo's.
                isRanked = true
                isRankedDuo = true
                rankedFormat = .teams
                rankChange = nil
            }
            await seatOnline(match, as: me, players: match.players.count + 1, hostDeals: !duo,
                             host: GameCenter.id(of: invite.sender))
            if duo, let leader = lobby?.host, view == nil { await followLeader(leader, as: me) }
        } catch {
            Log.table.error("The invitation could not be accepted: \(String(describing: error), privacy: .public)")
            guard !Task.isCancelled else { return }
            onlineStatus = nil
            // Off the waiting room if seating got that far: a table that could not be joined
            // is not a table to sit at.
            route = .lobby
            notice = .rejected("That table could not be joined")
        }
    }

    /// True once Game Center has answered. Observed rather than asked, so the two things
    /// that need a signed-in player before they can start — the ladder's rank and the first
    /// merge of the account — can wait for it instead of polling `GKLocalPlayer`.
    private(set) var isSignedIn = false

    /// Signs in quietly for anyone already on Game Center, and listens for invitations.
    func listenForInvites() {
        guard !DebugLaunch.staysSignedOut else { return }
        // Signing in quietly is also how the lobby learns your league: the ladder is asked the
        // moment Game Center answers, so the chip under the wordmark is right on the first screen.
        GameCenter.signInQuietly { [weak self] in
            self?.isSignedIn = true
            self?.refreshRank()
        } whenSignedOut: { [weak self] in
            self?.isSignedIn = false
        }
        GameCenter.listenForInvites({ [weak self] invite in self?.accept(invite) },
                                    requested: { [weak self] friends in
                                        self?.leavingStake { [weak self] in self?.inviteFriends(naming: friends) }
                                    })
    }

    /// Sits down at a match that has everyone in it, host or guest, decided by the ids.
    ///
    /// A table normally deals itself the moment its `players` are all seated. `hostDeals` holds
    /// it in the waiting room instead, for a table of invited friends whose empty chairs the
    /// host fills.
    private func seatOnline(_ match: GKMatch, as me: Player, players: Int, hostDeals: Bool = false,
                            host: PlayerID? = nil) async {
        onlineStatus = .seating
        let stake = self.stake, wagerID = self.wagerID, fillsTo = self.fillsTo
        let session = GameCenterSession(match: match, localPlayer: dressed(me), host: host)
        gameCenter = session
        onlineSize = players
        self.hostDeals = hostDeals
        // reset() cleared the wager on the way in. It is the same game, so it comes back.
        self.stake = stake
        self.wagerID = wagerID
        self.fillsTo = fillsTo
        watchForProblems(session.problems)
        connection.begin(.gameCenter(phones: players)) { [weak self] in await self?.askHostAgain() }
        connection.watch(failures: session.failed)
        if session.isHost {
            await hostOnline(session, stake: stake)
        } else {
            await guestOnline(session)
        }
        // Whatever superseded this owns the status now.
        guard !Task.isCancelled else { return }
        onlineStatus = nil
    }

    /// Game Center gives the name. The seat mark, the cornice, the companion and the week's
    /// badge are still this phone's to send.
    private func dressed(_ player: Player) -> Player {
        var me = player
        me.mark = seatMark.wireValue
        me.honour = challenges.honourOnWire
        me.cornice = cornice.wireValue
        me.companion = companion.wireValue
        me.livery = livery.wireValue
        me.flourish = flourish.wireValue
        return me
    }

    private func hostOnline(_ session: GameCenterSession, stake: Stake?) async {
        isHost = true
        // A wager fills its empty seats with the fixed contest bot, and a ranked duo fills
        // its other two with the house, which plays for the league the pair are playing for.
        let strength: BotStrength = if stake != nil { Self.contestLevel.strength }
                                    else if isRanked { houseStrength }
                                    else { botLevel.strength }
        let coordinator = HostCoordinator(transport: session, strength: strength)
        backend = .host(coordinator)
        route = .waiting
        consume(await coordinator.updates)
        await passOnHold(to: coordinator)
        await coordinator.start()
    }

    /// A hold asked for before there was a table to hold: the match-found moment goes up the
    /// moment somebody is found, and the table it covers is set up underneath it. See `holdBots`.
    private var botsHeldUntil: ContinuousClock.Instant?

    /// Hands a freshly made host whatever is left of a hold asked for before it existed.
    private func passOnHold(to coordinator: HostCoordinator) async {
        guard let until = botsHeldUntil, until > .now else { return }
        await coordinator.holdBots(for: until - .now)
    }

    private func guestOnline(_ session: GameCenterSession) async {
        isHost = false
        let client = GuestClient(transport: session)
        backend = .guest(client)
        route = .waiting
        consume(await client.updates)
        await client.start()
        // Asked again until the host answers: their listener can come up a beat after ours,
        // and a join that lands before it is lost. A duo waits longest, because its host is
        // still filling the other chairs.
        for attempt in 0..<Self.joinAttempts where lobby == nil && !Task.isCancelled {
            do {
                try await client.join()
            } catch {
                Log.table.error("Join \(attempt + 1) could not be sent: \(String(describing: error), privacy: .public)")
            }
            try? await Task.sleep(for: .milliseconds(700))
        }
        // Said out loud rather than left as a waiting room that never fills. Not once called
        // off: the sleeps above stop sleeping then, and the `reset` here would end whatever
        // called it off, an invitation said yes to included.
        guard lobby == nil, !Task.isCancelled else { return }
        Log.table.error("The host never answered the join")
        reset()
        route = .lobby
        notice = .rejected("That table could not be joined")
    }

    // MARK: A table of your own

    /// Tables we keep, on the same Worker as the ladder. Nil turns rooms off.
    private var rooms: Relay? { Ladder.baseURL.map(Relay.init(baseURL:)) }

    /// Whether rooms can be offered at all.
    var canOpenRooms: Bool { Ladder.isOn }

    /// This table, if it is one of ours rather than Apple's or the Wi-Fi's.
    var isRoomTable: Bool { relay != nil }

    /// Opens a table and sits down at it alone. The code comes back before anybody else is
    /// there, so the host can send it on and the friend joins whenever they get to it. Nobody
    /// signs in to anything.
    func openRoom(seats: Int = GameConfiguration.playerRange.upperBound) {
        guard let rooms else {
            notice = .rejected("Online tables are not set up yet")
            return
        }
        reset()
        onlineStatus = .opening
        let me = localPlayer
        searchTask = Task {
            do {
                let table = try await rooms.open(as: me, capacity: seats)
                guard !Task.isCancelled else { return }
                room = table
                Log.table.info("Opened table \(table.code, privacy: .public)")
                let session = rooms.session(code: table.code, as: me)
                try await session.connect()
                guard !Task.isCancelled else { session.disconnect(); return }
                await seatRoom(session)
            } catch {
                guard !Task.isCancelled else { return }
                onlineStatus = nil
                room = nil
                notice = .rejected(Self.explain(error))
            }
        }
    }

    /// Sits down at somebody else's table. The code is checked first, so a typo is answered
    /// with "no table with that code" instead of a spinner that never stops.
    func joinRoom(code: String) {
        guard let rooms else {
            notice = .rejected("Online tables are not set up yet")
            return
        }
        let code = Relay.tidy(code)
        guard Relay.isCode(code) else {
            notice = .rejected("A table code is four letters")
            return
        }
        reset()
        route = .lobby
        onlineStatus = .seating
        let me = localPlayer
        searchTask = Task { await enterRoom(code: code, as: me, through: rooms) }
    }

    private func enterRoom(code: String, as me: Player, through rooms: Relay) async {
        do {
            let status = try await rooms.status(of: code)
            guard !Task.isCancelled else { return }
            guard !status.isFull else { throw RelayError.tableFull }
            let session = rooms.session(code: code, as: me)
            try await session.connect()
            guard !Task.isCancelled else { session.disconnect(); return }
            room = Relay.Table(code: code, link: rooms.link(to: code))
            Log.table.info("Joined table \(code, privacy: .public), hosted by \(status.host, privacy: .public)")
            await seatRoom(session)
        } catch {
            guard !Task.isCancelled else { return }
            onlineStatus = nil
            room = nil
            notice = .rejected(Self.explain(error))
        }
    }

    /// An invitation link that iOS handed us, tapped in Messages or wherever it was sent.
    /// Returns whether it was one of ours. Anything else is left alone.
    @discardableResult
    func open(_ url: URL) -> Bool {
        guard let code = Self.code(inside: url) else { return false }
        joinRoom(code: code)
        return true
    }

    /// The code inside an invitation link, or nil for any other URL. Matches the `/j/<code>`
    /// path the Worker serves and the entitlement lists.
    static func code(inside url: URL) -> String? {
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.first?.lowercased() == "j", let raw = parts.dropFirst().first,
              Relay.isCode(raw) else { return nil }
        return Relay.tidy(raw)
    }

    /// Sits down at a room, host or guest, as `seatOnline` does for a Game Center match. A
    /// friends' room never deals itself when it fills: the empty chairs are the host's to fill
    /// with bots first. A ranked room deals as soon as its `humans` are in, like a found match.
    private func seatRoom(_ session: RelaySession, ranked: Bool = false, humans: Int = 2) async {
        onlineStatus = .seating
        relay = session
        hostDeals = !ranked
        onlineSize = ranked ? humans : nil
        watchForProblems(session.problems)
        watchForReconnects(session)
        connection.begin(.relay) { [weak self] in await self?.askHostAgain() }
        connection.watch(session)
        if session.isHost {
            isHost = true
            let strength = ranked ? houseStrength : botLevel.strength
            let coordinator = HostCoordinator(transport: session, strength: strength)
            backend = .host(coordinator)
            route = .waiting
            consume(await coordinator.updates)
            await passOnHold(to: coordinator)
            await coordinator.start()
        } else {
            isHost = false
            let client = GuestClient(transport: session)
            backend = .guest(client)
            route = .waiting
            consume(await client.updates)
            await client.start()
            // Asked again until the host answers: their listener can come up a beat after ours,
            // and a join that lands before it is lost.
            for _ in 0..<(ranked ? Self.joinAttempts : 8) where lobby == nil && !Task.isCancelled {
                try? await client.join()
                try? await Task.sleep(for: .milliseconds(700))
            }
        }
        // Whatever superseded this owns the status now.
        guard !Task.isCancelled else { return }
        onlineStatus = nil
    }

    /// A socket that dropped and came back. A guest asks to be caught up on the seat it still
    /// holds. The host sends everybody the table again: what it sent while the line was down
    /// went nowhere, and a guest left a move behind waits on a turn that has already passed.
    private func watchForReconnects(_ session: RelaySession) {
        reconnectPump?.cancel()
        reconnectPump = Task { [weak self] in
            for await _ in session.reconnects {
                guard let self, !Task.isCancelled else { return }
                Log.table.info("Back at the table; catching up")
                switch self.backend {
                case .guest(let client): try? await client.join()
                case .host(let coordinator): await coordinator.catchUp()
                case .hotSeat, .none: break
                }
            }
        }
    }

    // MARK: Coming back

    /// Asks the host for this phone's seat again. Sent while the host is away: a join into a
    /// room the host has left goes nowhere, and the first one after it is back is answered with
    /// the table as it stands.
    func askHostAgain() async {
        if case .guest(let client) = backend { try? await client.join() }
    }

    /// Sits back down at the room this phone was a guest at when the app was closed: the same
    /// code and the same id, so the host hands back the chair its bot has been keeping warm.
    func rejoin(_ ticket: RejoinTicket) {
        guard let rooms else { return }
        reset()
        isRanked = ticket.ranked
        // Its first minutes were before the app closed. A game called off then says so in the
        // lobby the host sends back.
        rankedDealtAt = ticket.ranked ? .distantPast : nil
        isRankedDuo = ticket.duo
        rankedFormat = ticket.format.flatMap(RankedSolo.init(rawValue:)) ?? .teams
        rankChange = nil
        onlineStatus = .seating
        Log.table.info("Rejoining table \(ticket.code, privacy: .public)")
        searchTask = Task {
            let session = rooms.session(code: ticket.code, as: ticket.player)
            do {
                try await session.connect()
            } catch {
                // Called off meanwhile: whatever did it owns the screen, and `reset` would end it.
                guard !Task.isCancelled else { return }
                return rejoinFailed(ticket, error)
            }
            guard !Task.isCancelled else { return session.disconnect() }
            room = Relay.Table(code: ticket.code, link: rooms.link(to: ticket.code))
            await seatRoom(session, ranked: ticket.ranked, humans: ticket.humans)
            if lobby == nil, !Task.isCancelled { rejoinFailed(ticket, RelayError.noSuchTable) }
        }
    }

    /// A room that answered with no game for us is over. One that could not be reached may not
    /// be, so its seat goes back on offer.
    private func rejoinFailed(_ ticket: RejoinTicket, _ error: Error) {
        Log.table.error("Could not rejoin: \(String(describing: error), privacy: .public)")
        reset()
        route = .lobby
        if case .unreachable? = error as? RelayError {
            connection.offer(ticket)
            notice = .rejected(Self.explain(error))
        } else {
            connection.forgetTicket()
            notice = .rejected("That game is over, or its table has closed")
        }
    }

    /// This phone's seat at the room it is a guest at, while the game there is still to finish.
    private var rejoinTicket: RejoinTicket? {
        guard let relay, !isHost, let lobby, view?.isFinished != true else { return nil }
        return RejoinTicket(code: relay.code, player: relay.localPlayer, hostName: lobby.host.name,
                            ranked: isRanked, duo: isRankedDuo, format: isRanked ? rankedFormat.rawValue : nil,
                            humans: onlineSize ?? 2)
    }

    /// What the reconnect banner learns from the table: the host answering, and the seat to
    /// keep until the game is over.
    private func noteLine(_ update: TableUpdate) {
        guard connection.link != nil, !isHost else { return }
        switch update {
        case .lobby, .view:
            connection.hostHeard()
            // Only the host sends these, so a host drawn as gone while it was away is back.
            if let host = lobby?.host.id { departed.remove(host) }
        default:
            break
        }
        if case .view(let view) = update, view.isFinished { return connection.forgetTicket() }
        if let rejoinTicket { connection.keep(rejoinTicket) }
    }

    /// A player whose phone had gone is back in their chair, and the bot face comes off it.
    private func noteReturn(of id: PlayerID) {
        departed.remove(id)
        let me = relay?.localPlayer.id ?? gameCenter?.localPlayer.id ?? multipeer?.localPlayer.id
        guard id != me, let name = lobby?.players.first(where: { $0.id == id })?.name else { return }
        notice = .playerBack(name)
    }

    /// The host called this ranked game off because somebody left it in its first minutes.
    /// Said over the table, since the summary at the end will not say Victory or Defeat.
    private func noteCalledOff(by id: PlayerID) {
        let me = relay?.localPlayer.id ?? gameCenter?.localPlayer.id ?? multipeer?.localPlayer.id
        let name = lobby?.players.first(where: { $0.id == id })?.name ?? "A player"
        notice = .calledOff(id == me ? nil : name)
    }

    /// The host put the table away. Their phone reported walking out as their own loss, so a
    /// ranked game is reported the same way here rather than as this phone's: won by the side
    /// across from the host, which is not this one when the host was this phone's partner.
    private func hostClosedTable() {
        guard !isHost, view?.isFinished != true else { return }
        connection.expectGoodbye()
        let name = lobby?.host.name ?? "The host"
        let calledOff = isCalledOff
        if isRanked, let view, ladderTable != nil, let host = lobby?.host.id,
           let hostSeat = view.configuration.seat(of: host), let winner = view.configuration.seat(across: hostSeat) {
            reportRanked(winnerSeat: winner)
        }
        isRanked = false
        leaveTable()
        notice = calledOff ? .calledOff(name) : .playerLeft(name)
    }

    /// A guest walked out of a ranked game against people, and said so on the way. Their phone
    /// reported it as their side's loss, so this one reports the same, now, rather than
    /// whatever the house in their chair goes on to make of it, which could be a win the two
    /// reports would then disagree about.
    private func noteForfeit(of id: PlayerID) {
        guard isHost, isRanked, ladderTable == .people, let view, !view.isFinished,
              let seat = view.configuration.seat(of: id), let winner = view.configuration.seat(across: seat) else { return }
        Log.table.info("A guest walked out of a ranked game; reporting it")
        reportRanked(winnerSeat: winner)
    }

    /// Leaves a table whose host's phone has gone. Nothing is reported: a dropped signal and a
    /// walk-out cannot be told apart from here, and the host's phone settles the game if it can.
    func leaveWithoutHost() {
        isRanked = false
        leaveTable()
    }

    /// Whether walking out of this table at `moment` counts as this phone's loss on the ladder.
    ///
    /// Never in the game's first minutes (`leavesFree`). Past them, always on the host's phone
    /// and at the house's table. A guest at a table of people only when the host can be told
    /// (`forfeit`) and will report the same loss: a guest whose line or host is gone, or whose
    /// host is a build that cannot, leaves the game to the host's phone, so the ladder never
    /// hears two stories and settles nothing.
    private func walkOutCounts(at moment: Date) -> Bool {
        guard isRanked, let view, !view.isFinished, let kind = ladderTable, !leavesFree(at: moment) else { return false }
        if isHost || kind == .house { return true }
        return connection.link?.state == .steady && lobby?.takesForfeits == true
    }

    /// Whether walking out of this ranked game at `moment` leaves the ladder out of it: no
    /// points, and the run stands. The first two minutes from the deal, as this phone saw it.
    func leavesFree(at moment: Date = .now) -> Bool {
        guard isRanked, ladderTable != nil, view?.isFinished == false else { return false }
        return EarlyExit.isFree(dealtAt: rankedDealtAt, at: moment)
    }

    /// A chair at a ranked table this phone hosts emptied in the game's first minutes, by a
    /// walk-out or a dropped line: the game is called off for every phone, so nobody is rated.
    /// A guest who walked out later said so (`forfeit`), and that report has already gone.
    private func callOffIfEarly(leftBy id: PlayerID) {
        guard isHost, ladderTable != nil, view?.isFinished == false, reportedGameID != rankedID,
              EarlyExit.callsOff(dealtAt: rankedDealtAt, lastSeen: lastSeen[id]),
              case .host(let coordinator) = backend else { return }
        Log.table.info("A chair emptied in the first minutes; calling the ranked game off")
        Task { await coordinator.callOff(leftBy: id) }
    }

    /// Notes a person at a ranked table this phone hosts as there, for `callOffIfEarly`.
    private func noteSeen(_ id: PlayerID?) {
        guard isHost, isRanked, let id, !departed.contains(id),
              lobby?.players.contains(where: { $0.id == id && !$0.isBot }) == true else { return }
        lastSeen[id] = .now
    }

    /// A host walking out tells the guests first, so their phones leave too rather than wait
    /// for a host whose signal they take to have dropped; a guest walking out of a ranked game
    /// against people tells the host, which reports it the same way. A host walking out of a
    /// ranked game in its first minutes calls it off first, so no guest reports it either. The
    /// line is held open until that is said: `reset` would otherwise cut it before the words
    /// went out.
    private func sayGoodbye(forfeiting: Bool, callingOff: Bool) {
        guard view?.isFinished == false else { return }
        let goodbye: @Sendable () async -> Void
        let me = lobby?.host.id
        switch backend {
        case .host(let coordinator):
            goodbye = {
                if callingOff, let me { await coordinator.callOff(leftBy: me) }
                await coordinator.closeTable()
            }
        case .guest(let client) where forfeiting: goodbye = { try? await client.forfeit() }
        case .host, .guest, .hotSeat, .none: return
        }
        let relay = self.relay, gameCenter = self.gameCenter, multipeer = self.multipeer
        guard relay != nil || gameCenter != nil || multipeer != nil else { return }
        self.relay = nil
        self.gameCenter = nil
        self.multipeer = nil
        Task {
            await goodbye()
            try? await Task.sleep(for: .milliseconds(400))
            relay?.disconnect()
            gameCenter?.disconnect()
            withExtendedLifetime(multipeer) {}
        }
    }

    /// What to put in front of a player when a table could not be opened or joined.
    private static func explain(_ error: Error) -> String {
        (error as? RelayError)?.explanation ?? "Could not reach the table. Check your connection."
    }

    // MARK: Ranked

    /// How long a ranked search runs before it gives up and offers the house. It was eight
    /// seconds, which is about what Game Center takes to pair two phones that are both
    /// searching, so two friends who tapped a moment apart each got the house. The offer
    /// now comes early instead (`houseOfferDelay`), so the wait is the player's to cut short.
    static let rankedSearchTime: TimeInterval = 30

    /// How far into a ranked search the house is offered, the search carrying on behind it.
    static let houseOfferDelay: TimeInterval = 5

    /// A ranked table played alone: one real opponent, whatever their league. `rankedSolo`
    /// says whether that is the whole table or whether the house sits behind each of you.
    /// Nobody found yet offers the house rather than turning the player away.
    func playRanked() {
        let format = rankedSolo
        reset()
        isRanked = true
        rankedFormat = format
        // However few the search fills, the house takes the rest — of a four. A heads-up
        // table has no rest: the second chair is the opponent or it is the house.
        fillsTo = format.seatCount
        rankedID = UUID()
        rankChange = nil
        onlineStatus = .signingIn
        searchTask = searchRanked(format)
    }

    /// Signs in, looks, and sits down with whoever is found. Nobody found leaves the house
    /// on offer, and the task ends there.
    private func searchRanked(_ format: RankedSolo) -> Task<Void, Never> {
        Task {
            do {
                let me = try await GameCenter.signIn { controller in Self.present(controller) }
                guard !Task.isCancelled, let found = await lookForOpponent(format, as: me) else { return }
                let ranked = isRanked, id = rankedID
                switch found {
                case .match(let match):
                    announceMatch(match.players.map(\.displayName), as: [me.name])
                    await seatOnline(match, as: me, players: 2)
                    guard !Task.isCancelled else { return }
                    rankedFormat = format
                case .room(let pairing):
                    await seatRankedRoom(pairing, as: me)
                }
                // A guest has taken the host's game id from the lobby by now; writing its own
                // back would make the two phones report two different games.
                guard !Task.isCancelled, !isRanked else { return }
                isRanked = ranked
                rankedID = id
            } catch GameCenterError.notSignedIn {
                onlineStatus = nil
                notice = .rejected("Sign in to Game Center to play ranked")
            } catch {
                onlineStatus = nil
                notice = .rejected("Could not find a ranked game")
            }
        }
    }

    /// One run of the search, with the house offered a few seconds in. Nil when nobody was
    /// found, which leaves the offer up, or when the search was called off, which changes
    /// nothing: whoever called it off has already said what happens next.
    private func lookForOpponent(_ format: RankedSolo, as me: Player) async -> RankedFind? {
        onlineStatus = .searching
        let search = RankedSearch(startedAt: .now, length: Self.rankedSearchTime)
        rankedSearch = search
        // Checked against this search's start, so a search stopped and started again within
        // the delay does not have the old one's offer land on it early.
        let offer = Task {
            try? await Task.sleep(for: .seconds(Self.houseOfferDelay))
            while !Task.isCancelled, (rankedSearch?.searching ?? 0) > 0 {
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled, rankedSearch?.startedAt == search.startedAt else { return }
            rankedSearch?.offersHouse = true
        }
        let found = await findRanked(format, as: me, startedAt: search.startedAt)
        offer.cancel()
        guard !Task.isCancelled else { return nil }
        guard let found else {
            rankedSearch?.offersHouse = true
            rankedSearch?.isOver = true
            return nil
        }
        rankedSearch = nil
        return found
    }

    /// The house, taken up on. The search is called off first — the matchmaker cancelled,
    /// and a match caught on its way in disconnected by `GameCenter` — so nobody is left
    /// waiting at a table this phone has walked away from.
    func playTheHouse() {
        if duoSearch?.leads == true { return playTheHouseAsDuo() }
        guard rankedSearch != nil else { return }
        GameCenter.cancelSearch()
        searchTask?.cancel()
        searchTask = nil
        rankedSearch = nil
        seatRankedStranger()
    }

    /// "Keep looking": the offer put away while the search still has time, or a fresh search
    /// once it has run out.
    func keepLooking() {
        if let duo = duoSearch, duo.leads { return keepLookingForPair(duo) }
        guard let search = rankedSearch else { return }
        guard search.isOver else { rankedSearch?.offersHouse = false; return }
        searchTask?.cancel()
        searchTask = searchRanked(rankedFormat)
    }

    /// What a ranked search came back with: a Game Center match, or a room the queue paired us at.
    enum RankedFind {
        case match(GKMatch)
        case room(RankedQueue.Pairing)
    }

    /// How often a search asks the ranked queue whether it has been paired.
    static let queuePollInterval: Duration = .milliseconds(1500)
    /// How often a duo partner asks while the leader sits on the house offer. Well inside
    /// `noShowPatience`, should the leader look again and pair at once.
    static let offerPollInterval: Duration = .seconds(4)

    /// The ranked queue on the Worker, or nil when the Worker is not set up.
    private var rankedQueue: RankedQueue? { Ladder.baseURL.map(RankedQueue.init(baseURL:)) }

    /// The Worker's ranked queue first: one line for every search, so two players searching at
    /// the same time always meet, whatever their league, format or build. Game Center's
    /// matchmaker is only the fallback for when the queue cannot be reached.
    private func findRanked(_ format: RankedSolo, as me: Player, startedAt: Date) async -> RankedFind? {
        let deadline = startedAt.addingTimeInterval(Self.rankedSearchTime)
        if let queue = rankedQueue {
            switch await waitInQueue(queue, as: dressed(me), format: format.queueName, until: deadline) {
            case .paired(let pairing): return .room(pairing)
            case .over: return nil
            case .unreachable: break
            }
        }
        let left = deadline.timeIntervalSinceNow
        guard left > 1 else { return nil }
        return await findRankedMatch(format, within: left).map(RankedFind.match)
    }

    enum QueueOutcome {
        case paired(RankedQueue.Pairing)
        /// The search ran out or was called off.
        case over
        /// The queue never answered, so the search falls back to Game Center.
        case unreachable
    }

    /// Asks the queue every 1.5 s until it pairs this phone, the clock runs out or the search is
    /// called off. The player is taken out of the line on the way out, unless they were paired.
    /// A duo's leader names its `teammate`, and searches for another pair.
    private func waitInQueue(_ queue: RankedQueue, as me: Player, format: String, teammate: Player? = nil,
                             until deadline: Date) async -> QueueOutcome {
        var answered = false, failures = 0
        let search = UUID().uuidString
        while Date.now < deadline, !Task.isCancelled {
            do {
                let answer = try await queue.seek(as: me, format: format, search: search, teammate: teammate)
                answered = true
                failures = 0
                // Written only on a change: every write redraws the search sheet.
                if rankedSearch?.searching != answer.searching { rankedSearch?.searching = answer.searching }
                if duoSearch?.searching != answer.searching { duoSearch?.searching = answer.searching }
                if let pairing = answer.pairing, !Task.isCancelled { return .paired(pairing) }
            } catch {
                failures += 1
                Log.table.error("Ranked queue: \(String(describing: error), privacy: .public)")
                if !answered, failures >= 2 { return .unreachable }
            }
            try? await Task.sleep(for: Self.queuePollInterval)
        }
        Task.detached { await queue.leave(as: me) }
        return .over
    }

    /// Sits down at the room the queue paired us at. The phone that waited longer deals, in
    /// its format; the house fills whatever chairs that format has left.
    private func seatRankedRoom(_ pairing: RankedQueue.Pairing, as me: Player) async {
        guard let rooms, let format = RankedSolo(queueName: pairing.format) else { return }
        Log.table.info("Ranked queue paired us with \(pairing.opponent, privacy: .public) at \(pairing.code, privacy: .public)")
        announceMatch([pairing.opponent], as: [me.name])
        rankedFormat = format
        fillsTo = format.seatCount
        onlineStatus = .seating
        let session = rooms.session(code: pairing.code, as: dressed(me))
        do {
            try await session.connect()
        } catch {
            onlineStatus = nil
            notice = .rejected("Could not find a ranked game")
            return
        }
        guard !Task.isCancelled else { session.disconnect(); return }
        watchForNoShow(session)
        await seatRoom(session, ranked: true)
    }

    /// Says who a search found, for `length`. Nothing waits for it: the seating goes on, under a
    /// moment that covers it, and any bots already at the table hold their first card until it
    /// lifts. `ours` is this phone's name, then a partner's where there is one; `house` is the
    /// division the house plays at when it is the house across the table.
    private func announceMatch(_ theirs: [String], as ours: [String], house: Int? = nil,
                               for length: Duration = MatchFound.length) {
        guard !theirs.isEmpty else { return }
        let found = MatchFound(ours: ours, theirs: theirs, houseStep: house)
        matchFound = found
        holdBots(for: length)
        Task { [weak self] in
            try? await Task.sleep(for: length)
            if self?.matchFound == found { self?.matchFound = nil }
        }
    }

    /// The house sat down across a ranked table, said with the same moment as a person would
    /// be: its chairs under the names they sit at, this phone's side with its own name first.
    private func announceHouse(at lobby: Lobby) {
        let me = gameCenter?.localPlayer.id ?? relay?.localPlayer.id
        let people = lobby.players.filter { !$0.isBot }
        let ours = people.filter { $0.id == me } + people.filter { $0.id != me }
        announceMatch(lobby.players.filter(\.isBot).map(\.name), as: ours.map(\.name), house: lobby.houseStep ?? ownStep)
    }

    /// How long a paired table may sit undealt before the search starts again.
    static let noShowPatience: Duration = .seconds(20)

    /// The opponent the queue named never sat down, most likely because they took the house a
    /// moment before the pairing. Rather than a waiting room that never fills, say so.
    private func watchForNoShow(_ session: RelaySession,
                                saying reason: String = "Your opponent left before the deal. Try ranked again.") {
        Task { [weak self] in
            try? await Task.sleep(for: Self.noShowPatience)
            guard let self, self.relay === session, self.view == nil else { return }
            Log.table.error("Ranked opponent never arrived")
            self.reset()
            self.route = .lobby
            self.notice = .rejected(reason)
        }
    }

    /// Game Center's matchmaker, one pool per format and open to every league. Phones on
    /// different builds (TestFlight, App Store, Xcode) never meet here, which is why the
    /// Worker's queue comes first.
    private func findRankedMatch(_ format: RankedSolo, within seconds: TimeInterval) async -> GKMatch? {
        let found = try? await GameCenter.findMatch(players: 2, pool: "\u{1}\(format.pool)/any",
                                                    within: seconds)
        guard !Task.isCancelled else { found.map(GameCenter.leave); return nil }
        return found
    }

    // MARK: A duo against a duo

    /// How long a duo asks the queue for another pair before it stops. The house is on offer
    /// from `houseOfferDelay` on whatever this is.
    static let duoSearchTime: TimeInterval = 60

    /// How long a duo waits before asking a queue that did not answer again.
    static let queueRetryInterval: Duration = .seconds(5)

    /// The leader's half of a duo's search, once the partner has sat down at the held table:
    /// the queue asked for another pair, the house offered a few seconds in, as a search alone
    /// offers it. Only the leader's tap seats the house.
    ///
    /// A queue that could not be reached used to deal the house at once, which is how a duo
    /// came to feel like it was always the house: a Worker without the duo line refuses every
    /// duo search, so every duo sat down with bots before anybody saw a search.
    private func searchAsPair() async {
        guard let partner = await seatedPartner(), let me = lobby?.host else { return }
        // The partner's league, for the house's division and the match-found moment.
        Task { await lookUpRanks(of: [partner]) }
        duoSearch = DuoSearch(startedAt: .now, length: Self.duoSearchTime, leads: true, partner: partner.name)
        let offer = offerHouseToDuo()
        let deadline = Date.now.addingTimeInterval(Self.duoSearchTime)
        let outcome = await seekPair(as: me, with: partner, until: deadline)
        offer.cancel()
        guard !Task.isCancelled else { return }
        if case .paired(let pairing) = outcome { return await seatDuoRoom(pairing, as: me, partner: partner) }
        duoSearch?.offersHouse = true
        duoSearch?.isOver = true
    }

    /// The queue asked for another pair until `deadline`. A queue that does not answer is asked
    /// again a few seconds later rather than given up on, and with no queue at all the clock is
    /// simply run out: either way the search line runs and the house waits on the leader.
    private func seekPair(as me: Player, with partner: Player, until deadline: Date) async -> QueueOutcome {
        while let queue = rankedQueue, Date.now < deadline, !Task.isCancelled {
            let outcome = await waitInQueue(queue, as: me, format: "duo", teammate: partner, until: deadline)
            guard case .unreachable = outcome else { return outcome }
            try? await Task.sleep(for: Self.queueRetryInterval)
        }
        while Date.now < deadline, !Task.isCancelled { try? await Task.sleep(for: .seconds(1)) }
        return .over
    }

    /// The partner, once they have a chair at the held table. Nil if the table goes first.
    private func seatedPartner() async -> Player? {
        while !Task.isCancelled, gameCenter != nil {
            if let lobby, let partner = lobby.players.first(where: { !$0.isBot && $0.id != lobby.host.id }) {
                return partner
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return nil
    }

    /// The house, offered five seconds into a duo's search on both phones, whoever else is in
    /// the line: the leader's to take, the partner's to know about. The search goes on under it.
    private func offerHouseToDuo() -> Task<Void, Never> {
        let startedAt = duoSearch?.startedAt
        return Task {
            try? await Task.sleep(for: .seconds(Self.houseOfferDelay))
            guard !Task.isCancelled, duoSearch?.startedAt == startedAt else { return }
            duoSearch?.offersHouse = true
        }
    }

    /// The leader takes the house. Out of the queue first, so a pairing that lands after the
    /// tap finds nobody, then the held table is dealt.
    private func playTheHouseAsDuo() {
        searchTask?.cancel()
        searchTask = nil
        duoSearch = nil
        let me = lobby?.host, queue = rankedQueue
        Task {
            if let me, let queue { await queue.leave(as: me) }
            dealDuoWithHouse()
        }
    }

    /// "Keep looking" on a duo: the offer put away while the search has time, or a fresh
    /// search once it has run out. The partner's phone follows whichever is running.
    private func keepLookingForPair(_ search: DuoSearch) {
        guard search.isOver else { duoSearch?.offersHouse = false; return }
        searchTask?.cancel()
        searchTask = Task { await searchAsPair() }
    }

    /// The held table dealt with two of the house in the empty chairs.
    private func dealDuoWithHouse() {
        duoSearch = nil
        guard isHost, view == nil, case .host(let coordinator) = backend else { return }
        Log.table.info("Duo playing the house")
        onlineSize = nil
        dealOnlineTable(through: coordinator)
    }

    /// The partner's half: the leader's search followed through the queue until it pairs, the
    /// leader deals the house at this table, or the leader walks out. Never in the line itself.
    private func followLeader(_ leader: Player, as me: Player) async {
        duoSearch = DuoSearch(startedAt: .now, leads: false, partner: leader.name)
        let offer = offerHouseToDuo()
        defer { offer.cancel() }
        var answered = false, failures = 0, leaderWaits = false
        while view == nil, !Task.isCancelled {
            runPartnersClock(leaderLooking: answered && !leaderWaits)
            // Read before asking: see `DuoFollow`. Nothing to ask counts as an answer.
            let leftBeforeAsking = duoLeaderLeft
            var heard = rankedQueue == nil || !(answered || failures < 2)
            // An old Worker has no follow: two misses and this phone only watches the table.
            if let queue = rankedQueue, answered || failures < 2 {
                do {
                    let answer = try await queue.follow(as: me, leader: leader.id)
                    (answered, failures, heard) = (true, 0, true)
                    leaderWaits = answer.inLine == false
                    if duoSearch?.searching != answer.searching { duoSearch?.searching = answer.searching }
                    if let pairing = answer.pairing, !Task.isCancelled {
                        // A leader who took the house in the same breath stays here and deals:
                        // following the pairing then would split the pair between two tables.
                        guard await leaderWentToRoom() else { continue }
                        return await seatDuoRoom(pairing, as: me, partner: leader)
                    }
                } catch {
                    failures += 1
                    Log.table.error("Following the duo's search: \(String(describing: error), privacy: .public)")
                }
            }
            // The leader leaves the held table the moment it is paired, so an answer already on
            // its way when it left says nothing: only one asked for afterwards can.
            if DuoFollow.verdict(paired: false, leaderLeftBeforeAsking: leftBeforeAsking && heard,
                                 leaderLeftNow: duoLeaderLeft) == .abandon {
                return abandonDuo("Your partner left, so the search stopped.")
            }
            // The leader's search is over and the offer is up: nothing can pair until they choose.
            try? await Task.sleep(for: leaderWaits ? Self.offerPollInterval : Self.queuePollInterval)
        }
        duoSearch = nil
    }

    /// What the leader's phone did with a pairing, as this table shows it: left for the room, or
    /// sat the house down here because the house was tapped as the pairing landed. Neither
    /// within a few seconds is taken as the room, where the other pair is already waiting.
    private func leaderWentToRoom() async -> Bool {
        let deadline = ContinuousClock.now + .seconds(4)
        while !duoLeaderLeft, !houseSatDown, ContinuousClock.now < deadline, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(200))
        }
        return !houseSatDown && !Task.isCancelled
    }

    /// The leader has started filling the held table's empty chairs, or dealt it.
    private var houseSatDown: Bool { view != nil || lobby?.players.contains(where: \.isBot) == true }

    /// The partner's line runs on this phone's own clock, the leader's being out of reach: over
    /// once its length is up, and run again when the queue says the leader is looking again.
    private func runPartnersClock(leaderLooking: Bool) {
        guard let search = duoSearch, !search.leads else { return }
        if search.isOver, leaderLooking {
            duoSearch = DuoSearch(startedAt: .now, leads: false, partner: search.partner,
                                  searching: search.searching, offersHouse: true)
        } else if !search.isOver, Date.now.timeIntervalSince(search.startedAt) >= search.length {
            duoSearch?.isOver = true
        }
    }

    /// Two pairs met: this phone leaves the held table for the queue's room for four, its
    /// partner declared so the host seats the pairs opposite. Nobody from the house sits here.
    private func seatDuoRoom(_ pairing: RankedQueue.Pairing, as me: Player, partner: Player) async {
        guard let rooms else { return }
        let theirs = pairing.opponents ?? [pairing.opponent]
        Log.table.info("Duo paired with \(theirs.joined(separator: ", "), privacy: .public) at \(pairing.code, privacy: .public)")
        announceMatch(theirs, as: [me.name, partner.name])
        duoSearch = nil
        leaveHeldTable()
        // Only the room's host deals with this id; every guest reads the host's off the lobby.
        rankedID = UUID()
        onlineStatus = .seating
        var seated = me
        seated.partner = partner.id.rawValue
        let session = rooms.session(code: pairing.code, as: dressed(seated))
        do {
            try await session.connect()
        } catch {
            return abandonDuo("Could not find a ranked game")
        }
        guard !Task.isCancelled else { session.disconnect(); return }
        watchForNoShow(session, saying: "Not everyone made it to the table. Try ranked again.")
        await seatRoom(session, ranked: true, humans: Self.duoSeats)
    }

    /// Leaves the Game Center table a duo was held at, keeping what makes this a ranked duo.
    /// Not `reset()`, which would cancel the search task this runs in.
    private func leaveHeldTable() {
        pump?.cancel(); pump = nil
        problemPump?.cancel(); problemPump = nil
        stopBackend()
        backend = .none
        // The match is being left on purpose: nothing it says from here is the banner's business.
        connection.end()
        gameCenter?.disconnect()
        gameCenter = nil
        lobby = nil
        departed = []
        onlineSize = nil
        hostDeals = false
        fillsTo = nil
    }

    /// The other phone of a duo walked out of the held table. The leader stops searching; the
    /// partner's phone asks the queue once more first, since a paired leader leaves for the room.
    private func pairBroke() {
        // Left on purpose: the match failing behind it is not this phone's line.
        connection.expectGoodbye()
        guard isHost else { duoLeaderLeft = true; return }
        abandonDuo("Your partner left, so the search stopped.")
    }

    /// Back to the lobby from anywhere in a duo's search, saying why.
    private func abandonDuo(_ reason: String) {
        reset()
        route = .lobby
        notice = .rejected(reason)
    }

    #if DEBUG
    /// Says the phrase on this phone's behalf, so the pages that carry the house tie rule can
    /// be checked without typing it into the settings first.
    func pretendTieRules() { pretendsTieRules = true }

    /// Puts a quick game behind the lobby's Resume door, dealt but never written to disk, so
    /// the lobby can be judged with a game waiting without leaving one on the simulator.
    /// `none` hides whatever the simulator has saved instead, without deleting it.
    func pretendSavedGame(none: Bool = false) {
        hasLookedForSavedGame = true
        guard !none else { return savedGame = nil }
        let seats = [LocalSeat.person(name: playerName)] + quickTable.botNames.map { LocalSeat.bot(name: $0) }
        let (players, bots) = LocalSeat.table(seats)
        guard let config = try? GameConfiguration(players: players, teams: quickTable.teams) else { return }
        let table = HotSeatTable(configuration: config, bots: bots)
        Task {
            // Stopped first, so the deal does not wait on the bots playing their turns.
            await table.stop()
            await table.deal()
            let snapshot = await table.snapshot
            savedGame = SavedGame(snapshot: snapshot, bots: bots, deviceSeat: 0, stake: nil, wagerID: UUID(),
                                  tally: nil, savedAt: .now)
        }
    }

    /// Puts a ranked search on screen, part-way through and staying there, so the line that
    /// runs out can be judged without a Game Center account. Nothing is actually searched for.
    ///
    /// Far enough in that the house is on offer, as it would be. `-rankedSearch over` shows
    /// the search run out instead, and "Play the house" sits down as a real search would.
    func pretendSearching() {
        isRanked = true
        rankedFormat = rankedSolo
        rankedID = UUID()
        onlineStatus = .searching
        // Long enough to sit still for a screenshot, and started far enough back that the line
        // is drawn part-run rather than full.
        rankedSearch = RankedSearch(startedAt: .now.addingTimeInterval(-24), length: 120,
                                    offersHouse: true, isOver: DebugLaunch.rankedSearchIsOver)
    }

    /// A ranked duo held at its table and looking for another pair, the house offered after the
    /// usual few seconds, with no Game Center and no queue. `partner` draws the invited phone.
    func pretendDuoSearch(leads: Bool) {
        let me = Player(id: PlayerID(rawValue: "gc:me"), name: playerName)
        let friend = Player(id: PlayerID(rawValue: "gc:friend"), name: "Giulia")
        isRanked = true
        isRankedDuo = true
        isHost = leads
        lobby = Lobby(host: leads ? me : friend, players: leads ? [me, friend] : [friend, me])
        route = .waiting
        duoSearch = DuoSearch(startedAt: .now, leads: leads, partner: friend.name, searching: 0)
        _ = offerHouseToDuo()
    }

    /// The match-found moment against `names`, held three times as long so a screenshot can
    /// catch it settled. `house` is the house heads-up at this phone's league, and `house,2`
    /// the two of it across a duo with Giulia.
    func pretendMatchFound(_ names: [String]) {
        guard names.first == "house" else { return announceMatch(names, as: [playerName], for: MatchFound.length * 3) }
        let duo = names.dropFirst().first == "2"
        announceMatch(Presence.strangers(duo ? 2 : 1), as: [playerName] + (duo ? ["Giulia"] : []), house: ownStep,
                      for: MatchFound.length * 3)
    }

    /// Sits down at a ranked table against the house, as ranked does once the search time is
    /// up, without needing a Game Center account. `-target 2` shortens the game, and the table
    /// is dealt in whatever shape `rankedSolo` is set to, as a real search would have.
    func pretendRankedHouse(targetScore: Int = 11) {
        rankedFormat = rankedSolo
        seatRankedStranger(targetScore: targetScore)
    }

    /// Plants a league on the phone, so the lobby's rosette can be checked without a Game
    /// Center account and twenty ranked games behind it.
    func pretendRank(rating: Int, games: Int, change: Int? = nil, finished: Int? = nil, streak: Int = 0,
                     housePlayed: Int = 3) {
        let standing = Ranking.standing(for: rating)
        rank = Ladder.RankAnswer(
            rating: rating,
            games: games,
            wins: games / 2,
            standing: .init(league: standing.league.rawValue, division: standing.division,
                            progress: standing.progress, step: standing.step, title: standing.title),
            lastChange: change,
            streak: streak,
            // Part of the day spent, which is the state worth looking at: both ends of it read
            // the same when the count is missing. `-houseSpent` stands the other end up.
            house: .init(playedToday: housePlayed, perDay: Ranking.houseGamesPerDay,
                         win: Ranking.houseWin, loss: Ranking.houseLoss),
            finish: finished.map { rating in
                let standing = Ranking.standing(for: rating)
                return .init(season: "2026-08", rating: rating, games: 58, wins: 32,
                             standing: .init(league: standing.league.rawValue, division: standing.division,
                                             progress: standing.progress, step: standing.step, title: standing.title))
            }
        )
        rankChange = change
    }
    #endif

    /// Ranked found nobody, or nobody yet, and the player took up the house: a house stranger
    /// takes the chair and the game is played out as a ranked game.
    ///
    /// It reaches the ladder at the house price, because nobody at this table can confirm the
    /// result but the phone that played it. See `ladderTable`. `targetScore` is eleven for
    /// every real ranked game, and only `-rankedHouse -target 2` asks for anything else.
    private func seatRankedStranger(targetScore: Int = 11) {
        let id = rankedID, format = rankedFormat
        // The same chairs a found game would have had, so ranked is one game and not two:
        // heads-up means one of the house across the table, a four means one behind you and
        // two across. `playOnThisDevice` resets on the way in, so what marks this as ranked
        // goes back afterwards.
        let strangers = Presence.strangers(format.seatCount - 1), step = ownStep
        playOnThisDevice(seats: [.person(name: playerName)] + strangers.map { .bot(name: $0) },
                         teams: format.teams, targetScore: targetScore,
                         strength: .house(atStep: step, losing: HouseRelief.losses))
        isRanked = true
        rankedID = id
        rankedFormat = format
        dealtHouseStep = step
        onlineStatus = nil
        // At a four the chair opposite is yours: the house across is the other two.
        let across = format.teams ? strangers.enumerated().filter { $0.offset != 1 }.map(\.element) : strangers
        announceMatch(across, as: [playerName] + (format.teams ? [strangers[1]] : []), house: step)
    }

    /// Reads the league off the ladder when Game Center is already awake. Never wakes it, so
    /// no sign-in sheet appears over the lobby.
    func refreshRank() {
        guard Ladder.isOn, GameCenter.isSignedIn, let id = gameCenterPlayerID else { return }
        Task {
            if let answer = try? await Ladder.rank(gamePlayerID: id) { rank = answer }
        }
    }

    /// A finished game, counted towards the week. Returns the tasks this game finished, so
    /// the summary can pay them.
    ///
    /// The post to the ladder goes out on every counted game, not only the finishing one,
    /// because most weeks are never finished.
    @discardableResult
    func recordChallenge(_ tally: RewardTally, won: Bool) -> ChallengeBook.Finish? {
        let finished = challenges.record(tally, won: won)
        if finished?.week == true { finishedChallenge = challenges.goals }
        postWeekly()
        return finished
    }

    /// Tells the ladder where the week has got to: every task's steps added up, so the board
    /// can rank a week of three tasks with the one count it keeps. Quiet about failure, since
    /// the progress is kept on the phone and the board catches up on the next game.
    private func postWeekly() {
        guard Ladder.isOn, GameCenter.isSignedIn else { return }
        let week = challenges.week
        let count = challenges.steps
        let target = challenges.totalSteps
        Task { _ = try? await Ladder.postWeekly(week: week, count: count, goal: target) }
    }

    /// The week's board in full, for the screen that shows it.
    func weeklyBoard(week: String) async -> Ladder.WeeklyBoard? {
        guard Ladder.isOn else { return nil }
        do {
            return try await Ladder.weeklyBoard(week: week, gamePlayerID: gameCenterPlayerID)
        } catch {
            // Said out loud rather than swallowed: the screen shows one "not answering" for
            // a Worker that is down, a week it will not accept and an answer it cannot read,
            // and those are three different bugs.
            Log.table.error("The week's board (\(week, privacy: .public)) could not be read: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// The day's ladder in full. Nil when the ladder is off or the Worker will not answer, and
    /// the screen says so rather than showing an empty table.
    ///
    /// The id is passed when there is one so the Worker can mark the reader's own row. Without
    /// it the board still comes back.
    func ladderBoard(day: String) async -> Ladder.Board? {
        guard Ladder.isOn else { return nil }
        return try? await Ladder.board(day: day, gamePlayerID: gameCenterPlayerID)
    }

    /// The season's ranked board, for the sheet behind the league panel.
    func seasonBoard() async -> Ladder.SeasonBoard? {
        #if DEBUG
        if DebugLaunch.showsSeasonBoard { return .sample }
        #endif
        guard Ladder.isOn else { return nil }
        do {
            return try await Ladder.seasonBoard(gamePlayerID: gameCenterPlayerID)
        } catch {
            Log.table.error("The season's board could not be read: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// The season's board among the reader's Game Center friends. Throws `GameCenterError`
    /// when the friends cannot be had, which the sheet puts in its own words, and answers nil
    /// when the ladder does not.
    ///
    /// `GameCenter.loadFriends` rather than `loadFriends`: a tab is no place to put Apple's
    /// sign-in sheet up, so a player who is signed out is told so instead.
    func friendsSeasonBoard() async throws -> Ladder.SeasonBoard? {
        #if DEBUG
        if DebugLaunch.showsSeasonBoard { return .friendsSample }
        #endif
        guard Ladder.isOn else { return nil }
        let friends = try await GameCenter.loadFriends().map(\.gamePlayerID)
        do {
            return try await Ladder.friendsSeasonBoard(friends: friends, gamePlayerID: gameCenterPlayerID)
        } catch {
            Log.table.error("The friends' season board could not be read: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// The bare Game Center id, which is what the ladder keys on. Nil on a table without one.
    private var gameCenterPlayerID: String? {
        gameCenter.map { Self.bareID($0.localPlayer.id) } ?? (GameCenter.isSignedIn ? GameCenter.player(for: GKLocalPlayer.local).id.rawValue.replacingOccurrences(of: "gc:", with: "") : nil)
    }

    private static func bareID(_ id: PlayerID) -> String { id.rawValue.replacingOccurrences(of: "gc:", with: "") }

    /// Whether this ranked table reaches the ladder at all, and at what price.
    ///
    /// The house is at every ranked table now — it fills whatever the search does not — so what
    /// decides the price is not whether a bot is sitting down but whether two phones can hold
    /// each other to the result. That takes a real player on each side.
    ///
    /// A duo that met another pair is people on both sides. A duo against the house is two
    /// friends on one side, and the side that beats them is the house's, which no phone can
    /// report; so it stays a house game, as it was. So does a table you were left alone at.
    enum LadderTable { case people, house }

    var ladderTable: LadderTable? {
        isCalledOff ? nil : seatedTable
    }

    /// Somebody left this ranked game in its first minutes, and the host called it off: no
    /// phone reports it. See `EarlyExit`.
    var isCalledOff: Bool { lobby?.leftEarly != nil }

    /// What the seats make of the table, called off or not.
    private var seatedTable: LadderTable? {
        guard isRanked, let view else { return nil }
        let configuration = view.configuration
        let sides = Set(configuration.players.enumerated()
            .filter { !$0.element.isBot }
            .map { configuration.side(ofSeat: $0.offset) })
        guard !sides.isEmpty else { return nil }
        return sides.count >= 2 ? .people : .house
    }

    func reportRanked(winnerSeat: Int) {
        guard let kind = ladderTable, let view else { return }
        let configuration = view.configuration
        // The side that won, not the seat: in a duo both partners are the winners.
        let winningSide = configuration.side(ofSeat: winnerSeat)
        let gameID = rankedID
        // Once a game from this phone. The ladder keeps each phone's first word on a game, and
        // a walk-out has already said it here; the summary still wants to hear how it settled.
        guard reportedGameID != gameID else { return settleOnLadder(gameID: gameID) { nil } }
        reportedGameID = gameID
        switch kind {
        case .house:
            let won = winningSide == view.mySide
            HouseRelief.record(won: won)
            settleOnLadder(gameID: gameID) { try await Ladder.postHouseGame(gameID: gameID, won: won) }
        case .people:
            if winningSide == view.mySide { HouseRelief.record(won: true) }
            let humans = configuration.players.filter { !$0.isBot }
            // The winning side, minus the house sitting on it: the ladder only knows about
            // real players, and a bot id sent as a winner is a rating nobody owns.
            let winners = configuration.players.enumerated()
                .filter { configuration.side(ofSeat: $0.offset) == winningSide && !$0.element.isBot }
                .map { Self.bareID($0.element.id) }
            guard !winners.isEmpty else { return }
            settleOnLadder(gameID: gameID) {
                try await Ladder.postRanked(gameID: gameID, players: humans.map { Self.bareID($0.id) }, winnerIDs: winners)
            }
        }
    }

    /// Reports a finished ranked game, then waits for the ladder to settle it.
    ///
    /// A real table is applied only once two phones agree, or once one report has stood alone
    /// for ten minutes, so the answer to the report is often the answer to the game before this
    /// one. The change is taken only when the ladder names this game as the one it last applied.
    ///
    /// The wait runs about twenty seconds, which covers the other phone reporting a moment
    /// later. Past that the lobby picks the result up on its own.
    private func settleOnLadder(gameID: UUID, report: @escaping () async throws -> Ladder.RankAnswer?) {
        isAwaitingLadder = true
        Task {
            defer { isAwaitingLadder = false }
            var answer = try? await report()
            for _ in 0..<9 where answer?.lastGameID != gameID.uuidString {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, let id = gameCenterPlayerID else { break }
                answer = try? await Ladder.rank(gamePlayerID: id)
            }
            guard let answer else { return }
            rank = answer
            // Only onto the game it was asked for: an answer that comes after another ranked
            // table sat down would put the last game's swing on that one's summary.
            guard rankedID == gameID else { return }
            rankChange = answer.lastGameID == gameID.uuidString ? answer.lastChange : nil
        }
    }

    /// The run the ranked game on the summary broke, while a video can still carry it on.
    var keepableRun: Ladder.RankAnswer.KeepableRun? {
        guard isRanked, let keep = rank?.keepableRun, keep.gameID == rankedID.uuidString else { return nil }
        return keep
    }

    /// Carries on the run the last ranked game broke, the video for it watched. A few tries,
    /// since the video was already paid for in the player's time. True once the ladder has it.
    func keepRun() async -> Bool {
        let gameID = rankedID
        for attempt in 1...3 {
            if let answer = try? await Ladder.keepRun(gameID: gameID) {
                rank = answer
                return answer.keepableRun == nil && (answer.streak ?? 0) > 0
            }
            try? await Task.sleep(for: .seconds(attempt))
        }
        return false
    }

    /// A season the ladder says is over and has not paid out yet, for the lobby's ceremony.
    var seasonFinish: Ladder.RankAnswer.Finish? { rank?.finish }

    /// Tells the ladder a finished season has been handed over, and clears it here either way.
    /// The denari are granted under a key that cannot pay twice, so a claim lost on the network
    /// costs nothing but a second ceremony that pays nothing.
    func markSeasonClaimed(_ season: String) async {
        if let answer = try? await Ladder.claimSeason(season) {
            rank = answer
        } else {
            rank?.finish = nil
        }
    }

    /// Asks the ladder where everyone else at this table stands, so their league can be shown
    /// over their seat. Ranked tables only.
    ///
    /// Failures are silent and leave a seat with no badge, which is what an opponent who has
    /// never played ranked gets too.
    func loadOpponentRanks() async {
        guard isRanked, Ladder.isOn, let view else { return }
        let ids = view.opponents.filter { !$0.player.isBot }.map { Self.bareID($0.player.id) }
        for id in ids where opponentRanks[id] == nil {
            guard let answer = try? await Ladder.rank(gamePlayerID: id) else { continue }
            opponentRanks[id] = answer
        }
    }

    /// The league of every real player in `players` this phone does not know yet, asked all at
    /// once and waited on for no longer than `patience`. Before a table is dealt, and for the
    /// match-found moment, neither of which may stall on a slow ladder.
    func lookUpRanks(of players: [Player], within patience: Duration = .seconds(2.5)) async {
        guard Ladder.isOn else { return }
        let mine = gameCenterPlayerID
        let ids = Set(players.filter { !$0.isBot }.map { Self.bareID($0.id) })
            .filter { $0 != mine && opponentRanks[$0] == nil }
        guard !ids.isEmpty else { return }
        await withTaskGroup(of: (String, Ladder.RankAnswer?)?.self) { group in
            for id in ids { group.addTask { (id, try? await Ladder.rank(gamePlayerID: id)) } }
            group.addTask { try? await Task.sleep(for: patience); return nil }
            var waiting = ids
            for await answer in group {
                guard let (id, rank) = answer else { break }
                if let rank { opponentRanks[id] = rank }
                waiting.remove(id)
                if waiting.isEmpty { break }
            }
            group.cancelAll()
        }
    }

    /// The division the house plays at a table about to be dealt with `players` at it: the
    /// strongest real player's, by `Ranking.houseStep`. A league the ladder does not answer for
    /// in time counts as unranked.
    func houseStep(for players: [Player]) async -> Int {
        await lookUpRanks(of: players)
        let others = players.filter { !$0.isBot }.compactMap { opponentRanks[Self.bareID($0.id)]?.standing.step }
        return Ranking.houseStep(among: [ownStep] + others)
    }

    /// The league over one seat. Nil for a player with no ranked games, and at any table that
    /// is not ranked.
    func rank(of player: Player) -> Ladder.RankAnswer? {
        guard isRanked else { return nil }
        guard !player.isBot else { return houseRank(of: player) }
        return opponentRanks[Self.bareID(player.id)]
    }

    /// The league drawn over a house seat at a ranked table.
    ///
    /// The house sits under a stranger's name (see `seatRankedStranger`), and a chair with no
    /// rosette when every other ranked chair has one would give that away. It wears the division
    /// the house plays at this table (`tableHouseStep`), which the host names for every phone, so
    /// the league over the chair is the league it plays like. Points into the division and games
    /// come from the seat's own id, so two house seats at a duo table are not twins.
    ///
    /// It used to drift a division or two either side of this phone's own rank, which put the
    /// same two bots in Diamond on one phone of a duo and in Bronze on the other.
    ///
    /// Nothing here is sent anywhere, and the ladder never rates anybody against one of these.
    private func houseRank(of player: Player) -> Ladder.RankAnswer {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in player.id.rawValue.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        let rating = Ranking.houseRating(atStep: tableHouseStep, jitter: Int((hash >> 8) % 100))
        let standing = Ranking.standing(for: rating)
        // Enough games behind them to have earned it, and about as many won as lost.
        let games = 20 + Int((hash >> 16) % 180)
        return Ladder.RankAnswer(
            rating: rating, games: games, wins: games / 2,
            standing: .init(league: standing.league.rawValue, division: standing.division,
                            progress: standing.progress, step: standing.step, title: standing.title),
            lastChange: nil
        )
    }

    /// Whether this seat is somebody who can be looked up: a real person met through Game
    /// Center. The house, a guest over the relay, a player on this phone and your own seat all
    /// answer false.
    func hasProfile(_ player: Player) -> Bool {
        guard #available(iOS 18, *) else { return false }
        return !player.isBot && gameCenter?.account(for: player.id) != nil
    }

    /// Opens that player's Game Center profile, which is Apple's own page with the friend
    /// request button on it. Does nothing when there is no profile to open.
    func showProfile(of player: Player) {
        guard #available(iOS 18, *), !player.isBot,
              let account = gameCenter?.account(for: player.id) else { return }
        GameCenter.showProfile(of: account) { controller in Self.present(controller) }
    }

    /// Stops looking. Nothing to undo once seated: leaving the table does that.
    func cancelOnline() {
        GameCenter.cancelSearch()
        searchTask?.cancel()
        searchTask = nil
        onlineStatus = nil
        rankedSearch = nil
    }

    var isOnline: Bool { gameCenter != nil || relay != nil }

    /// Game Center's own sign-in sheet, over whatever is on screen.
    ///
    /// Never onto a sheet on its way down: what is put there leaves with it, and Apple's sheets
    /// answer only while they are up. Nor onto one still on its way up, which refuses it, nor
    /// before there is a window, at a launch from an invitation. Each is waited out first, for
    /// two seconds at most: the matchmaker's own watchdog gives a sheet ten.
    @MainActor
    private static func present(_ controller: UIViewController) {
        if let top = topScreen(), !isMoving(top) { return top.present(controller, animated: true) }
        Task { @MainActor in
            for _ in 0..<20 {
                if let top = topScreen(), !isMoving(top) { break }
                try? await Task.sleep(for: .milliseconds(100))
            }
            topScreen()?.present(controller, animated: true)
        }
    }

    @MainActor
    private static func isMoving(_ top: UIViewController) -> Bool {
        top.isBeingPresented || top.presentedViewController?.isBeingDismissed == true || top.transitionCoordinator != nil
    }

    /// The screen on top, passing over any sheet that is being taken down.
    @MainActor
    private static func topScreen() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        guard var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController else { return nil }
        while let presented = top.presentedViewController, !presented.isBeingDismissed { top = presented }
        return top
    }

    // MARK: On this phone

    /// One phone, with every seat either a person taking it in turn or a bot playing itself.
    /// `strength` overrides how hard the bots think, for a table that is not the player's to
    /// set: the coached first game and a ranked table both pass one. `deal` replaces the
    /// shuffled first deal, for a practice table laid out in advance.
    func playOnThisDevice(seats: [LocalSeat], teams: Bool, turnClock: TurnClock = .default, targetScore: Int = 11,
                          primiera: PrimieraRule = .default, ties: TieRule = .default,
                          house: Set<HouseRule> = [], strength: BotStrength? = nil,
                          deal: ((HotSeatTable) async -> Void)? = nil) {
        reset()
        isHost = true
        let (players, bots) = LocalSeat.table(seats)
        botSeats = bots
        deviceSeat = seats.firstIndex { !$0.isBot } ?? 0
        let config: GameConfiguration
        do {
            config = try GameConfiguration(players: players, teams: teams, targetScore: targetScore,
                                           turnClock: turnClock, primiera: primiera, ties: ties, house: house)
        } catch {
            notice = .rejected(message(for: error))
            return
        }
        let table = HotSeatTable(configuration: config, bots: bots, strength: strength ?? botLevel.strength)
        backend = .hotSeat(table)
        route = .table
        Task {
            consume(await table.updates)
            if let deal { await deal(table) } else { await table.deal() }
        }
    }

    /// The lobby's first door: you, and as many bots as `quickTable` is set for. Deals without
    /// asking anything, because the size is changed from the tile itself. `scatouch` stands in
    /// for the switch in the settings, for `-scatouch`.
    func playQuickGame(scatouch: Bool? = nil) {
        let table = quickTable
        playOnThisDevice(seats: [.person(name: playerName)] + table.botNames.map { .bot(name: $0) },
                         teams: table.teams)
        if scatouch ?? Scatouch.shared.isOn { beginScatouch() }
    }

    /// Turns every card over at the table just dealt, and steers its bots.
    private func beginScatouch() {
        guard route == .table, case .hotSeat(let table) = backend else { return }
        scatouch = ScatouchTable(table: table, bots: botSeats, homeSeat: deviceSeat)
    }

    /// A table on the campaign's road, dealt as the stage says whatever the settings do.
    /// Not saved for later: walking out is a game not played, and the map is one tap away.
    func playCampaign(_ stage: CampaignStage) {
        playOnThisDevice(seats: stage.seats(you: playerName), teams: stage.teams, turnClock: stage.clock,
                         targetScore: stage.target, primiera: stage.primiera, house: stage.house,
                         strength: stage.strength)
        if route == .table { campaignStage = stage }
    }

    // MARK: The first game

    /// The hand that follows the walkthrough: the coach on, the easy bot across the table, no
    /// clock, nothing riding on it. The coach stays on after this game, and the settings turn
    /// it off in one tap.
    func playCoached() {
        assist = .coached
        playFirstHand()
    }

    /// The same easy hand, at whatever level of help the player picked on the way in.
    func playFirstHand() {
        playOnThisDevice(seats: [.person(name: playerName), .bot(name: BotNames.dealer)],
                         teams: false, turnClock: .off, strength: BotLevel.easy.strength)
    }

    // MARK: Today's deal

    /// The name of the deck on offer right now.
    var today: String { DailyDeal.day() }
    var yesterday: String { DailyDeal.day(for: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now) }

    /// Asks the ladder who won yesterday, once per day. Nothing waits on the answer.
    func loadBestYesterday() {
        guard Ladder.isOn, bestYesterday?.day != yesterday else { return }
        Task { [weak self] in
            guard let self, let best = try? await Ladder.best(day: yesterday) else { return }
            self.bestYesterday = best
        }
    }

    /// One round against the bot on the deck everybody gets today. The table is built on the
    /// day's generator, so the same play meets the same cards on every phone.
    func playTodaysDeal() {
        reset()
        let day = today
        isHost = true
        let players = [localPlayer, Player(id: PlayerID(rawValue: "bot-daily"), name: BotNames.dealer, isBot: true)]
        botSeats = [1]
        deviceSeat = 0
        let config: GameConfiguration
        do {
            config = try GameConfiguration(players: players, teams: false, targetScore: 11, turnClock: .off,
                                           // Pinned rather than defaulted: the ladder compares
                                           // margins, so this rule may never drift.
                                           primiera: .mostSevens)
        } catch {
            notice = .rejected(message(for: error))
            return
        }
        let table = HotSeatTable(configuration: config, bots: botSeats, strength: Self.contestLevel.strength,
                                 rng: DailyDeal.generator(for: day))
        backend = .hotSeat(table)
        dailyDay = day
        route = .table
        Task {
            consume(await table.updates)
            await table.deal()
        }
    }

    var isDailyDeal: Bool { dailyDay != nil }

    /// Days in a row as they stand once today's deal is in the book.
    var dailyStreak: Int { dailyBook.streak(endingOn: today) }

    /// The streak mark today's deal has just reached, if it reached one.
    var streakMilestone: Streaks.Milestone? {
        guard let dailyDay, dailyResult != nil else { return nil }
        return Streaks.milestone(reachedAt: dailyBook.streak(endingOn: dailyDay))
    }

    // MARK: Playing for denari

    /// How long the search for real opponents runs before the bots take the empty seats.
    static let wagerSearchTime: Duration = .seconds(20)
    /// A wager table is always this full: whoever came, and bots for the rest.
    static let wagerSeats = 4
    /// How many seats to fill with bots before the host deals, at a table that wants them.
    private var fillsTo: Int?

    /// A ranked duo is a table of four: the pair, and another pair or the house in the other
    /// two chairs. Ranked played alone is whatever `RankedSolo` says instead, and its search
    /// looks for one other phone. Only the real chairs are rated; see `ladderTable`.
    static let duoSeats = 4

    /// How many times a guest asks to be seated before giving up, 700ms apart, which is a
    /// little over twenty seconds.
    static let joinAttempts = 30

    /// A game with denari on it, against whoever is looking for the same stake online. The
    /// caller has already put the stake down under `gameID`. If Game Center is off, nobody
    /// comes within `wagerSearchTime`, or the search fails, the bot sits down for the same stake.
    func playForStake(_ stake: Stake, gameID: UUID) {
        reset()
        self.stake = stake
        wagerID = gameID
        onlineStatus = .signingIn
        searchTask = Task {
            let match = await findWagerMatch(stake)
            guard !Task.isCancelled else { return }
            guard let match else {
                seatBot(stake: stake, gameID: gameID)
                return
            }
            self.stake = stake
            wagerID = gameID
            fillsTo = Self.wagerSeats
            announceMatch(match.match.players.map(\.displayName), as: [match.me.name])
            await seatOnline(match.match, as: match.me, players: match.match.players.count + 1)
        }
    }

    /// Looks for a table at the same stake for `wagerSearchTime`. Nil when nobody came.
    private func findWagerMatch(_ stake: Stake) async -> GKMatchBox? {
        do {
            let me = try await GameCenter.signIn { controller in Self.present(controller) }
            guard !Task.isCancelled else { return nil }
            onlineStatus = .searching
            // Only tables of the same stake meet. The control character keeps one feature's
            // pool names clear of another's. The clock is Game Center's to hold, so it stops
            // the moment a table is made: one of ours here called the matchmaker off after a
            // table was found, and in the seconds it takes the others to arrive at it.
            let found = try await GameCenter.findMatch(players: 2...Self.wagerSeats, pool: "\u{1}wager/\(stake.rawValue)",
                                                       within: Self.wagerSearchTime / .seconds(1))
            return GKMatchBox(match: found, me: me)
        } catch {
            return nil
        }
    }

    /// The same stake against the bot, right now. What a wager falls back to, and what "play
    /// Hugo now" does when nobody is coming.
    func playBotForStake() {
        guard let stake else { return }
        let gameID = wagerID
        searchTask?.cancel()
        GameCenter.cancelSearch()
        seatBot(stake: stake, gameID: gameID)
    }

    private struct GKMatchBox {
        let match: GKMatch
        let me: Player
    }

    private func seatBot(stake: Stake, gameID: UUID) {
        reset()
        self.stake = stake
        wagerID = gameID
        isHost = true
        let players = [localPlayer] + wagerBots()
        botSeats = Set(1..<players.count)
        deviceSeat = 0
        let config: GameConfiguration
        do {
            config = try GameConfiguration(players: players, teams: false, targetScore: 11, turnClock: .off)
        } catch {
            // The table never opened, so the denari have to come back: nothing else knows the
            // stake went down, and the player is looking at a lobby that just charged them.
            notice = .rejected(message(for: error))
            refusedStake = RefusedStake(stake: stake, gameID: gameID)
            self.stake = nil
            return
        }
        let table = HotSeatTable(configuration: config, bots: botSeats, strength: Self.contestLevel.strength)
        backend = .hotSeat(table)
        route = .table
        Task {
            consume(await table.updates)
            await table.deal()
        }
    }

    /// Only as many bots as there are empty seats. Seating the whole cast made a table of
    /// nine, which the rules refuse, and the wager table then never opened at all.
    private func wagerBots() -> [Player] {
        Presence.strangers(Self.wagerSeats - 1).enumerated().map {
            Player(id: PlayerID(rawValue: "bot-\($0.offset)"), name: $0.element, isBot: true)
        }
    }

    // MARK: Playing

    func play(_ card: Card, capturing captures: [Card] = []) {
        // A practice hand is a lesson: only the move it teaches is sent.
        if let nudge = practiceNudge(card, capturing: captures) {
            notice = .rejected(nudge)
            return
        }
        Task {
            switch backend {
            case .host(let coordinator): try? await coordinator.play(card, capturing: captures)
            case .guest(let client): try? await client.play(card, capturing: captures)
            case .hotSeat(let table): try? await table.play(card, capturing: captures)
            case .none: break
            }
        }
    }

    func react(_ reaction: Reaction) {
        Task {
            switch backend {
            case .host(let coordinator): await coordinator.react(reaction)
            case .guest(let client): try? await client.react(reaction)
            case .hotSeat: show(reaction, from: view.map { name(ofSeat: $0.seat) } ?? playerName)
            case .none: break
            }
        }
    }

    func forget(_ reaction: SeenReaction) {
        reactions.removeAll { $0.id == reaction.id }
    }

    private func show(_ reaction: Reaction, from name: String) {
        reactions.append(SeenReaction(name: name, reaction: reaction))
        if reactions.count > 6 { reactions.removeFirst() }
    }

    /// Used when a turn clock runs out. The host decides the move so every device agrees.
    func playAutomatically(for seat: Int) {
        Task {
            switch backend {
            case .host(let coordinator): await coordinator.playAutomatically()
            case .hotSeat(let table): await table.playAutomatically(for: seat)
            case .guest(let client): try? await client.playAutomatically()
            case .none: break
            }
        }
    }

    /// Keeps the bots from playing while the screen shows something first. Released by
    /// `releaseBots`, or by the deadline if that never comes. Tables with no bots ignore it.
    func holdBots(for duration: Duration) {
        botsHeldUntil = .now + duration
        Task {
            switch backend {
            case .host(let coordinator): await coordinator.holdBots(for: duration)
            case .hotSeat(let table): await table.holdBots(for: duration)
            case .guest, .none: break
            }
        }
    }

    func releaseBots() {
        botsHeldUntil = nil
        Task {
            switch backend {
            case .host(let coordinator): await coordinator.releaseBots()
            case .hotSeat(let table): await table.releaseBots()
            case .guest, .none: break
            }
        }
    }

    func dealNextRound() {
        Task {
            switch backend {
            case .host(let coordinator):
                do { try await coordinator.dealNextRound() } catch { notice = .rejected("Could not deal again") }
            case .hotSeat(let table): await table.deal()
            case .guest, .none: break
            }
        }
    }

    /// `askedAt` is when the player asked to leave, which the dialog judged the first minutes
    /// by: the walk-out keeps to what it said, however long it stayed up.
    func leaveTable(askedAt: Date? = nil) {
        // Read before the goodbye, which lets go of the line it looks at.
        let moment = askedAt ?? .now
        let reports = walkOutCounts(at: moment)
        sayGoodbye(forfeiting: reports && ladderTable == .people, callingOff: isHost && leavesFree(at: moment))
        // Walking out of a ranked game is a loss, against the house as much as against people:
        // the chair you left is the chair you lost. Saying so lets the other phone's report
        // settle at once instead of standing alone for ten minutes. In its first two minutes it
        // is nothing at all, which is what a line that dropped at the deal needs.
        //
        // The seat named is any one on the other side, which is a side rather than a person —
        // a duo's two partners both lose a game one of them walked out of.
        if reports, let view,
           let other = view.opponents.first(where: { view.configuration.side(ofSeat: $0.seat) != view.mySide }) {
            reportRanked(winnerSeat: other.seat)
        }
        // A game on this phone with nothing staked on it is kept, so an X tapped by mistake is
        // waiting in the lobby afterwards. A wager is not: the dialog said the stake stays behind.
        // A campaign table goes back to its map rather than into the saved game.
        if campaignStage != nil || practice != nil { campaignBook.showsMap = true }
        if case .hotSeat(let table) = backend, dailyDay == nil, campaignStage == nil, practice == nil {
            if stake == nil, view?.isFinished == false {
                saveTask?.cancel()
                let bots = botSeats, seat = deviceSeat, id = wagerID, tally = tally, scatouched = scatouch != nil
                Task { [weak self] in
                    let snapshot = await table.snapshot
                    self?.keep(snapshot, bots: bots, deviceSeat: seat, stake: nil, wagerID: id, tally: tally,
                               scatouch: scatouched)
                }
            } else {
                forgetSavedGame()
            }
        }
        reset()
        route = .lobby
    }

    // MARK: Picking a game back up

    /// Looks for a game left unfinished on this phone. Called once from the lobby rather than
    /// from `init`, so nothing at launch waits on a file.
    func loadSavedGame() {
        guard !hasLookedForSavedGame else { return }
        hasLookedForSavedGame = true
        savedGame = SavedGameFile.load()
    }

    /// Sits back down at the saved game, exactly where it was left.
    func resumeSavedGame() {
        guard let saved = savedGame else { return }
        reset()
        isHost = true
        botSeats = saved.bots
        deviceSeat = saved.deviceSeat
        stake = saved.stake
        wagerID = saved.wagerID
        // Restored before the first view arrives, so `startTallyIfNeeded` leaves it alone and
        // the scope swept before the relaunch still count.
        tally = saved.tally
        // A ranked game comes back ranked, its house at the division it was dealt at.
        let strength = saved.ranked.map { BotStrength.house(atStep: $0.step, losing: HouseRelief.losses) }
            ?? (saved.stake == nil ? botLevel.strength : Self.contestLevel.strength)
        if let ranked = saved.ranked {
            isRanked = true
            // Its first minutes were before the app closed.
            rankedDealtAt = .distantPast
            rankedID = ranked.id
            rankedFormat = RankedSolo(rawValue: ranked.format) ?? .teams
            dealtHouseStep = ranked.step
        }
        let table = HotSeatTable(snapshot: saved.snapshot, bots: saved.bots, strength: strength)
        backend = .hotSeat(table)
        // Before the first view too, so a Scatouch game opens no tally on its way back.
        if saved.scatouch == true {
            scatouch = ScatouchTable(table: table, bots: saved.bots, homeSeat: saved.deviceSeat)
        }
        route = .table
        Log.table.info("Resuming a saved game from round \(saved.state.roundNumber)")
        Task {
            consume(await table.updates)
            await table.resume()
        }
    }

    /// Throws the saved game away. From the lobby card, or when the game it was is over.
    func forgetSavedGame() {
        saveTask?.cancel()
        saveTask = nil
        savedGame = nil
        SavedGameFile.clear()
    }

    /// Whether more than one person plays on this phone, in which case a hand has to be hidden
    /// while the phone changes hands.
    var passesThePhone: Bool {
        guard isHotSeat, let view else { return false }
        return view.configuration.seatCount - botSeats.count > 1
    }

    /// Writes the table down a moment after it changes. Coalesced, because every move arrives
    /// as a view and then its events, and the tally is only right after the second.
    private func saveSoon() {
        guard case .hotSeat(let table) = backend, dailyDay == nil, campaignStage == nil, practice == nil else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, let self else { return }
            let snapshot = await table.snapshot
            guard !Task.isCancelled, case .hotSeat(let current) = backend, current === table else { return }
            let ranked = isRanked ? SavedGame.Ranked(id: rankedID, step: tableHouseStep, format: rankedFormat.rawValue) : nil
            keep(snapshot, bots: botSeats, deviceSeat: deviceSeat, stake: stake, wagerID: wagerID, tally: tally,
                 scatouch: scatouch != nil, ranked: ranked)
        }
    }

    private func keep(_ snapshot: HotSeatTable.Snapshot, bots: Set<Int>, deviceSeat: Int,
                      stake: Stake?, wagerID: UUID, tally: RewardTally?, scatouch: Bool,
                      ranked: SavedGame.Ranked? = nil) {
        // Nothing to come back to once it is over.
        guard !snapshot.state.isFinished, snapshot.state.round != nil else { return forgetSavedGame() }
        let saved = SavedGame(snapshot: snapshot, bots: bots, deviceSeat: deviceSeat,
                              stake: stake, wagerID: wagerID, tally: tally, savedAt: .now,
                              scatouch: scatouch ? true : nil, ranked: ranked)
        savedGame = saved
        SavedGameFile.save(saved)
    }

    func clearNotice() { notice = nil }

    // MARK: Plumbing

    private func consume(_ updates: AsyncStream<TableUpdate>) {
        pump?.cancel()
        pump = Task { [weak self] in
            for await update in updates {
                #if DEBUG
                await DebugLaunch.lagEvents(update)
                #endif
                guard let self else { return }
                self.apply(update)
            }
        }
    }

    private func apply(_ update: TableUpdate) {
        switch update {
        case .lobby(let lobby): applyLobby(lobby)
        case .view(let view): applyView(view)
        case .events(let events): applyEvents(events)
        case .rejected(let error): notice = .rejected(message(for: error))
        case .playerLeft(let id): applyDeparture(of: id)
        case .playerReturned(let id): noteReturn(of: id)
        case .tableClosed: hostClosedTable()
        case .forfeited(let id): noteForfeit(of: id)
        case .reacted(let player, let reaction):
            noteSeen(player)
            show(reaction, from: lobby?.players.first { $0.id == player }?.name ?? "Someone")
        case .joinRefused:
            notice = .joinRefused
            route = .lobby
        case .record(let record):
            Log.table.info("Record arrived: \(record.rounds.count) rounds")
            self.record = record
            readBack(record)
        }
        noteLine(update)
    }

    private func applyLobby(_ lobby: Lobby) {
        Log.table.info("Lobby: \(lobby.players.map(\.name).joined(separator: ", "), privacy: .public) at \(lobby.host.name, privacy: .public)'s table")
        let houseNamed = self.lobby?.houseStep == nil && lobby.houseStep != nil
        let calledOff = self.lobby?.leftEarly == nil ? lobby.leftEarly : nil
        self.lobby = lobby
        if let calledOff, isRanked { noteCalledOff(by: calledOff) }
        // The leader of a duo took the house: the partner's phone is shown who sat down too.
        // Before the deal only: a lobby sent again to a phone sitting back down is no news.
        if houseNamed, isRankedDuo, !isHost, view == nil { announceHouse(at: lobby) }
        // Every phone at a ranked table reports the game the host named, so the Worker sees
        // one game with four reports rather than four games with one.
        if isRanked, !isHost, let id = lobby.gameID.flatMap(UUID.init(uuidString:)) { rankedID = id }
        // An online table has nothing to set: the moment everyone is seated, the host deals.
        guard isHost, !hostDeals, let onlineSize, lobby.players.filter({ !$0.isBot }).count >= onlineSize,
              case .host(let coordinator) = backend else { return }
        self.onlineSize = nil
        dealOnlineTable(through: coordinator)
    }

    /// Fills the empty chairs, names the ranked game, seats the partners, and deals.
    private func dealOnlineTable(through coordinator: HostCoordinator) {
        let ranked = isRanked, duo = isRankedDuo, id = rankedID
        Log.table.info("Table full — ranked: \(ranked, privacy: .public), duo: \(duo, privacy: .public)")
        let fill = fillsTo
        fillsTo = nil
        Task {
            // Empty chairs first: `seatPartners` seats partners opposite and wants four.
            if let fill { await coordinator.addBots(upTo: fill, names: Presence.strangers(fill)) }
            if ranked { await coordinator.setGameID(id.uuidString) }
            if ranked { await nameTheHouse(through: coordinator, duo: duo) }
            if duo {
                await coordinator.seatPartners()
                await coordinator.setTeams(true)
            } else if ranked, rankedFormat.teams {
                // No seating to do: the phones took seats 0 and 1 and the house filled 2 and 3
                // behind them, so teams alone puts one real player on each side, each with a
                // house partner. A duo is the other way round and has to be sat. A heads-up
                // table is left alone: two seats are two sides, and calling it teams would
                // make the pair of them one.
                await coordinator.setTeams(true)
            }
            // The ladder's 2.5 seconds are long enough to have left the table meanwhile.
            guard isCurrent(coordinator) else { return }
            startGame()
        }
    }

    /// Whether `coordinator` still runs the table on screen, after an await it might not.
    private func isCurrent(_ coordinator: HostCoordinator) -> Bool {
        if case .host(let current) = backend { current === coordinator } else { false }
    }

    /// A ranked table with the house at it: its division decided once, here, from everyone real
    /// at the table, named on the lobby for every phone and played by this phone's bots. A duo
    /// that took the house is shown who it took, as the partner's phone is when the lobby lands.
    private func nameTheHouse(through coordinator: HostCoordinator, duo: Bool) async {
        let players = await coordinator.lobby.players
        guard players.contains(where: \.isBot) else { return }
        let step = await houseStep(for: players)
        await coordinator.setHouseStep(step)
        Log.table.info("The house plays at step \(step, privacy: .public)")
        if duo, isCurrent(coordinator) { announceHouse(at: await coordinator.lobby) }
    }

    private func applyView(_ view: PlayerView) {
        // A fresh hand after a finished game is the host dealing again, so the last game's
        // tally, record and review go with it.
        if let tally, tally.isSettled, !view.isFinished { beginAnotherGame() }
        self.view = view
        if isRanked, rankedDealtAt == nil { rankedDealtAt = .now }
        scatouch?.refresh()
        startTallyIfNeeded(for: view)
        if route != .table { route = .table }
        if view.isFinished { Log.table.info("Game finished") }
        saveSoon()
    }

    private func applyEvents(_ events: [GameEvent]) {
        tally?.observe(events)
        saveSoon()
        let digest = EventDigest(events)
        if let seat = digest.played?.seat { noteSeen(view?.configuration.players[safe: seat]?.id) }
        if let seat = digest.sweptSeat { notice = .scopa(name(ofSeat: seat)) }
        if digest.touchesLeftovers {
            leftovers = digest.leftovers.map { Leftovers(side: $0.side, cards: $0.cards) }
        }
        if let score = digest.roundScore { noteRoundEnd(score) }
        notePlay(digest)
        // A sweep has its own banner, so it keeps the floor.
        if digest.isRefill, !digest.sweeps { notice = .dealt }
    }

    /// Keeps the round's score, and writes the day's result the first time a daily deal ends.
    private func noteRoundEnd(_ score: RoundScore) {
        lastRoundScore = score
        guard let dailyDay, dailyResult == nil else { return }
        let result = DailyDealResult(day: dailyDay, playedAt: .now,
                                     mine: score.points[safe: 0] ?? 0, theirs: score.points[safe: 1] ?? 0,
                                     scope: score.scope[safe: 0] ?? 0, accuracy: nil)
        dailyResult = result
        dailyBook.record(result)
        freshDailyDay = dailyDay
    }

    /// Keeps the last card played, and what it took, for the table's callout.
    private func notePlay(_ digest: EventDigest) {
        guard let played = digest.played else { return }
        lastPlay = Play(seat: played.seat, name: name(ofSeat: played.seat), mark: mark(ofSeat: played.seat),
                        isHonoured: isHonoured(seat: played.seat), isBot: isBot(ofSeat: played.seat),
                        card: played.card, captures: digest.captured, sweeps: digest.sweeps)
    }

    /// See `Departure` for who does what. A duo is held at its Game Center table while it looks
    /// for another pair; a host waited for is waited for by the banner, which says how long.
    private func applyDeparture(of id: PlayerID) {
        let name = lobby?.players.first { $0.id == id }?.name ?? "A player"
        switch Departure.of(hostWent: id == lobby?.host.id, thisPhoneHosts: isHost,
                            heldDuo: isRankedDuo && gameCenter != nil, dealt: view != nil,
                            finished: view?.isFinished == true, watched: connection.link != nil) {
        case .pairBroke: pairBroke()
        case .waitForHost:
            // Counted before the host joins the departed: theirs is one of the table's phones.
            let phones = lobby?.players.filter { !$0.isBot && !departed.contains($0.id) }.count ?? 2
            departed.insert(id)
            connection.hostLeft(name, phones: phones)
        case .leave:
            leaveTable()
            notice = .playerLeft(name)
        case .coverSeat:
            departed.insert(id)
            notice = .playerLeft(name)
            callOffIfEarly(leftBy: id)
            if isAlone { connection.expectGoodbye() }
        }
    }

    /// Every other chair is the house's now, or empty: nobody is left on the line, and a Game
    /// Center match failing after this has nobody to lose. The game goes on against the house.
    private var isAlone: Bool {
        guard let lobby else { return false }
        let me = gameCenter?.localPlayer.id ?? relay?.localPlayer.id ?? multipeer?.localPlayer.id
        return lobby.players.allSatisfy { $0.isBot || $0.id == me || departed.contains($0.id) }
    }

    /// Judges the moves this phone can show, off the main thread, and shows the review when it
    /// is ready. Bots' moves are never shown, and the rounds already read are not read again.
    private func readBack(_ record: GameRecord) {
        // A practice hand is laid out in advance: there is nothing in it to review. A Scatouch
        // game was played with every card in view, which no review can judge.
        guard practice == nil, scatouch == nil else { return }
        reviewTask?.cancel()
        let seats = Set(reviewableSeats)
        let earlier = review
        // Detached so cancelling it reaches the reviewer, which stops between moves.
        reviewTask = Task.detached(priority: .utility) { [weak self] in
            let review = Reviewer.review(record, seats: seats.isEmpty ? nil : seats, after: earlier)
            await self?.settle(review)
        }
    }

    private func settle(_ review: GameReview) {
        guard !Task.isCancelled else {
            Log.table.info("Review dropped: cancelled")
            return
        }
        Log.table.info("Review ready: \(review.moves.count) moves")
        self.review = review
        guard let dailyDay, dailyResult != nil else { return }
        let accuracy = review.summary(forSeat: 0).accuracy
        dailyBook.note(accuracy: accuracy, for: dailyDay)
        dailyResult?.accuracy = accuracy
        // Sent once the accuracy is known, so the ladder gets the whole result.
        if let result = dailyResult { postToLadder(result) }
    }

    /// Tells the ladder how the day went. Does nothing when the ladder is off or the player is
    /// not on Game Center, and a network failure raises no notice.
    private func postToLadder(_ result: DailyDealResult) {
        guard Ladder.isOn else { return }
        Task {
            guard let standing = try? await Ladder.post(result), let rank = standing.rank else { return }
            dailyBook.note(rank: rank, played: standing.played, for: result.day)
        }
    }

    /// Whether a seat is being played by the machine right now: a bot by design, or a person
    /// whose device has gone.
    func isBot(_ player: Player) -> Bool {
        // The house strangers are bots the table draws as people. `Player.isBot` stays true
        // underneath, which is what `ladderTable` reads to price the game. The named cast in
        // `BotNames` is not covered: Hugo deals the quick game as himself.
        if player.isBot, Presence.people.contains(player.name) { return false }
        return player.isBot || departed.contains(player.id)
    }

    /// The seats a review on this phone can be read from: one seat on a networked table, every
    /// human seat on a shared phone.
    var reviewableSeats: [Int] {
        guard let view else { return [] }
        if isHotSeat { return (0..<view.configuration.seatCount).filter { !botSeats.contains($0) } }
        return [view.seat]
    }

    /// The seat whose phone this is, which is the one the review opens on.
    var reviewedSeat: Int? {
        isHotSeat ? deviceSeat : view?.seat
    }

    /// The chair this phone belongs to, which the table colours terracotta whoever else sits
    /// down. A shared phone keeps its owner's rather than following the seat about to play.
    var homeSeat: Int {
        if let reviewedSeat { return reviewedSeat }
        let me = multipeer?.localPlayer.id ?? gameCenter?.localPlayer.id ?? relay?.localPlayer.id
        return lobby?.players.firstIndex { $0.id == me } ?? 0
    }

    /// The tally of a game that has actually finished, and nil until then.
    ///
    /// Every backend sends the view before the events it came from, so the summary is on screen
    /// a beat before the tally hears `.gameEnded`. A payout keyed on the summary appearing
    /// would settle a game the tally does not yet know is over, and pay nothing.
    var finishedTally: RewardTally? {
        guard let tally, tally.isSettled else { return nil }
        return tally
    }

    /// Opened once per game, on the first view to arrive, which comes before the first events
    /// on the host, on a guest and on a hot seat table alike.
    private func startTallyIfNeeded(for view: PlayerView) {
        guard tally == nil, let mode else { return }
        // A local view follows whichever seat is about to play, so `mySide` would change hands
        // every turn.
        let side = isHotSeat ? view.configuration.side(ofSeat: deviceSeat) : view.mySide
        tally = RewardTally(side: side, configuration: view.configuration, mode: mode)
    }

    /// Clears what one game leaves on the table before the next is dealt to the same seats.
    private func beginAnotherGame() {
        tally = nil
        record = nil
        review = nil
        reviewTask?.cancel(); reviewTask = nil
        lastRoundScore = nil
        leftovers = nil
        lastPlay = nil
        notice = nil
        wagerID = UUID()
        // Left here, the last game's swing is what the new summary shows for the seconds
        // before the ladder answers.
        rankChange = nil
        rankedDealtAt = nil
        lastSeen = [:]
    }

    private var isHotSeat: Bool {
        if case .hotSeat = backend { true } else { false }
    }

    private var mode: TableMode? {
        // A practice table opens no tally, so it pays, records and counts nothing. Nor does a
        // Scatouch game: every card in it was seen, and half of them were chosen.
        guard practice == nil, scatouch == nil, let seats = view?.configuration.seatCount else { return nil }
        if let dailyDay { return .dailyDeal(day: dailyDay) }
        switch backend {
        case .host, .guest: return .multipeer(players: seats)
        case .hotSeat: return botSeats.isEmpty ? .hotSeat(seats: seats) : .withBots(seats: seats, bots: botSeats.count)
        case .none: return nil
        }
    }

    private func name(ofSeat seat: Int) -> String {
        view?.configuration.players[safe: seat]?.name ?? lobby?.players[safe: seat]?.name ?? "Someone"
    }

    func mark(ofSeat seat: Int) -> SeatMark {
        (view?.configuration.players[safe: seat] ?? lobby?.players[safe: seat]).map(SeatMark.init) ?? .initial
    }

    /// Whether the seat is a machine, by the same reckoning the rest of the table uses, so a
    /// house stranger is drawn as a person here too.
    private func isBot(ofSeat seat: Int) -> Bool {
        (view?.configuration.players[safe: seat] ?? lobby?.players[safe: seat]).map(isBot) ?? false
    }

    /// Whether the player in a seat is entitled to this week's badge, by what their phone sent.
    /// A week that is not this one or the one before is ignored, so a stale badge is not
    /// honoured across the table.
    func isHonoured(seat: Int) -> Bool {
        let player = view?.configuration.players[safe: seat] ?? lobby?.players[safe: seat]
        return ChallengeBook.honours(player?.honour, on: challenges.week)
    }

    private func message(for error: ConfigurationError) -> String {
        switch error {
        case .playerCount: "A table seats two to four players"
        case .teamsRequireFourPlayers: "Teams need four players"
        case .scoponeRequiresTeams: "Scopone is played four, in two teams"
        case .invalidTargetScore: "Pick a score to play to"
        }
    }

    private func message(forHost error: Error) -> String {
        guard let error = error as? HostCoordinator.HostError else { return "Could not start the game" }
        switch error {
        case .cannotStart: return "Not enough players"
        case .gameAlreadyRunning: return "That game has already started"
        case .noGame: return "There is no game to play"
        }
    }

    private func message(for error: MoveError) -> String {
        switch error {
        case .notYourTurn: "Not your turn"
        case .captureIsMandatory: "You have to take"
        case .invalidCapture: "That take is not allowed"
        case .cardNotInHand: "That card is not in your hand"
        case .captureNotOnTable: "Those cards are not on the table"
        case .notPlaying: "The round is over"
        }
    }

    private func reset() {
        problemPump?.cancel(); problemPump = nil
        saveTask?.cancel(); saveTask = nil
        pump?.cancel(); pump = nil
        stopBrowsing()
        stopBackend()
        searchTask?.cancel(); searchTask = nil
        inviteTask?.cancel(); inviteTask = nil
        reconnectPump?.cancel(); reconnectPump = nil
        connection.end()
        closeConnections()
        clearTable()
    }

    private func stopBackend() {
        if case .host(let coordinator) = backend { Task { await coordinator.stop() } }
        if case .guest(let client) = backend { Task { await client.stop() } }
        if case .hotSeat(let table) = backend { Task { await table.stop() } }
    }

    /// Drops the transport and everything that described the table it reached.
    private func closeConnections() {
        gameCenter?.disconnect()
        gameCenter = nil
        relay?.disconnect()
        relay = nil
        room = nil
        onlineSize = nil
        hostDeals = false
        onlineStatus = nil
        fillsTo = nil
        isRanked = false
        isRankedDuo = false
        rankedFormat = .teams
        dealtHouseStep = nil
        // Asked for once per game rather than cached between tables: a league is exactly the
        // kind of number that has changed since the last one.
        opponentRanks = [:]
        backend = .none
        botSeats = []
        deviceSeat = 0
        multipeer = nil
    }

    /// Clears everything the last table put on screen.
    private func clearTable() {
        lobby = nil
        view = nil
        notice = nil
        invitationOverStake = nil
        lastPlay = nil
        lastRoundScore = nil
        leftovers = nil
        reactions = []
        departed = []
        rankedDealtAt = nil
        lastSeen = [:]
        tally = nil
        record = nil
        review = nil
        reviewTask?.cancel(); reviewTask = nil
        dailyDay = nil
        dailyResult = nil
        stake = nil
        rankedSearch = nil
        duoSearch = nil
        duoLeaderLeft = false
        campaignStage = nil
        practice = nil
        scatouch = nil
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
