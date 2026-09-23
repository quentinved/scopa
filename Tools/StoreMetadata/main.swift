import Foundation

// Pushes the App Store listing in Tools/StoreMetadata/copy.swift to App Store Connect:
// categories, the name, subtitle and privacy policy on the app record, and the
// description, keywords, promotional text and support URL on the version being prepared.
// Run it with Tools/push-metadata.sh.
//
// Idempotent, like the achievement seeder: a locale that is already there is updated, one
// that is missing is added. It never submits anything for review.

let arguments = CommandLine.arguments
guard arguments.count == 2 else { ASC.fail("usage: push-metadata <bundle id>") }
let bundleID = arguments[1]
let supportURL = ASC.environment["SCOPA_SUPPORT_URL"] ?? defaultSupportURL

let app = ASC.app(bundleID: bundleID)
print("\(app.name) (\(bundleID))")

// MARK: The app record

let infos = ASC.many(ASC.call("GET", "/v1/apps/\(app.id)/appInfos"))
guard let info = infos.first(where: { ASC.attributes($0)["state"] as? String == "PREPARE_FOR_SUBMISSION" })
    ?? infos.first else { ASC.fail("no editable app info") }
let infoID = ASC.id(info)

ASC.call("PATCH", "/v1/appInfos/\(infoID)", [
    "data": ["type": "appInfos", "id": infoID, "relationships": [
        "primaryCategory": ASC.link("appCategories", "GAMES"),
        "primarySubcategoryOne": ASC.link("appCategories", "GAMES_CARD"),
        "primarySubcategoryTwo": ASC.link("appCategories", "GAMES_BOARD"),
    ]],
])
print("  categories: Games / Card / Board")

let infoLocalizations = ASC.many(ASC.call("GET", "/v1/appInfos/\(infoID)/appInfoLocalizations"))
for listing in listings {
    let fields: [String: Any] = ["name": listing.name, "subtitle": listing.subtitle,
                                 "privacyPolicyUrl": privacyURL]
    if let known = infoLocalizations.first(where: { ASC.attributes($0)["locale"] as? String == listing.locale }) {
        ASC.call("PATCH", "/v1/appInfoLocalizations/\(ASC.id(known))", [
            "data": ["type": "appInfoLocalizations", "id": ASC.id(known), "attributes": fields],
        ])
        print("  \(listing.locale): name and subtitle updated")
    } else {
        var create = fields
        create["locale"] = listing.locale
        ASC.call("POST", "/v1/appInfoLocalizations", [
            "data": ["type": "appInfoLocalizations", "attributes": create,
                     "relationships": ["appInfo": ASC.link("appInfos", infoID)]],
        ])
        print("  \(listing.locale): added")
    }
}

// MARK: The age rating

// Answered against what the app contains. The one that matters is simulated gambling:
// wager tables stake denari on a hand. Denari cannot be bought and the shop is cosmetic,
// but staking a virtual currency on an outcome is what the question asks about.
let declaration: [String: Any] = [
    "alcoholTobaccoOrDrugUseOrReferences": "NONE",
    "contests": "NONE",
    "gamblingSimulated": "INFREQUENT_OR_MILD",
    "gambling": false,
    "gunsOrOtherWeapons": "NONE",
    "horrorOrFearThemes": "NONE",
    "matureOrSuggestiveThemes": "NONE",
    "medicalOrTreatmentInformation": "NONE",
    "profanityOrCrudeHumor": "NONE",
    "sexualContentGraphicAndNudity": "NONE",
    "sexualContentOrNudity": "NONE",
    "violenceCartoonOrFantasy": "NONE",
    "violenceRealistic": "NONE",
    "violenceRealisticProlongedGraphicOrSadistic": "NONE",
    // No chat and no free text reaches another player: reactions are a fixed set, and the
    // only thing you type is the name over your own seat.
    "messagingAndChat": false,
    "userGeneratedContent": false,
    "unrestrictedWebAccess": false,
    "lootBox": false,
    "advertising": true,
    "healthOrWellnessTopics": false,
    // No age gate and no in-app parental controls: there is nothing in the game to gate.
    "parentalControls": false,
    "ageAssurance": false,
]
ASC.call("PATCH", "/v1/ageRatingDeclarations/\(infoID)", [
    "data": ["type": "ageRatingDeclarations", "id": infoID, "attributes": declaration],
])
let rated = ASC.attributes(ASC.one(ASC.call("GET", "/v1/appInfos/\(infoID)")))
print("  age rating: \(rated["appStoreAgeRating"] as? String ?? "not computed yet")")

// MARK: The version

let versions = ASC.many(ASC.call("GET", "/v1/apps/\(app.id)/appStoreVersions"))
guard let version = versions.first(where: {
    let attributes = ASC.attributes($0)
    return attributes["platform"] as? String == "IOS"
        && attributes["appVersionState"] as? String == "PREPARE_FOR_SUBMISSION"
}) else { ASC.fail("no iOS version being prepared") }
let versionID = ASC.id(version)
let versionString = ASC.attributes(version)["versionString"] as? String ?? "?"

