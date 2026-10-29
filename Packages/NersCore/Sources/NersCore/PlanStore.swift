import Foundation

/// Stores settings and dose history in a JSON file on the device. No network needed.
public struct PlanStore: Sendable {
    public static let currentVersion = 1

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    private struct Stored: Codable {
        var version: Int
        var settings: ReminderSettings
        var history: [DoseRecord]
    }

    /// Loads the saved state. Without a file it returns default settings and an empty history.
    /// A corrupt file throws instead of silently wiping history.
    public func load() throws -> Planner {
        guard FileManager.default.fileExists(atPath: url.path) else { return Planner() }
        let stored = try JSONDecoder().decode(Stored.self, from: Data(contentsOf: url))
        return Planner(settings: stored.settings, history: stored.history)
    }

    /// Overwrites the whole state atomically, so a half-written file never exists.
    public func save(_ planner: Planner) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(
            Stored(version: Self.currentVersion, settings: planner.settings, history: planner.history)
        )
        #if os(iOS)
        // The "Taken" App Intent runs in the background and must write while the phone is locked.
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }
}
