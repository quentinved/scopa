import Foundation
import Observation
import ScopaCore
import ScopaGameCenter
import ScopaProfile
import ScopaRewards
import SwiftUI

/// What makes a phone and an iPad the same player: preferences, the cosmetics in use, the
/// counters, the album and the purse, merged between every device signed in to the one
/// Game Center account.
///
/// Keyed on Game Center rather than on iCloud, and the difference matters more than it
/// looks. Since iOS 16 the two can be different accounts, and the thing a player recognises
/// as themselves in a card game is the name on the board, not the Apple Account behind the
/// App Store. The Worker already checks a Game Center signature on every ladder post, so an
/// account costs a table and two calls rather than a second way of proving who you are.
///
/// Nothing here is in charge. Every device keeps playing from its own copy and merges when
/// it can: signed out, offline, or with the Worker switched off, the game is exactly what it
/// was before any of this existed.
@MainActor
@Observable
final class AccountSync {
    /// When the account last came back merged. Nil until it has, which is what the settings
    /// screen shows as "not synced yet".
    private(set) var syncedAt: Date?
    private(set) var isSyncing = false
    /// Something worth telling the player. A `LocalizedStringKey` rather than a `String`,
    /// because `Text(someString)` would print it in English whatever the game's language.
    private(set) var problem: LocalizedStringKey?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Where this device has got to. None of it travels: it is a record of what *this*
    /// device has already seen and said.
    private enum Mark {
        static let rev = "sync.rev"
        /// The last ledger row read back from the Worker.
        static let since = "sync.since"
        /// How many of this device's own ledger entries have been handed over.
        static let pushed = "sync.pushed"
        /// The account as it was left at the end of the last sync, so an unchanged
        /// preference can be told from a changed one without stamping every `didSet`.
        static let profile = "sync.profile"
    }

    /// Whether this device has ever merged with the account. Until it has, it adopts what
    /// the account already says rather than arguing with it. See `gather`.
    private var hasSynced: Bool { defaults.object(forKey: Mark.rev) != nil }

    // MARK: Syncing

