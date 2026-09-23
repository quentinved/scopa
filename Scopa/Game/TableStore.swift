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
    var houseStrength: BotStrength { BotStrength.house(atStep: rank?.standing.step ?? 0) }

    /// Which deck you like looking at. Yours alone: nothing about it crosses the wire.
    var cardTheme: CardTheme {
        didSet {
            UserDefaults.standard.set(cardTheme.style.rawValue, forKey: Self.styleKey)
            UserDefaults.standard.set(cardTheme.skin.rawValue, forKey: Self.skinKey)
        }
    }

    /// The language the game speaks. Kept on the device like the rest of the preferences.
    var language: Language {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey) }
    }

    /// The colour of the table under the cards. Yours alone, like the deck.
    var tableFelt: TableFelt {
        didSet { UserDefaults.standard.set(tableFelt.rawValue, forKey: Self.feltKey) }
    }

    /// The weave of the cloth, where `tableFelt` is its colour. Yours alone, like the felt.
    var tapis: Tapis {
        didSet { UserDefaults.standard.set(tapis.rawValue, forKey: Self.tapisKey) }
    }

    /// What is printed on the back of the cards. Yours alone, like the deck and the felt.
    var cardBack: CardBackPattern {
        didSet { UserDefaults.standard.set(cardBack.rawValue, forKey: CardBackPattern.stored) }
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

    /// What the table does when you sweep it. Yours alone: the flourish is drawn on the
    /// phone that swept, because it is a reaction to your own move and not a fact about
    /// the game the others need told.
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
        }
    }
    /// What the last ranked game did, for the summary. Nil until the ladder answers.
    private(set) var rankChange: Int?
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
        /// How long the whole search runs before the house takes the chair.
        let length: TimeInterval
        /// True once your own league has been given up on and anybody will do.
        var isWidened = false
    }

    private(set) var rankedSearch: RankedSearch?
    private var pump: Task<Void, Never>?
    private var browsePump: Task<Void, Never>?
    private var problemPump: Task<Void, Never>?
    private var reconnectPump: Task<Void, Never>?
    /// The invitation sheet for a friend named at a table that is already open. Its own task,
    /// because `searchTask` is for finding a table and this one goes out from a standing one.
    private var inviteTask: Task<Void, Never>?

    init(playerName: String? = nil, assist: AssistLevel? = nil) {
        self.playerName = playerName ?? UserDefaults.standard.string(forKey: Self.nameKey) ?? Self.defaultName
        self.assist = assist ?? Self.stored(Self.assistKey, or: .default)
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
               companion: companion.wireValue, livery: livery.wireValue)
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

    func setTeams(_ teams: Bool) {
        guard case .host(let coordinator) = backend else { return }
        Task { await coordinator.setTeams(teams) }
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

    func setTargetScore(_ score: Int) {
        guard case .host(let coordinator) = backend else { return }
        Task { await coordinator.setTargetScore(score) }
    }

    /// Whether this phone is setting the table, with the cards still to be dealt. The seats
    /// are the host's to arrange only until then.
    var isSettingTheTable: Bool {
        guard case .host = backend else { return false }
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
    /// Friends find a nearby table through "Join a table" instead, and ranked and code tables
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
                let match = try await GameCenter.inviteToRoom(group: group) { controller in Self.present(controller) }
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
    }

    /// Whether "Play again" belongs on the last summary: a table this phone can deal again by
    /// itself, with nothing at stake. A guest waits for the host, a wager needs a new stake,
    /// and today's deal is one a day.
    ///
    /// Not at a ranked table of people either, where dealing again would put somebody else's
    /// rating at stake on this phone's tap. Against the house there is nobody to ask, so the
    /// button stands.
    var canPlayAgain: Bool {
        guard view?.isFinished == true, stake == nil, dailyDay == nil else { return false }
        if isRanked, ladderTable == .people { return false }
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
        let ranked = isRanked
        let again = UUID()
        switch backend {
        case .host(let coordinator):
            if ranked {
                rankedID = again
                rankChange = nil
            }
            Task { try? await coordinator.playAgain(gameID: ranked ? again.uuidString : nil) }
        case .hotSeat:
            guard let configuration = view?.configuration else { return }
            let seats = configuration.players.map { $0.isBot ? LocalSeat.bot(name: $0.name) : .person(name: $0.name) }
            leaveTable()
            // The house plays a ranked game at its ranked strength, whatever the settings say.
            playOnThisDevice(seats: seats, teams: configuration.teams,
                             turnClock: configuration.turnClock, targetScore: configuration.targetScore,
                             primiera: configuration.primiera, ties: configuration.ties,
                             strength: ranked ? houseStrength : nil)
            if ranked {
                isRanked = true
                rankedID = again
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
        // The waiting room comes after the seat. Going there on the tap left a guest whose
        // invitation was quietly timing out staring at an empty table for twenty seconds.
        joining = table
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
            } catch GameCenterError.cancelled {
                onlineStatus = nil
            } catch GameCenterError.notSignedIn {
                onlineStatus = nil
                notice = .rejected("Sign in to Game Center to play online")
            } catch {
                onlineStatus = nil
                notice = .rejected("Could not find a table online")
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

    /// A ranked duo: one friend invited by name, the house in the other two chairs,
    /// partners seated opposite, the pair rated together.
    func playRankedDuo(with friend: GKPlayer) {
        beginRankedDuo { _ in try await GameCenter.makeDuo(with: friend) }
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
        // Two people, and the house takes the other two chairs.
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
            // differs on each and both would wait for a join the other never sends.
            await seatOnline(match, as: me, players: 2, host: me.id)
            isRanked = true
            isRankedDuo = true
            rankedFormat = .teams
            rankedID = id
        } catch GameCenterError.cancelled {
            onlineStatus = nil
        } catch GameCenterError.notSignedIn {
            onlineStatus = nil
            notice = .rejected("Sign in to Game Center to play ranked")
        } catch {
            onlineStatus = nil
            notice = .rejected("Could not set the duo up")
        }
    }

    /// Apple's sheet for inviting friends to a table of up to `players`. Once everyone invited
    /// has accepted the table waits in the waiting room, because the empty chairs are the
    /// host's to fill with bots before dealing.
    func inviteFriends(players: Int) {
        reset()
        onlineStatus = .signingIn
        searchTask = Task {
            do {
                let me = try await GameCenter.signIn { controller in Self.present(controller) }
                guard !Task.isCancelled else { return }
                onlineStatus = .searching
                let match = try await GameCenter.inviteFriends(players: 2...players) { controller in Self.present(controller) }
                guard !Task.isCancelled else { GameCenter.leave(match); return }
                await seatOnline(match, as: me, players: match.players.count + 1, hostDeals: true, host: me.id)
            } catch GameCenterError.cancelled {
                onlineStatus = nil
            } catch GameCenterError.notSignedIn {
                onlineStatus = nil
                notice = .rejected("Sign in to Game Center to play online")
            } catch {
                onlineStatus = nil
                notice = .rejected("Could not set the table up")
            }
        }
    }

    /// Somebody invited this player and they said yes, from a notification or from Messages,
    /// with the app closed or open. Whatever was on screen gives way to the table.
    func accept(_ invite: GKInvite) {
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
        // The waiting room rather than the lobby. Accepting takes as long as the other
        // phone takes to seat the table, and a menu with nothing on it made "it is joining"
        // and "it did not work" look exactly the same — which is what a friend invited to a
        // duo saw for three minutes before anything was said at all.
        route = .waiting
        onlineStatus = .signingIn
        searchTask = Task { await acceptMatch(invite) }
    }

    private func acceptMatch(_ invite: GKInvite) async {
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
            Log.table.info("Invitation accepted — \(match.players.count + 1, privacy: .public) at the table")
            // The sender deals, and naming them beats reading the smallest id at the table:
            // the match arrives before everyone has connected, so two phones can read
            // different tables and pick the same chair.
            await seatOnline(match, as: me, players: match.players.count + 1, hostDeals: !duo,
                             host: GameCenter.id(of: invite.sender))
            if duo {
                isRanked = true
                isRankedDuo = true
                rankedFormat = .teams
            }
        } catch {
            Log.table.error("The invitation could not be accepted: \(String(describing: error), privacy: .public)")
            onlineStatus = nil
            // Off the waiting room it was put on when the invitation was taken: a table that
            // could not be joined is not a table to sit at.
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
        }
        GameCenter.listenForInvites { [weak self] invite in self?.accept(invite) }
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
        if session.isHost {
            await hostOnline(session, stake: stake)
        } else {
            await guestOnline(session)
        }
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
        await coordinator.start()
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
        for attempt in 0..<Self.joinAttempts where lobby == nil {
            do {
                try await client.join()
            } catch {
                Log.table.error("Join \(attempt + 1) could not be sent: \(String(describing: error), privacy: .public)")
            }
            try? await Task.sleep(for: .milliseconds(700))
        }
        // Said out loud rather than left as a waiting room that never fills.
        guard lobby == nil else { return }
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

    /// Sits down at a room, host or guest, as `seatOnline` does for a Game Center match. A room
    /// never deals itself when it fills: the empty chairs are the host's to fill with bots first.
    private func seatRoom(_ session: RelaySession) async {
        onlineStatus = .seating
        relay = session
        hostDeals = true
        onlineSize = nil
        watchForProblems(session.problems)
        watchForReconnects(session)
        if session.isHost {
            isHost = true
            let coordinator = HostCoordinator(transport: session, strength: botLevel.strength)
            backend = .host(coordinator)
            route = .waiting
            consume(await coordinator.updates)
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
            for _ in 0..<8 where lobby == nil {
                try? await client.join()
                try? await Task.sleep(for: .milliseconds(700))
            }
        }
        onlineStatus = nil
    }

    /// A socket that dropped and came back. The host has nothing to do, since the game is on
    /// this phone. A guest asks to be caught up on the seat it still holds.
    private func watchForReconnects(_ session: RelaySession) {
        reconnectPump?.cancel()
        reconnectPump = Task { [weak self] in
            for await _ in session.reconnects {
                guard let self, !Task.isCancelled else { return }
                Log.table.info("Back at the table; asking to be caught up")
                if case .guest(let client) = self.backend { try? await client.join() }
            }
        }
    }

    /// What to put in front of a player when a table could not be opened or joined.
    private static func explain(_ error: Error) -> String {
        (error as? RelayError)?.explanation ?? "Could not reach the table. Check your connection."
    }

    // MARK: Ranked

    /// How long a ranked search runs in total, your own league first and then anyone, before
    /// the house sits down instead. Short on purpose: the wait is the worst part of ranked,
    /// and the house in the chair is a game rather than an apology.
    static let rankedSearchTime: TimeInterval = 8

    /// A ranked table played alone: one real opponent, searched for in your own league first
    /// and anywhere after that. `rankedSolo` says whether that is the whole table or whether
    /// the house sits behind each of you. Nobody found at all seats the house rather than
    /// turning the player away.
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
        searchTask = Task {
            do {
                let me = try await GameCenter.signIn { controller in Self.present(controller) }
                guard !Task.isCancelled else { return }
                onlineStatus = .searching
                rankedSearch = RankedSearch(startedAt: .now, length: Self.rankedSearchTime)
                let found = await findRankedMatch(format)
                rankedSearch = nil
                guard !Task.isCancelled else { return }
                guard let found else { seatRankedStranger(); return }
                let ranked = isRanked, id = rankedID
                await seatOnline(found, as: me, players: 2)
                isRanked = ranked
                rankedID = id
                rankedFormat = format
            } catch GameCenterError.notSignedIn {
                onlineStatus = nil
                notice = .rejected("Sign in to Game Center to play ranked")
            } catch {
                onlineStatus = nil
                notice = .rejected("Could not find a ranked game")
            }
        }
    }

    /// Your own league for the first third of the search time, then anybody.
    ///
    /// A budget per stage rather than one shared: sharing meant the first stage always spent
    /// the lot, so two people searching in different leagues never met and both got the house.
    ///
    /// The format names the pool, so a phone looking for a heads-up game never lands at a
    /// table of four it did not ask for. The four's pools keep the names they always had.
    private func findRankedMatch(_ format: RankedSolo) async -> GKMatch? {
        let league = rank?.standing.league ?? 0
        let stages: [(pool: String, seconds: TimeInterval)] = [
            ("\u{1}\(format.pool)/league-\(league)", Self.rankedSearchTime / 3),
            ("\u{1}\(format.pool)/any", Self.rankedSearchTime * 2 / 3),
        ]
        var found: GKMatch?
        for (index, stage) in stages.enumerated() where found == nil {
            rankedSearch?.isWidened = index > 0
            found = try? await GameCenter.findMatch(players: 2, pool: stage.pool, within: stage.seconds)
            guard !Task.isCancelled else { found.map(GameCenter.leave); return nil }
        }
        return found
    }

    #if DEBUG
    /// Says the phrase on this phone's behalf, so the pages that carry the house tie rule can
    /// be checked without typing it into the settings first.
    func pretendTieRules() { pretendsTieRules = true }

    /// Puts a ranked search on screen, part-way through and staying there, so the line that
    /// runs out can be judged without a Game Center account. Nothing is actually searched for.
    func pretendSearching() {
        isRanked = true
        onlineStatus = .searching
        // Long enough to sit still for a screenshot, and started far enough back that the line
        // is drawn part-run rather than full.
        rankedSearch = RankedSearch(startedAt: .now.addingTimeInterval(-24), length: 120, isWidened: true)
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

    /// Ranked found nobody inside `rankedSearchTime`, so a house stranger takes the chair and
    /// the game is played out as a ranked game.
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
        let strangers = Presence.strangers(format.seatCount - 1)
        playOnThisDevice(seats: [.person(name: playerName)] + strangers.map { .bot(name: $0) },
                         teams: format.teams, targetScore: targetScore, strength: houseStrength)
        isRanked = true
        rankedID = id
        rankedFormat = format
        onlineStatus = nil
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
    /// A duo is two friends on one side, and the side that beats them is the house's, which no
    /// phone can report; so a duo stays a house game, as it was. So does a table you were left
    /// alone at.
    enum LadderTable { case people, house }

    var ladderTable: LadderTable? {
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
        switch kind {
        case .house:
            let won = winningSide == view.mySide
            settleOnLadder(gameID: gameID) { try await Ladder.postHouseGame(gameID: gameID, won: won) }
        case .people:
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
            rankChange = answer.lastGameID == gameID.uuidString ? answer.lastChange : nil
        }
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
    /// rosette when every other ranked chair has one would give that away. It gets a division
    /// or two either side of where this phone stands, derived from the seat's own id so the
    /// chair keeps the same league all game and two house seats at a duo table are not twins.
    ///
    /// Nothing here is sent anywhere, and `reportRanked` refuses to post a table with a bot at
    /// it, so no rating ever moves against one of these.
    private func houseRank(of player: Player) -> Ladder.RankAnswer {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in player.id.rawValue.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        let divisions = Ranking.top / Ranking.pointsPerDivision
        let mine = (rank?.rating ?? 0) / Ranking.pointsPerDivision
        let drift = Int(hash % 5) - 2
        let rating = min(max(mine + drift, 0), divisions) * Ranking.pointsPerDivision
            + Int((hash >> 8) % UInt64(Ranking.pointsPerDivision))
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
    @MainActor
    private static func present(_ controller: UIViewController) {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        guard let root = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        top.present(controller, animated: true)
    }

    // MARK: On this phone

    /// One phone, with every seat either a person taking it in turn or a bot playing itself.
    /// `strength` overrides how hard the bots think, for a table that is not the player's to
    /// set: the coached first game and a ranked table both pass one.
    func playOnThisDevice(seats: [LocalSeat], teams: Bool, turnClock: TurnClock = .default, targetScore: Int = 11,
                          primiera: PrimieraRule = .default, ties: TieRule = .default, strength: BotStrength? = nil) {
        reset()
        isHost = true
        let (players, bots) = LocalSeat.table(seats)
        botSeats = bots
        deviceSeat = seats.firstIndex { !$0.isBot } ?? 0
        let config: GameConfiguration
        do {
            config = try GameConfiguration(players: players, teams: teams, targetScore: targetScore,
                                           turnClock: turnClock, primiera: primiera, ties: ties)
        } catch {
            notice = .rejected(message(for: error))
            return
        }
        let table = HotSeatTable(configuration: config, bots: bots, strength: strength ?? botLevel.strength)
        backend = .hotSeat(table)
        route = .table
        Task {
            consume(await table.updates)
            await table.deal()
        }
    }

    /// The lobby's first door: you, and as many bots as `quickTable` is set for. Deals without
    /// asking anything, because the size is changed from the tile itself.
    func playQuickGame() {
        let table = quickTable
        playOnThisDevice(seats: [.person(name: playerName)] + table.botNames.map { .bot(name: $0) },
                         teams: table.teams)
    }

    // MARK: The first game

    /// The hand that follows the walkthrough: the coach on, the easy bot across the table, no
    /// clock, nothing riding on it. The coach stays on after this game, and the settings turn
    /// it off in one tap.
    func playCoached() {
        assist = .coached
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

    /// A ranked duo is a table of four: the pair, and the house in the other two chairs.
    /// Ranked played alone is whatever `RankedSolo` says instead. Either way the search looks
    /// for one other phone — waiting for three more people would be a long wait for a game
    /// that is meant to start — and only the real chairs are rated; see `ladderTable`.
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
            await seatOnline(match.match, as: match.me, players: match.match.players.count + 1)
        }
    }

    /// Looks for a table at the same stake for `wagerSearchTime`. Nil when nobody came.
    private func findWagerMatch(_ stake: Stake) async -> GKMatchBox? {
        do {
            let me = try await GameCenter.signIn { controller in Self.present(controller) }
            guard !Task.isCancelled else { return nil }
            onlineStatus = .searching
            // Giving up on the search makes it throw `cancelled`.
            let deadline = Task {
                try? await Task.sleep(for: Self.wagerSearchTime)
                GameCenter.cancelSearch()
            }
            defer { deadline.cancel() }
            // Only tables of the same stake meet. The control character keeps one feature's
            // pool names clear of another's.
            let found = try await GameCenter.findMatch(players: 2...Self.wagerSeats, pool: "\u{1}wager/\(stake.rawValue)")
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
    func playAutomatically() {
        Task {
            switch backend {
            case .host(let coordinator): await coordinator.playAutomatically()
            case .hotSeat(let table): await table.playAutomatically()
            case .guest(let client): try? await client.playAutomatically()
            case .none: break
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

    func leaveTable() {
        // Walking out of a ranked game is a loss, against the house as much as against people:
        // the chair you left is the chair you lost. Saying so lets the other phone's report
        // settle at once instead of standing alone for ten minutes.
        //
        // The seat named is any one on the other side, which is a side rather than a person —
        // a duo's two partners both lose a game one of them walked out of.
        if isRanked, let view, !view.isFinished, ladderTable != nil,
           let other = view.opponents.first(where: { view.configuration.side(ofSeat: $0.seat) != view.mySide }) {
            reportRanked(winnerSeat: other.seat)
        }
        // A game on this phone with nothing staked on it is kept, so an X tapped by mistake is
        // waiting in the lobby afterwards. A wager is not: the dialog said the stake stays behind.
        if case .hotSeat(let table) = backend, dailyDay == nil {
            if stake == nil, view?.isFinished == false {
                saveTask?.cancel()
                let bots = botSeats, seat = deviceSeat, id = wagerID, tally = tally
                Task { [weak self] in
                    let snapshot = await table.snapshot
                    self?.keep(snapshot, bots: bots, deviceSeat: seat, stake: nil, wagerID: id, tally: tally)
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
        let table = HotSeatTable(snapshot: saved.snapshot, bots: saved.bots,
                                 strength: saved.stake == nil ? botLevel.strength : Self.contestLevel.strength)
        backend = .hotSeat(table)
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
        guard case .hotSeat(let table) = backend, dailyDay == nil else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, let self else { return }
            let snapshot = await table.snapshot
            guard !Task.isCancelled, case .hotSeat(let current) = backend, current === table else { return }
            keep(snapshot, bots: botSeats, deviceSeat: deviceSeat, stake: stake, wagerID: wagerID, tally: tally)
        }
    }

    private func keep(_ snapshot: HotSeatTable.Snapshot, bots: Set<Int>, deviceSeat: Int,
                      stake: Stake?, wagerID: UUID, tally: RewardTally?) {
        // Nothing to come back to once it is over.
        guard !snapshot.state.isFinished, snapshot.state.round != nil else { return forgetSavedGame() }
        let saved = SavedGame(snapshot: snapshot, bots: bots, deviceSeat: deviceSeat,
                              stake: stake, wagerID: wagerID, tally: tally, savedAt: .now)
        savedGame = saved
        SavedGameFile.save(saved)
    }

    func clearNotice() { notice = nil }

    // MARK: Plumbing

    private func consume(_ updates: AsyncStream<TableUpdate>) {
        pump?.cancel()
        pump = Task { [weak self] in
            for await update in updates {
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
        case .reacted(let player, let reaction):
            show(reaction, from: lobby?.players.first { $0.id == player }?.name ?? "Someone")
        case .joinRefused:
            notice = .joinRefused
            route = .lobby
        case .record(let record):
            Log.table.info("Record arrived: \(record.rounds.count) rounds")
            self.record = record
            readBack(record)
        }
    }

    private func applyLobby(_ lobby: Lobby) {
        Log.table.info("Lobby: \(lobby.players.map(\.name).joined(separator: ", "), privacy: .public) at \(lobby.host.name, privacy: .public)'s table")
        self.lobby = lobby
        // Every phone at a ranked table reports the game the host named, so the Worker sees
        // one game with four reports rather than four games with one.
        if isRanked, !isHost, let id = lobby.gameID.flatMap(UUID.init(uuidString:)) { rankedID = id }
        // An online table has nothing to set: the moment everyone is seated, the host deals.
        guard isHost, !hostDeals, let onlineSize, lobby.players.count >= onlineSize,
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
            startGame()
        }
    }

    private func applyView(_ view: PlayerView) {
        // A fresh hand after a finished game is the host dealing again, so the last game's
        // tally, record and review go with it.
        if let tally, tally.isSettled, !view.isFinished { beginAnotherGame() }
        self.view = view
        startTallyIfNeeded(for: view)
        if route != .table { route = .table }
        if view.isFinished { Log.table.info("Game finished") }
        saveSoon()
    }

    private func applyEvents(_ events: [GameEvent]) {
        tally?.observe(events)
        saveSoon()
        let digest = EventDigest(events)
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

    private func applyDeparture(of id: PlayerID) {
        departed.insert(id)
        notice = .playerLeft(lobby?.players.first { $0.id == id }?.name ?? "A player")
        if !isHost, id == lobby?.host.id { leaveTable() }
    }

    /// Judges every move off the main thread, since a long four-handed game is a few thousand
    /// evaluations, and shows the review when it is ready.
    private func readBack(_ record: GameRecord) {
        reviewTask?.cancel()
        reviewTask = Task {
            let review = await Task.detached(priority: .userInitiated) { Reviewer.review(record) }.value
            guard !Task.isCancelled else {
                Log.table.info("Review dropped: cancelled")
                return
            }
            Log.table.info("Review ready: \(review.moves.count) moves")
            self.review = review
            if let dailyDay, dailyResult != nil {
                let accuracy = review.summary(forSeat: 0).accuracy
                dailyBook.note(accuracy: accuracy, for: dailyDay)
                dailyResult?.accuracy = accuracy
                // Sent once the accuracy is known, so the ladder gets the whole result.
                if let result = dailyResult { postToLadder(result) }
            }
        }
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
    }

    private var isHotSeat: Bool {
        if case .hotSeat = backend { true } else { false }
    }

    private var mode: TableMode? {
        guard let seats = view?.configuration.seatCount else { return nil }
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
        lastPlay = nil
        lastRoundScore = nil
        leftovers = nil
        reactions = []
        departed = []
        tally = nil
        record = nil
        review = nil
        reviewTask?.cancel(); reviewTask = nil
        dailyDay = nil
        dailyResult = nil
        stake = nil
        rankedSearch = nil
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
