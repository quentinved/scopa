import Foundation
import ScopaRewards

/// What each reminder says, in the game's language. The kinds that can come round on
/// consecutive days have more than one wording, and the day's `variant` turns them over.
enum ReminderCopy {
    struct Words: Equatable {
        let title: String
        let body: String

        /// The same words with one more sentence on the end, when there is one.
        func adding(_ line: String?) -> Words {
            guard let line else { return self }
            return Words(title: title, body: "\(body) \(line)")
        }
    }

    /// Looks words up in the game's language. A notification is drawn outside the app, where
    /// the environment's locale does not reach, and `String(localized:locale:)` only formats
    /// in a locale: it still reads the phone's language. A resource's own locale does both.
    struct Voice {
        let locale: Locale

        func callAsFunction(_ resource: LocalizedStringResource) -> String {
            var resource = resource
            resource.locale = locale
            return String(localized: resource)
        }
    }

    static func words(for nudge: Nudge, variant: Int, locale: Locale) -> Words {
        let say = Voice(locale: locale)
        switch nudge {
        case .weeklyClosing(let left, let tonight): return weekly(left: left, tonight: tonight, say)
        case .seasonClosing(let days, let league, let division):
            return season(days: days, league: league, division: division, say)
        case .streak(let days): return streak(days, variant: variant, say)
        case .daily(let wheel, let deal, let packs):
            return daily(wheel: wheel, deal: deal, variant: variant, say).adding(packsLine(packs, say))
        case .comeback(let days, let hook): return comeback(days: days, hook: hook, say)
        }
    }

    // MARK: Deadlines

    private static func weekly(left: Int, tonight: Bool, _ say: Voice) -> Words {
        let title = tonight ? say("The week closes tonight") : say("The week closes tomorrow night")
        let body = left == 1
            ? say("One task left before the laurel.")
            : say("\(left) tasks still open, and the laurel after them.")
        return Words(title: title, body: body)
    }

    private static func season(days: Int, league: Int, division: Int, _ say: Voice) -> Words {
        let title = days <= 1 ? say("Last day of the season") : say("Two days left in the season")
        let standing = leagueTitle(league, division, say)
        return Words(title: title, body: say("You stand at \(standing). Room for one more climb before it pays out."))
    }

    /// "Silver II", said as `Ladder.RankAnswer.Standing.leagueTitle` says it on screen.
    /// Gran Maestro has no divisions, so no numeral.
    private static func leagueTitle(_ league: Int, _ division: Int, _ say: Voice) -> String {
        let names = [say("Bronze"), say("Silver"), say("Gold"), say("Platinum"), say("Diamond"), say("Maestro"),
                     say("Gran Maestro")]
        let name = names[safe: league] ?? names[0]
        guard league < names.count - 1 else { return name }
        return "\(name) \(["I", "II", "III"][safe: division - 1] ?? "")"
    }

    private static func streak(_ days: Int, variant: Int, _ say: Voice) -> Words {
        if variant.isMultiple(of: 2) {
            return Words(title: say("\(days) days in a row"), body: say("Today's deal keeps the run going."))
        }
        return Words(title: say("A run of \(days) days"),
                     body: say("\(BotNames.dealer) has dealt today's hand, if you'd like to make it \(days + 1)."))
    }

    // MARK: Every day

    private static func daily(wheel: Bool, deal: Bool, variant: Int, _ say: Voice) -> Words {
        if !deal { return wheelOnly(variant, say) }
        if !wheel { return dealOnly(variant, say) }
        let dealer = BotNames.dealer
        switch variant % 3 {
        case 0:
            return Words(title: say("The wheel is ready"),
                         body: say("Today's deal is dealt too. \(dealer) is keeping your seat warm."))
        case 1:
            return Words(title: say("Today's deal is dealt"), body: say("The wheel's free turn is waiting beside it."))
        default:
            return Words(title: say("Your seat is ready"),
                         body: say("A free turn of the wheel and a fresh deal against \(dealer). Nothing to lose but a hand."))
        }
    }

    /// Today's deal is already played, so only the wheel is left.
    private static func wheelOnly(_ variant: Int, _ say: Voice) -> Words {
        if variant.isMultiple(of: 2) {
            return Words(title: say("The wheel is ready"), body: say("Your free turn of the day is waiting in the lobby."))
        }
        return Words(title: say("The wheel is waiting"),
                     body: say("Today's free turn is still yours. The gran premio is on there somewhere."))
    }

    /// The wheel is already turned, so only the deal is left.
    private static func dealOnly(_ variant: Int, _ say: Voice) -> Words {
        if variant.isMultiple(of: 2) {
            return Words(title: say("Today's deal is ready"),
                         body: say("Everyone gets the same cards today. Let's see what you make of yours."))
        }
        return Words(title: say("\(BotNames.dealer) has dealt"),
                     body: say("Today's deal is on the table, the same one for everybody."))
    }

    private static func packsLine(_ packs: Int, _ say: Voice) -> String? {
        switch packs {
        case 0: nil
        case 1: say("A pack is waiting in the album too.")
        default: say("\(packs) packs are waiting in the album too.")
        }
    }

    // MARK: Comebacks

    private static func comeback(days: Int, hook: Nudge.Hook, _ say: Voice) -> Words {
        let title = days >= 7 ? say("\(BotNames.dealer) has kept your seat for a week") : say("Three days without a scopa")
        return Words(title: title, body: hookLine(hook, say))
    }

    private static func hookLine(_ hook: Nudge.Hook, _ say: Voice) -> String {
        switch hook {
        case .packs(1): say("A pack is still sealed in your album, and the wheel has a free turn.")
        case .packs(let count): say("\(count) packs are still sealed in your album, and the wheel has a free turn.")
        case .weekly(1): say("One task left on the week's challenge, and the wheel has a free turn.")
        case .weekly(let left): say("\(left) tasks still open this week, and the wheel has a free turn.")
        case .newWeek: say("A new week of tasks is up, and the wheel has a free turn.")
        case .wheel: say("The wheel has a free turn, and today's deal is dealt.")
        }
    }
}