    /// One pass: read the account, fold it into this device, hand back what it did not have.
    ///
    /// Quiet about everything that is not a real failure. Not being signed in is not an
    /// error, and neither is the Worker being switched off — both just mean this device
    /// plays on its own, which is what it did before there were accounts.
    func sync(_ store: TableStore, purse: PurseStore, ads: AdsStore, reminders: Reminders) async {
        guard Ladder.isOn, GameCenter.isSignedIn, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await pass(store, purse: purse, ads: ads, reminders: reminders)
            problem = nil
            syncedAt = .now
        } catch is CancellationError {
            // The screen went away mid-call. Nothing was lost: the marks only move on success.
        } catch {
            problem = "Your account could not be synced just now."
        }
    }

    /// How many times a refused write is merged again before giving up. A refusal means the
    /// other device wrote first, so merging again *is* the repair — but it is a loop, and a
    /// loop over the network gets a ceiling.
    private static let attempts = 3

    private func pass(_ store: TableStore, purse: PurseStore, ads: AdsStore, reminders: Reminders) async throws {
        guard var account = try await Ladder.readAccount(since: defaults.integer(forKey: Mark.since)) else { return }
        // Everything the ledger gained elsewhere, however many answers it takes to say it.
        let known = account
        var arrived = account.ledger
        while account.more {
            guard let next = try await Ladder.readAccount(since: account.since) else { break }
            account = next
            arrived += next.ledger
        }
        let cursor = account.since

        // Worked out before anything arriving is folded in: what comes back from the Worker
        // is the Worker's already, and pushing it again would be a round trip for nothing.
        let unsent = Array(purse.purse.entries.dropFirst(defaults.integer(forKey: Mark.pushed)))
        var merged = Profile.merged(gather(store), known.profile ?? .empty)
        apply(merged, to: store, ads: ads, reminders: reminders)
        await purse.credit(arrived)

        // The ledger goes first and on its own. It cannot conflict, so a player's denari
        // should not wait behind a revision race over which felt is selected.
        for batch in stride(from: 0, to: unsent.count, by: Ladder.ledgerBatch) {
            let slice = Array(unsent[batch..<min(batch + Ladder.ledgerBatch, unsent.count)])
            _ = try await Ladder.writeAccount(rev: known.rev, profile: nil, ledger: slice, since: cursor)
        }

        var rev = known.rev
        for _ in 0..<Self.attempts {
            guard let answer = try await Ladder.writeAccount(rev: rev, profile: merged, ledger: [], since: cursor)
            else { return }
            switch answer {
            case .written(let settled):
                // Whatever the other device pushed while this one was talking comes back in
                // the same answer, and the cursor is about to move past it. So it is folded
                // in here or it is never seen again.
                await purse.credit(settled.ledger)
                remember(rev: settled.rev, cursor: settled.since, pushed: purse.purse.entries.count)
                return
            case .stale(let theirs):
                // The other device wrote in the gap between the read and the write. Fold in
                // what it said and try again — the merge is the whole of the repair.
                merged = Profile.merged(merged, theirs.profile ?? .empty)
                apply(merged, to: store, ads: ads, reminders: reminders)
                await purse.credit(theirs.ledger)
                rev = theirs.rev
            }
        }
        throw AccountError.tooBusy
    }

    /// Where the Worker got to, written down only once it has agreed to the write. A pass
    /// that failed anywhere leaves these where they were and is simply run again.
    ///
    /// `Mark.profile` is not here: it is a record of what this device last knew, not of what
    /// the Worker has accepted, and `apply` keeps it. See there for why the difference bites.
    private func remember(rev: Int, cursor: Int, pushed: Int) {
        defaults.set(rev, forKey: Mark.rev)
        defaults.set(cursor, forKey: Mark.since)
        // Everything on this device is now either something it handed over or something it
        // was given, so there is nothing left to push.
        defaults.set(pushed, forKey: Mark.pushed)
    }

    // MARK: This device's copy

    /// The account as this device has it.
    ///
    /// Preferences carry the clock of the last sync that saw them unchanged, rather than the
    /// clock of this moment. Otherwise a value nobody has touched in a month would out-rank
    /// the other device's newer one simply by being sent again, and the last device to open
    /// the app would always win.
    ///
    /// A device that has never synced claims nothing: its preferences are dated to the
    /// distant past, so the account it is joining wins every key they both have. That is
    /// what signing in on a second device ought to do — the iPad adopts the account instead
    /// of pushing its out-of-the-box felt over the iPhone's. Nothing of value is risked by
    /// it: counters, the album and the purse are not dated at all and merge on their own
    /// terms, so the only thing being given up is which felt is selected.
    private func gather(_ store: TableStore) -> Profile {
        let last = (defaults.data(forKey: Mark.profile)
            .flatMap { try? Profile.decoder.decode(Profile.self, from: $0) }) ?? .empty
        let stamp = hasSynced ? Date.now : .distantPast

        var settings: [String: Profile.Setting] = [:]
        for stored in Stored.settings {
            guard let value = stored.read(from: defaults) else { continue }
            if let known = last.settings[stored.key], known.value == value {
                settings[stored.key] = known
            } else {
                settings[stored.key] = Profile.Setting(value, at: stamp)
            }
        }

        var counters: [String: Int] = [:]
        for key in Stored.counters where defaults.object(forKey: key) != nil {
            counters[key] = defaults.integer(forKey: key)
        }

        return Profile(
            settings: settings,
            counters: counters,
            album: store.albumBook.album.counts.reduce(into: [:]) { album, card in
                album[card.key.code] = card.value
            },
            paidSuits: Set(defaults.stringArray(forKey: Stored.paidSuits) ?? []),
            paidDeck: defaults.bool(forKey: Stored.paidDeck),
            challengeWeek: store.challenges.week,
            challengeCount: defaults.integer(forKey: Stored.challengeCount),
            challengeCounts: store.challenges.counts,
            finishedWeek: store.challenges.finishedWeek
        )
    }

    /// Writes the merged account down, then tells the live screens to read it again.
    ///
    /// Everything goes through `UserDefaults` rather than through each store's properties,
    /// because that is where all of it already lives — the stores are holding a copy for the
    /// views. So the order is: write it all down, then ask each one to read itself again.
    private func apply(_ profile: Profile, to store: TableStore, ads: AdsStore, reminders: Reminders) {
        for stored in Stored.settings {
            guard let setting = profile.settings[stored.key] else { continue }
            stored.write(setting.value, to: defaults)
        }
        // Only ever upwards, in case a game finished on this device while the call was out.
        for (key, value) in profile.counters {
            defaults.set(max(value, defaults.integer(forKey: key)), forKey: key)
        }
        writeAlbum(profile)
        writeChallenge(profile)

        // Kept here rather than after a successful write, because this is the baseline
        // `gather` tells a changed preference from an unchanged one against — a record of
        // what this device last knew, not of what the Worker has accepted. Left behind on a
        // failed push, a value merged in from the other device would look like a change made
        // here, be stamped with this moment on the next pass, and beat the newer value the
        // other device has since chosen.
        if let data = try? Profile.encoder.encode(profile) { defaults.set(data, forKey: Mark.profile) }

        store.readStoredAgain()
        Audio.shared.readStoredAgain()
        reminders.readStoredAgain()
        ads.sweepIfSaidElsewhere()
    }

    private func writeAlbum(_ profile: Profile) {
        let counts = profile.album.reduce(into: [Card: Int]()) { counts, found in
            if let card = Card(code: found.key) { counts[card] = found.value }
        }
        if let data = try? JSONEncoder().encode(Album(counts: counts)) {
            defaults.set(data, forKey: Stored.album)
        }
        defaults.set(Array(profile.paidSuits), forKey: Stored.paidSuits)
        // A bonus paid stays paid. Never written back to false: the other device having no
        // record of it means it has not seen it yet, not that it did not happen.
        if profile.paidDeck { defaults.set(true, forKey: Stored.paidDeck) }
    }

    private func writeChallenge(_ profile: Profile) {
        guard !profile.challengeWeek.isEmpty else { return }
        defaults.set(profile.challengeWeek, forKey: Stored.challengeWeek)
        defaults.set(profile.challengeCount, forKey: Stored.challengeCount)
        // Already merged with this device's own counts. An empty list comes only from builds
        // before the week had several tasks, and the book reads a missing list as a fresh week.
        if profile.challengeCounts.isEmpty {
            defaults.removeObject(forKey: Stored.challengeCounts)
        } else {
            defaults.set(profile.challengeCounts, forKey: Stored.challengeCounts)
        }
        if let finished = profile.finishedWeek { defaults.set(finished, forKey: Stored.challengeFinished) }
    }
}

