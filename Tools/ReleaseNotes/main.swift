import Foundation

// Sets "What's New in This Version" on the iOS version being prepared, from
// Tools/ReleaseNotes/notes.swift. Run it with Tools/push-release-notes.sh.
//
// Kept apart from push-metadata, which describes the game and is pushed again whenever the
// copy changes: these notes describe one build, so they are keyed by version and only ever
// written to the version that carries that string. It refuses a first release, which
// Apple will not take notes for, and a locale the version does not have yet
// (push-metadata adds those). It never submits anything for review.
//
// `--check [version]` prints the notes and their lengths without calling App Store Connect.

let limit = 4000
let arguments = Array(CommandLine.arguments.dropFirst())

/// The notes for a version, checked for every language before anything is sent.
func notes(for version: String) -> [(locale: String, text: String)] {
    guard let byLocale = releaseNotes[version] else {
        ASC.fail("no notes for version \(version) in Tools/ReleaseNotes/notes.swift")
    }
    let notes = byLocale.sorted { $0.key < $1.key }.map { (locale: $0.key, text: $0.value) }
    for (locale, text) in notes where text.isEmpty || text.count > limit {
        ASC.fail("\(version) \(locale) notes are \(text.count) characters, want 1...\(limit)")
    }
    return notes
}

if arguments.first == "--check" {
    let version = arguments.dropFirst().first ?? releaseNotes.keys.max { $0.compare($1, options: .numeric) == .orderedAscending } ?? "?"
    for (locale, text) in notes(for: version) {
        print("== \(version) \(locale): \(text.count) of \(limit) characters\n\(text)\n")
    }
    exit(0)
}

guard arguments.count == 1 else { ASC.fail("usage: push-release-notes <bundle id> | --check [version]") }
let app = ASC.app(bundleID: arguments[0])
print("\(app.name) (\(arguments[0]))")

let versions = ASC.many(ASC.call("GET", "/v1/apps/\(app.id)/appStoreVersions"))
    .filter { ASC.attributes($0)["platform"] as? String == "IOS" }
guard let version = versions.first(where: {
    ASC.editableVersionStates.contains(ASC.attributes($0)["appVersionState"] as? String ?? "")
}) else { ASC.fail("no iOS version being prepared (Tools/push-metadata.sh opens one)") }
guard versions.count > 1 else { ASC.fail("this is the first release, and Apple takes no notes for it") }

let versionID = ASC.id(version)
let versionString = ASC.attributes(version)["versionString"] as? String ?? "?"
let wanted = notes(for: versionString)

let localizations = ASC.many(ASC.call("GET", "/v1/appStoreVersions/\(versionID)/appStoreVersionLocalizations"))
func localization(_ locale: String) -> [String: Any]? {
    localizations.first { ASC.attributes($0)["locale"] as? String == locale }
}
// All or nothing: a missing locale stops the run before the first one is written.
let missing = wanted.map(\.locale).filter { localization($0) == nil }
guard missing.isEmpty else {
    ASC.fail("version \(versionString) has no \(missing.joined(separator: ", ")) yet: run Tools/push-metadata.sh first")
}

for (locale, text) in wanted {
    let id = ASC.id(localization(locale)!)
    ASC.call("PATCH", "/v1/appStoreVersionLocalizations/\(id)", [
        "data": ["type": "appStoreVersionLocalizations", "id": id, "attributes": ["whatsNew": text]],
    ])
    print("  \(versionString) \(locale): what's new set (\(text.count) characters)")
}
print("done")
