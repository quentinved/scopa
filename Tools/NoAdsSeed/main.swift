import CryptoKit
import Foundation

// Sets up the no-ads purchase in App Store Connect: the product, its name in each listing
// language, the price, where it is sold and the screenshot App Review asks for. Run it
// with Tools/seed-no-ads.sh.
//
// Idempotent, like the other seeders: whatever is already there is updated or left alone.
// The product id must match `AdFreePass.productID` in the app.

// MARK: The product

let productID = "com.quentinvedrenne.scopa.noads"
let referenceName = "No ads"

/// Priced in euros in France; Apple converts it for every other storefront.
let baseTerritory = "FRA"
let basePrice = "2.99"

let reviewNote = """
Settings (gear in the lobby) → Ads → Scopa without ads. It removes the banner under the \
lobby and the full screen ad shown between games. The optional rewarded videos, which pay \
in-game coins, stay available. Restore purchases sits in the same section.
"""

/// What the App Store shows on the purchase sheet. 30 characters for the name, 45 for the
/// description.
let wordings: [(locale: String, name: String, description: String)] = [
    ("en-US", "Scopa without ads", "No banner and no ad between games."),
    ("en-GB", "Scopa without ads", "No banner and no ad between games."),
    ("fr-FR", "Scopa sans pub", "Ni bannière ni pub entre les parties."),
    ("it", "Scopa senza pubblicità", "Niente banner né pubblicità tra le partite."),
]

for wording in wordings {
    if wording.name.count > 30 { ASC.fail("\(wording.locale) name is over 30 characters") }
    if wording.description.count > 45 { ASC.fail("\(wording.locale) description is over 45 characters") }
}

let arguments = CommandLine.arguments
guard arguments.count == 4 else { ASC.fail("usage: seed-no-ads <bundle id> <review screenshot> <promotional image>") }
let bundleID = arguments[1]
let screenshot = URL(fileURLWithPath: arguments[2])
let promo = URL(fileURLWithPath: arguments[3])

let app = ASC.app(bundleID: bundleID)
print("\(app.name) (\(bundleID))")

// MARK: The purchase

let settings: [String: Any] = ["name": referenceName, "reviewNote": reviewNote]
let known = ASC.many(ASC.call("GET", "/v1/apps/\(app.id)/inAppPurchasesV2?limit=200"))
    .first { ASC.attributes($0)["productId"] as? String == productID }
let purchaseID: String
if let known {
    purchaseID = ASC.id(known)
    ASC.call("PATCH", "/v2/inAppPurchases/\(purchaseID)",
        ["data": ["type": "inAppPurchases", "id": purchaseID, "attributes": settings]])
    print("  \(productID): updated (\(ASC.attributes(known)["state"] as? String ?? "?"))")
} else {
    var create = settings
    create["productId"] = productID
    create["inAppPurchaseType"] = "NON_CONSUMABLE"
    let made = ASC.one(ASC.call("POST", "/v2/inAppPurchases", [
        "data": ["type": "inAppPurchases", "attributes": create,
                 "relationships": ["app": ASC.link("apps", app.id)]],
    ]))
    purchaseID = ASC.id(made)
    print("  \(productID): created")
}

// MARK: Names

let localizations = ASC.many(ASC.call("GET", "/v2/inAppPurchases/\(purchaseID)/inAppPurchaseLocalizations?limit=50"))
for wording in wordings {
    let text: [String: Any] = ["name": wording.name, "description": wording.description]
    if let existing = localizations.first(where: { ASC.attributes($0)["locale"] as? String == wording.locale }) {
        let id = ASC.id(existing)
        ASC.call("PATCH", "/v1/inAppPurchaseLocalizations/\(id)",
            ["data": ["type": "inAppPurchaseLocalizations", "id": id, "attributes": text]])
        print("    \(wording.locale): updated")
    } else {
        var create = text
        create["locale"] = wording.locale
        ASC.call("POST", "/v1/inAppPurchaseLocalizations", [
            "data": ["type": "inAppPurchaseLocalizations", "attributes": create,
                     "relationships": ["inAppPurchaseV2": ASC.link("inAppPurchases", purchaseID)]],
        ])
        print("    \(wording.locale): added")
    }
}

// MARK: Price

/// The price point for `basePrice` in the base territory. Price points are paged, so this
/// follows the `next` links until it finds it.
func pricePoint() -> String {
    var path: String? = "/v2/inAppPurchases/\(purchaseID)/pricePoints?filter%5Bterritory%5D=\(baseTerritory)&limit=200"
    while let page = path {
        let response = ASC.call("GET", page)
        if let match = ASC.many(response).first(where: { ASC.attributes($0)["customerPrice"] as? String == basePrice }) {
            return ASC.id(match)
        }
        let next = (response["links"] as? [String: Any])?["next"] as? String
        path = next.map { $0.replacingOccurrences(of: "https://api.appstoreconnect.apple.com", with: "") }
    }
    ASC.fail("no \(basePrice) price point in \(baseTerritory)")
}

