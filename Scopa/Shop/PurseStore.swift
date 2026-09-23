import Foundation
import Observation
import ScopaCore
import ScopaRewards
import SwiftUI

/// The purse as the screens need it: on the main actor, observable, and never throwing at a
/// view. `Wallet` does the work, this holds its last answer.
@MainActor
@Observable
final class PurseStore {
    private(set) var purse = Purse()
    /// False until the ledger has been read once, so the lobby can hold the balance back
    /// rather than flash a zero.
    private(set) var isReady = false
    /// Something the player should be told about, most often a failed write.
    ///
    /// A `LocalizedStringKey` rather than a `String`, because `Text(someString)` would
    /// print it in English whatever the game's language.
    private(set) var problem: LocalizedStringKey?

    private let wallet: Wallet

    init(wallet: Wallet) {
        self.wallet = wallet
    }

    /// The real purse: a JSON ledger in Application Support, keyed to this device.
    convenience init() {
        do {
            self.init(wallet: Wallet(store: try FileLedgerStore.onDisk(device: Device.id)))
        } catch {
            // Application Support was unreachable. Play on with a purse that lasts as long
            // as the process rather than refusing to launch.
            self.init(wallet: Wallet(store: MemoryLedgerStore()))
            problem = "Your denari could not be saved on this device."
        }
    }

    var balance: Denari { purse.balance }

    /// A free cosmetic has no shop item, and everybody owns it.
    func owns(_ item: ShopItem?) -> Bool {
        guard let item else { return true }
        return purse.owns(item)
    }

    func owns(_ option: some DeckOption) -> Bool { owns(option.shopItem) }
    /// A deck is owned only when both the drawing and the colourway are.
    func owns(_ theme: CardTheme) -> Bool { owns(theme.style) && owns(theme.skin) }
    func owns(_ felt: TableFelt) -> Bool { owns(Cosmetics.item(for: felt)) }
    func owns(_ tapis: Tapis) -> Bool { owns(Cosmetics.item(for: tapis)) }
    func owns(_ mark: SeatMark) -> Bool { owns(Cosmetics.item(for: mark)) }
    func owns(_ cornice: Cornice) -> Bool { owns(Cosmetics.item(for: cornice)) }
    func owns(_ back: CardBackPattern) -> Bool { owns(Cosmetics.item(for: back)) }
    func owns(_ companion: Companion) -> Bool { owns(Cosmetics.item(for: companion)) }
    func owns(_ pack: Cosmetics.ReactionPack) -> Bool { owns(pack.item) }
    func owns(_ livery: SeatLivery) -> Bool { owns(Cosmetics.item(for: livery)) }
    func owns(_ flourish: Flourish) -> Bool { owns(Cosmetics.item(for: flourish)) }
    func owns(_ cheer: Cheer) -> Bool { owns(Cosmetics.item(for: cheer)) }

    /// Everything this player may say at a table: the free reactions plus any bought packs.
    var reactions: [Reaction] {
        Reaction.free + Cosmetics.reactionPacks.filter { owns($0) }.flatMap(\.reactions)
    }

    func canAfford(_ item: ShopItem) -> Bool { purse.canAfford(item) }

    func load() async {
        await update { try await wallet.purse() }
        isReady = true
    }

    /// Grants, free and once, whatever the player was already using before it had a price.
    /// Does nothing on a fresh install.
    func grandfather(_ items: [ShopItem?]) async {
        for item in items.compactMap({ $0 }) where !purse.owns(item) {
            if let updated = try? await wallet.grandfather(item) { purse = updated }
        }
    }

    /// Folds in entries earned on the player's other device.
    ///
    /// This is the whole of merging a purse, and it is why the ledger was built as keyed
    /// entries rather than as a balance: `Wallet` drops anything whose key it has already
    /// seen, so the same game arriving twice is not paid twice, and the two devices need no
    /// agreement about who was right.
    func credit(_ entries: [LedgerEntry]) async {
        guard !entries.isEmpty else { return }
        do {
            _ = try await wallet.credit(entries)
            purse = try await wallet.purse()
        } catch {
            problem = "Your denari from your other device could not be saved."
        }
    }

