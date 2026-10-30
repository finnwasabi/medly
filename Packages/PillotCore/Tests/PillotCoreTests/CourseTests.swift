import Foundation
import Testing
@testable import PillotCore

@Suite struct CourseTests {
    /// A month of daily doses, then twice a day: the frozen month stays taken, with no misses appearing in it.
    @Test func changingTheScheduleKeepsThePast() {
        var planner = Planner(settings: ReminderSettings(mainHour: 21))
        for day in 1...20 { planner.markTaken(at: vn(2026, 10, day, 21, 5)) }
        let change = vn(2026, 10, 21, 10)
        let before = planner.dayStatuses(now: change)
        var reread = planner
        reread.changeSchedule(hour: 9, minute: 0, dosesPerDay: 2, now: change)
        reread.settings.maxInterval = 12 * hour
        #expect(reread.missedCount(now: change) > 0, "without freezing the past is re-read under the new schedule")

        planner.freezeHistory(now: change)
        planner.changeSchedule(hour: 9, minute: 0, dosesPerDay: 2, now: change)
        planner.settings.maxInterval = 12 * hour
        #expect(planner.missedCount(now: change) == 0)
        #expect(planner.dayStatuses(now: change) == before)
        #expect(planner.timeline(now: change).count == 20)
        // The new schedule runs from the last take: its first dose time, 09:00, is already due.
        #expect(planner.currentDose(now: change).dueAt == vn(2026, 10, 21, 9))
    }

    @Test func deletingAFrozenTakeDropsItsDay() {
        var planner = Planner(settings: ReminderSettings(mainHour: 21))
        let first = planner.markTaken(at: vn(2026, 10, 1, 21))
        planner.markTaken(at: vn(2026, 10, 2, 21))
        planner.freezeHistory(now: vn(2026, 10, 3, 10))
        planner.removeRecord(id: first.id)
        let days = planner.dayStatuses(now: vn(2026, 10, 3, 10))
        #expect(days[vn(2026, 10, 1, 0)] == nil)
        #expect(days[vn(2026, 10, 2, 0)] == .taken)
    }

    @Test func twoPillsADose() {
        var settings = ReminderSettings(mainHour: 21, pills: PillCounter(count: 10, at: vn(2026, 10, 1, 0)))
        settings.pillsPerDose = 2
        var planner = Planner(settings: settings)
        planner.markTaken(at: vn(2026, 10, 1, 21))
        #expect(planner.settings.pills?.remaining == 8)
        let undone = planner.undoLastTaken(now: vn(2026, 10, 1, 21, 2))
        #expect(undone)
        #expect(planner.settings.pills?.remaining == 10)
    }

    @Test func nothingRingsOrIsMissedAfterTheCourse() {
        var settings = ReminderSettings(mainHour: 21)
        settings.endDay = vn(2026, 10, 7, 0)
        var planner = Planner(settings: settings)
        planner.markTaken(at: vn(2026, 10, 1, 21))
        let events = planner.events(now: vn(2026, 10, 5, 22))
        #expect(!events.isEmpty)
        #expect(events.allSatisfy { $0.date < vn(2026, 10, 8, 0) })
        planner.markTaken(at: vn(2026, 10, 7, 21))
        let later = vn(2026, 10, 20, 12)
        #expect(planner.settings.courseEnded(now: later))
        #expect(planner.events(now: later).isEmpty)
        #expect(planner.restingUntil(now: later) == .distantFuture)
        let missedAfter = planner.timeline(now: later).filter { $0.status == .missed && $0.scheduledAt >= vn(2026, 10, 8, 0) }
        #expect(missedAfter.isEmpty)
        #expect(planner.timeline(now: later).allSatisfy { $0.status != .paused })
    }

    @Test func asNeededHasNoScheduleAndNoMisses() {
        var settings = ReminderSettings()
        settings.asNeeded = true
        settings.minGap = 6 * hour
        var planner = Planner(settings: settings)
        planner.markTaken(at: vn(2026, 10, 1, 8))
        planner.markTaken(at: vn(2026, 10, 1, 15))
        let now = vn(2026, 10, 9, 12)
        #expect(planner.events(now: now).isEmpty)
        #expect(planner.missedCount(now: now) == 0)
        #expect(planner.takenToday(now: vn(2026, 10, 1, 16)) == 2)
        #expect(planner.nextAllowed(now: vn(2026, 10, 1, 16)) == vn(2026, 10, 1, 21))
        #expect(planner.timeline(now: now).count == 2)
    }
}
