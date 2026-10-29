import Foundation
import Testing
@testable import NersCore

/// Make-ups: missed yesterday, take an extra pill today for yesterday.
@Suite struct MadeUpTests {
    /// Taken 26/10 21:00, skipped 27/10, so 27/10 becomes missed at 28/10 09:00 (end of the 12 h late window).
    private func plannerWithOneMiss() -> (Planner, missed: DoseRecord) {
        var planner = Planner()
        planner.addPills(28, now: vn(2026, 10, 1, 8))
        planner.markTaken(at: vn(2026, 10, 26, 21))
        let missed = planner.outstandingMissed(now: vn(2026, 10, 28, 10)).first!
        return (planner, missed)
    }

    @Test func missedDoseIsOutstandingUntilMadeUp() {
        let (planner, missed) = plannerWithOneMiss()
        #expect(VietnamClock.calendar.isDate(missed.scheduledAt, inSameDayAs: vn(2026, 10, 27, 12)))
        #expect(planner.outstandingMissed(now: vn(2026, 10, 28, 10)).count == 1)
        // Within the late window it is not missed yet, so there is nothing to make up.
        #expect(planner.outstandingMissed(now: vn(2026, 10, 28, 8)).isEmpty)
    }

    @Test func makeUpTogetherWithTodaysDose() {
        var (planner, missed) = plannerWithOneMiss()
        let now = vn(2026, 10, 28, 21)
        planner.markTaken(at: now)
        let before = planner.currentDose(now: now.addingTimeInterval(60))
        let made = planner.markMadeUp(missedAt: missed.scheduledAt, at: now.addingTimeInterval(30))
        #expect(made != nil)
        let later = now.addingTimeInterval(60)

        // Two pills in one day: one for today, one making up yesterday.
        #expect(planner.settings.pills?.remaining == 25)
        // A make-up does not change the schedule.
        #expect(planner.currentDose(now: later) == before)
        #expect(planner.missedCount(now: later) == 1)
        #expect(planner.madeUpCount(now: later) == 1)
        #expect(planner.outstandingMissed(now: later).isEmpty)
        #expect(planner.timeline(now: later).map(\.status) == [.taken, .madeUp, .taken])
        #expect(planner.daysTaken(now: later) == 2)

        let day = { VietnamClock.calendar.startOfDay(for: vn(2026, 10, $0, 12)) }
        let days = planner.dayStatuses(now: later)
        #expect(days[day(27)] == .madeUp)
        #expect(days[day(28)] == .taken)
    }

    @Test func cannotMakeUpTwiceOrForADoseThatWasNotMissed() {
        var (planner, missed) = plannerWithOneMiss()
        let now = vn(2026, 10, 28, 12)
        #expect(planner.markMadeUp(missedAt: missed.scheduledAt, at: now) != nil)
        #expect(planner.markMadeUp(missedAt: missed.scheduledAt, at: now.addingTimeInterval(60)) == nil)
        #expect(planner.markMadeUp(missedAt: vn(2026, 10, 26, 21), at: now) == nil)
        #expect(planner.settings.pills?.remaining == 26)
    }

    @Test func removingAMistakenMakeUpGivesThePillBack() {
        var (planner, missed) = plannerWithOneMiss()
        let now = vn(2026, 10, 28, 12)
        let made = planner.markMadeUp(missedAt: missed.scheduledAt, at: now)!
        planner.removeRecord(id: made.id)
        #expect(planner.settings.pills?.remaining == 27)
        #expect(planner.outstandingMissed(now: now).count == 1)
        #expect(planner.madeUpCount(now: now) == 0)
    }

    @Test func makeUpWhoseMissDisappearsStaysVisibleButUncounted() {
        var planner = Planner()
        let first = planner.markTaken(at: vn(2026, 10, 26, 21))
        let missed = planner.outstandingMissed(now: vn(2026, 10, 28, 10)).first!
        planner.markMadeUp(missedAt: missed.scheduledAt, at: vn(2026, 10, 28, 10))
        // Moving the earlier take to 27/10 21:00 leaves no miss to match.
        planner.editTakenTime(id: first.id, to: vn(2026, 10, 27, 21))
        let now = vn(2026, 10, 28, 11)
        #expect(planner.madeUpCount(now: now) == 0)
        #expect(planner.timeline(now: now).filter { $0.status == .madeUp }.count == 1)
    }

    @Test func severalMissesAndOnlyRecentOnesAreOutstanding() {
        var planner = Planner()
        planner.markTaken(at: vn(2026, 10, 10, 21))
        let now = vn(2026, 10, 20, 12)
        // Skipped 11/10 to 19/10: 9 misses, only the last 7 days are offered for make-up.
        #expect(planner.missedCount(now: now) == 9)
        let outstanding = planner.outstandingMissed(now: now)
        #expect(!outstanding.isEmpty && outstanding.count <= 7)
        #expect(outstanding.map(\.scheduledAt) == outstanding.map(\.scheduledAt).sorted(by: >))
    }

    @Test func pausedDaysAreNeverMissed() {
        var planner = Planner()
        planner.markTaken(at: vn(2026, 10, 26, 21))
        planner.pause(days: 3, now: vn(2026, 10, 26, 22))
        #expect(planner.outstandingMissed(now: vn(2026, 10, 29, 12)).isEmpty)
    }

    @Test func alertsCarryTheMissedLine() {
        let line = AlertPlanner.missedMessage(count: 1)
        #expect(AlertPlanner.missedMessage(count: 0) == nil)
        var planner = Planner()
        planner.markTaken(at: vn(2026, 10, 1, 23))
        let alerts = AlertPlanner.alerts(for: planner.events(now: vn(2026, 10, 1, 23, 1)), vibrateOnly: false,
                                         refillMessage: "còn 5 viên, nhớ mua thêm", missedMessage: line)
        #expect(alerts.first?.title == "Tới giờ uống thuốc. Còn 1 lần hụt chưa uống bù. Còn 5 viên, nhớ mua thêm")
    }

    @Test func oldRecordsWithoutMakeUpFieldStillDecode() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","scheduledAt":0,"takenAt":0,"status":"taken","consumedPill":false,"nextAtMainTime":false}"#
        let record = try JSONDecoder().decode(DoseRecord.self, from: Data(json.utf8))
        #expect(record.makesUpFor == nil)
    }

    @Test func snapshotReportsMadeUp() {
        var (planner, missed) = plannerWithOneMiss()
        planner.markMadeUp(missedAt: missed.scheduledAt, at: vn(2026, 10, 28, 12))
        let snapshot = Medication(name: "", settings: planner.settings, history: planner.history).snapshot(now: vn(2026, 10, 28, 13))
        #expect(snapshot.missedCount == 1)
        #expect(snapshot.madeUpCount == 1)
    }
}