enum AccountError: Error {
    /// Three writes in a row were beaten to it by another device. Vanishingly unlikely with
    /// two of them, and a pass that gives up now simply runs again later.
    case tooBusy
}

// MARK: - What travels

/// Everything that follows the player from one device to the next, and — just as much the
/// point — nothing that does not.
///
/// Left out on purpose: `deviceID`, which is this device's own name for itself and would
/// seat one player twice; `rank` and `bestYesterday`, which are the ladder's own answers
/// kept so the lobby has a number before the Worker replies; and the guards that stop a
/// finished game being counted twice — `achievements.lastGame`, `experience.lastGame`,
/// `experience.seeded` — which record what *this* device has already done with a game it
/// played, and mean nothing on the other one.
private enum Stored {
    /// How a preference is written down, so it can be read back out as the same thing.
    ///
    /// A `Bool` and an `Int` are both `NSNumber` once they are in `UserDefaults`, and asking
    /// one whether it is the other is how a count of three quietly becomes true. So the kind
    /// is stated here rather than guessed at the value.
    enum Kind { case text, flag, number }

    struct Setting {
        let key: String
        let kind: Kind

        init(_ key: String, _ kind: Kind = .text) {
            self.key = key
            self.kind = kind
        }

        /// Nil for a preference this device has never set, which is different from one set
        /// to its default: an untouched key must not out-rank the other device's answer.
        func read(from defaults: UserDefaults) -> String? {
            guard defaults.object(forKey: key) != nil else { return nil }
            switch kind {
            case .text: return defaults.string(forKey: key)
            case .flag: return defaults.bool(forKey: key) ? "1" : "0"
            case .number: return String(defaults.integer(forKey: key))
            }
        }

