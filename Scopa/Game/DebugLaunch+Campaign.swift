import Foundation
import ScopaCore

/// The campaign's launch flags.
///
/// `-campaign` opens the map. `-campaignStage 9` plants the road as won up to stage nine,
/// in memory only. `-campaignOld 21` plants it as a build from before Piemonte left it, won
/// up to its stage 21, to check a region put in behind a player. `-campaignReturn 6` plays the walk back from a three-star win at stage
/// six — a finale, so the region's prize card follows; `-campaignReturn 6 1` from a
/// one-star win, `-campaignReturn 6 0` from a loss. `-campaignCard 7` opens stage seven's
/// card. `-campaignPlay 4` sits straight down at stage four; with `-autoPlay` it walks back
/// to the map by itself once the game is over.
///
/// `-campaignFaces` opens the map with sample players at its tables. `-campaignBoard` does
/// that and opens the board's sheet; `-campaignBoard friends` opens it on the friends' tab.
///
/// The second road. `-campaignStage 37` plants the first road won with exactly the 72 stars
/// Toscana wants; `-campaignStars 64` with it brings the stars down to 64, so the map stops at
/// Toscana's banner saying so. `-campaignTorneo 1` plants every torneo one game in, memory
/// only, so `-campaignCard 56` shows Como's second game. Each mode at the table: `-campaignPlay
/// 37` a rimonta, `43` una mano, `49` carte scoperte, `56` a torneo's first game (`-campaignTorneo
/// 2` first for its last). `-houseLesson rimonta,torneo` opens the modes' lesson pages, and
/// takes house rules and modes mixed.
extension DebugLaunch {
    static var showsCampaign: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-campaign")
        #else
        false
        #endif
    }

    static var campaignStage: Int? { number(after: "-campaignStage") }
    static var campaignOld: Int? { number(after: "-campaignOld") }
    static var campaignReturn: Int? { number(after: "-campaignReturn") }
    /// `-campaignReturn 1 2`: the stars that win earned, three when left out; 0 plays a loss.
    static var campaignReturnStars: Int {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-campaignReturn") else { return 3 }
        return Int(arguments[safe: index + 2] ?? "").map { min(max($0, 0), 3) } ?? 3
        #else
        3
        #endif
    }
    static var campaignPlay: Int? { number(after: "-campaignPlay") }
    static var campaignStars: Int? { number(after: "-campaignStars") }
    static var campaignTorneo: Int? { number(after: "-campaignTorneo") }
    /// `-houseLesson napola,rimonta` opens the lesson over the campaign map, a page for each
    /// house rule or mode named.
    static var lessonPages: [LessonPage] {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-houseLesson") else { return [] }
        return (arguments[safe: index + 1] ?? "").split(separator: ",").compactMap { name in
            HouseRule(rawValue: String(name)).map(LessonPage.rule)
                ?? CampaignMode(rawValue: String(name)).map(LessonPage.mode)
        }
        #else
        []
        #endif
    }
    /// `-campaignCard 7` opens the map with stage seven's card up.
    static var campaignCard: Int? { number(after: "-campaignCard") }
    /// `-ruleTutorial napola` sits straight down at a house rule's practice table: napola,
    /// assoPigliaTutto, reBello or scopone.
    static var ruleTutorial: HouseRule? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-ruleTutorial").flatMap { HouseRule(rawValue: arguments[safe: $0 + 1] ?? "") }
        #else
        nil
        #endif
    }

    static var showsCampaignBoard: Bool { has("-campaignBoard") }
    /// Sample faces on the map and a sample board, never the Worker's.
    static var showsCampaignFaces: Bool { showsCampaignBoard || has("-campaignFaces") }
    static var campaignBoardOnFriends: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-campaignBoard").flatMap { arguments[safe: $0 + 1] } == "friends"
        #else
        false
        #endif
    }

    private static func has(_ flag: String) -> Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(flag)
        #else
        false
        #endif
    }

    private static func number(after flag: String) -> Int? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: flag).flatMap { Int(arguments[safe: $0 + 1] ?? "") }
        #else
        nil
        #endif
    }

    static func applyCampaign(to store: TableStore) {
        #if DEBUG
        let book = store.campaignBook
        if let number = campaignStage { book.pretend(reached: number) }
        if let total = campaignStars { book.pretend(stars: total) }
        if let won = campaignTorneo { book.pretendRun(won: won) }
        if let number = campaignOld { book.pretendBeforePiemonte(reached: number) }
        if let number = campaignReturn { book.pretendReturn(from: number, stars: campaignReturnStars) }
        if showsCampaign || showsCampaignFaces { book.showsMap = true }
        if let number = campaignPlay, let stage = Campaign.stage(number: number) { store.playCampaign(stage) }
        if let rule = ruleTutorial { store.playPractice(rule) }
        #endif
    }
}