// Posting a schedule replaces whatever was there, so running this again is harmless.
ASC.call("POST", "/v1/inAppPurchasePriceSchedules", [
    "data": ["type": "inAppPurchasePriceSchedules",
             "relationships": [
                "inAppPurchase": ASC.link("inAppPurchases", purchaseID),
                "baseTerritory": ASC.link("territories", baseTerritory),
                "manualPrices": ["data": [["type": "inAppPurchasePrices", "id": "${base}"]]],
             ]],
    "included": [["type": "inAppPurchasePrices", "id": "${base}",
                  "attributes": ["startDate": NSNull()],
                  "relationships": ["inAppPurchasePricePoint": ASC.link("inAppPurchasePricePoints", pricePoint())]]],
])
print("    price: €\(basePrice) in \(baseTerritory), converted elsewhere")

// MARK: Where it is sold

/// Every storefront there is, so the purchase is sold wherever the app is.
func allTerritories() -> [[String: Any]] {
    var found: [[String: Any]] = []
    var path: String? = "/v1/territories?limit=200"
    while let page = path {
        let response = ASC.call("GET", page)
        found += ASC.many(response).map { ["type": "territories", "id": ASC.id($0)] }
        let next = (response["links"] as? [String: Any])?["next"] as? String
        path = next.map { $0.replacingOccurrences(of: "https://api.appstoreconnect.apple.com", with: "") }
    }
    return found
}

let territories = allTerritories()
ASC.call("POST", "/v1/inAppPurchaseAvailabilities", [
    "data": ["type": "inAppPurchaseAvailabilities",
             "attributes": ["availableInNewTerritories": true],
             "relationships": [
                "inAppPurchase": ASC.link("inAppPurchases", purchaseID),
                "availableTerritories": ["data": territories],
             ]],
])
print("    sold in \(territories.count) storefronts, and any new ones")

// MARK: Pictures

/// Sends one picture through App Store Connect's reserve, upload, commit dance. `current`
/// is what is there already: a finished one is left alone, a failed or half-sent one is
/// deleted first, since it blocks the purchase as surely as a missing one.
func place(_ file: URL, as type: String, current: [String: Any], label: String) {
    guard let bytes = try? Data(contentsOf: file) else { ASC.fail("no \(label) at \(file.path)") }
    let state = (ASC.attributes(current)["assetDeliveryState"] as? [String: Any])?["state"] as? String
    if !ASC.id(current).isEmpty {
        if state == "COMPLETE" || state == "UPLOAD_COMPLETE" {
            print("    \(label) already uploaded")
            return
        }
        ASC.call("DELETE", "/v1/\(type)/\(ASC.id(current))")
    }
    let fileName = file.lastPathComponent
    let reservation = ASC.one(ASC.call("POST", "/v1/\(type)", [
        "data": ["type": type,
                 "attributes": ["fileSize": bytes.count, "fileName": fileName],
                 "relationships": [type == "inAppPurchaseImages" ? "inAppPurchase" : "inAppPurchaseV2":
                                    ASC.link("inAppPurchases", purchaseID)]],
    ]))
    let assetID = ASC.id(reservation)
    for operation in ASC.attributes(reservation)["uploadOperations"] as? [[String: Any]] ?? [] {
        guard let address = operation["url"] as? String, let url = URL(string: address),
              let offset = operation["offset"] as? Int, let length = operation["length"] as? Int else {
            ASC.fail("\(fileName): malformed upload operation")
        }
        var upload = URLRequest(url: url)
        upload.httpMethod = operation["method"] as? String ?? "PUT"
        for header in operation["requestHeaders"] as? [[String: Any]] ?? [] {
            if let name = header["name"] as? String, let value = header["value"] as? String {
                upload.setValue(value, forHTTPHeaderField: name)
            }
        }
        upload.httpBody = bytes.subdata(in: offset..<(offset + length))
        let (status, _) = ASC.send(upload)
        guard (200..<300).contains(status) else { ASC.fail("\(fileName): upload returned HTTP \(status)") }
    }
    let checksum = Insecure.MD5.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    ASC.call("PATCH", "/v1/\(type)/\(assetID)",
        ["data": ["type": type, "id": assetID,
                  "attributes": ["uploaded": true, "sourceFileChecksum": checksum]]])
    print("    \(label) uploaded (\(bytes.count) bytes)")
}

// What App Review sees: the purchase where the player finds it.
place(screenshot, as: "inAppPurchaseAppStoreReviewScreenshots",
      current: ASC.one(ASC.call("GET", "/v2/inAppPurchases/\(purchaseID)/appStoreReviewScreenshot")),
      label: "review screenshot")

// What the App Store shows if the purchase is promoted on the app's page. Opaque, 1024
// square, drawn by Tools/render-no-ads.sh.
place(promo, as: "inAppPurchaseImages",
      current: ASC.many(ASC.call("GET", "/v2/inAppPurchases/\(purchaseID)/images")).first ?? [:],
      label: "promotional image")

// The screenshot is processed after the upload, so the state can still read
// MISSING_METADATA here and turn READY_TO_SUBMIT a few seconds later.
let state = ASC.attributes(ASC.one(ASC.call("GET", "/v2/inAppPurchases/\(purchaseID)")))["state"] as? String ?? "?"
print("done — \(productID) is \(state)")
