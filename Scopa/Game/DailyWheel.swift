import Foundation
import Observation
import ScopaCore
import ScopaRewards

/// The day's wheel: one free turn per local calendar day.
///
/// The prize is decided and paid before the wheel moves, so a turn cut short by a closed app
/// is still a turn taken and still paid. Whether the day is spent is read off the ledger as
/// well as off this phone, under the key the prize was paid with — the ledger travels between
/// devices, so a turn taken on the iPad is a turn taken on the phone.
@MainActor
@Observable
final class DailyWheel {
    enum Prize: Hashable {
        case denari(Denari)
        /// A pack, left waiting like any gift: in the album for cards, in the shop for its own.
        case pack(PackTier)
        /// Something off the shop's shelves not owned yet, drawn when the turn is decided.
        case shelf
        /// The big one: a heap of denari and a strongbox.
        case jackpot
    }

    struct Segment: Hashable {
        let prize: Prize
        /// Out of the wheel's total. The slices are drawn equal; the odds are not.
        let weight: Double
    }

    /// Clockwise from the top, where the jackpot rests until the first turn.
    static let segments: [Segment] = [
        Segment(prize: .jackpot, weight: 1),
        Segment(prize: .denari(25), weight: 20),
        Segment(prize: .denari(100), weight: 9),
        Segment(prize: .shelf, weight: 6),
        Segment(prize: .denari(50), weight: 18),
        Segment(prize: .pack(.bottega), weight: 6),
        Segment(prize: .denari(25), weight: 20),
        Segment(prize: .denari(150), weight: 6),
        Segment(prize: .denari(75), weight: 12),
        Segment(prize: .denari(250), weight: 2),
    ]

    static let jackpotDenari: Denari = 2_500
    static let jackpotPack: PackTier = .forziere

    /// Which turn of the day this is. Only the free one exists; another way to turn — an ad,
    /// say — would be another case with its own key, so the ledger pays each once.
    enum Ticket: Hashable {
        case free

        func key(on day: String) -> String {
            switch self {
            case .free: "wheel/\(day)"
            }
        }
    }

    /// One turn, decided and paid.
    struct Spin: Codable, Equatable {
        let day: String
        let segment: Int
        let denari: Denari
        let tiers: [PackTier]
        let item: ShopItem.ID?

        var prize: Prize { DailyWheel.segments[segment].prize }
        var isJackpot: Bool { prize == .jackpot }
    }

    private static let lastKey = "wheel.last"
    /// Once per launch: the lobby makes a wheel every time it is rebuilt.
    private static var wasReset = false
    private let defaults: UserDefaults
    /// The latest turn on this phone, whatever day it was.
    private(set) var last: Spin?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if DebugLaunch.resetsWheel, !Self.wasReset {
            Self.wasReset = true
            defaults.removeObject(forKey: Self.lastKey)
        }
        last = defaults.data(forKey: Self.lastKey).flatMap { try? JSONDecoder().decode(Spin.self, from: $0) }
    }

    /// Whether the free turn is still there today.
    func isAvailable(on day: String, paid: Set<String>) -> Bool {
        guard last?.day != day else { return false }
        return DebugLaunch.resetsWheel || !paid.contains(Ticket.free.key(on: day))
    }

    /// Today's turn on this phone, once taken.
    func spin(on day: String) -> Spin? { last?.day == day ? last : nil }

    /// Decides the turn, pays it, and writes it down. Nil when it could not be paid, or when
    /// another device had already taken the day.
    func take(_ ticket: Ticket, on day: String, purse: PurseStore, book: AlbumBook) async -> Spin? {
        let segment = DebugLaunch.wheelOutcome ?? Self.draw()
        let spin = resolve(segment, on: day, owns: purse.owns)
        let item = spin.item.flatMap { Cosmetics.catalogue[$0] }
        guard let fresh = await purse.awardWheel(spin.denari, item: item, key: key(for: ticket, on: day))
        else { return nil }
        guard fresh else { return nil }
        record(spin)
        spin.tiers.forEach(book.give)
        return spin
    }

    // MARK: Deciding

    /// One segment, by weight.
    static func draw(using generator: inout some RandomNumberGenerator) -> Int {
        let total = segments.reduce(0) { $0 + $1.weight }
        var roll = Double.random(in: 0..<total, using: &generator)
        for (index, segment) in segments.enumerated() {
            roll -= segment.weight
            if roll < 0 { return index }
        }
        return 0
    }

    static func draw() -> Int {
        var generator = SystemRandomNumberGenerator()
        return draw(using: &generator)
    }

    /// What a segment pays today. A shelf with nothing left at the grade drawn pays what the
    /// shop would have charged, the way a pack does.
    private func resolve(_ segment: Int, on day: String, owns: (ShopItem) -> Bool) -> Spin {
        switch Self.segments[segment].prize {
        case .denari(let amount):
            return Spin(day: day, segment: segment, denari: amount, tiers: [], item: nil)
        case .pack(let tier):
            return Spin(day: day, segment: segment, denari: .zero, tiers: [tier], item: nil)
        case .jackpot:
            return Spin(day: day, segment: segment, denari: Self.jackpotDenari, tiers: [Self.jackpotPack], item: nil)
        case .shelf:
            var generator = SystemRandomNumberGenerator()
            let grade = Grade.draw(using: &generator)
            let item = Cosmetics.drop(atLeast: grade, excluding: [], owns: owns, using: &generator)
            return Spin(day: day, segment: segment, denari: item == nil ? Grade.denari(for: grade) : .zero,
                        tiers: [], item: item?.id)
        }
    }

    /// The ledger's name for a turn. A debug reset pays afresh each time, so the wheel can be
    /// turned again the same day without the ledger refusing it.
    private func key(for ticket: Ticket, on day: String) -> String {
        DebugLaunch.resetsWheel ? "\(ticket.key(on: day))/debug/\(UUID().uuidString)" : ticket.key(on: day)
    }

    private func record(_ spin: Spin) {
        last = spin
        if let data = try? JSONEncoder().encode(spin) { defaults.set(data, forKey: Self.lastKey) }
    }

    /// The share of turns that land on each segment, for the odds printed under the wheel.
    static func chance(of index: Int) -> Double {
        segments[index].weight / segments.reduce(0) { $0 + $1.weight }
    }
}

extension DailyWheel {
    /// The next local midnight, when the free turn comes back.
    static func nextTurn(after date: Date = .now, calendar: Calendar = .current) -> Date {
        calendar.nextDate(after: date, matching: DateComponents(hour: 0, minute: 0, second: 0),
                          matchingPolicy: .nextTime) ?? date.addingTimeInterval(86_400)
    }
}

extension DebugLaunch {
    /// `-wheel` opens the day's wheel over the lobby.
    static var showsWheel: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-wheel")
        #else
        false
        #endif
    }

    /// `-wheelReset` gives the day's free turn back, and pays it again under a fresh key.
    static var resetsWheel: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-wheelReset")
        #else
        false
        #endif
    }

    /// `-wheelWin jackpot|item|pack|<denari>` makes the next turn land there.
    static var wheelOutcome: Int? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let word = arguments.firstIndex(of: "-wheelWin").flatMap({ arguments[safe: $0 + 1] }) else { return nil }
        return DailyWheel.segments.firstIndex { segment in
            switch segment.prize {
            case .jackpot: word == "jackpot"
            case .shelf: word == "item"
            case .pack: word == "pack"
            case .denari(let amount): word == "\(amount.coins)"
            }
        }
        #else
        nil
        #endif
    }
}
