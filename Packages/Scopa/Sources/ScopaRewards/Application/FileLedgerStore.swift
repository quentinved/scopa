import Foundation

public enum LedgerFileError: Error, Hashable, Sendable {
    /// Written by a newer version of the app than this one. Refusing to read it is the
    /// point: starting from zero here would mean overwriting a real ledger with an empty one.
    case unknownVersion(Int)
}

/// The ledger as a JSON file on disk.
///
/// A file rather than `UserDefaults` because this grows with every game played, and because
/// the shape it is written in, a version plus the writing device plus a flat list of
/// entries, is the shape it will be handed to a server in.
public actor FileLedgerStore: LedgerStore {
    private struct Wrapper: Codable {
        var version: Int
        /// Which device's ledger this is. Two devices merging one day will each want to know
        /// where an entry came from, and by then it is far too late to start recording it.
        var device: String
        var entries: [LedgerEntry]
    }

    /// Bumped only for a change the previous version could not read.
    public static let version = 1

    private let url: URL
    private let device: String
    private var entries: [LedgerEntry]?

    public init(url: URL, device: String) {
        self.url = url
        self.device = device
    }

    /// The usual home: Application Support, which is backed up and not swept by the system.
    public static func onDisk(named name: String = "denari.json", device: String) throws -> FileLedgerStore {
        let folder = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return FileLedgerStore(url: folder.appendingPathComponent(name), device: device)
    }

    public func load() async throws -> [LedgerEntry] {
        if let entries { return entries }
        guard let data = try? Data(contentsOf: url) else {
            entries = []
            return []
        }
        let wrapper = try Self.decoder.decode(Wrapper.self, from: data)
        guard wrapper.version <= Self.version else { throw LedgerFileError.unknownVersion(wrapper.version) }
        entries = wrapper.entries
        return wrapper.entries
    }

    public func append(_ new: [LedgerEntry]) async throws {
        let all = try await load() + new
        let data = try Self.encoder.encode(Wrapper(version: Self.version, device: device, entries: all))
        try data.write(to: url, options: .atomic)
        entries = all
    }

    /// ISO dates and sorted keys, so the file stays legible and diffable, and so a server
    /// reading it is not handed Apple's reference-date doubles.
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
