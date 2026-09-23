import Foundation
import CryptoKit

// A small App Store Connect client, shared by the tools that configure the listing. It
// signs the ES256 JWT with CryptoKit, so there is nothing to install: the key is the .p8
// downloaded from Users and Access, kept outside this repo.
//
// Every call fails loudly: these tools write to a live App Store Connect account, and a
// half-applied pass is worse than one that stopped.

enum ASC {
    static let environment = ProcessInfo.processInfo.environment

    static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("error: \(message)\n".utf8))
        exit(1)
    }

    private static let keyPath = environment["ASC_KEY"] ?? ""
    private static let keyID = environment["ASC_KEY_ID"] ?? ""
    private static let issuerID = environment["ASC_ISSUER_ID"] ?? ""

    private static let signingKey: P256.Signing.PrivateKey = {
        guard !keyPath.isEmpty, !keyID.isEmpty, !issuerID.isEmpty else {
            fail("set ASC_KEY, ASC_KEY_ID and ASC_ISSUER_ID")
        }
        guard let pem = try? String(contentsOfFile: keyPath, encoding: .utf8),
              let key = try? P256.Signing.PrivateKey(pemRepresentation: pem) else {
            fail("could not read a private key from \(keyPath)")
        }
        return key
    }()

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func token() -> String {
        let header = ["alg": "ES256", "kid": keyID, "typ": "JWT"]
        let now = Int(Date().timeIntervalSince1970)
        let payload: [String: Any] = ["iss": issuerID, "iat": now, "exp": now + 900,
                                      "aud": "appstoreconnect-v1"]
        let head = base64URL(try! JSONSerialization.data(withJSONObject: header, options: [.sortedKeys]))
        let body = base64URL(try! JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]))
        let signing = "\(head).\(body)"
        let signature = try! signingKey.signature(for: Data(signing.utf8))
        return "\(signing).\(base64URL(signature.rawRepresentation))"
    }

    /// A raw request, used for the asset uploads that go to object storage rather than to
    /// the API, and so must not carry the bearer token.
    static func send(_ request: URLRequest) -> (status: Int, body: Data) {
        var status = 0
        var body = Data()
        let wait = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error { FileHandle.standardError.write(Data("\(error)\n".utf8)) }
            status = (response as? HTTPURLResponse)?.statusCode ?? 0
            body = data ?? Data()
            wait.signal()
        }.resume()
        wait.wait()
        return (status, body)
    }

    /// One App Store Connect call: JSON in, JSON out, and a stop on anything past 400.
    @discardableResult
    static func call(_ method: String, _ path: String, _ body: [String: Any]? = nil) -> [String: Any] {
        var request = URLRequest(url: URL(string: "https://api.appstoreconnect.apple.com\(path)")!)
        request.httpMethod = method
        request.setValue("Bearer \(token())", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = try! JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (status, data) = send(request)
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if status >= 400 {
            let detail = (object["errors"] as? [[String: Any]])?
                .compactMap { error -> String? in
                    let title = error["title"] as? String ?? ""
                    let text = error["detail"] as? String ?? title
                    return text.isEmpty ? nil : text
                }
                .joined(separator: "; ")
            fail("\(method) \(path) → HTTP \(status): \(detail ?? String(decoding: data, as: UTF8.self))")
        }
        return object
    }

    // MARK: Reading the envelope

    static func one(_ response: [String: Any]) -> [String: Any] {
        response["data"] as? [String: Any] ?? [:]
    }

    static func many(_ response: [String: Any]) -> [[String: Any]] {
        response["data"] as? [[String: Any]] ?? []
    }

    static func attributes(_ object: [String: Any]) -> [String: Any] {
        object["attributes"] as? [String: Any] ?? [:]
    }

    static func id(_ object: [String: Any]) -> String {
        object["id"] as? String ?? ""
    }

    static func link(_ type: String, _ id: String) -> [String: Any] {
        ["data": ["type": type, "id": id]]
    }

    // MARK: The app

    /// The app record for a bundle id, or a stop if there isn't one.
    static func app(bundleID: String) -> (id: String, name: String) {
        guard let app = many(call("GET", "/v1/apps?filter%5BbundleId%5D=\(bundleID)")).first else {
            fail("no app with bundle id \(bundleID)")
        }
        return (id(app), attributes(app)["name"] as? String ?? bundleID)
    }
}
