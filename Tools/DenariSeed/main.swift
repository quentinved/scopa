import Foundation

// Sets up the three bags of denari in App Store Connect: a consumable each, with its names,
// price, storefronts and the screenshot App Review asks for. Run it with Tools/seed-denari.sh.
//
// Idempotent, like the other seeders. Ids and amounts must match `DenariBag` in
// ScopaRewards, and Belgium and the Netherlands stay out, as `DenariBag.withheldStorefronts`
// keeps them out in the app.

let bags: [(id: String, title: String, denari: Int, price: String)] = [
    ("mancia", "Mancia", 2_500, "0.99"),
    ("borsellino", "Borsellino", 12_000, "3.99"),
    ("tesoretto", "Tesoretto", 30_000, "7.99"),
]

let reviewNote = """
Lobby → the denari chip at the top (opens the Shop) → "In a hurry?" → Buy a bag of denari. \
Denari are the game's coins, also earned by playing. They buy cosmetics and album card \
packs only, never an advantage, and every pack's odds are shown before it is bought (Odds, \
beside each shelf of packs). The denari are added the moment the purchase completes.
"""

/// "1,000", "1 000", "12.000": the number the way each listing writes it, with a plain
/// space, since App Store Connect refuses the narrow no-break one French grouping uses.
func amount(_ denari: Int, in locale: String) -> String {
    denari.formatted(.number.locale(Locale(identifier: locale)))
        .replacingOccurrences(of: "\u{202F}", with: " ")
        .replacingOccurrences(of: "\u{00A0}", with: " ")
}

func purchase(_ bag: (id: String, title: String, denari: Int, price: String)) -> Purchase {
    let en = amount(bag.denari, in: "en_US"), fr = amount(bag.denari, in: "fr_FR"), it = amount(bag.denari, in: "it_IT")
    return Purchase(
        productID: "com.quentinvedrenne.scopa.denari.\(bag.id)",
        referenceName: "Denari · \(bag.title) (\(en))",
        type: "CONSUMABLE",
        reviewNote: reviewNote,
        wordings: [
            ("en-US", "\(bag.title) · \(en) denari", "\(en) denari, straight into your purse."),
            ("en-GB", "\(bag.title) · \(en) denari", "\(en) denari, straight into your purse."),
            ("fr-FR", "\(bag.title) · \(fr) deniers", "\(fr) deniers, droit dans votre bourse."),
            ("it", "\(bag.title) · \(it) denari", "\(it) denari, dritti nel borsellino."),
        ],
        basePrice: bag.price,
        withheld: ["BEL", "NLD"])
}

let purchases = bags.map(purchase)
purchases.forEach { $0.checkWordings() }

let arguments = CommandLine.arguments
guard arguments.count == 3 else { ASC.fail("usage: seed-denari <bundle id> <review screenshot>") }
let bundleID = arguments[1]
let screenshot = URL(fileURLWithPath: arguments[2])

let app = ASC.app(bundleID: bundleID)
print("\(app.name) (\(bundleID))")

let existing = Purchase.existing(appID: app.id)
let territories = Purchase.territories()
for bag in purchases {
    let id = bag.upsert(appID: app.id, among: existing)
    bag.localize(id)
    bag.price(id)
    bag.sell(id, in: territories)
    Purchase.placeReviewScreenshot(screenshot, for: id)
    // Processed after the upload, so this can read MISSING_METADATA for a few seconds more.
    print("  \(bag.productID) is \(Purchase.state(id))")
}
print("done")
