import Foundation
import Testing
@testable import PillotCore

/// Changes the process time zone (like a user changing the phone's) and compares results.
/// Serialized because it changes global state.
@Suite(.serialized) struct TimeZoneTests {
    private func scenario() throws -> (events: [ReminderEvent], json: Data, next: Date, missed: Int) {
        var planner = Planner(settings: ReminderSettings(mainHour: 23, mainMinute: 30, pills: PillCounter(count: 30, at: vn(2026, 10, 1, 9))))
        planner.markTaken(at: vn(2026, 10, 24, 23, 40))
        planner.markTaken(at: vn(2026, 10, 25, 23, 31))
        planner.markTaken(at: vn(2026, 10, 27, 20))
        let now = vn(2026, 10, 27, 20, 5)
        return (planner.events(now: now), try Snapshot(name: nil, medications: [Medication(id: UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964FF")!, name: "TZ", settings: planner.settings, history: planner.history)], now: now).jsonData(), planner.nextReminder(now: now), planner.missedCount(now: now))
    }

    private func setDeviceTimeZone(_ zone: TimeZone) {
        setenv("TZ", zone.identifier, 1)
        NSTimeZone.resetSystemTimeZone()
        NSTimeZone.default = zone
    }

    @Test func resultsIdenticalAcrossDeviceTimeZones() throws {
        let original = TimeZone.current
        defer { setDeviceTimeZone(original) }

        setDeviceTimeZone(VietnamClock.timeZone)
        let reference = try scenario()
        #expect(reference.next == vn(2026, 10, 28, 20))
        #expect(reference.missed == 1)

        for id in ["Asia/Tokyo", "Europe/Paris", "America/Los_Angeles"] {
            let zone = TimeZone(identifier: id)!
            setDeviceTimeZone(zone)
            #expect(TimeZone.current.identifier == id)
            let result = try scenario()
            #expect(result.events == reference.events)
            #expect(result.json == reference.json)
            #expect(result.next == reference.next)
            #expect(result.missed == reference.missed)
        }
    }

    @Test func formatting() {
        let date = utc("2026-10-27T14:00:00Z")
        #expect(TimeFormatting.vietnamTime(date) == "21:00 giờ VN")
        #expect(TimeFormatting.clockTime(date, in: TimeZone(identifier: "Asia/Tokyo")!) == "23:00")
        #expect(TimeFormatting.clockTime(date, in: TimeZone(identifier: "Europe/Paris")!) == "15:00")
        #expect(TimeFormatting.clockTime(date, in: TimeZone(identifier: "America/Los_Angeles")!) == "07:00")
        #expect(TimeFormatting.dualTime(date, deviceTimeZone: TimeZone(identifier: "Asia/Tokyo")!) == "21:00 giờ VN, 23:00 giờ máy")
        #expect(TimeFormatting.vietnamTime(utc("2026-10-27T17:15:00Z")) == "00:15 giờ VN")
    }
}
