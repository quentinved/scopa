import CryptoKit
import Foundation

/// One in-app purchase as App Store Connect holds it: the product, its names, its price,
/// where it is sold and its pictures. The seeders say what to sell; this is how it gets there.
///
/// Every step is idempotent: whatever is already there is updated or left alone.
struct Purchase {
    let productID: String
    let referenceName: String
    /// `NON_CONSUMABLE` or `CONSUMABLE`. Only read when the product is made: it cannot change.
    let type: String
    let reviewNote: String
    /// What the App Store shows on the purchase sheet.
    let wordings: [(locale: String, name: String, description: String)]
    /// In euros in France; Apple converts it for every other storefront.
    let basePrice: String
    /// Storefronts it is kept out of, as territory ids (ISO 3166 alpha-3).
    var withheld: Set<String> = []

    static let baseTerritory = "FRA"
}

// MARK: The product

extension Purchase {
    /// Refuses what App Store Connect would: 30 characters for a name, 45 for a description.
    func checkWordings() {
        for wording in wordings {
            if wording.name.count > 30 { ASC.fail("\(wording.locale) name is over 30 characters") }
            if wording.description.count > 45 { ASC.fail("\(wording.locale) description is over 45 characters") }
        }
    }

    /// Every in-app purchase the app has, to find one already made.
    static func existing(appID: String) -> [[String: Any]] {
        ASC.many(ASC.call("GET", "/v1/apps/\(appID)/inAppPurchasesV2?limit=200"))
    }

    /// Makes the product, or updates the name and review note of the one already there.
    /// Returns its id in App Store Connect.
    func upsert(appID: String, among existing: [[String: Any]]) -> String {
        let settings: [String: Any] = ["name": referenceName, "reviewNote": reviewNote]
        if let known = existing.first(where: { ASC.attributes($0)["productId"] as? String == productID }) {
            let id = ASC.id(known)
            ASC.call("PATCH", "/v2/inAppPurchases/\(id)",
                ["data": ["type": "inAppPurchases", "id": id, "attributes": settings]])
            print("  \(productID): updated (\(ASC.attributes(known)["state"] as? String ?? "?"))")
            return id
        }
        var create = settings
        create["productId"] = productID
        create["inAppPurchaseType"] = type
        let made = ASC.one(ASC.call("POST", "/v2/inAppPurchases", [
            "data": ["type": "inAppPurchases", "attributes": create,
                     "relationships": ["app": ASC.link("apps", appID)]],
        ]))
        print("  \(productID): created")
        return ASC.id(made)
    }

    func localize(_ purchaseID: String) {
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
    }

    static func state(_ purchaseID: String) -> String {
        ASC.attributes(ASC.one(ASC.call("GET", "/v2/inAppPurchases/\(purchaseID)")))["state"] as? String ?? "?"
    }
}

// MARK: Price and storefronts

extension Purchase {
    // Posting a schedule replaces whatever was there, so running this again is harmless.
    func price(_ purchaseID: String) {
        let point = Self.pages("/v2/inAppPurchases/\(purchaseID)/pricePoints?filter%5Bterritory%5D=\(Self.baseTerritory)&limit=200")
            .first { ASC.attributes($0)["customerPrice"] as? String == basePrice }
        guard let point else { ASC.fail("no \(basePrice) price point in \(Self.baseTerritory)") }
        ASC.call("POST", "/v1/inAppPurchasePriceSchedules", [
            "data": ["type": "inAppPurchasePriceSchedules",
                     "relationships": [
                        "inAppPurchase": ASC.link("inAppPurchases", purchaseID),
                        "baseTerritory": ASC.link("territories", Self.baseTerritory),
                        "manualPrices": ["data": [["type": "inAppPurchasePrices", "id": "${base}"]]],
                     ]],
            "included": [["type": "inAppPurchasePrices", "id": "${base}",
                          "attributes": ["startDate": NSNull()],
                          "relationships": ["inAppPurchasePricePoint": ASC.link("inAppPurchasePricePoints", ASC.id(point))]]],
        ])
        print("    price: €\(basePrice) in \(Self.baseTerritory), converted elsewhere")
    }

    /// Every storefront there is, as territory ids.
    static func territories() -> [String] {
        pages("/v1/territories?limit=200").map(ASC.id)
    }

