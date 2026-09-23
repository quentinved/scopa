import Foundation

// Seeds the Game Center achievements in App Store Connect from the catalogue below.
// Run it with Tools/seed-achievements.sh.
//
// Idempotent: an achievement that already exists is updated rather than duplicated, and
// artwork is only re-uploaded when it is missing or half-uploaded. The ids have to match
// `Achievements.ID` in the app exactly, since GKAchievement.report swallows a mismatch.

// MARK: The catalogue

/// What one language calls a badge. Game Center keeps a set of these per achievement, and
/// shows the player whichever matches their phone.
struct Wording {
    let title: String
    let before: String
    let after: String
}

struct Badge {
    let id: String          // vendorIdentifier, and the PNG's file name
    let reference: String   // internal, never shown to players
    let points: Int
    let words: [String: Wording]   // locale → what it says
}

/// The same three languages the App Store listing speaks.
let locales = ["en-US", "fr-FR", "it"]

let catalogue: [Badge] = [
    Badge(id: "first_scopa", reference: "First Scopa", points: 5, words: [
        "en-US": Wording(title: "Scopa!",
                         before: "Sweep the table clean for the first time.",
                         after: "You swept the table clean."),
        "fr-FR": Wording(title: "Scopa !",
                         before: "Balayez la table pour la première fois.",
                         after: "Vous avez balayé la table."),
        "it": Wording(title: "Scopa!",
                      before: "Fai scopa per la prima volta.",
                      after: "Hai spazzato il tavolo."),
    ]),
    Badge(id: "scope_50", reference: "Fifty Scope", points: 50, words: [
        "en-US": Wording(title: "The Broom",
                         before: "Sweep the table 50 times.",
                         after: "Fifty tables swept clean."),
        "fr-FR": Wording(title: "Le Balai",
                         before: "Balayez la table 50 fois.",
                         after: "Cinquante tables balayées."),
        "it": Wording(title: "La Scopa",
                      before: "Fai scopa 50 volte.",
                      after: "Cinquanta tavoli spazzati."),
    ]),
    Badge(id: "first_settebello", reference: "First Settebello", points: 5, words: [
        "en-US": Wording(title: "Settebello",
                         before: "Take the seven of coins.",
                         after: "The seven of coins was yours."),
        "fr-FR": Wording(title: "Settebello",
                         before: "Prenez le sept de deniers.",
                         after: "Le sept de deniers était à vous."),
        "it": Wording(title: "Settebello",
                      before: "Prendi il sette di denari.",
                      after: "Il sette di denari era tuo."),
    ]),
    Badge(id: "settebello_25", reference: "Twenty-Five Settebelli", points: 50, words: [
        "en-US": Wording(title: "Coin Collector",
                         before: "Take the seven of coins 25 times.",
                         after: "Twenty-five sevens of coins."),
        "fr-FR": Wording(title: "Amasseur de deniers",
                         before: "Prenez le sept de deniers 25 fois.",
                         after: "Vingt-cinq sept de deniers."),
        "it": Wording(title: "Collezionista di denari",
                      before: "Prendi il sette di denari 25 volte.",
                      after: "Venticinque sette di denari."),
    ]),
    Badge(id: "first_cappotto", reference: "First Cappotto", points: 25, words: [
        "en-US": Wording(title: "Cappotto",
                         before: "Win all four scoring categories in one round.",
                         after: "All four categories, one round."),
        "fr-FR": Wording(title: "Cappotto",
                         before: "Gagnez les quatre catégories en une manche.",
                         after: "Les quatre catégories, en une manche."),
        "it": Wording(title: "Cappotto",
                      before: "Vinci tutte e quattro le categorie in una mano.",
                      after: "Tutte e quattro le categorie, in una mano."),
    ]),
    Badge(id: "first_win", reference: "First Win", points: 5, words: [
        "en-US": Wording(title: "First Blood",
                         before: "Win your first game.",
                         after: "Your first game won."),
        "fr-FR": Wording(title: "La première victoire",
                         before: "Gagnez votre première partie.",
                         after: "Votre première partie gagnée."),
        "it": Wording(title: "La prima vittoria",
                      before: "Vinci la tua prima partita.",
                      after: "La tua prima partita vinta."),
    ]),
    Badge(id: "wins_25", reference: "Twenty-Five Wins", points: 50, words: [
        "en-US": Wording(title: "Regular",
                         before: "Win 25 games.",
                         after: "Twenty-five games won."),
        "fr-FR": Wording(title: "Habitué",
                         before: "Gagnez 25 parties.",
                         after: "Vingt-cinq parties gagnées."),
        "it": Wording(title: "Uno di casa",
                      before: "Vinci 25 partite.",
                      after: "Venticinque partite vinte."),
    ]),
    Badge(id: "wins_100", reference: "One Hundred Wins", points: 100, words: [
        "en-US": Wording(title: "Maestro",
                         before: "Win 100 games.",
                         after: "One hundred games won."),
        "fr-FR": Wording(title: "Maestro",
                         before: "Gagnez 100 parties.",
                         after: "Cent parties gagnées."),
        "it": Wording(title: "Maestro",
                      before: "Vinci 100 partite.",
                      after: "Cento partite vinte."),
    ]),
    Badge(id: "first_daily", reference: "First Daily Deal", points: 5, words: [
        "en-US": Wording(title: "The Daily",
                         before: "Play your first daily deal.",
                         after: "Your first daily deal played."),
        "fr-FR": Wording(title: "La donne du jour",
                         before: "Jouez votre première donne du jour.",
                         after: "Votre première donne du jour jouée."),
        "it": Wording(title: "La smazzata del giorno",
                      before: "Gioca la tua prima smazzata del giorno.",
                      after: "La tua prima smazzata del giorno giocata."),
    ]),
    Badge(id: "daily_streak_7", reference: "Seven Day Streak", points: 50, words: [
        "en-US": Wording(title: "Seven Days",
                         before: "Play the daily deal seven days running.",
                         after: "Seven days without missing one."),
        "fr-FR": Wording(title: "Sept jours",
                         before: "Jouez la donne du jour sept jours de suite.",
                         after: "Sept jours sans en manquer une."),
        "it": Wording(title: "Sette giorni",
                      before: "Gioca la smazzata del giorno per sette giorni di fila.",
                      after: "Sette giorni senza saltarne una."),
    ]),
    Badge(id: "daily_streak_30", reference: "Thirty Day Streak", points: 100, words: [
        "en-US": Wording(title: "Thirty Days",
                         before: "Play the daily deal thirty days running.",
                         after: "Thirty days without missing one."),
        "fr-FR": Wording(title: "Trente jours",
                         before: "Jouez la donne du jour trente jours de suite.",
                         after: "Trente jours sans en manquer une."),
        "it": Wording(title: "Trenta giorni",
                      before: "Gioca la smazzata del giorno per trenta giorni di fila.",
                      after: "Trenta giorni senza saltarne una."),
    ]),
    Badge(id: "first_online_win", reference: "First Online Win", points: 25, words: [
        "en-US": Wording(title: "Away Win",
                         before: "Win a game online.",
                         after: "Won against a real opponent."),
        "fr-FR": Wording(title: "Victoire à l'extérieur",
                         before: "Gagnez une partie en ligne.",
                         after: "Gagnée contre un vrai adversaire."),
        "it": Wording(title: "Vittoria in trasferta",
                      before: "Vinci una partita online.",
                      after: "Vinta contro un avversario vero."),
    ]),
]

