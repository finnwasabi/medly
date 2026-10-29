import Foundation

/// Ảnh chụp trạng thái gửi lên `POST /v1/snapshot`. Khớp hợp đồng dữ liệu trong docs/spec.md:
/// mốc giờ là chuỗi UTC ISO 8601 không phần lẻ giây, trường không có giá trị ghi `null`.
public struct Snapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    /// Tên người dùng nhập trong app, để bot gọi đúng tên. `nil` khi chưa nhập.
    public var name: String?
    public var updatedAt: Date
    public var lastTakenAt: Date?
    public var nextDueAt: Date
    public var deadlineAt: Date
    public var daysTaken: Int
    public var missedCount: Int
    public var lateCount: Int
    /// Số lần hụt đã uống bù, nằm trong `missedCount`.
    public var madeUpCount: Int
    public var pillsTotal: Int?
    public var pillsRemaining: Int?
    public var refillReminder: RefillReminder
    public var pausedUntil: Date?

    public init(
        schemaVersion: Int = Snapshot.currentSchemaVersion,
        updatedAt: Date,
        lastTakenAt: Date?,
        nextDueAt: Date,
        deadlineAt: Date,
        daysTaken: Int,
        missedCount: Int,
        lateCount: Int,
        madeUpCount: Int = 0,
        pillsTotal: Int?,
        pillsRemaining: Int?,
        refillReminder: RefillReminder,
        pausedUntil: Date?
    ) {
        self.schemaVersion = schemaVersion
        self.updatedAt = UTCTimestamp.floorToSecond(updatedAt)
        self.lastTakenAt = lastTakenAt.map(UTCTimestamp.floorToSecond)
        self.nextDueAt = UTCTimestamp.floorToSecond(nextDueAt)
        self.deadlineAt = UTCTimestamp.floorToSecond(deadlineAt)
        self.daysTaken = daysTaken
        self.missedCount = missedCount
        self.lateCount = lateCount
        self.madeUpCount = madeUpCount
        self.pillsTotal = pillsTotal
        self.pillsRemaining = pillsRemaining
        self.refillReminder = refillReminder
        self.pausedUntil = pausedUntil.map(UTCTimestamp.floorToSecond)
    }

    /// Dựng snapshot từ cài đặt, lịch sử và thời điểm hiện tại.
    public init(settings: ReminderSettings, history: [DoseRecord], now: Date) {
        let planner = Planner(settings: settings, history: history)
        let dose = planner.currentDose(now: now)
        self.init(
            updatedAt: now,
            lastTakenAt: planner.lastTaken(now: now)?.takenAt,
            nextDueAt: dose.dueAt,
            deadlineAt: dose.deadlineAt,
            daysTaken: planner.daysTaken(now: now),
            missedCount: planner.missedCount(now: now),
            lateCount: planner.lateCount(now: now),
            madeUpCount: planner.madeUpCount(now: now),
            pillsTotal: settings.pills?.total,
            pillsRemaining: settings.pills?.remaining,
            refillReminder: settings.refillReminder,
            pausedUntil: settings.pausedUntil(now: now)
        )
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, name, updatedAt, lastTakenAt, nextDueAt, deadlineAt, daysTaken, missedCount, lateCount, madeUpCount
        case pillsTotal, pillsRemaining, refillReminder, pausedUntil
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(name, forKey: .name)
        try c.encode(UTCTimestamp.string(from: updatedAt), forKey: .updatedAt)
        // Dùng encode cho Optional để ghi `null` thay vì bỏ trường.
        try c.encode(lastTakenAt.map(UTCTimestamp.string(from:)), forKey: .lastTakenAt)
        try c.encode(UTCTimestamp.string(from: nextDueAt), forKey: .nextDueAt)
        try c.encode(UTCTimestamp.string(from: deadlineAt), forKey: .deadlineAt)
        try c.encode(daysTaken, forKey: .daysTaken)
        try c.encode(missedCount, forKey: .missedCount)
        try c.encode(lateCount, forKey: .lateCount)
        try c.encode(madeUpCount, forKey: .madeUpCount)
        try c.encode(pillsTotal, forKey: .pillsTotal)
        try c.encode(pillsRemaining, forKey: .pillsRemaining)
        try c.encode(refillReminder, forKey: .refillReminder)
        try c.encode(pausedUntil.map(UTCTimestamp.string(from:)), forKey: .pausedUntil)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func date(_ key: CodingKeys) throws -> Date? {
            guard let text = try c.decodeIfPresent(String.self, forKey: key) else { return nil }
            guard let value = UTCTimestamp.date(from: text) else {
                throw DecodingError.dataCorruptedError(forKey: key, in: c, debugDescription: "Không đọc được mốc giờ \(text)")
            }
            return value
        }
        func required(_ key: CodingKeys) throws -> Date {
            guard let value = try date(key) else {
                throw DecodingError.valueNotFound(Date.self, .init(codingPath: c.codingPath + [key], debugDescription: "Thiếu mốc giờ"))
            }
            return value
        }
        self.init(
            schemaVersion: try c.decode(Int.self, forKey: .schemaVersion),
            updatedAt: try required(.updatedAt),
            lastTakenAt: try date(.lastTakenAt),
            nextDueAt: try required(.nextDueAt),
            deadlineAt: try required(.deadlineAt),
            daysTaken: try c.decode(Int.self, forKey: .daysTaken),
            missedCount: try c.decode(Int.self, forKey: .missedCount),
            lateCount: try c.decodeIfPresent(Int.self, forKey: .lateCount) ?? 0,
            madeUpCount: try c.decodeIfPresent(Int.self, forKey: .madeUpCount) ?? 0,
            pillsTotal: try c.decodeIfPresent(Int.self, forKey: .pillsTotal),
            pillsRemaining: try c.decodeIfPresent(Int.self, forKey: .pillsRemaining),
            refillReminder: try c.decode(RefillReminder.self, forKey: .refillReminder),
            pausedUntil: try date(.pausedUntil)
        )
        name = try c.decodeIfPresent(String.self, forKey: .name)
    }

    /// JSON gửi lên server, khoá sắp xếp để kết quả ổn định.
    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(from data: Data) throws -> Snapshot {
        try JSONDecoder().decode(Snapshot.self, from: data)
    }
}

extension Planner {
    public func snapshot(now: Date) -> Snapshot {
        Snapshot(settings: settings, history: history, now: now)
    }
}
