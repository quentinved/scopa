import SwiftUI
import ScopaCore

/// A practice table for one house rule, opened from the campaign: a hand laid out so the
/// rule does everything it does in front of you, the coach saying what is happening at
/// every move, and nothing kept afterwards. `deal` is nil on a free game played after it.
struct RulePractice: Equatable {
    let rule: HouseRule
    let deal: PracticeDeal?

    /// How long the bots wait for the coach's line to be read before moving anyway.
    static let hold: Duration = .seconds(600)

    /// The scripted move the hand is waiting on. Nil on a free game, once the script has
    /// run out, and between rounds.
    func beat(in view: PlayerView) -> Int? {
        guard let deal, view.roundNumber == 1, view.phase == .playing else { return nil }
        let index = deal.played(in: view)
        return deal.moves.indices.contains(index) ? index : nil
    }

    /// The move the learner is to make now, when it is theirs.
    func expected(in view: PlayerView) -> Move? {
        guard let index = beat(in: view), let move = deal?.moves[index], move.seat == view.seat else { return nil }
        return move
    }

    /// Whether this phase ends the table with the practice's own summary. A laid-out hand
    /// is one round; a free game shows the ordinary summary between rounds.
    func summarises(_ phase: Phase) -> Bool {
        switch phase {
        case .finished: true
        case .roundOver: deal != nil
        case .awaitingDeal, .playing: false
        }
    }

    /// The star on the card to play: the scripted one, or the coach's pick once the script is done.
    func marks(in view: PlayerView) -> [Card: Coach.Standing] {
        guard view.isMyTurn, view.phase == .playing else { return [:] }
        if let move = expected(in: view) { return [move.card: .best] }
        guard beat(in: view) == nil else { return [:] }
        let best = Coach.hand(view).filter { $0.standing == .best }.map(\.card)
        return Dictionary(uniqueKeysWithValues: best.map { ($0, .best) })
    }

    /// The chairs: Hugo across the table, or beside you as your partner at scopone.
    static func seats(for rule: HouseRule, you: String) -> [LocalSeat] {
        let others = rule == .scopone ? [BotNames.table[0], BotNames.dealer, BotNames.table[1]] : [BotNames.dealer]
        return [.person(name: you)] + others.map { .bot(name: $0) }
    }
}

extension HouseRule {
    /// The rule's name, which is the same word in every language.
    var name: String {
        switch self {
        case .scopone: "Scopone"
        case .reBello: "Re bello"
        case .napola: "Napola"
        case .assoPigliaTutto: "Asso piglia tutto"
        }
    }
}

// MARK: - At the table

extension TableStore {
    /// Sits down at the practice table for `rule`: the laid-out hand, or with `free` an
    /// ordinary game of it, against the easy bot with no clock and to the campaign's own
    /// six points. Nothing it plays is kept, and leaving goes back to the campaign's map.
    func playPractice(_ rule: HouseRule, free: Bool = false) {
        let deal = rule.practice
        HouseRuleLessons.learn([rule])
        playOnThisDevice(seats: RulePractice.seats(for: rule, you: playerName), teams: deal.teams,
                         turnClock: .off, targetScore: free ? 6 : 1, house: [rule],
                         strength: BotLevel.easy.strength,
                         deal: free ? nil : { table in
                             // The bots lead, and wait for the coach's opening line to be read.
                             await table.holdBots(for: RulePractice.hold)
                             await table.deal(stacked: deal.deck, botMoves: deal.botMoves)
                         })
        if route == .table { practice = RulePractice(rule: rule, deal: free ? nil : deal) }
    }

    /// What to say when a practice hand is sent a move other than the one it teaches. Nil
    /// for that move, and at every other table.
    func practiceNudge(_ card: Card, capturing captures: [Card]) -> String? {
        guard let practice, let view, let move = practice.expected(in: view) else { return nil }
        if card == move.card, Set(captures) == Set(move.captures) { return nil }
        return "Play the card with the star"
    }

    /// How much the table helps: a practice table outlines the take whatever the settings say.
    var tableAssist: AssistLevel { practice == nil ? assist : .beginner }
}
