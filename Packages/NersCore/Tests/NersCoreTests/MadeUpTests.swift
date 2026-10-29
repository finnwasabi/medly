import Foundation
import Testing
@testable import NersCore

/// Uống bù: hôm qua hụt, hôm nay uống thêm một viên cho hôm qua.
@Suite struct MadeUpTests {
    /// Uống 26/10 21:00, bỏ 27/10, nên lần 27/10 thành hụt lúc 28/10 09:00 (hết cửa sổ trễ 12 giờ).
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
        // Còn trong cửa sổ trễ thì chưa phải hụt, chưa có gì để bù.
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

        // Hai viên trong ngày: một cho hôm nay, một bù hôm qua.
        #expect(planner.settings.pills?.remaining == 25)
        // Uống bù không làm đổi lịch nhắc.
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
        // Sửa giờ lần uống trước sang 27/10 21:00: không còn lần hụt nào để khớp.
        planner.editTakenTime(id: first.id, to: vn(2026, 10, 27, 21))
        let now = vn(2026, 10, 28, 11)
        #expect(planner.madeUpCount(now: now) == 0)
        #expect(planner.timeline(now: now).filter { $0.status == .madeUp }.count == 1)
    }

    @Test func severalMissesAndOnlyRecentOnesAreOutstanding() {
        var planner = Planner()
        planner.markTaken(at: vn(2026, 10, 10, 21))
        let now = vn(2026, 10, 20, 12)
        // Bỏ từ 11/10 tới 19/10: 9 lần hụt, chỉ 7 ngày gần nhất còn nhắc bù.
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
        #expect(alerts.first?.title == "Tới giờ uống thuốc. Còn 1 viên hụt chưa uống bù. Còn 5 viên, nhớ mua thêm")
    }

    @Test func oldRecordsWithoutMakeUpFieldStillDecode() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","scheduledAt":0,"takenAt":0,"status":"taken","consumedPill":false,"nextAtMainTime":false}"#
        let record = try JSONDecoder().decode(DoseRecord.self, from: Data(json.utf8))
        #expect(record.makesUpFor == nil)
    }

    @Test func snapshotReportsMadeUp() {
        var (planner, missed) = plannerWithOneMiss()
        planner.markMadeUp(missedAt: missed.scheduledAt, at: vn(2026, 10, 28, 12))
        let snapshot = planner.snapshot(now: vn(2026, 10, 28, 13))
        #expect(snapshot.missedCount == 1)
        #expect(snapshot.madeUpCount == 1)
    }
}
