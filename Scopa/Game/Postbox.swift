import Foundation
import UIKit

/// Opens a pre-filled mail to support from Settings. Same address as the support page, with
/// the version lines that page asks people to type already filled in.
enum Postbox {
    /// The same address the support page prints.
    static let address = "contact@quentinvedrenne.com"

    /// Where a phone with no mail account is sent instead.
    static let supportPage = URL(string: "https://scopa-ladder.quentin-vedrenne.workers.dev/support")!

    /// Why the player is writing in. It picks the subject line, which is what sorts the inbox.
    enum Errand: CaseIterable {
        case problem, idea

        var subject: String.LocalizationValue {
            switch self {
            case .problem: "Scopa — something is wrong"
            case .idea: "Scopa — an idea"
            }
        }

        /// The line waiting above the cursor, so the message starts with something useful.
        var prompt: String.LocalizationValue {
            switch self {
            case .problem: "What happened, and what you were doing just before:"
            case .idea: "What you would like Scopa to do:"
            }
        }
    }

    /// A `mailto:` with the subject filled in and the build and device stated at the bottom.
    /// Nil if the text will not percent-encode. The caller falls back to the support page.
    static func letter(about errand: Errand, in locale: Locale) -> URL? {
        let subject = String(localized: errand.subject, locale: locale)
        let body = """


        \(String(localized: errand.prompt, locale: locale))


        —
        \(String(localized: "Please leave the lines below: they say which version this is.", locale: locale))
        \(signature(in: locale))
        """
        guard let subject = escape(subject), let body = escape(body) else { return nil }
        return URL(string: "mailto:\(address)?subject=\(subject)&body=\(body)")
    }

    /// Version, device, system and language. Nothing here identifies the player.
    static func signature(in locale: Locale) -> String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        let system = UIDevice.current
        return """
        Scopa \(version) (\(build))
        \(model) · \(system.systemName) \(system.systemVersion)
        \(locale.identifier)
        """
    }

    /// The hardware identifier such as "iPhone17,1" rather than the marketing name, so no table
    /// of names has to be kept up to date here.
    private static var model: String {
        // A simulator would otherwise report the Mac's own architecture.
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: &system.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    /// `urlQueryAllowed` leaves `&`, `+` and `=` alone, which is right for a whole query and
    /// wrong for a single value inside one.
    private static func escape(_ text: String) -> String? {
        text.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+=?"))
        )
    }
}
