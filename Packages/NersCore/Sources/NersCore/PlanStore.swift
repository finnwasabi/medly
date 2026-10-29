import Foundation

/// Stores every medication with its settings and history in a JSON file on the device. No network needed.
public struct PlanStore: Sendable {
    /// 1: a single schedule (`settings` and `history`). 2: a list of medications.
    public static let currentVersion = 2

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    private struct Version: Decodable { var version: Int }

    private struct StoredV1: Decodable {
        var settings: ReminderSettings
        var history: [DoseRecord]
    }

    private struct Stored: Codable {
        var version: Int
        var medications: [Medication]
    }

    /// Loads the saved medications. Without a file there are none yet.
    /// Version 1 becomes one medication with an empty name, which the app fills in its language.
    /// A corrupt file or an unknown version throws instead of silently wiping history.
    public func load() throws -> [Medication] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        switch try decoder.decode(Version.self, from: data).version {
        case 1:
            let old = try decoder.decode(StoredV1.self, from: data)
            return [Medication(name: "", settings: old.settings, history: old.history)]
        case 2:
            return try decoder.decode(Stored.self, from: data).medications
        case let version:
            throw CocoaError(.fileReadCorruptFile, userInfo: [NSDebugDescriptionErrorKey: "unknown version \(version)"])
        }
    }

    /// Overwrites the whole state atomically, so a half-written file never exists.
    public func save(_ medications: [Medication]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(Stored(version: Self.currentVersion, medications: medications))
        #if os(iOS)
        // The "Taken" App Intent runs in the background and must write while the phone is locked.
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }
}
