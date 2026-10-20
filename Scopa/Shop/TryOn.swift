import Foundation
import Observation
import ScopaRewards

/// A deck or a cloth worn for one game before it is bought, for a video.
///
/// Only what nobody else at the table sees can be tried: a deck's drawing or colours, its
/// back, the felt and the cloth. It goes on as the video ends, lobby and all, and comes off
/// as the next finished game is left, with a word in the lobby saying what it costs. Kept on
/// the phone, so a relaunch before that game does not take it away.
@MainActor
@Observable
final class TryOn {
    /// What is worn on trial, and the game that used it up once one has.
    struct Trial: Codable, Equatable {
        let item: ShopItem.ID
        var spentOn: UUID?
    }

    /// What the trial puts on, worked out once rather than on every redraw of the root.
    private enum Look {
        case style(CardStyle)
        case skin(CardSkin)
        case back(CardBackPattern)
        case felt(TableFelt)
        case tapis(Tapis)
    }

    private(set) var trial: Trial? {
        didSet {
            look = trial.flatMap { Self.look(of: $0.item) }
            save()
        }
    }

    @ObservationIgnored private var look: Look?

    init() {
        let stored = UserDefaults.standard.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(Trial.self, from: $0) }
        // A game that used it up and was never left, because the app was closed on its summary.
        trial = stored?.spentOn == nil ? stored : nil
        look = trial.flatMap { Self.look(of: $0.item) }
    }

    /// Whether this can be worn for a game: sold rather than earned, and seen by nobody else.
    static func offers(_ item: ShopItem) -> Bool {
        item.price.isCredit && look(of: item.id) != nil
    }

    func isTrying(_ item: ShopItem?) -> Bool {
        item != nil && trial?.item == item?.id
    }

    /// On until the end of the next game finished.
    func start(_ item: ShopItem) {
        trial = Trial(item: item.id)
    }

    /// Something of the same kind was put on by hand, which the trial must not hide.
    func yield(_ kind: ShopItem.Kind) {
        guard let trial, Cosmetics.catalogue[trial.item]?.kind == kind else { return }
        self.trial = nil
    }

    /// A game finished with it on, so it comes off as that game is left.
    func spend(on gameID: UUID) {
        guard trial != nil, trial?.spentOn == nil else { return }
        trial?.spentOn = gameID
    }

    /// Takes it off once a finished game has used it up, and says what it was.
    func endIfSpent() -> ShopItem? {
        guard let trial, trial.spentOn != nil else { return nil }
        self.trial = nil
        return Cosmetics.catalogue[trial.item]
    }

    // MARK: What it changes

    func theme(over theme: CardTheme) -> CardTheme {
        switch look {
        case .style(let style): style.applied(to: theme)
        case .skin(let skin): skin.applied(to: theme)
        default: theme
        }
    }

    func back(over back: CardBackPattern) -> CardBackPattern {
        if case .back(let pattern) = look { pattern } else { back }
    }

    func felt(over felt: TableFelt) -> TableFelt {
        if case .felt(let worn) = look { worn } else { felt }
    }

    func tapis(over tapis: Tapis) -> Tapis {
        if case .tapis(let worn) = look { worn } else { tapis }
    }

    private static func look(of id: ShopItem.ID) -> Look? {
        if let style = CardStyle.options.first(where: { $0.shopItem?.id == id }) { return .style(style) }
        if let skin = CardSkin.options.first(where: { $0.shopItem?.id == id }) { return .skin(skin) }
        if let back = CardBackPattern.allCases.first(where: { Cosmetics.item(for: $0)?.id == id }) { return .back(back) }
        if let felt = TableFelt.allCases.first(where: { Cosmetics.item(for: $0)?.id == id }) { return .felt(felt) }
        if let tapis = Tapis.allCases.first(where: { Cosmetics.item(for: $0)?.id == id }) { return .tapis(tapis) }
        return nil
    }

    private func save() {
        if let trial, let data = try? JSONEncoder().encode(trial) {
            UserDefaults.standard.set(data, forKey: Self.key)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.key)
        }
    }

    private static let key = "shop.tryOn"
}
