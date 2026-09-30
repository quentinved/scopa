import SwiftUI
import UIKit
import os
import ScopaCore

/// What only ranked gives: every league reached puts its medal on your seat and, from
/// Silver up, strikes the app icon in its metal.
///
/// Kept for good. A league is a floor the seasons never take back, so what it unlocked
/// stays unlocked. The mark is kept on the phone, like the achievement counters, so the
/// prizes do not vanish while Game Center is still waking up.
enum LadderPrizes {
    private static let bestKey = "ladder.bestLeague"
    private static let celebratedKey = "ladder.celebratedLeague"

    /// The highest league this phone has seen its player reach. Nil before a ranked game.
    static var best: League? { league(forKey: bestKey) }

    /// The highest league whose ceremony has been shown.
    static var celebrated: League? { league(forKey: celebratedKey) }

    /// A league reached and not yet celebrated.
    static var owed: League? {
        guard let best, celebrated.map({ $0 < best }) ?? true else { return nil }
        return best
    }

    static func isEarned(_ league: League) -> Bool { best.map { $0 >= league } ?? false }

    /// Raises the mark to the league a ladder answer shows. Never lowers it, and ignores an
    /// answer for somebody who has not played, which reads as Bronze without being it.
    static func remember(_ rank: Ladder.RankAnswer?) {
        guard let rank, rank.games > 0 || rank.rating > 0,
              let league = League(rawValue: rank.standing.league),
              best.map({ $0 < league }) ?? true else { return }
        UserDefaults.standard.set(league.rawValue, forKey: bestKey)
    }

    static func markCelebrated(_ league: League) {
        guard celebrated.map({ $0 < league }) ?? true else { return }
        UserDefaults.standard.set(league.rawValue, forKey: celebratedKey)
    }

    private static func league(forKey key: String) -> League? {
        guard UserDefaults.standard.object(forKey: key) != nil else { return nil }
        return League(rawValue: UserDefaults.standard.integer(forKey: key))
    }
}

extension League {
    /// "Silver", in the interface's language.
    func title(locale: Locale) -> String {
        switch self {
        case .bronze: String(localized: "Bronze", locale: locale)
        case .silver: String(localized: "Silver", locale: locale)
        case .gold: String(localized: "Gold", locale: locale)
        case .platinum: String(localized: "Platinum", locale: locale)
        case .diamond: String(localized: "Diamond", locale: locale)
        case .maestro: String(localized: "Maestro", locale: locale)
        }
    }

    /// The seat mark this league gives.
    var medal: SeatMark {
        switch self {
        case .bronze: .medalBronze
        case .silver: .medalSilver
        case .gold: .medalGold
        case .platinum: .medalPlatinum
        case .diamond: .medalDiamond
        case .maestro: .medalMaestro
        }
    }

    /// The icon struck in this league's metal. Bronze gives the medal alone.
    var icon: LadderIcon? { LadderIcon.allCases.first { $0.league == self } }

    /// The league above this one. Nil at the top.
    var next: League? { League(rawValue: rawValue + 1) }
}

/// The app icons the ladder gives, one per league from Silver up.
enum LadderIcon: String, CaseIterable, Identifiable {
    case silver, gold, platinum, diamond, maestro

    var id: String { rawValue }

    var league: League {
        switch self {
        case .silver: .silver
        case .gold: .gold
        case .platinum: .platinum
        case .diamond: .diamond
        case .maestro: .maestro
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .silver: "Silver icon"
        case .gold: "Gold icon"
        case .platinum: "Platinum icon"
        case .diamond: "Diamond icon"
        case .maestro: "Maestro icon"
        }
    }

    /// The icon set's name in the asset catalogue, and in the build setting that ships it.
    var assetName: String { "AppIcon-" + rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    var finish: IconArtwork.Finish {
        switch self {
        case .silver: .silver
        case .gold: .gold
        case .platinum: .platinum
        case .diamond: .diamond
        case .maestro: .maestro
        }
    }

    /// False on a Mac running the iPad app, which keeps the one icon.
    static var isSupported: Bool { UIApplication.shared.supportsAlternateIcons }

    /// The icon on the home screen now. Nil for the classic one.
    static var current: LadderIcon? {
        guard let name = UIApplication.shared.alternateIconName else { return nil }
        return allCases.first { $0.assetName == name }
    }

    /// Puts an icon on the home screen, or the classic one back for nil. iOS says so itself
    /// with an alert of its own.
    static func use(_ icon: LadderIcon?) async {
        guard isSupported, current != icon else { return }
        do {
            try await UIApplication.shared.setAlternateIconName(icon?.assetName)
        } catch {
            Log.table.error("Could not change the icon: \(error.localizedDescription)")
        }
    }
}

/// The icon as the home screen shows it, at any size.
struct LadderIconArt: View {
    let icon: LadderIcon?
    var size: CGFloat = 44

    var body: some View {
        IconArtwork(size: size, finish: icon?.finish ?? .classic)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
            .drawingGroup()
    }
}
