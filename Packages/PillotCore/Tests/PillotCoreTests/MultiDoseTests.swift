import Foundation
import Testing
@testable import PillotCore

/// Several doses a day, and several medications sharing alerts.
@Suite struct MultiDoseTests {
    private func twiceADay() -> Planner {
        Planner(settings: ReminderSettings(mainHour: 8, mainMinute: 0, dosesPerDay: 2, maxInterval: 12 * hour))
    }

    @Test func oneDoseADayKeepsTheOldMainTimeRule() {
        var rng = SeededGenerator(seed: 7)
        for _ in 0..<500 {
            let planner = Planner(settings: ReminderSettings(mainHour: Int.random(in: 0...23, using: &rng), mainMinute: Int.random(in: 0...59, using: &rng)))
            let date = vn(2026, 1, 1, 0).addingTimeInterval(TimeInterval.random(in: 0...(400 * 24 * hour), using: &rng).rounded())
            let s = planner.settings
            #expect(planner.firstSlot(after: date) == VietnamClock.firstMainTime(after: date, hour: s.mainHour, minute: s.mainMinute))
            #expect(planner.firstSlot(atOrAfter: date) == VietnamClock.firstMainTime(atOrAfter: date, hour: s.mainHour, minute: s.mainMinute))
        }
    }

    @Test func slotsRepeatEveryPeriodFromTheMainTime() {
        let planner = Planner(settings: ReminderSettings(mainHour: 6, mainMinute: 30, dosesPerDay: 3))
        #expect(planner.firstSlot(after: vn(2026, 10, 1, 6, 30)) == vn(2026, 10, 1, 14, 30))
        #expect(planner.firstSlot(after: vn(2026, 10, 1, 23)) == vn(2026, 10, 1, 22, 30).addingTimeInterval(8 * hour))
        #expect(planner.firstSlot(atOrAfter: vn(2026, 10, 1, 22, 30)) == vn(2026, 10, 1, 22, 30))
        #expect(planner.firstSlot(after: vn(2026, 10, 1, 3)) == vn(2026, 10, 1, 6, 30))
    }

    @Test func takenOnTimeMovesToTheNextDoseOfTheDay() {
        var planner = twiceADay()
        planner.markTaken(at: vn(2026, 10, 1, 8, 5))
        let dose = planner.currentDose(now: vn(2026, 10, 1, 9))
        #expect(dose.dueAt == vn(2026, 10, 1, 20))
        #expect(dose.deadlineAt == vn(2026, 10, 1, 20, 5))
        #expect(dose.lateUntil == vn(2026, 10, 2, 2, 5))
        planner.markTaken(at: vn(2026, 10, 1, 20))
        #expect(planner.currentDose(now: vn(2026, 10, 1, 21)).dueAt == vn(2026, 10, 2, 8))
        #expect(planner.lateCount(now: vn(2026, 10, 2, 9)) == 0)
    }

    @Test func missedEveningDoseCountsAndTheNextMorningFollows() {
        var planner = twiceADay()
        planner.markTaken(at: vn(2026, 10, 1, 8))
        // 20:00 never taken: missed once its 6 h late window ends at 02:00.
        #expect(planner.missedCount(now: vn(2026, 10, 2, 1, 59)) == 0)
        #expect(planner.missedCount(now: vn(2026, 10, 2, 2, 1)) == 1)
        #expect(planner.currentDose(now: vn(2026, 10, 2, 2, 1)).dueAt == vn(2026, 10, 2, 8))
        let days = planner.dayStatuses(now: vn(2026, 10, 2, 9))
        #expect(days[VietnamClock.calendar.startOfDay(for: vn(2026, 10, 1, 12))] == .missed)
    }

    @Test func lateTakeWithinTheShorterWindow() {
        var planner = twiceADay()
        planner.markTaken(at: vn(2026, 10, 1, 8))
        planner.markTaken(at: vn(2026, 10, 1, 23))
        #expect(planner.lateCount(now: vn(2026, 10, 2, 0)) == 1)
        #expect(planner.missedCount(now: vn(2026, 10, 2, 0)) == 0)
        // The next deadline counts from the late take.
        #expect(planner.currentDose(now: vn(2026, 10, 2, 0)).deadlineAt == vn(2026, 10, 2, 11))
    }

