import SwiftUI
import ScopaCore

/// What a table of the campaign's second road plays besides the cards: one mode for each of
/// its regions, as each region of the first brought a house rule. All four are things the
/// engine deals: a head start, a target of one, every hand face up, and a run of games kept
/// by `CampaignBook`.
enum CampaignMode: String, CaseIterable, Hashable {
    /// The others start a few points up.
    case rimonta
    /// One round decides.
    case unaMano
    /// Every hand face up, so nothing is hidden but the deck.
    case carteScoperte
    /// Three games in a row, each against somebody new. A loss starts it again.
    case torneo

    /// The same words in every language, like a house rule's name.
    var name: String {
        switch self {
        case .rimonta: "Rimonta"
        case .unaMano: "Una mano"
        case .carteScoperte: "Carte scoperte"
        case .torneo: "Torneo"
        }
    }
}

extension CampaignStage {
    /// A target of one: whoever leads once the round is counted has won.
    static let oneRound = 1

    var isOneRound: Bool { target == Self.oneRound }

    /// The modes this table plays, in the order the road brings them in.
    var modes: [CampaignMode] {
        CampaignMode.allCases.filter { mode in
            switch mode {
            case .rimonta: deficit > 0
            case .unaMano: isOneRound
            case .carteScoperte: openHands
            case .torneo: games > 1
            }
        }
    }

    /// What a mode does at this table, in a line, for the stage card.
    func explanation(of mode: CampaignMode, locale: Locale) -> LocalizedStringKey {
        switch mode {
        case .rimonta:
            "You start \(deficit) points behind. Catch up before they reach \(target)."
        case .unaMano:
            "One round, and whoever leads at the end of it wins. Level, and another round is dealt."
        case .carteScoperte:
            "Every hand is dealt face up: you see theirs, they see yours. Only the deck stays hidden."
        case .torneo:
            "\(games) games in a row, against \(rivalNames(locale: locale)). Lose one and the torneo starts again from the first."
        }
    }

    /// "Laurence, Lucas and Arthur", in the reader's own words for "and".
    func rivalNames(locale: Locale) -> String {
        (0..<games).map { rival(at: $0).opponent }.formatted(.list(type: .and).locale(locale))
    }
}

/// One page of the lesson the campaign shows before a table: a house rule or a mode.
enum LessonPage: Hashable {
    case rule(HouseRule)
    case mode(CampaignMode)
}

extension HouseRuleLessons {
    private static let modesKey = "campaign.modes.learned"

    static var learnedModes: Set<CampaignMode> {
        let names = UserDefaults.standard.stringArray(forKey: modesKey) ?? []
        return Set(names.compactMap(CampaignMode.init(rawValue:)))
    }

    /// The pages `stage` still has to show this phone: its rules not yet taught, then its
    /// modes not yet taught.
    static func unlearned(at stage: CampaignStage) -> [LessonPage] {
        let known = learnedModes
        return unlearned(in: stage.house).map(LessonPage.rule)
            + stage.modes.filter { !known.contains($0) }.map(LessonPage.mode)
    }

    static func learn(_ pages: [LessonPage]) {
        learn(pages.compactMap { if case .rule(let rule) = $0 { rule } else { nil } })
        let modes = pages.compactMap { if case .mode(let mode) = $0 { mode } else { nil } }
        let all = learnedModes.union(modes)
        UserDefaults.standard.set(all.map(\.rawValue).sorted(), forKey: modesKey)
    }
}