    /// Sold in every storefront but the withheld ones, and in any new one Apple opens.
    func sell(_ purchaseID: String, in territories: [String]) {
        let sold = territories.filter { !withheld.contains($0) }
        ASC.call("POST", "/v1/inAppPurchaseAvailabilities", [
            "data": ["type": "inAppPurchaseAvailabilities",
                     "attributes": ["availableInNewTerritories": true],
                     "relationships": [
                        "inAppPurchase": ASC.link("inAppPurchases", purchaseID),
                        "availableTerritories": ["data": sold.map { ["type": "territories", "id": $0] }],
                     ]],
        ])
        let left = withheld.isEmpty ? "" : ", not in \(withheld.sorted().joined(separator: " or "))"
        print("    sold in \(sold.count) storefronts\(left), and any new ones")
    }

    /// Every object a paged list holds, following its `next` links.
    private static func pages(_ first: String) -> [[String: Any]] {
        var found: [[String: Any]] = []
        var path: String? = first
        while let page = path {
            let response = ASC.call("GET", page)
            found += ASC.many(response)
            let next = (response["links"] as? [String: Any])?["next"] as? String
            path = next.map { $0.replacingOccurrences(of: "https://api.appstoreconnect.apple.com", with: "") }
        }
        return found
    }
}

// MARK: Pictures

extension Purchase {
    /// What App Review sees: the purchase where the player finds it.
    static func placeReviewScreenshot(_ file: URL, for purchaseID: String) {
        place(file, as: "inAppPurchaseAppStoreReviewScreenshots", for: purchaseID,
              current: ASC.one(ASC.call("GET", "/v2/inAppPurchases/\(purchaseID)/appStoreReviewScreenshot")),
              label: "review screenshot")
    }

    /// What the App Store shows if the purchase is promoted on the app's page. Opaque, 1024 square.
    static func placePromotionalImage(_ file: URL, for purchaseID: String) {
        place(file, as: "inAppPurchaseImages", for: purchaseID,
              current: ASC.many(ASC.call("GET", "/v2/inAppPurchases/\(purchaseID)/images")).first ?? [:],
              label: "promotional image")
    }

    /// Sends one picture through App Store Connect's reserve, upload, commit dance. `current`
    /// is what is there already: a finished one is left alone, a failed or half-sent one is
    /// deleted first, since it blocks the purchase as surely as a missing one.
    /// `ASC_REPLACE_IMAGES=1` replaces a finished one too, for when what it shows changed.
    private static func place(_ file: URL, as type: String, for purchaseID: String, current: [String: Any], label: String) {
        guard let bytes = try? Data(contentsOf: file) else { ASC.fail("no \(label) at \(file.path)") }
        let state = (ASC.attributes(current)["assetDeliveryState"] as? [String: Any])?["state"] as? String
        let replaces = ProcessInfo.processInfo.environment["ASC_REPLACE_IMAGES"] == "1"
        if !ASC.id(current).isEmpty {
            if !replaces, state == "COMPLETE" || state == "UPLOAD_COMPLETE" {
                print("    \(label) already uploaded")
                return
            }
            ASC.call("DELETE", "/v1/\(type)/\(ASC.id(current))")
        }
        let reservation = ASC.one(ASC.call("POST", "/v1/\(type)", [
            "data": ["type": type,
                     "attributes": ["fileSize": bytes.count, "fileName": file.lastPathComponent],
                     "relationships": [type == "inAppPurchaseImages" ? "inAppPurchase" : "inAppPurchaseV2":
                                        ASC.link("inAppPurchases", purchaseID)]],
        ]))
        upload(bytes, named: file.lastPathComponent, by: ASC.attributes(reservation)["uploadOperations"])
        let checksum = Insecure.MD5.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        ASC.call("PATCH", "/v1/\(type)/\(ASC.id(reservation))",
            ["data": ["type": type, "id": ASC.id(reservation),
                      "attributes": ["uploaded": true, "sourceFileChecksum": checksum]]])
        print("    \(label) uploaded (\(bytes.count) bytes)")
    }

    private static func upload(_ bytes: Data, named fileName: String, by operations: Any?) {
        for operation in operations as? [[String: Any]] ?? [] {
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
    }
}
