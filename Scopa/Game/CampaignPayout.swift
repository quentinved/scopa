import Foundation
import ScopaCore
import ScopaRewards

/// A campaign game, settled on the final summary beside the usual payout: the stars written
/// down, and what a first win, three stars or a region's last table pay.
///
/// The game itself pays like any game against bots, through `PurseStore.settle`; this only
/// adds what the road gives on top. The stars say what was earned, the ledger's keys what was
/// paid, so a payment that failed is made after the next campaign game rather than lost.
@MainActor
enum CampaignPayout {
    /// `stage` is the table played, read before anything was awaited: leaving the table
    /// clears the store's own.
    static func settle(_ tally: RewardTally, at stage: CampaignStage?, in view: PlayerView,
                       store: TableStore, purse: PurseStore, locale: Locale) async -> [PayoutLine] {
        guard let stage, tally.isSettled else { return [] }
        let earned = stage.stars(won: tally.outcome == .won, margin: margin(of: tally.side, in: view),
                                 scope: tally.scope)
        guard store.campaignBook.record(stage, stars: earned, game: tally.gameID) != nil else { return [] }
        if earned > 0 { CampaignStandings.report(store.campaignBook, store: store) }
        var paid: [PayoutLine] = []
        for stage in Campaign.stages {
            paid += await payOwed(stage, store: store, purse: purse, locale: locale)
        }
        return paid
    }

    /// Your side's points less the best of the rest.
    static func margin(of side: Int, in view: PlayerView) -> Int {
        let mine = view.scores[safe: side] ?? 0
        let best = view.scores.enumerated().filter { $0.offset != side }.map(\.element).max() ?? 0
        return mine - best
    }

    /// Whatever this table's stars have earned and the ledger does not yet hold.
    private static func payOwed(_ stage: CampaignStage, store: TableStore, purse: PurseStore,
                                locale: Locale) async -> [PayoutLine] {
        let stars = store.campaignBook.keptStars(of: stage)
        guard stars > 0 else { return [] }
        var paid: [PayoutLine] = []
        if !clearKeys(stage).isSubset(of: purse.purse.keys) {
            paid += await payClear(stage, store: store, purse: purse, locale: locale)
        }
        let starsKey = "campaign/\(stage.id)/stars"
        if stars == 3, !purse.purse.keys.contains(starsKey),
           let credited = await purse.awardCampaign(CampaignStage.threeStarBonus, key: starsKey) {
            paid.append(PayoutLine(id: "campaign.stars.\(stage.id)",
                                   title: String(localized: "Three stars at \(stage.place)", locale: locale),
                                   value: credited))
        }
        return paid
    }

    /// The first win at a table: its denari, and on a region's last table the prize and a pack.
    /// The pack only when the denari were paid just now, as that is the ledger's word that
    /// nobody has had it.
    private static func payClear(_ stage: CampaignStage, store: TableStore, purse: PurseStore,
                                 locale: Locale) async -> [PayoutLine] {
        guard let credited = await purse.awardCampaign(stage.denari, items: prizes(stage), key: clearKey(stage))
        else { return [] }
        if stage.isFinale { store.albumBook.give(stage.region.pack) }
        return [PayoutLine(id: "campaign.clear.\(stage.id)",
                           title: String(localized: "Won at \(stage.place)", locale: locale),
                           value: credited)]
    }

    private static func prizes(_ stage: CampaignStage) -> [ShopItem] {
        stage.isFinale ? [stage.region.prizeItem].compactMap { $0 } : []
    }

    private static func clearKey(_ stage: CampaignStage) -> String { "campaign/\(stage.id)" }

    /// The clear's own key and its prize's, as `PurseStore.awardCampaign` writes them.
    private static func clearKeys(_ stage: CampaignStage) -> Set<String> {
        let key = clearKey(stage)
        return Set([key] + prizes(stage).map { "\(key)/\($0.id.rawValue)" })
    }
}
