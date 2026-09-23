import Foundation

// Uploads the screenshots under Artwork/Screenshots to the App Store version being
// prepared: one set per device size per language, in the order the files are named.
// Run it with Tools/push-screenshots.sh.
//
// Idempotent by replacement: a set that already has shots is emptied first, so a re-shoot
// leaves exactly what is on disk.

/// A directory of shots, and the display size App Store Connect files it under.
let sizes: [(directory: String, displayType: String)] = [
    ("iphone-6.9", "APP_IPHONE_67"),
    ("ipad-13", "APP_IPAD_PRO_3GEN_129"),
]

let arguments = CommandLine.arguments
guard arguments.count == 3 else { ASC.fail("usage: push-screenshots <bundle id> <screenshots directory>") }
let bundleID = arguments[1]
let root = URL(fileURLWithPath: arguments[2], isDirectory: true)

let app = ASC.app(bundleID: bundleID)
print("\(app.name) (\(bundleID))")

let versions = ASC.many(ASC.call("GET", "/v1/apps/\(app.id)/appStoreVersions"))
guard let version = versions.first(where: {
    let attributes = ASC.attributes($0)
    return attributes["platform"] as? String == "IOS"
        && attributes["appVersionState"] as? String == "PREPARE_FOR_SUBMISSION"
}) else { ASC.fail("no iOS version being prepared") }
let versionID = ASC.id(version)

var localizations: [String: String] = [:]   // locale → localization id
for localization in ASC.many(ASC.call("GET", "/v1/appStoreVersions/\(versionID)/appStoreVersionLocalizations")) {
    if let locale = ASC.attributes(localization)["locale"] as? String {
        localizations[locale] = ASC.id(localization)
    }
}

let fileManager = FileManager.default

for size in sizes {
    let sizeDirectory = root.appendingPathComponent(size.directory, isDirectory: true)
    guard let locales = try? fileManager.contentsOfDirectory(atPath: sizeDirectory.path).sorted() else {
        ASC.fail("no screenshots at \(sizeDirectory.path)")
    }

    for locale in locales where !locale.hasPrefix(".") {
        guard let localizationID = localizations[locale] else {
            print("  \(size.directory)/\(locale): no such locale on the version, skipped")
            continue
        }
        let shots = (try? fileManager.contentsOfDirectory(at: sizeDirectory.appendingPathComponent(locale),
                                                          includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "png" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
        guard !shots.isEmpty else { continue }

        // The set for this size, made if it is not there yet.
        let existingSets = ASC.many(ASC.call("GET", "/v1/appStoreVersionLocalizations/\(localizationID)/appScreenshotSets"))
        let setID: String
        if let known = existingSets.first(where: { ASC.attributes($0)["screenshotDisplayType"] as? String == size.displayType }) {
            setID = ASC.id(known)
            for old in ASC.many(ASC.call("GET", "/v1/appScreenshotSets/\(setID)/appScreenshots")) {
                ASC.call("DELETE", "/v1/appScreenshots/\(ASC.id(old))")
            }
        } else {
            setID = ASC.id(ASC.one(ASC.call("POST", "/v1/appScreenshotSets", [
                "data": ["type": "appScreenshotSets",
                         "attributes": ["screenshotDisplayType": size.displayType],
                         "relationships": ["appStoreVersionLocalization":
                                            ASC.link("appStoreVersionLocalizations", localizationID)]],
            ])))
        }

        for shot in shots {
            guard let bytes = try? Data(contentsOf: shot) else { ASC.fail("could not read \(shot.path)") }
            let reservation = ASC.one(ASC.call("POST", "/v1/appScreenshots", [
                "data": ["type": "appScreenshots",
                         "attributes": ["fileSize": bytes.count, "fileName": shot.lastPathComponent],
                         "relationships": ["appScreenshotSet": ASC.link("appScreenshotSets", setID)]],
            ]))
            let shotID = ASC.id(reservation)
            for operation in ASC.attributes(reservation)["uploadOperations"] as? [[String: Any]] ?? [] {
                guard let address = operation["url"] as? String, let url = URL(string: address),
                      let offset = operation["offset"] as? Int, let length = operation["length"] as? Int else {
                    ASC.fail("\(shot.lastPathComponent): malformed upload operation")
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
                guard (200..<300).contains(status) else {
                    ASC.fail("\(shot.lastPathComponent): upload returned HTTP \(status)")
                }
            }
            ASC.call("PATCH", "/v1/appScreenshots/\(shotID)", [
                "data": ["type": "appScreenshots", "id": shotID, "attributes": ["uploaded": true]],
            ])
        }
        print("  \(size.directory)/\(locale): \(shots.count) uploaded")
    }
}

print("done")
