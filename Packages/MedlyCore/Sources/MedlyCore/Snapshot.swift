import Foundation

/// The status snapshot sent to `POST /v1/snapshot`. Matches the data contract in docs/spec.md:
/// times are UTC ISO 8601 strings without fractional seconds, and empty fields are written as `null`.
public struct Snapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    /// The user's name from the app, so the bot can address them. `nil` until entered.
    public var name: String?
    public var updatedAt: Date
    public var medications: [MedicationSnapshot]

    public init(name: String?, updatedAt: Date, medications: [MedicationSnapshot]) {
        schemaVersion = Self.currentSchemaVersion
        self.name = name
        self.updatedAt = UTCTimestamp.floorToSecond(updatedAt)
        self.medications = medications
    }

    public init(name: String?, medications: [Medication], now: Date) {
        self.init(name: name, updatedAt: now, medications: medications.map { $0.snapshot(now: now) })
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, name, updatedAt, medications
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        // Encode optionals explicitly to write `null` instead of dropping the key.
        try c.encode(name, forKey: .name)
        try c.encode(UTCTimestamp.string(from: updatedAt), forKey: .updatedAt)
        try c.encode(medications, forKey: .medications)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        updatedAt = try c.timestamp(.updatedAt)
        medications = try c.decode([MedicationSnapshot].self, forKey: .medications)
    }

    /// JSON for the server, with sorted keys for stable output.
    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(from data: Data) throws -> Snapshot {
        try JSONDecoder().decode(Snapshot.self, from: data)
    }
}

/// The status of one medication inside a snapshot.
public struct MedicationSnapshot: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var dosesPerDay: Int
    public var lastTakenAt: Date?
    public var nextDueAt: Date
    public var deadlineAt: Date
    /// Doses taken since pills were last entered or added, or since the start when not counting.
    public var takenCount: Int
    public var missedCount: Int
    public var lateCount: Int
    /// Misses that were made up, included in `missedCount`.
    public var madeUpCount: Int
    /// Doses skipped on purpose, not counted as missed.
    public var skippedCount: Int
    public var pillsTotal: Int?
    public var pillsRemaining: Int?
    public var refillReminder: RefillReminder
    public var pausedUntil: Date?

    public init(
        id: UUID, name: String, dosesPerDay: Int, lastTakenAt: Date?, nextDueAt: Date, deadlineAt: Date,
        takenCount: Int, missedCount: Int, lateCount: Int, madeUpCount: Int, skippedCount: Int = 0,
        pillsTotal: Int?, pillsRemaining: Int?, refillReminder: RefillReminder, pausedUntil: Date?
    ) {
        self.id = id
        self.name = name
        self.dosesPerDay = dosesPerDay
        self.lastTakenAt = lastTakenAt.map(UTCTimestamp.floorToSecond)
        self.nextDueAt = UTCTimestamp.floorToSecond(nextDueAt)
        self.deadlineAt = UTCTimestamp.floorToSecond(deadlineAt)
        self.takenCount = takenCount
        self.missedCount = missedCount
        self.lateCount = lateCount
        self.madeUpCount = madeUpCount
        self.skippedCount = skippedCount
        self.pillsTotal = pillsTotal
        self.pillsRemaining = pillsRemaining
        self.refillReminder = refillReminder
        self.pausedUntil = pausedUntil.map(UTCTimestamp.floorToSecond)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, dosesPerDay, lastTakenAt, nextDueAt, deadlineAt, takenCount, missedCount, lateCount, madeUpCount, skippedCount
        case pillsTotal, pillsRemaining, refillReminder, pausedUntil
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id.uuidString, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(dosesPerDay, forKey: .dosesPerDay)
        try c.encode(lastTakenAt.map(UTCTimestamp.string(from:)), forKey: .lastTakenAt)
        try c.encode(UTCTimestamp.string(from: nextDueAt), forKey: .nextDueAt)
        try c.encode(UTCTimestamp.string(from: deadlineAt), forKey: .deadlineAt)
        try c.encode(takenCount, forKey: .takenCount)
        try c.encode(missedCount, forKey: .missedCount)
        try c.encode(lateCount, forKey: .lateCount)
        try c.encode(madeUpCount, forKey: .madeUpCount)
        try c.encode(skippedCount, forKey: .skippedCount)
        try c.encode(pillsTotal, forKey: .pillsTotal)
        try c.encode(pillsRemaining, forKey: .pillsRemaining)
        try c.encode(refillReminder, forKey: .refillReminder)
        try c.encode(pausedUntil.map(UTCTimestamp.string(from:)), forKey: .pausedUntil)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(UUID.self, forKey: .id),
            name: try c.decode(String.self, forKey: .name),
            dosesPerDay: try c.decode(Int.self, forKey: .dosesPerDay),
            lastTakenAt: try c.optionalTimestamp(.lastTakenAt),
            nextDueAt: try c.timestamp(.nextDueAt),
            deadlineAt: try c.timestamp(.deadlineAt),
            takenCount: try c.decode(Int.self, forKey: .takenCount),
            missedCount: try c.decode(Int.self, forKey: .missedCount),
            lateCount: try c.decode(Int.self, forKey: .lateCount),
            madeUpCount: try c.decode(Int.self, forKey: .madeUpCount),
            skippedCount: try c.decodeIfPresent(Int.self, forKey: .skippedCount) ?? 0,
            pillsTotal: try c.decodeIfPresent(Int.self, forKey: .pillsTotal),
            pillsRemaining: try c.decodeIfPresent(Int.self, forKey: .pillsRemaining),
            refillReminder: try c.decode(RefillReminder.self, forKey: .refillReminder),
            pausedUntil: try c.optionalTimestamp(.pausedUntil)
        )
    }
}

extension Medication {
    public func snapshot(now: Date) -> MedicationSnapshot {
        let planner = planner
        let dose = planner.currentDose(now: now)
        return MedicationSnapshot(
            id: id,
            name: name,
            dosesPerDay: settings.dosesPerDay,
            lastTakenAt: planner.lastTaken(now: now)?.takenAt,
            nextDueAt: dose.dueAt,
            deadlineAt: dose.deadlineAt,
            takenCount: planner.daysTaken(now: now),
            missedCount: planner.missedCount(now: now),
            lateCount: planner.lateCount(now: now),
            madeUpCount: planner.madeUpCount(now: now),
            skippedCount: planner.skippedCount(now: now),
            pillsTotal: settings.pills?.total,
            pillsRemaining: settings.pills?.remaining,
            refillReminder: settings.refillReminder,
            pausedUntil: planner.restingUntil(now: now)
        )
    }
}

extension KeyedDecodingContainer {
    fileprivate func optionalTimestamp(_ key: Key) throws -> Date? {
        guard let text = try decodeIfPresent(String.self, forKey: key) else { return nil }
        guard let value = UTCTimestamp.date(from: text) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Unreadable timestamp \(text)")
        }
        return value
    }

    fileprivate func timestamp(_ key: Key) throws -> Date {
        guard let value = try optionalTimestamp(key) else {
            throw DecodingError.valueNotFound(Date.self, .init(codingPath: codingPath + [key], debugDescription: "Missing timestamp"))
        }
        return value
    }
}