ASC.call("PATCH", "/v1/appStoreVersions/\(versionID)", [
    "data": ["type": "appStoreVersions", "id": versionID,
             "attributes": ["copyright": "2026 Quentin Vedrenne", "releaseType": "AFTER_APPROVAL"]],
])
print("  version \(versionString): copyright set")

let versionLocalizations = ASC.many(ASC.call("GET", "/v1/appStoreVersions/\(versionID)/appStoreVersionLocalizations"))
for listing in listings {
    // `whatsNew` is left alone: there is nothing new about a first release, and Apple
    // rejects the field on one.
    let fields: [String: Any] = ["description": listing.description, "keywords": listing.keywords,
                                 "promotionalText": listing.promotional, "supportUrl": supportURL]
    if let known = versionLocalizations.first(where: { ASC.attributes($0)["locale"] as? String == listing.locale }) {
        ASC.call("PATCH", "/v1/appStoreVersionLocalizations/\(ASC.id(known))", [
            "data": ["type": "appStoreVersionLocalizations", "id": ASC.id(known), "attributes": fields],
        ])
        print("  \(listing.locale): description and keywords updated")
    } else {
        var create = fields
        create["locale"] = listing.locale
        ASC.call("POST", "/v1/appStoreVersionLocalizations", [
            "data": ["type": "appStoreVersionLocalizations", "attributes": create,
                     "relationships": ["appStoreVersion": ASC.link("appStoreVersions", versionID)]],
        ])
        print("  \(listing.locale): description added")
    }
}

// MARK: What review needs to know

// Written for a reviewer who has never seen the game and has one device.
let notes = """
No account, sign-up or demo credentials are needed. Everything opens from the lobby.

Fastest way to see a full game on one device: tap Quick game on the lobby (a game against \
a bot), or Pass the phone, which runs a whole table on a single device. The rules are in \
Settings, and an optional coach explains every card in hand.

Game Center: signing in is optional. It is used for Ranked, for playing strangers online, \
for inviting a Game Center friend, and to keep progress the same on a player's iPhone and \
iPad. Quick game, Pass the phone, Nearby and a table code all work signed out. Ranked \
never leaves a reviewer waiting: if no opponent is found, a bot (Hugo) takes the chair.

Playing another person needs a second device. Nearby uses Wi-Fi and Bluetooth directly \
between devices. A table code ("Meet at a code word" or "Join with a code") connects two \
devices through our own relay server without any sign-in; the relay passes moves in real \
time and keeps nothing once the table closes.

Currency: denari are earned by playing, by the daily deal and, up to three times a day, \
by choosing to watch a rewarded ad. They cannot be bought: the app contains no in-app \
purchase of any kind and no real money can enter the game. Denari buy cosmetics only — \
felts, card backs, table marks, reaction sets — and card packs for a collectible album. \
Pack contents are random, the odds are shown before opening ("What is in a pack"), a pack \
never repeats a card already owned, and a free pack also comes every three games. Nothing \
bought or won changes how a hand is played or scored.

Stakes: some online tables let a player put earned denari on the result (the reason the \
age rating declares infrequent simulated gambling). Only earned, non-purchasable denari \
can be staked; nothing can be cashed out or traded.

Ads: Google AdMob — a banner in the lobby, an occasional interstitial at the end of a \
game, and the optional rewarded ad above. In the EEA, Google's consent form appears \
on first launch and can be reopened from Settings > Your privacy choices. The App Tracking \
Transparency prompt is shown before any ad request; declining it leaves the game identical.

Privacy policy: \(privacyURL)
"""

let existingDetail = ASC.one(ASC.call("GET", "/v1/appStoreVersions/\(versionID)/appStoreReviewDetail"))
var contact: [String: Any] = [
    "contactFirstName": "Quentin",
    "contactLastName": "Vedrenne",
    "contactEmail": "contact@quentinvedrenne.com",
    "demoAccountRequired": false,
    "notes": notes,
]
if let phone = ASC.environment["SCOPA_CONTACT_PHONE"] { contact["contactPhone"] = phone }

if ASC.id(existingDetail).isEmpty {
    ASC.call("POST", "/v1/appStoreReviewDetails", [
        "data": ["type": "appStoreReviewDetails", "attributes": contact,
                 "relationships": ["appStoreVersion": ASC.link("appStoreVersions", versionID)]],
    ])
    print("  review notes: added")
} else {
    ASC.call("PATCH", "/v1/appStoreReviewDetails/\(ASC.id(existingDetail))", [
        "data": ["type": "appStoreReviewDetails", "id": ASC.id(existingDetail), "attributes": contact],
    ])
    print("  review notes: updated")
}

print("done — \(listings.count) languages")
