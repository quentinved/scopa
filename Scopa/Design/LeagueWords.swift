import SwiftUI
import ScopaCore

/// How a standing is said. Below Gran Maestro it is a league and a division's numeral; past
/// it the league alone, with its points and its place, because there are no divisions left to
/// number. The rating itself is never said anywhere. Gran Maestro's points are the one number
/// shown, since they are the whole point of the tier.
extension Standing {
    /// "Silver II", or "Gran Maestro", in the interface's language. Twin of the ladder's own
    /// title in `Language.swift`, for a standing worked out on the phone.
    func leagueTitle(locale: Locale) -> String {
        guard league.hasDivisions else { return league.title(locale: locale) }
        return "\(league.title(locale: locale)) \(["I", "II", "III"][safe: division - 1] ?? "")"
    }

    /// What a chip beside a medal has room for: the division's numeral, or Gran Maestro's
    /// points. None at nought, where the medal says it alone.
    func chipLabel(locale: Locale) -> String {
        guard let points else { return ["I", "II", "III"][safe: division - 1] ?? "" }
        return points > 0 ? points.formatted(.number.locale(locale)) : ""
    }

    /// "Gran Maestro · 340 pts", or the league title where there are divisions.
    func titleWithPoints(locale: Locale) -> String {
        guard let points, points > 0 else { return leagueTitle(locale: locale) }
        return "\(leagueTitle(locale: locale)) · \(GrandWords.points(points, locale: locale))"
    }
}

extension Ladder.RankAnswer.Standing {
    /// The same chip, from a standing the ladder answered.
    func chipLabel(locale: Locale) -> String {
        guard isGrand else { return ["I", "II", "III"][safe: division - 1] ?? "" }
        return progress > 0 ? progress.formatted(.number.locale(locale)) : ""
    }

    var isGrand: Bool { league == League.granMaestro.rawValue }

    /// "Gran Maestro · 340 pts", or the league title where there are divisions.
    func titleWithPoints(locale: Locale) -> String {
        guard isGrand, progress > 0 else { return leagueTitle(locale: locale) }
        return "\(leagueTitle(locale: locale)) · \(GrandWords.points(progress, locale: locale))"
    }
}

/// Gran Maestro's points and place, in words.
enum GrandWords {
    /// "340 pts".
    static func points(_ points: Int, locale: Locale) -> String {
        String(localized: "\(points) pts", locale: locale)
    }

    /// "4th", the way the reader writes a place: "4e" in French, "4º" in Italian.
    static func place(_ place: Int, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .ordinal
        return formatter.string(from: place as NSNumber) ?? "\(place)"
    }

    /// "340 pts · 4th", or the points alone before the season's first game, which has no place.
    static func line(points: Int, place: Int?, locale: Locale) -> String {
        let said = Self.points(points, locale: locale)
        guard let place else { return said }
        return "\(said) · \(Self.place(place, locale: locale))"
    }
}

extension Ladder.RankAnswer {
    /// "340 pts · 4th" for a Gran Maestro, from the Worker's own count where it sent one.
    /// Nil below Gran Maestro.
    func grandLine(locale: Locale) -> String? {
        let standing = Ranking.standing(for: rating)
        guard let points = grand?.points ?? standing.points else { return nil }
        return GrandWords.line(points: points, place: grand?.place, locale: locale)
    }

    /// Whether this answer is a Campione's: top ten of Gran Maestro, with the points for it.
    var isCampione: Bool { grand?.campione ?? false }
}

extension Ranking {
    /// "45 to Gold III": what the next division costs from where a rating stands. Used by
    /// the lobby as well as the summary. In Gran Maestro there is no next division, so it is
    /// the points.
    static func climb(from rating: Int, locale: Locale) -> String {
        if let points = standing(for: rating).points { return GrandWords.points(points, locale: locale) }
        let toGo = pointsPerDivision - standing(for: rating).progress
        let next = standing(for: rating + toGo)
        return String(localized: "\(toGo) to \(next.leagueTitle(locale: locale))", locale: locale)
    }
}

/// "CAMPIONE", between the two halves of a laurel: the title in the house voice, the laurel
/// in gold. Said quietly, beside the place it was won by, never lit.
struct CampioneTag: View {
    var size: CGFloat = 12.5

    var body: some View {
        HStack(spacing: size * 0.3) {
            laurel("laurel.leading")
            Text(verbatim: "Campione")
                .textCase(.uppercase)
                .font(.system(size: size, weight: .bold))
                .tracking(size * 0.11)
                .foregroundStyle(Palette.onTable)
                .lineLimit(1)
                .fixedSize()
            laurel("laurel.trailing")
        }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: "Campione"))
    }

    private func laurel(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: size * 1.15, weight: .semibold))
            .foregroundStyle(Palette.goldSheen)
            .accessibilityHidden(true)
    }
}
