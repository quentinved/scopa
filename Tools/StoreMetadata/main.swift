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

// Checked before the first call: Apple refuses an over-long field only once the locales
// before it have already gone through.
for listing in listings {
    let limits = [("name", listing.name, 30), ("subtitle", listing.subtitle, 30),
                  ("keywords", listing.keywords, 100), ("promotional text", listing.promotional, 170),
                  ("description", listing.description, 4000)]
    for (field, value, limit) in limits where value.count > limit {
        ASC.fail("\(listing.locale) \(field) is \(value.count) characters, over \(limit)")
    }
}

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

// Answered against what the app contains. Simulated gambling is None because the wager
// tables are switched off (`LobbyView.offersWagers`): Apple will not review a gambling
// rating from an individual account (2.3.6, September 2026). Turn them back on and this
// goes back to INFREQUENT_OR_MILD. Card packs have random contents, which is a loot box
// whether or not denari can be bought.
let declaration: [String: Any] = [
    "alcoholTobaccoOrDrugUseOrReferences": "NONE",
    "contests": "NONE",
    "gamblingSimulated": "NONE",
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
    "lootBox": true,
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

// A live app takes a new listing only on a new version: SCOPA_VERSION=1.0.1 opens one when
// none is being prepared. Apple copies the live version's text and screenshots into it.
let isEditable: ([String: Any]) -> Bool = {
    let attributes = ASC.attributes($0)
    return attributes["platform"] as? String == "IOS"
        && ASC.editableVersionStates.contains(attributes["appVersionState"] as? String ?? "")
}
var prepared = ASC.many(ASC.call("GET", "/v1/apps/\(app.id)/appStoreVersions")).first(where: isEditable)
if prepared == nil, let wanted = ASC.environment["SCOPA_VERSION"] {
    ASC.call("POST", "/v1/appStoreVersions", [
        "data": ["type": "appStoreVersions",
                 "attributes": ["platform": "IOS", "versionString": wanted],
                 "relationships": ["app": ASC.link("apps", app.id)]],
    ])
    print("  version \(wanted): opened")
    prepared = ASC.many(ASC.call("GET", "/v1/apps/\(app.id)/appStoreVersions")).first(where: isEditable)
}
guard let version = prepared else { ASC.fail("no iOS version being prepared (SCOPA_VERSION=x.y.z opens one)") }
let versionID = ASC.id(version)
let versionString = ASC.attributes(version)["versionString"] as? String ?? "?"

ASC.call("PATCH", "/v1/appStoreVersions/\(versionID)", [
    "data": ["type": "appStoreVersions", "id": versionID,
             "attributes": ["copyright": "2026 Quentin Vedrenne", "releaseType": "AFTER_APPROVAL"]],
])
print("  version \(versionString): copyright set")

let versionLocalizations = ASC.many(ASC.call("GET", "/v1/appStoreVersions/\(versionID)/appStoreVersionLocalizations"))
for listing in listings {
    // `whatsNew` is left alone: it describes a build rather than the game, so it is written
    // in App Store Connect when the build is chosen. Apple rejects it on a first release.
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

No wagering: denari cannot be staked on the result of a game, and nothing can be cashed \
out or traded.

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