    /// The passphrase unlocks the shop as well as removing ads. Safe to call on every
    /// launch, since anything already owned is left as it is.
    func unlockEverything() async {
        guard !ownsEverything else { return }
        if let updated = try? await wallet.unlockEverything(in: Cosmetics.catalogue, note: "balai") {
            purse = updated
        }
    }

    var ownsEverything: Bool {
        Cosmetics.catalogue.items.allSatisfy(purse.owns)
    }

    /// Buys an item and says whether it worked, so the caller can equip it.
    @discardableResult
    func buy(_ item: ShopItem) async -> Bool {
        do {
            purse = try await wallet.buy(item)
            problem = nil
            return true
        } catch PurchaseError.alreadyOwned {
            return true
        } catch PurchaseError.tooDear(let short) {
            problem = "You are \(short.coins) denari short."
            return false
        } catch {
            problem = "That purchase could not be saved."
            return false
        }
    }

    /// Pays out a finished game and returns what it earned. Empty when the game was
    /// already settled once.
    func settle(_ tally: RewardTally) async -> [Award] {
        do {
            let credited = try await wallet.settle(tally)
            purse = try await wallet.purse()
            return credited.compactMap {
                guard case .earned(let award) = $0.reason else { return nil }
                return award
            }
        } catch {
            problem = "Your denari from that game could not be saved."
            return []
        }
    }

    /// Puts a stake down for a wager game. On failure `problem` says how short the purse
    /// was.
    func stake(_ stake: Stake, gameID: UUID) async -> Bool {
        do {
            purse = try await wallet.stake(stake, gameID: gameID)
            problem = nil
            return true
        } catch WagerError.short(let short) {
            problem = "You are \(short.coins) denari short of that table."
            return false
        } catch {
            problem = "That stake could not be saved."
            return false
        }
    }

    /// Puts a stake back after a table that never opened. Quiet either way, since the
    /// lobby has already said the table was refused.
    func refund(_ stake: Stake, gameID: UUID) async {
        guard (try? await wallet.refund(stake, gameID: gameID)) != nil else { return }
        purse = (try? await wallet.purse()) ?? purse
    }

    /// Collects the pot of a won wager game. Nil when there was nothing to collect, as for
    /// a summary shown twice.
    func payOut(_ stake: Stake, players: Int, gameID: UUID) async -> Denari? {
        do {
            let paid = try await wallet.payOut(stake, players: players, gameID: gameID)
            purse = try await wallet.purse()
            return paid.first?.amount
        } catch {
            problem = "Your winnings could not be saved."
            return nil
        }
    }

    /// Hands over something a pack turned up, free and once.
    ///
    /// Keyed on the pack and the slot rather than on the item, so an opening shown twice
    /// after a crash unlocks the same thing once, and two packs that both happen to pay in
    /// the same felt still only ever record it as owned once — the wallet refuses the
    /// second because it is already owned, which is the answer we want anyway.
    @discardableResult
    func win(_ item: ShopItem, key: String) async -> Bool {
        do {
            purse = try await wallet.unlock(item, key: key)
            problem = nil
            return true
        } catch {
            problem = "What that pack turned up could not be saved."
            return false
        }
    }

    /// Buys a pack. The denari leave here; the cards and anything with them are drawn by
    /// `AlbumBook`, which is the only thing that knows what a pack is made of.
    ///
    /// A pack is not a `ShopItem` — it is not a thing you own, it is a thing you spend on
    /// and open — so it goes out through the ledger's plain grant rather than through
    /// `buy`, which would record it on the shelf of things owned and never let it be
    /// bought twice.
    func buyPack(_ tier: PackTier) async -> Bool {
        guard let price = tier.price else { return false }
        guard balance >= price else {
            problem = "You are \((price - balance).coins) denari short of that pack."
            return false
        }
        do {
            _ = try await wallet.grant(-price, note: "pack/\(tier.rawValue)",
                                       key: "pack/\(tier.rawValue)/\(UUID().uuidString)")
            purse = try await wallet.purse()
            problem = nil
            return true
        } catch {
            problem = "That pack could not be bought."
            return false
        }
    }

