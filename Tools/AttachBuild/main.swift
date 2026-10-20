import Foundation

// Attaches an uploaded build to the iOS version being prepared, once App Store Connect has
// finished processing it. `--status` only reads: the version, its build, and the purchases.
// Nothing here submits anything for review.

let arguments = Array(CommandLine.arguments.dropFirst())
guard let bundleID = arguments.first else {
    ASC.fail("usage: attach-build <bundle id> [--status | <version> <build number>]")
}
let app = ASC.app(bundleID: bundleID)
print("\(app.name) (\(bundleID))")

let versions = ASC.many(ASC.call("GET", "/v1/apps/\(app.id)/appStoreVersions?limit=10"))
    .filter { ASC.attributes($0)["platform"] as? String == "IOS" }

func describe(_ version: [String: Any]) -> String {
    let attributes = ASC.attributes(version)
    return "\(attributes["versionString"] as? String ?? "?") \(attributes["appVersionState"] as? String ?? "?")"
}

if arguments.dropFirst().first == "--status" {
    for version in versions.prefix(4) {
        let build = ASC.one(ASC.call("GET", "/v1/appStoreVersions/\(ASC.id(version))/build"))
        let number = ASC.attributes(build)["version"] as? String ?? "none"
        print("  version \(describe(version)), build \(number)")
    }
    for purchase in Purchase.existing(appID: app.id) {
        let attributes = ASC.attributes(purchase)
        print("  purchase \(attributes["productId"] as? String ?? "?"): \(attributes["state"] as? String ?? "?")")
    }
    exit(0)
}

guard arguments.count == 3 else { ASC.fail("usage: attach-build <bundle id> <version> <build number>") }
let (versionString, number) = (arguments[1], arguments[2])
guard let version = versions.first(where: {
    ASC.attributes($0)["versionString"] as? String == versionString
        && ASC.editableVersionStates.contains(ASC.attributes($0)["appVersionState"] as? String ?? "")
}) else { ASC.fail("no editable iOS version \(versionString)") }

/// The build, once processed. Polled for up to an hour: processing takes ten to thirty minutes.
func processedBuild() -> [String: Any] {
    let query = "filter%5Bapp%5D=\(app.id)&filter%5BpreReleaseVersion.version%5D=\(versionString)"
        + "&filter%5Bversion%5D=\(number)&limit=1"
    for attempt in 0..<120 {
        if let build = ASC.many(ASC.call("GET", "/v1/builds?\(query)")).first {
            let state = ASC.attributes(build)["processingState"] as? String ?? "?"
            if state == "VALID" { return build }
            if state == "FAILED" || state == "INVALID" { ASC.fail("build \(versionString) (\(number)) is \(state)") }
            if attempt % 4 == 0 { print("  build \(versionString) (\(number)) is \(state), waiting") }
        } else if attempt % 4 == 0 {
            print("  build \(versionString) (\(number)) not listed yet, waiting")
        }
        Thread.sleep(forTimeInterval: 30)
    }
    ASC.fail("build \(versionString) (\(number)) still not processed after an hour")
}

let build = processedBuild()
ASC.call("PATCH", "/v1/appStoreVersions/\(ASC.id(version))/relationships/build", ASC.link("builds", ASC.id(build)))
print("  attached build \(number) to \(describe(version))")
print("done")