        func write(_ value: String, to defaults: UserDefaults) {
            switch kind {
            case .text: defaults.set(value, forKey: key)
            case .flag: defaults.set(value == "1", forKey: key)
            case .number: defaults.set(Int(value) ?? 0, forKey: key)
            }
        }
    }

    /// Preferences and the cosmetics in use. Merged one key at a time, latest change wins.
    static let settings: [Setting] = [
        .init("playerName"), .init("assistLevel"), .init("botLevel"), .init("quickTable"),
        .init("rankedSolo"),
        .init("cardStyle"), .init("cardSkin"), .init("language"),
        .init("tableFelt"), .init("tapis"), .init("cardBack"), .init("seatMark"),
        .init("companion"), .init("cornice"), .init("livery"), .init("flourish"), .init("cheer"),
        .init("hasSeenRules", .flag), .init("knowsTieRules", .flag), .init("adsAreSwept", .flag),
        .init("musicOn", .flag), .init("soundsOn", .flag),
        .init("reminders.on", .flag), .init("reminders.offered", .flag),
        // Packs are spent, not collected, so these three can go down as well as up and
        // travel as preferences — the latest word rather than the largest. Taking the larger
        // would hand back a pack that was opened on the other device, and a pack opened
        // twice is its cards, its denari and whatever it turned up off the shelves, twice.
        // The other way round loses a pack, which is the side to be wrong on.
        .init("album.waiting", .number), .init("album.games", .number), .init("album.announced", .number),
        .init("album.gifts"),
    ]

    /// Counters that only ever climb, so the larger of the two is the true one.
    ///
    /// Two devices that each play a game while apart come back with one game between them
    /// rather than two. That is what counting without asking a server after every hand
    /// costs, and it errs downwards: nobody is handed a win they did not play.
    static let counters = [
        "achievements.scope", "achievements.settebelli", "achievements.cappotti",
        "achievements.wins", "achievements.losses", "achievements.daily", "achievements.onlineWins",
        "experience.total",
    ]

    static let album = "album.cards"
    static let paidSuits = "album.paidSuits"
    static let paidDeck = "album.paidDeck"
    static let challengeWeek = "challenge.week"
    /// The one-goal weeks' count. Only carried, for a device still on an older build.
    static let challengeCount = "challenge.count"
    static let challengeCounts = "challenge.counts"
    static let challengeFinished = "challenge.finished"
}

private extension Card {
    /// "7d" for the seven of coins, as `description` prints it.
    ///
    /// The album travels by these rather than by the card's own `Codable` shape, because a
    /// merge compares one card's count with another's and a key on the wire has to be a
    /// string. `[Card: Int]` would encode as a flat array of alternating keys and values,
    /// which is not something two devices can merge card by card.
    var code: String { description }

    init?(code: String) {
        guard let initial = code.last,
              let suit = Suit.allCases.first(where: { $0.initial == initial }),
              let value = Int(code.dropLast()), let rank = Rank(rawValue: value)
        else { return nil }
        self.init(rank, of: suit)
    }
}
