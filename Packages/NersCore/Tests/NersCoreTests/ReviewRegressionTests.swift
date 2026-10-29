import Foundation
import Testing
@testable import NersCore

/// Regressions found in review.
@Suite struct ReviewRegressionTests {
    private func day(_ d: Int) -> Date { VietnamClock.calendar.startOfDay(for: vn(2026, 10, d, 12)) }

    /// A late dose taken more than 12 h after its main time belongs to the day of the dose it was late for,
    /// the same day History shows, not to the next day.
    @Test func lateDoseCountsForTheDayItWasLateFor() {
        var planner = Planner()
        // Taken 2 h late on 1/10, so the 2/10 deadline is 23:00 and the late window runs to 3/10 11:00.
        planner.markTaken(at: vn(2026, 10, 1, 23))
        planner.markTaken(at: vn(2026, 10, 3, 9, 30))
        let now = vn(2026, 10, 3, 10)
        let late = planner.timeline(now: now).filter { $0.status == .late }
        #expect(late.map(\.scheduledAt) == [vn(2026, 10, 2, 21)])
        let days = planner.dayStatuses(now: now)
        #expect(days[day(2)] == .late)
        #expect(days[day(3)] == nil)
    }

    /// Changing the main time moves the computed reminder time of past misses. A make-up must stay linked to its miss,
    /// otherwise the miss shows up again as "not made up" and every alert nags about it.
    @Test(arguments: [(14, 0), (3, 30), (23, 30)])
    func makeUpSurvivesMainTimeChange(hour: Int, minute: Int) {
        var planner = Planner()
        planner.addPills(28, now: vn(2026, 10, 1, 8))
        planner.markTaken(at: vn(2026, 10, 26, 21))
        let missed = planner.outstandingMissed(now: vn(2026, 10, 28, 10)).first!
        planner.markMadeUp(missedAt: missed.scheduledAt, at: vn(2026, 10, 28, 10))
        planner.markTaken(at: vn(2026, 10, 28, 21))
        let now = vn(2026, 10, 28, 21, 5)
        #expect(planner.madeUpCount(now: now) == 1)

        planner.changeMainTime(hour: hour, minute: minute, now: now)
        #expect(planner.missedCount(now: now) == 1)
        #expect(planner.madeUpCount(now: now) == 1)
        #expect(planner.outstandingMissed(now: now).isEmpty)
        #expect(planner.settings.pills?.remaining == 25)
    }
}
