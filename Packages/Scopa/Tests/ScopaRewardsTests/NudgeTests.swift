import Foundation
import Testing
@testable import ScopaRewards

private let paris: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    calendar.firstWeekday = 2
    return calendar
}()

private func at(_ day: Int, _ hour: Int, month: Int = 10) -> Date {
    paris.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
}

/// Monday 12 October 2026, nine in the morning: the week ends at midnight on Sunday.
private let monday = at(12, 9)
private let weekEnds = at(19, 0)

private func plan(_ change: (inout NudgeFacts) -> Void = { _ in }, now: Date = monday) -> [NudgePlanner.Planned] {
    var facts = NudgeFacts()
    facts.weekEnds = weekEnds
    change(&facts)
    return NudgePlanner.plan(facts, now: now, calendar: paris)
}

private func nudge(on day: Int, in planned: [NudgePlanner.Planned]) -> Nudge? {
    planned.first { paris.component(.day, from: $0.fire) == day }?.nudge
}

@Suite struct Nudges {
    @Test func aQuietWeekKnocksOnceADayAndComesBackTwice() {
        let planned = plan()
        #expect(planned.count == 8)
        #expect(planned.allSatisfy { paris.component(.hour, from: $0.fire) == 18 })
        #expect(nudge(on: 12, in: planned) == .daily(wheel: true, deal: true, packs: 0))
        #expect(nudge(on: 15, in: planned) == .comeback(days: 3, hook: .wheel))
        #expect(nudge(on: 19, in: planned) == .comeback(days: 7, hook: .newWeek))
    }

    @Test func todayIsLeftAloneOnceTheWheelAndTheDealAreDone() {
        let done = plan { $0.wheelSpentToday = true; $0.dealPlayedToday = true }
        #expect(nudge(on: 12, in: done) == nil)
        let halfDone = plan { $0.wheelSpentToday = true }
        #expect(nudge(on: 12, in: halfDone) == .daily(wheel: false, deal: true, packs: 0))
    }

    @Test func anHourAlreadyGoneIsSkipped() {
        #expect(nudge(on: 12, in: plan(now: at(12, 19))) == nil)
        #expect(nudge(on: 13, in: plan(now: at(12, 19))) != nil)
    }

    @Test func theHourFollowsTheLastDealWithinTheDay() {
        #expect(NudgePlanner.usualHour(nil, calendar: paris) == 18)
        #expect(NudgePlanner.usualHour(at(11, 23), calendar: paris) == 21)
        #expect(NudgePlanner.usualHour(at(11, 7), calendar: paris) == 10)
        #expect(NudgePlanner.usualHour(at(11, 13), calendar: paris) == 13)
    }

    @Test func theWeekClosingWinsItsLastTwoDays() {
        let planned = plan { $0.weeklyStarted = true; $0.weeklyLeft = 2 }
        #expect(nudge(on: 16, in: planned) == .daily(wheel: true, deal: true, packs: 0))
        #expect(nudge(on: 17, in: planned) == .weeklyClosing(left: 2, tonight: false))
        #expect(nudge(on: 18, in: planned) == .weeklyClosing(left: 2, tonight: true))
    }

    @Test func aWeekNotStartedOrFinishedIsNoDeadline() {
        let untouched = plan { $0.weeklyLeft = 3 }
        #expect(nudge(on: 18, in: untouched) == .daily(wheel: true, deal: true, packs: 0))
        let finished = plan { $0.weeklyStarted = true; $0.weeklyLeft = 0 }
        #expect(nudge(on: 18, in: finished) == .daily(wheel: true, deal: true, packs: 0))
    }

    @Test func aRunIsToldOnTheDayItWouldBreak() {
        let unplayed = plan { $0.streak = 4 }
        #expect(nudge(on: 12, in: unplayed) == .streak(days: 4))
        #expect(nudge(on: 13, in: unplayed) == .daily(wheel: true, deal: true, packs: 0))
        let played = plan { $0.streak = 5; $0.dealPlayedToday = true }
        #expect(nudge(on: 12, in: played) == .daily(wheel: true, deal: false, packs: 0))
        #expect(nudge(on: 13, in: played) == .streak(days: 5))
        #expect(nudge(on: 13, in: plan { $0.streak = 1; $0.dealPlayedToday = true }) == .daily(wheel: true, deal: true, packs: 0))
    }

    @Test func theSeasonCountsWholeDaysToItsEnd() {
        let ends = ISO8601DateFormatter().date(from: "2026-11-01T00:00:00Z")!
        let planned = plan({ $0.seasonEnds = ends; $0.league = 1; $0.division = 2 }, now: at(29, 9))
        #expect(nudge(on: 29, in: planned) == .daily(wheel: true, deal: true, packs: 0))
        #expect(nudge(on: 30, in: planned) == .seasonClosing(days: 2, league: 1, division: 2))
        #expect(nudge(on: 31, in: planned) == .seasonClosing(days: 1, league: 1, division: 2))
        #expect(nudge(on: 2, in: planned) == .daily(wheel: true, deal: true, packs: 0))
    }

    @Test func aComebackNamesSealedPacksFirst() {
        let planned = plan { $0.packs = 2; $0.weeklyStarted = true; $0.weeklyLeft = 1 }
        #expect(nudge(on: 15, in: planned) == .comeback(days: 3, hook: .packs(2)))
        let noPacks = plan { $0.weeklyStarted = true; $0.weeklyLeft = 1 }
        #expect(nudge(on: 15, in: noPacks) == .comeback(days: 3, hook: .weekly(left: 1)))
    }

    @Test func noTwoDaysRunningShareAWording() {
        let variants = plan().map(\.variant)
        #expect(zip(variants, variants.dropFirst()).allSatisfy { $0 != $1 })
    }
}
