import Foundation

/// Lưu cài đặt và lịch sử uống vào một file JSON trên máy. Không cần mạng.
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

    /// Đọc trạng thái đã lưu. Chưa có file thì trả cài đặt mặc định, lịch sử rỗng.
    /// File hỏng thì ném lỗi chứ không lặng lẽ xoá lịch sử.
    public func load() throws -> Planner {
        guard FileManager.default.fileExists(atPath: url.path) else { return Planner() }
        let stored = try JSONDecoder().decode(Stored.self, from: Data(contentsOf: url))
        return Planner(settings: stored.settings, history: stored.history)
    }

    /// Ghi đè toàn bộ trạng thái, ghi atomic để không bao giờ còn file ghi dở.
    public func save(_ planner: Planner) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(
            Stored(version: Self.currentVersion, settings: planner.settings, history: planner.history)
        )
        #if os(iOS)
        // App Intent "Đã uống" chạy nền lúc máy khoá vẫn phải ghi được.
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }
}
