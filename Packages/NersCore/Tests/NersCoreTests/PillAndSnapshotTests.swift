import Foundation
import Testing
@testable import NersCore

@Suite struct PillCounterTests {
    @Test func countDownToZero() {
        var pills = PillCounter(count: 3, at: vn(2026, 10, 1, 8))
        let consumed = [pills.consume(), pills.consume(), pills.consume(), pills.consume()]
        #expect(consumed == [true, true, true, false])
        #expect(pills.remaining == 0)
        pills.restore()
        #expect(pills.remaining == 1)
    }

    @Test func refillReminderThreshold() {
        var pills = PillCounter(count: 10, at: vn(2026, 10, 1, 8))
        let reminder = RefillReminder(enabled: true, daysBefore: 7)
        var flags: [Bool] = []
        while pills.remaining > 0 {
            pills.consume()
            flags.append(pills.needsRefill(reminder))
        }
        // Còn 9, 8 thì chưa nhắc; còn 7 trở xuống thì nhắc.
        #expect(flags == [false, false, true, true, true, true, true, true, true, true])
        pills.add(3, at: vn(2026, 10, 11, 8))
        #expect(pills.refillMessage(reminder) == "còn 3 viên, nhớ mua thêm")
        #expect(pills.refillMessage(RefillReminder(enabled: false, daysBefore: 7)) == nil)
        pills.add(20, at: vn(2026, 10, 11, 9))
        #expect(pills.total == 33 && pills.remaining == 23)
        #expect(!pills.needsRefill(reminder))
    }

    @Test func daysTakenResetsOnAddPills() {
        var planner = Planner()
        planner.markTaken(at: vn(2026, 10, 1, 21))
        planner.markTaken(at: vn(2026, 10, 2, 21))
        #expect(planner.daysTaken(now: vn(2026, 10, 3, 8)) == 2)
        planner.addPills(10, now: vn(2026, 10, 3, 8))
        #expect(planner.daysTaken(now: vn(2026, 10, 3, 9)) == 0)
        planner.markTaken(at: vn(2026, 10, 3, 21))
        #expect(planner.daysTaken(now: vn(2026, 10, 3, 22)) == 1)
        #expect(planner.settings.pills?.remaining == 9)
    }
}

@Suite struct SnapshotTests {
    static let specJSON = """
    {
      "schemaVersion": 1,
      "updatedAt": "2026-10-27T14:03:00Z",
      "lastTakenAt": "2026-10-27T14:03:00Z",
      "nextDueAt": "2026-10-28T14:00:00Z",
      "deadlineAt": "2026-10-28T14:03:00Z",
      "daysTaken": 12,
      "missedCount": 1,
      "lateCount": 0,
      "pillsTotal": 28,
      "pillsRemaining": 16,
      "refillReminder": { "enabled": true, "daysBefore": 7 },
      "pausedUntil": null,
      "signatureExpiresAt": null
    }
    """

    private func object(_ data: Data) throws -> NSDictionary {
        try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
    }

    /// Dựng lại đúng tình huống trong JSON mẫu của spec: uống 21:03 giờ VN mỗi ngày từ 15/10,
    /// bỏ ngày 20/10, nhập 28 viên.
    @Test func matchesSpecExample() throws {
        var planner = Planner(settings: ReminderSettings(pills: PillCounter(count: 28, at: vn(2026, 10, 15, 8))))
        for day in 15...27 where day != 20 {
            planner.markTaken(at: vn(2026, 10, day, 21, 3))
        }
        let now = utc("2026-10-27T14:03:00Z")
        let data = try planner.snapshot(now: now).jsonData()
        #expect(try object(data) == object(Data(Self.specJSON.utf8)))

        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"pausedUntil\":null"))
        #expect(!text.contains("."))
    }

    @Test func nullsAndRoundTrip() throws {
        var planner = Planner(settings: ReminderSettings(refillReminder: RefillReminder(enabled: false, daysBefore: 5)))
        planner.pause(days: 2, now: vn(2026, 10, 27, 8))
        let now = vn(2026, 10, 27, 8).addingTimeInterval(0.75)
        let snapshot = planner.snapshot(now: now)
        let data = try snapshot.jsonData()
        let json = try object(data)
        for key in ["lastTakenAt", "pillsTotal", "pillsRemaining"] {
            #expect(json[key] is NSNull)
        }
        #expect(json["pausedUntil"] as? String == "2026-10-29T01:00:00Z")
        #expect(json["updatedAt"] as? String == "2026-10-27T01:00:00Z")
        #expect(json.count == 13)

        let decoded = try Snapshot.decode(from: data)
        #expect(decoded == snapshot)
        #expect(try Snapshot.decode(from: Data(SnapshotTests.specJSON.utf8)).nextDueAt == utc("2026-10-28T14:00:00Z"))
    }

    @Test func settingsDecodeWithDefaults() throws {
        let settings = try JSONDecoder().decode(ReminderSettings.self, from: Data(#"{"mainHour": 8}"#.utf8))
        #expect(settings.mainHour == 8)
        #expect(settings.maxInterval == 24 * hour)
        #expect(settings.refillReminder == RefillReminder(enabled: true, daysBefore: 7))
        let roundTrip = try JSONDecoder().decode(ReminderSettings.self, from: JSONEncoder().encode(settings))
        #expect(roundTrip == settings)
    }
}

@Suite struct DayAndPackTests {
    @Test func dayStatusesPickWorstPerVietnamDay() {
        var planner = Planner()
        planner.markTaken(at: vn(2026, 10, 1, 21))
        planner.markTaken(at: vn(2026, 10, 2, 23))
        // Ngày 3 bỏ, ngày 4 uống lại.
        planner.markTaken(at: vn(2026, 10, 4, 21))
        let days = planner.dayStatuses(now: vn(2026, 10, 5, 8))
        let start = { VietnamClock.calendar.startOfDay(for: vn(2026, 10, $0, 12)) }
        #expect(days[start(1)] == .taken)
        #expect(days[start(2)] == .late)
        #expect(days[start(3)] == .missed)
        #expect(days[start(4)] == .taken)
        #expect(days[start(5)] == nil)
    }

    @Test func onePackCountsDownAndAsksRefill() {
        var planner = Planner()
        planner.addPills(28, now: vn(2026, 10, 1, 8))
        for day in 0..<21 {
            planner.markTaken(at: vn(2026, 10, 1, 21).addingTimeInterval(TimeInterval(day) * 24 * hour))
        }
        let pills = planner.settings.pills!
        #expect(pills.remaining == 7)
        #expect(pills.refillMessage(planner.settings.refillReminder) == "còn 7 viên, nhớ mua thêm")
        #expect(planner.daysTaken(now: vn(2026, 10, 22, 8)) == 21)
        for day in 21..<30 {
            planner.markTaken(at: vn(2026, 10, 1, 21).addingTimeInterval(TimeInterval(day) * 24 * hour))
        }
        #expect(planner.settings.pills?.remaining == 0)
        #expect(planner.history.count == 30)
    }
}
