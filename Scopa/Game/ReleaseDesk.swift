import Foundation
import Observation
import ScopaRewards

/// Whether the house has something to say on arrival: a gift owed, the pages of a version
/// not yet seen, or both, and the moment that shows them.
///
/// Two records, kept apart on purpose. The version last welcomed is this phone's own, in
/// `UserDefaults`, because "What's new" is news to a device. A gift is the ledger's, keyed
/// like every other grant, so it pays once per player whichever device opens it first and
/// travels with the account. A parcel closed unopened stays owed and is offered again on the
/// next launch, never twice in one.
@MainActor
@Observable
final class ReleaseDesk {
    /// What to show, once the lobby is clear.
    struct Moment: Equatable {
        /// Everything owed, as one parcel. Nil when there is only news.
        var gift: ReleaseGift?
        /// The gifts it is made of, each paid under its own key.
        var parts: [ReleaseGift] = []
        /// Pages to turn after the parcel, or on their own.
        var version: String?
        /// A first launch rather than an update, which changes the words and not the gift.
        var isWelcome = false
        var startsOpen = false
        var page = 0
        /// Asked for with a debug flag, so closing it writes nothing down.
        var isForced = false
    }

    private enum Key {
        static let seen = "release.seen"
        /// The version whose own gift this phone owes, written on the first launch after
        /// updating to it. Whether it is still owed is the ledger's to say.
        static let giftFor = "release.giftFor"
        /// `TableStore`'s, read here only to tell a fresh install from an update.
        static let rules = "hasSeenRules"
    }

    private(set) var moment: Moment?
    private let defaults: UserDefaults
    /// True while this build's pages are still news to this phone.
    private var isUpdate: Bool
    /// The moment has been up and closed since launch, so the lobby clearing again after a
    /// sheet does not bring it back. Static, as the lobby that holds the desk can be rebuilt.
    private static var isDone = false

    /// A phone that has never seen the rules is a fresh install: there is nothing new to it,
    /// so the version is written down at once and only the welcome is owed. A phone that has
    /// seen them but no version is an update from before versions were kept.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let seen = defaults.string(forKey: Key.seen)
        if seen == nil, !defaults.bool(forKey: Key.rules) {
            defaults.set(Releases.version, forKey: Key.seen)
            isUpdate = false
        } else {
            isUpdate = seen != Releases.version
        }
        if isUpdate { defaults.set(Releases.version, forKey: Key.giftFor) }
    }

    /// Puts the moment up if anything is owed. `paid` is every key in the ledger.
    func check(paid: Set<String>) {
        guard moment == nil, !Self.isDone else { return }
        if let forced = Self.forced { moment = forced; return }
        guard !Self.isQuiet else { return }
        let parts = owedGifts(paid: paid)
        let notes = isUpdate ? Releases.current.flatMap { $0.notes.isEmpty ? nil : $0.version } : nil
        guard !parts.isEmpty || notes != nil else {
            if isUpdate { markSeen() }
            return
        }
        let onlyWelcome = parts.allSatisfy { $0.key == Releases.welcome.key }
        moment = Moment(gift: parts.isEmpty ? nil : .together(parts), parts: parts,
                        version: notes, isWelcome: !isUpdate && onlyWelcome)
    }

    /// Opens the parcel: pays each gift under its own key, and leaves the packs of the ones
    /// paid just now waiting, each on its own shelf. A gift the ledger already holds gives nothing again.
    func open(purse: PurseStore, book: AlbumBook) async {
        for gift in moment?.parts ?? [] {
            guard await purse.claim(gift) == true else { continue }
            gift.packs.forEach(book.give)
        }
    }

    /// Marks the pages read. A gift is left to the ledger: one not claimed is owed still.
    func close() {
        if moment?.isForced == false { markSeen() }
        moment = nil
        Self.isDone = true
    }

    private func owedGifts(paid: Set<String>) -> [ReleaseGift] {
        var owed = [Releases.welcome]
        if let gift = Releases.current?.gift, gift.key != Releases.welcome.key,
           defaults.string(forKey: Key.giftFor) == Releases.version { owed.append(gift) }
        return owed.filter { !paid.contains($0.key) }
    }

    private func markSeen() {
        defaults.set(Releases.version, forKey: Key.seen)
        isUpdate = false
    }

    /// Screenshots are taken with `-noGameCenter` and must not be covered by a parcel
    /// nobody asked for. `-updateGift` and `-whatsNew` ask for one.
    private static var isQuiet: Bool {
        #if DEBUG
        DebugLaunch.staysSignedOut
        #else
        false
        #endif
    }

    private static var forced: Moment? {
        #if DEBUG
        if let gift = DebugLaunch.updateGift {
            let parts = [Releases.welcome]
            return Moment(gift: .together(parts), parts: parts, version: Releases.latestNotes?.version,
                          isWelcome: gift == .welcome, startsOpen: gift == .opened, isForced: true)
        }
        if let page = DebugLaunch.whatsNewPage {
            return Moment(version: Releases.latestNotes?.version, page: page, isForced: true)
        }
        #endif
        return nil
    }
}
