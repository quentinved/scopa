import Foundation
import Testing
@testable import ScopaProfile

private let monday = Date(timeIntervalSince1970: 1_758_000_000)
private let tuesday = monday.addingTimeInterval(86_400)

private func setting(_ value: String, _ at: Date) -> Profile.Setting { Profile.Setting(value, at: at) }

@Suite struct MergingPreferences {
    @Test func theLaterChangeWins() {
        let phone = Profile(settings: ["tableFelt": setting("green", monday)])
        let pad = Profile(settings: ["tableFelt": setting("wine", tuesday)])
        #expect(Profile.merged(phone, pad).settings["tableFelt"]?.value == "wine")
        #expect(Profile.merged(pad, phone).settings["tableFelt"]?.value == "wine")
    }

    /// The reason settings are merged key by key rather than as one blob: two devices that
    /// each changed something different must come back with both changes, not the newer one.
    @Test func twoDevicesChangingDifferentThingsKeepBoth() {
        let phone = Profile(settings: ["tableFelt": setting("wine", tuesday)])
        let pad = Profile(settings: ["language": setting("fr", monday)])
        let merged = Profile.merged(phone, pad)
        #expect(merged.settings["tableFelt"]?.value == "wine")
        #expect(merged.settings["language"]?.value == "fr")
    }

    /// Two devices must never settle on different answers, so even a dead heat is broken
    /// the same way on both.
    @Test func aTieIsBrokenTheSameWayRoundWhicheverSideAsks() {
        let phone = Profile(settings: ["cheer": setting("casa", monday)])
        let pad = Profile(settings: ["cheer": setting("piazza", monday)])
        #expect(Profile.merged(phone, pad) == Profile.merged(pad, phone))
    }

    @Test func aKeyOnlyOneSideHasIsKept() {
        let phone = Profile(settings: ["cornice": setting("alloro", monday)])
        #expect(Profile.merged(phone, .empty).settings["cornice"]?.value == "alloro")
        #expect(Profile.merged(.empty, phone).settings["cornice"]?.value == "alloro")
    }
}

@Suite struct MergingProgress {
    @Test func aCounterTakesTheLargerOfTheTwo() {
        let phone = Profile(counters: ["achievements.wins": 12, "experience.total": 900])
        let pad = Profile(counters: ["achievements.wins": 7, "experience.total": 1_400])
        let merged = Profile.merged(phone, pad)
        #expect(merged.counters["achievements.wins"] == 12)
        #expect(merged.counters["experience.total"] == 1_400)
    }

    @Test func theAlbumIsMergedCardByCard() {
        let phone = Profile(album: ["7d": 1, "3c": 2])
        let pad = Profile(album: ["7d": 3, "1b": 1])
        let merged = Profile.merged(phone, pad)
        #expect(merged.album == ["7d": 3, "3c": 2, "1b": 1])
    }

    /// A bonus is paid once. Either side having paid it has to settle it for both, or the
    /// next pack pays for a suit that was already bought.
    @Test func aPaidBonusStaysPaid() {
        let phone = Profile(paidSuits: ["coins"], paidDeck: false)
        let pad = Profile(paidSuits: ["cups"], paidDeck: true)
        let merged = Profile.merged(phone, pad)
        #expect(merged.paidSuits == ["coins", "cups"])
        #expect(merged.paidDeck)
    }
}

@Suite struct MergingTheWeeklyChallenge {
    @Test func progressInTheSameWeekTakesTheFurtherOn() {
        let phone = Profile(challengeWeek: "2026-W37", challengeCount: 4)
        let pad = Profile(challengeWeek: "2026-W37", challengeCount: 9)
        #expect(Profile.merged(phone, pad).challengeCount == 9)
    }

    /// A count belongs to the week it was made in. Carrying one across would hand this
    /// week's badge to a phone for games it played last week.
    @Test func aCountFromAnOlderWeekIsNotProgressTowardsThisOne() {
        let stale = Profile(challengeWeek: "2026-W36", challengeCount: 30)
        let current = Profile(challengeWeek: "2026-W37", challengeCount: 2)
        let merged = Profile.merged(stale, current)
        #expect(merged.challengeWeek == "2026-W37")
        #expect(merged.challengeCount == 2)
    }

