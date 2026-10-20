import Foundation

// Sets up the no-ads purchase in App Store Connect: the product, its name in each listing
// language, the price, where it is sold and the screenshot App Review asks for. Run it
// with Tools/seed-no-ads.sh.
//
// Idempotent, like the other seeders: whatever is already there is updated or left alone.
// The product id must match `AdFreePass.productID` in the app.

let noAds = Purchase(
    productID: "com.quentinvedrenne.scopa.noads",
    referenceName: "No ads",
    type: "NON_CONSUMABLE",
    reviewNote: """
    Settings (gear in the lobby) → Ads → Scopa without ads. It removes the banner under the \
    lobby and the full screen ad shown between games. The optional rewarded videos, which pay \
    in-game coins, stay available. Restore purchases sits in the same section.
    """,
    wordings: [
        ("en-US", "Scopa without ads", "No banner and no ad between games."),
        ("en-GB", "Scopa without ads", "No banner and no ad between games."),
        ("fr-FR", "Scopa sans pub", "Ni bannière ni pub entre les parties."),
        ("it", "Scopa senza pubblicità", "Niente banner né pubblicità tra le partite."),
    ],
    basePrice: "2.99")
noAds.checkWordings()

let arguments = CommandLine.arguments
guard arguments.count == 4 else { ASC.fail("usage: seed-no-ads <bundle id> <review screenshot> <promotional image>") }
let bundleID = arguments[1]
let screenshot = URL(fileURLWithPath: arguments[2])
let promo = URL(fileURLWithPath: arguments[3])

let app = ASC.app(bundleID: bundleID)
print("\(app.name) (\(bundleID))")

let purchaseID = noAds.upsert(appID: app.id, among: Purchase.existing(appID: app.id))
noAds.localize(purchaseID)
noAds.price(purchaseID)
noAds.sell(purchaseID, in: Purchase.territories())
Purchase.placeReviewScreenshot(screenshot, for: purchaseID)
// Drawn by Tools/render-no-ads.sh.
Purchase.placePromotionalImage(promo, for: purchaseID)

// The screenshot is processed after the upload, so the state can still read
// MISSING_METADATA here and turn READY_TO_SUBMIT a few seconds later.
print("done — \(noAds.productID) is \(Purchase.state(purchaseID))")