    /// Pays a streak milestone: the denari, and the felt if it carries one. Keyed on the day
    /// the run reached it, so one run pays once. Nil when that day was already paid.
    func award(_ milestone: Streaks.Milestone, day: String) async -> Denari? {
        do {
            let fresh = try await wallet.grant(milestone.denari, note: "streak/\(milestone.days)",
                                               key: "streak/\(milestone.days)/\(day)")
            if let felt = milestone.felt, let item = Cosmetics.item(for: felt) {
                try await wallet.unlock(item, key: "streak/felt/\(felt.rawValue)")
            }
            purse = try await wallet.purse()
            return fresh.isEmpty ? nil : milestone.denari
        } catch {
            problem = "Your streak reward could not be saved."
            return nil
        }
    }

    /// Pays one of the week's tasks. Keyed on the week and the task, so redrawing the summary
    /// does not pay again.
    func award(_ goal: WeeklyChallenge.Goal, slot: Int, week: String) async -> Denari? {
        await grantChallenge(goal.denari, key: "challenge/\(week)/\(slot)")
    }

    /// Pays the bonus for finishing every task in a week, once per week.
    func awardWeek(_ week: String) async -> Denari? {
        await grantChallenge(WeeklyChallenge.allDoneBonus, key: "challenge/\(week)/all")
    }

    private func grantChallenge(_ amount: Denari, key: String) async -> Denari? {
        do {
            let fresh = try await wallet.grant(amount, note: key, key: key)
            purse = try await wallet.purse()
            return fresh.isEmpty ? nil : amount
        } catch {
            problem = "Your challenge reward could not be saved."
            return nil
        }
    }

    /// Pays a finished season. Keyed on the season, so a claim made twice, from two phones
    /// or a lost reply, pays once.
    @discardableResult
    func awardSeason(_ amount: Denari, season: String) async -> Denari? {
        do {
            let fresh = try await wallet.grant(amount, note: "season/\(season)", key: "season/\(season)")
            purse = try await wallet.purse()
            return fresh.isEmpty ? nil : amount
        } catch {
            problem = "Your season reward could not be saved."
            return nil
        }
    }

    /// Pays what an opened pack came to: the spares in it, and any suit or deck it
    /// finished. Keyed on the opening, so a grant retried pays once and two packs holding
    /// the same three cards are still two packs.
    @discardableResult
    func awardPack(_ amount: Denari, key: String) async -> Denari? {
        guard amount.isCredit else { return nil }
        do {
            let fresh = try await wallet.grant(amount, note: "pack", key: key)
            purse = try await wallet.purse()
            return fresh.isEmpty ? nil : amount
        } catch {
            problem = "What that pack paid could not be saved."
            return nil
        }
    }

    /// Denari for an opt-in ad. The caller's key is what makes it safe to retry: the shop
    /// keys on which watch it was, the end of a game on the game.
    func earnFromAd(_ amount: Denari, key: String) async {
        do {
            _ = try await wallet.grant(amount, note: "ad", key: key)
            purse = try await wallet.purse()
            problem = nil
        } catch {
            problem = "Your denari from that ad could not be saved."
        }
    }

    #if DEBUG
    /// Debug only. Moves the purse to exactly `amount`, up or down.
    ///
    /// Keyed afresh on every call rather than on the figure, unlike `grantForDebugging`:
    /// what it has to grant is the difference from whatever is already there, so the same
    /// figure asked for twice is two different grants.
    func setForDebugging(_ amount: Denari) async {
        let difference = amount - balance
        guard !difference.isZero else { return }
        _ = try? await wallet.grant(difference, note: "debug", key: "debug/purse/\(UUID().uuidString)")
        await update { try await wallet.purse() }
    }

    /// Debug only. The amount is part of the key, so the same figure grants once.
    func grantForDebugging(_ amount: Denari) async {
        _ = try? await wallet.grant(amount, note: "debug", key: "debug/\(amount)")
        await update { try await wallet.purse() }
    }
    #endif

    private func update(_ read: () async throws -> Purse) async {
        do {
            purse = try await read()
            problem = nil
        } catch {
            problem = "Your denari could not be read on this device."
        }
    }
}