    /// Each task is its own count: the phone's sweeps and the iPad's wins both stand.
    @Test func eachTaskTakesTheFurtherOnOfTheTwo() {
        let phone = Profile(challengeWeek: "2026-W37", challengeCounts: [4, 30, 0])
        let pad = Profile(challengeWeek: "2026-W37", challengeCounts: [9, 12, 1])
        #expect(Profile.merged(phone, pad).challengeCounts == [9, 30, 1])
    }

    @Test func tasksFromAnOlderWeekAreNotProgressTowardsThisOnes() {
        let stale = Profile(challengeWeek: "2026-W36", challengeCounts: [40, 100, 4])
        let current = Profile(challengeWeek: "2026-W37", challengeCounts: [1, 2, 0])
        #expect(Profile.merged(stale, current).challengeCounts == [1, 2, 0])
    }

    /// A profile written before the week had several tasks has no list at all. It must still
    /// read, or one old copy on the Worker stops every device syncing.
    @Test func aProfileFromBeforeTheTasksStillReads() throws {
        let old = #"{"settings":{},"counters":{},"album":{},"paidSuits":[],"paidDeck":false,"#
            + #""challengeWeek":"2026-W37","challengeCount":6}"#
        let profile = try Profile.decoder.decode(Profile.self, from: Data(old.utf8))
        #expect(profile.challengeCount == 6)
        #expect(profile.challengeCounts == [])
    }

    @Test func theLatestFinishedWeekIsTheOneTheBadgeComesFrom() {
        let phone = Profile(finishedWeek: "2026-W35")
        let pad = Profile(finishedWeek: "2026-W37")
        #expect(Profile.merged(phone, pad).finishedWeek == "2026-W37")
        #expect(Profile.merged(pad, .empty).finishedWeek == "2026-W37")
    }
}

@Suite struct TheMergeItself {
    private var phone: Profile {
        Profile(settings: ["tableFelt": setting("wine", tuesday), "language": setting("it", monday)],
                counters: ["achievements.wins": 12], album: ["7d": 2], paidSuits: ["coins"],
                challengeWeek: "2026-W37", challengeCount: 4, challengeCounts: [4, 0, 2],
                finishedWeek: "2026-W35")
    }

    private var pad: Profile {
        Profile(settings: ["tableFelt": setting("green", monday), "cheer": setting("piazza", tuesday)],
                counters: ["achievements.wins": 3, "experience.total": 80], album: ["7d": 1, "1b": 1],
                paidDeck: true, challengeWeek: "2026-W37", challengeCount: 9, challengeCounts: [1, 7])
    }

    /// Syncing twice has to mean syncing once, or a device that retries a failed push
    /// changes the answer by retrying.
    @Test func mergingTwiceChangesNothing() {
        let once = Profile.merged(phone, pad)
        #expect(Profile.merged(once, pad) == once)
        #expect(Profile.merged(once, phone) == once)
        #expect(Profile.merged(once, once) == once)
    }

    /// Neither device is in charge, so neither may get a different answer by asking first.
    @Test func theOrderTheTwoSidesMergeInDoesNotMatter() {
        #expect(Profile.merged(phone, pad) == Profile.merged(pad, phone))
    }

    @Test func anEmptyProfileChangesNothing() {
        #expect(Profile.merged(phone, .empty) == phone)
        #expect(Profile.merged(.empty, phone) == phone)
        #expect(Profile.merged([]) == .empty)
    }

    /// The Worker keeps this as JSON and reads its dates in JavaScript, so it has to
    /// survive the trip in the shape both ends agree on.
    @Test func itSurvivesTheRoundTripThroughTheWorker() throws {
        let data = try Profile.encoder.encode(phone)
        #expect(try Profile.decoder.decode(Profile.self, from: data) == phone)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("2025-09-16T"))
    }
}
