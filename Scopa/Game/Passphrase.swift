import CryptoKit
import Foundation

/// The unlock phrase for this phone: it removes the ads for good and enables the house tie
/// rule on tables you set yourself.
///
/// Only the digest is stored, so `strings` on the binary does not hand the phrase out.
enum Passphrase {
    /// SHA-256 of the phrase, case- and diacritic-folded then trimmed.
    private static let digest = "7ddcebf8d4cdae7cec35c59f5e0488fd2b2c26b85fa65db768b574fc989160c1"

    static func isRight(_ phrase: String) -> Bool { Self.digest(of: phrase) == digest }

    /// Case, spacing and accents are all forgiven.
    private static func digest(of phrase: String) -> String {
        let folded = phrase
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let bytes = SHA256.hash(data: Data(folded.utf8))
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
