import Foundation
import ScopaCore
import ScopaRewards
import SwiftUI

/// A few goals per week, the same ones for everybody, counted across every game played.
///
/// The goals are derived from the week's name through the same hash the daily deck is dealt
/// from, so every phone agrees on it without talking to a server.
enum WeeklyChallenge {
    /// A week's name, "2026-W37", in the player's own calendar rather than UTC, so the week
    /// turns over on the night they call Sunday.
    static func week(for date: Date = .now, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d", parts.yearForWeekOfYear ?? 0, parts.weekOfYear ?? 0)
    }

    /// When a named week starts, for the countdown and for stepping between weeks.
    static func date(of week: String, calendar: Calendar = .current) -> Date? {
        let parts = week.split(separator: "-W")
        guard parts.count == 2, let year = Int(parts[0]), let number = Int(parts[1]) else { return nil }
        var components = DateComponents()
        components.yearForWeekOfYear = year
        components.weekOfYear = number
        components.weekday = calendar.firstWeekday
        return calendar.date(from: components)
    }

    /// When a named week ends and the next one starts.
    static func end(of week: String, calendar: Calendar = .current) -> Date? {
        guard let start = date(of: week, calendar: calendar) else { return nil }
        return calendar.date(byAdding: .weekOfYear, value: 1, to: start)
    }

    // MARK: The goals

    /// What a week can ask for. Each case is counted off the `RewardTally` a finished game
    /// already produces, so nothing extra has to be tracked during play.
    enum Goal: Hashable, Codable {
        /// Games won, however they were won.
        case wins(Int)
        /// Tables swept.
        case scope(Int)
        /// Rounds where the seven of coins was yours.
        case settebelli(Int)
        /// Rounds where every category went one way.
        case cappotti(Int)
        /// Games won against people rather than the machine.
        case onlineWins(Int)
        /// Days whose deal was won. A deal is one a day, so seven is a perfect week.
        case dailyWins(Int)

        var target: Int {
            switch self {
            case .wins(let n), .scope(let n), .settebelli(let n), .cappotti(let n), .onlineWins(let n),
                 .dailyWins(let n): n
            }
        }

        /// What one finished game adds to this goal.
        func credit(for tally: RewardTally, won: Bool) -> Int {
            switch self {
            case .wins: won ? 1 : 0
            case .scope: tally.scope
            case .settebelli: tally.settebelli
            case .cappotti: tally.cappotti
            case .onlineWins:
                if case .multipeer = tally.mode { won ? 1 : 0 } else { 0 }
            case .dailyWins: tally.mode.isDailyDeal && won ? 1 : 0
            }
        }

        var title: LocalizedStringKey {
            switch self {
            case .wins(let n): "Win ^[\(n) game](inflect: true)"
            case .scope(let n): "Sweep the table \(n) times"
            case .settebelli(let n): "Take the settebello \(n) times"
            case .cappotti(let n): "Win ^[\(n) cappotto](inflect: true)"
            case .onlineWins(let n): "Beat ^[\(n) person](inflect: true)"
            case .dailyWins(let n): "Win the day's deal \(n) times"
            }
        }

        /// The line under the title on the card.
        var detail: LocalizedStringKey {
            switch self {
            case .wins: "Any table, any size. Bots count."
            case .scope: "A scopa is the whole table in one card."
            case .settebelli: "The seven of coins, at the end of a round."
            case .cappotti: "Every category in one round. Rare, and meant to be."
            case .onlineWins: "Nearby, online or ranked — anyone who is not the machine."
            case .dailyWins: "One deal a day, so a slow start leaves no room."
            }
        }

        var symbol: String {
            switch self {
            case .wins: "trophy.fill"
            case .scope: "sparkles"
            case .settebelli: "seal.fill"
            case .cappotti: "crown.fill"
            case .onlineWins: "person.2.fill"
            case .dailyWins: "calendar"
            }
        }

        /// What finishing it pays, scaled to how hard the goal is. The laurel and
        /// `WeeklyChallenge.allDoneBonus` come only with the last of the week's tasks.
        var denari: Denari {
            switch self {
            case .wins: 150
            case .scope: 180
            case .settebelli: 180
            case .cappotti: 350
            case .onlineWins: 250
            case .dailyWins: 200
            }
        }
    }

    /// How many tasks a week sets. The laurel is for finishing every one of them.
    static let tasksPerWeek = 3

    /// Paid on top of the last task's own reward, with the laurel.
    static let allDoneBonus: Denari = 300

    /// The pool a week draws from, one entry per kind with the targets it can ask for and how
    /// often it comes up. Each target is about fifteen to twenty games — two or three an evening —
    /// so no one task outweighs the others: the laurel is three of these at once.
    ///
    /// People are the rarest draw, since a week that needs them is out of reach for anyone
    /// who only plays the machine.
    private static let pool: [(choices: [Goal], weight: Int)] = [
        ([.wins(10), .wins(12), .wins(15)], 4),
        ([.scope(30), .scope(40), .scope(50)], 4),
        ([.settebelli(12), .settebelli(15), .settebelli(18)], 4),
        ([.dailyWins(5), .dailyWins(6)], 3),
        ([.cappotti(3), .cappotti(4)], 2),
        ([.onlineWins(5), .onlineWins(6)], 1),
    ]

    /// The tasks a week sets, in the order they are shown. Drawn from the week's name through
    /// the daily deck's hash, so they are stable across app versions and identical on every
    /// phone: weighted, each at one of its kind's targets, and never one kind twice — "win 25
    /// games" and "win 40 games" are one task, not two.
    static func goals(for week: String) -> [Goal] {
        var generator = SeededGenerator(seed: DailyDeal.seed(for: week))
        var left = pool
        var goals: [Goal] = []
        while goals.count < tasksPerWeek, !left.isEmpty {
            var roll = Int(generator.next() % UInt64(left.map(\.weight).reduce(0, +)))
            var index = 0
            while roll >= left[index].weight {
                roll -= left[index].weight
                index += 1
            }
            let choices = left.remove(at: index).choices
            goals.append(choices[Int(generator.next() % UInt64(choices.count))])
        }
        return goals
    }
}
