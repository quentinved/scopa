import Observation
import ScopaRewards

/// The shop's counter: the purchase waiting on a yes, and the last thing bought.
///
/// Shared by every shelf, so each one buys the same way and the page asks one question.
@MainActor
@Observable
final class ShopCounter {
    /// A purchase waiting on a yes.
    struct Pending {
        let item: ShopItem
        let equip: () -> Void
    }

    let purse: PurseStore
    /// The last item bought, so its tile can show the gilding.
    var bought: ShopItem.ID?
    /// Kept after the dialog closes so the dismissal animation still has a title to draw.
    var pending: Pending?
    var confirmsPurchase = false

    init(purse: PurseStore) {
        self.purse = purse
    }

    func affordable(_ item: ShopItem?) -> Bool {
        item.map(purse.canAfford) ?? true
    }

    func justBought(_ item: ShopItem?) -> Bool {
        item != nil && bought == item?.id
    }

    /// Equips what is owned, refuses what is earned, and asks before buying the rest.
    func buyIfNeeded(_ item: ShopItem?, then equip: @escaping () -> Void) {
        guard let item, !purse.owns(item) else {
            Audio.shared.play(.toggle)
            return equip()
        }
        // Priced at nothing because it is earned rather than sold: the tile says how.
        if item.price == .zero {
            Audio.shared.play(.refused)
            return
        }
        ask(for: item, then: equip)
    }

    /// A purse too light is refused on the spot, and the refusal writes the "N denari
    /// short" line under the balance.
    func ask(for item: ShopItem, then equip: @escaping () -> Void) {
        let pending = Pending(item: item, equip: equip)
        self.pending = pending
        guard purse.canAfford(item) else { return pay(for: pending) }
        confirmsPurchase = true
    }

    func pay(for pending: Pending) {
        Task {
            if await purse.buy(pending.item) {
                Audio.shared.play(.purchase)
                bought = pending.item.id
                pending.equip()
            } else {
                Audio.shared.play(.refused)
            }
        }
    }
}