// MARK: Setup

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    ASC.fail("usage: seed-achievements <bundle id> <artwork directory>")
}
let bundleID = arguments[1]
let artwork = URL(fileURLWithPath: arguments[2], isDirectory: true)

// MARK: Artwork

/// Puts the badge's PNG on one localization. Every language carries its own copy of the
/// image — App Store Connect will not accept a localization without a complete one.
///
/// An image that never finished uploading is deleted and sent again, since a half-uploaded
/// one blocks the localization just as a missing one does.
func placeArtwork(_ bytes: Data, named fileName: String, on localizationID: String) {
    let current = ASC.one(ASC.call("GET", "/v2/gameCenterAchievementLocalizations/\(localizationID)/image"))
    if !ASC.id(current).isEmpty {
        let state = (ASC.attributes(current)["assetDeliveryState"] as? [String: Any])?["state"] as? String
        if state == "COMPLETE" {
            print("      artwork already uploaded")
            return
        }
        ASC.call("DELETE", "/v1/gameCenterAchievementImages/\(ASC.id(current))")
    }

    let reservation = ASC.one(ASC.call("POST", "/v1/gameCenterAchievementImages", [
        "data": ["type": "gameCenterAchievementImages",
                 "attributes": ["fileSize": bytes.count, "fileName": fileName],
                 "relationships": ["gameCenterAchievementLocalization":
                                    ASC.link("gameCenterAchievementLocalizations", localizationID)]],
    ]))
    let imageID = ASC.id(reservation)
    let operations = ASC.attributes(reservation)["uploadOperations"] as? [[String: Any]] ?? []
    for operation in operations {
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
    ASC.call("PATCH", "/v1/gameCenterAchievementImages/\(imageID)",
        ["data": ["type": "gameCenterAchievementImages", "id": imageID,
                  "attributes": ["uploaded": true]]])
    print("      artwork uploaded (\(bytes.count) bytes)")
}

// MARK: The app

let app = ASC.app(bundleID: bundleID)
print("\(app.name) (\(bundleID))")

let detailID = ASC.id(ASC.one(ASC.call("GET", "/v1/apps/\(app.id)/gameCenterDetail")))
guard !detailID.isEmpty else { ASC.fail("Game Center is not enabled for this app") }

var existing: [String: String] = [:]   // vendorIdentifier → achievement id
for achievement in ASC.many(ASC.call("GET", "/v1/gameCenterDetails/\(detailID)/gameCenterAchievements?limit=200")) {
    if let vendor = ASC.attributes(achievement)["vendorIdentifier"] as? String {
        existing[vendor] = ASC.id(achievement)
    }
}

// MARK: The pass

for badge in catalogue {
    let picture = artwork.appendingPathComponent("\(badge.id).png")
    guard let bytes = try? Data(contentsOf: picture) else { ASC.fail("no artwork at \(picture.path)") }

    // The achievement itself. Hidden is `showBeforeEarned` inverted: showing it before it
    // is earned is what "Hidden: No" means in the web form.
    let settings: [String: Any] = ["referenceName": badge.reference, "points": badge.points,
                                   "showBeforeEarned": true, "repeatable": false]
    let achievementID: String
    if let known = existing[badge.id] {
        achievementID = known
        ASC.call("PATCH", "/v1/gameCenterAchievements/\(known)",
            ["data": ["type": "gameCenterAchievements", "id": known, "attributes": settings]])
        print("  \(badge.id): updated")
    } else {
        var create = settings
        create["vendorIdentifier"] = badge.id
        let made = ASC.one(ASC.call("POST", "/v1/gameCenterAchievements", [
            "data": ["type": "gameCenterAchievements", "attributes": create,
                     "relationships": ["gameCenterDetail": ASC.link("gameCenterDetails", detailID)]],
        ]))
        achievementID = ASC.id(made)
        print("  \(badge.id): created")
    }

    // Localizations hang off a version rather than the achievement: the editable one is
    // whichever version is still being prepared.
    let versions = ASC.many(ASC.call("GET", "/v2/gameCenterAchievements/\(achievementID)/versions"))
    guard let version = versions.first(where: { ASC.attributes($0)["state"] as? String == "PREPARE_FOR_SUBMISSION" })
        ?? versions.last else { ASC.fail("\(badge.id) has no editable version") }
    let versionID = ASC.id(version)
    let localizations = ASC.many(ASC.call("GET", "/v2/gameCenterAchievementVersions/\(versionID)/localizations"))

    for locale in locales {
        guard let words = badge.words[locale] else { ASC.fail("\(badge.id) says nothing in \(locale)") }
        let text: [String: Any] = ["locale": locale, "name": words.title,
                                   "beforeEarnedDescription": words.before,
                                   "afterEarnedDescription": words.after]
        let localizationID: String
        if let known = localizations.first(where: { ASC.attributes($0)["locale"] as? String == locale }) {
            localizationID = ASC.id(known)
            // `locale` is fixed at creation, so an update sends only the words.
            var revision = text
            revision["locale"] = nil
            ASC.call("PATCH", "/v2/gameCenterAchievementLocalizations/\(localizationID)",
                ["data": ["type": "gameCenterAchievementLocalizations", "id": localizationID,
                          "attributes": revision]])
            print("    \(locale): updated")
        } else {
            let made = ASC.one(ASC.call("POST", "/v2/gameCenterAchievementLocalizations", [
                "data": ["type": "gameCenterAchievementLocalizations", "attributes": text,
                         "relationships": ["version": ASC.link("gameCenterAchievementVersions", versionID)]],
            ]))
            localizationID = ASC.id(made)
            print("    \(locale): added")
        }
        placeArtwork(bytes, named: "\(badge.id).png", on: localizationID)
    }
}

print("done — \(catalogue.count) achievements in \(locales.count) languages, "
      + "\(catalogue.reduce(0) { $0 + $1.points }) points")