    @Test func changingDosesPerDayResetsTheGapAndRealigns() {
        var planner = Planner()
        planner.markTaken(at: vn(2026, 10, 1, 21))
        planner.changeSchedule(hour: 9, minute: 0, dosesPerDay: 2, now: vn(2026, 10, 1, 21, 30))
        #expect(planner.settings.maxInterval == 12 * hour)
        #expect(planner.settings.maxIntervalRange == (12 * hour)...(18 * hour))
        #expect(planner.currentDose(now: vn(2026, 10, 1, 21, 30)).dueAt == vn(2026, 10, 2, 9))
        // An unknown count is ignored.
        planner.changeSchedule(hour: 9, minute: 0, dosesPerDay: 5, now: vn(2026, 10, 1, 22))
        #expect(planner.settings.dosesPerDay == 2)
    }

    @Test func unknownDosesPerDayDecodesAsOnce() throws {
        let settings = try JSONDecoder().decode(ReminderSettings.self, from: Data(#"{"dosesPerDay": 5}"#.utf8))
        #expect(settings.dosesPerDay == 1)
        #expect(ReminderSettings(dosesPerDay: 7).dosesPerDay == 1)
    }

    @Test func medicationsAtTheSameTimeShareOneAlert() {
        var a = Medication(name: "Vitamin D"), b = Medication(name: "Iron")
        a.planner.markTaken(at: vn(2026, 10, 1, 21))
        b.planner.markTaken(at: vn(2026, 10, 1, 21))
        b.settings.pills = PillCounter(count: 3, at: vn(2026, 10, 1, 8))
        let now = vn(2026, 10, 1, 21, 1)
        let alerts = AlertPlanner.alerts(for: [MedicationReminders(a, now: now, language: .en), MedicationReminders(b, now: now, language: .en)],
                                         vibrateOnly: false, language: .en)
        let first = try! #require(alerts.first)
        #expect(first.date == vn(2026, 10, 2, 21))
        #expect(Set(first.medicationIDs) == [a.id, b.id])
        #expect(first.title == "Deadline reached: take Vitamin D, Iron. Iron: 3 pills left, time to buy more")
        #expect(Set(alerts.map(\.date)).count == alerts.count)
    }

    @Test func medicationsAtDifferentTimesStaySeparate() {
        let a = Medication(name: "A", settings: ReminderSettings(mainHour: 8))
        let b = Medication(name: "B", settings: ReminderSettings(mainHour: 21))
        let now = vn(2026, 10, 1, 7)
        let alerts = AlertPlanner.alerts(for: [MedicationReminders(a, now: now, language: .vi), MedicationReminders(b, now: now, language: .vi)],
                                         vibrateOnly: false, language: .vi)
        #expect(alerts[0].medicationIDs == [a.id])
        #expect(alerts[0].title == "Tới hạn chót: uống A")
        #expect(alerts.contains { $0.medicationIDs == [b.id] && $0.date == vn(2026, 10, 1, 21) })
    }

    @Test func manyNamesAreShortened() {
        #expect(AlertPlanner.names(["A", "B", "C", "D"], language: .en) == "A, B +2")
        #expect(AlertPlanner.names([""], language: .en) == "your pill")
        #expect(AlertPlanner.title(for: .main, names: "Iron", language: .vi) == "Tới giờ uống Iron")
    }

    @Test func alarmBudgetKeepsTheEarliest() {
        let meds = (0..<4).map { Medication(name: "M\($0)", settings: ReminderSettings(mainHour: 6 + $0, dosesPerDay: 3)) }
        let now = vn(2026, 10, 1, 5)
        let alerts = AlertPlanner.alerts(for: meds.map { MedicationReminders($0, now: now, language: .en) }, vibrateOnly: false)
        #expect(alerts.count == AlertPlanner.alarmLimit)
        #expect(alerts.map(\.date) == alerts.map(\.date).sorted())
    }
}
