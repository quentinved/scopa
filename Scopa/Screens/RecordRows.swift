import SwiftUI
import ScopaRewards

// MARK: - Copy

extension Rivalry {
    /// "You lead Marco 5–3", told from your side, for the last summary.
    func line(locale: Locale) -> String {
        let name = name.shortName()
        let won = record.won, lost = record.lost
        if won > lost { return String(localized: "You lead \(name) \(won)–\(lost)", locale: locale) }
        if lost > won { return String(localized: "\(name) leads you \(lost)–\(won)", locale: locale) }
        return String(localized: "All square with \(name), \(won)–\(lost)", locale: locale)
    }
}

extension LoggedGame.Table {
    var title: LocalizedStringKey {
        switch self {
        case .quick: "Quick game"
        case .campaign: "Campaign"
        case .daily: "Daily deal"
        case .wager: "For denari"
        case .ranked: "Ranked"
        case .rankedHouse: "Ranked · against the house"
        case .nearby: "Nearby"
        case .online: "Game Center"
        case .room: "Table by code"
        case .passThePhone: "Pass the phone"
        }
    }
}

extension LoggedGame.Group {
    var title: LocalizedStringKey {
        switch self {
        case .ranked: "Ranked"
        case .campaign: "Campaign"
        case .people: "With people"
        case .bots: "Against bots"
        }
    }
}

/// "3 October", the way the page dates everything.
private func day(_ date: Date) -> Text {
    Text(date, format: .dateTime.day().month(.wide))
}

// MARK: - Rows

/// A number with its caption under it, in the profile's hand.
struct RecordFigure: View {
    let value: Text
    let caption: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            value
                .font(.display(26))
                .monospacedDigit()
                .foregroundStyle(Palette.onTable)
            Text(caption)
                .textCase(.uppercase)
                .font(.system(size: 12.5, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(Palette.onTableSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// One kind of table, and how it has gone there.
struct RecordGroupRow: View {
    let group: LoggedGame.Group
    let record: WonLost

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(group.title)
                .textCase(.uppercase)
                .font(.system(size: 12.5, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(Palette.onTable)
            Spacer(minLength: 8)
            Text("\(record.won) won · \(record.lost) lost")
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Palette.onTableSoft)
            Text(Double(record.won) / Double(max(record.played, 1)), format: .percent.precision(.fractionLength(0)))
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Palette.onTable)
                .frame(minWidth: 44, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A personal best: what it was, when, and the number itself on the right.
struct KeepsakeRow: View {
    /// Nil draws the broom, which is what a scopa looks like everywhere else in the game.
    let symbol: String?
    let tint: Color
    let title: LocalizedStringKey
    var detail: Text?
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            coin
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.onTable)
                detail?
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.onTableSoft)
            }
            Spacer(minLength: 8)
            Text(verbatim: value)
                .font(.system(size: 17, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Palette.onTable)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var coin: some View {
        if let symbol {
            SymbolCoin(symbol: symbol, tint: tint, size: 32)
        } else {
            Circle()
                .fill(tint.opacity(0.9))
                .frame(width: 32, height: 32)
                .overlay { BroomMark(size: 17, tint: Palette.cream) }
                .overlay { Circle().strokeBorder(Palette.cream.opacity(0.25), lineWidth: 1) }
        }
    }

    /// "Against Laurence, 3 October", or the day alone.
    static func when(_ best: Best) -> Text {
        guard let against = best.against else { return day(best.date) }
        return Text("Against \(against), \(day(best.date))")
    }
}

/// Somebody you keep meeting: the badge they sit behind, how the last one went, and the tally.
struct RivalRow: View {
    let rival: Rivalry
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            SeatBadge(name: rival.name, tint: tint, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: rival.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.onTable)
                    .lineLimit(1)
                detail
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.onTableSoft)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            if rival.record.played > 0 {
                Text(verbatim: "\(rival.record.won)–\(rival.record.lost)")
                    .font(.system(size: 17, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.onTable)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var detail: Text {
        guard let won = rival.lastWon, let faced = rival.lastFaced else {
            return Text("On your side ^[\(rival.partnered) time](inflect: true)")
        }
        let when = Text(faced, format: .relative(presentation: .named))
        return won ? Text("You took the last one, \(when)") : Text("\(rival.name) took the last one, \(when)")
    }
}

/// One of the house's own, and how you stand with it.
struct BotRow: View {
    let name: String
    let record: WonLost
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            BotFace(tint: tint, size: 30)
            Text(verbatim: name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.onTable)
            Spacer(minLength: 8)
            Text(verbatim: "\(record.won)–\(record.lost)")
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Palette.onTable)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }
}

/// A game in the list: who was across, at which table and when, and the score.
struct LoggedGameRow: View {
    let game: LoggedGame

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(game.won ? Palette.gold : Palette.onTableSoft.opacity(0.35))
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: game.opponents.map(\.name).joined(separator: ", "))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.onTable)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(game.table.title)
                    Text(verbatim: "·")
                    Text(game.date, format: .dateTime.day().month(.abbreviated))
                }
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.onTableSoft)
                .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(verbatim: "\(game.mine)–\(game.theirs)")
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(game.won ? Palette.onTable : Palette.onTableSoft)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
        .accessibilityValue(game.won ? Text("Game won") : Text("Game lost"))
    }
}
