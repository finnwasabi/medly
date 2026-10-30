import Foundation
import Testing
@testable import PillotCore

@Suite struct AlertDiffTests {
    @Test func samePlanChangesNothing() {
        let diff = AlertDiff.diff(scheduled: ["a": "k1", "b": "k2"], planned: ["k1", "k2"])
        #expect(diff.cancel.isEmpty)
        #expect(diff.add.isEmpty)
    }

    @Test func movedAlertIsReplacedOthersStay() {
        let diff = AlertDiff.diff(scheduled: ["a": "k1", "b": "k2", "c": "k3"], planned: ["k1", "k2b", "k3", "k4"])
        #expect(diff.cancel == ["b"])
        #expect(diff.add == [1, 3])
    }

    @Test func duplicateKeepsOne() {
        let diff = AlertDiff.diff(scheduled: ["a": "k1", "b": "k1"], planned: ["k1"])
        #expect(diff.cancel.count == 1)
        #expect(diff.add.isEmpty)
    }

    /// Taking one of two medications re-plans only that one: every alert of the other keeps its key, so it stays scheduled.
    /// A at :07 never shares a minute with B's chain (:00, :05, :10, :15, :30, :45); a shared minute would merge them into one alert.
    @Test func takingOneMedicationKeepsTheOther() {
        let a = Medication(name: "A", settings: ReminderSettings(mainHour: 8, mainMinute: 7))
        var b = Medication(name: "B", settings: ReminderSettings(mainHour: 20))
        let now = vn(2026, 10, 1, 7)
        let plan = { (meds: [Medication], at: Date) in
            AlertPlanner.alerts(for: meds.map { MedicationReminders($0, now: at, language: .en) }, vibrateOnly: false, language: .en)
        }
        let before = plan([a, b], now)
        b.planner.markTaken(at: now)
        let after = plan([a, b], now.addingTimeInterval(60)).map { $0.key(snoozeMinutes: 9, language: .en) }
        let keysOfA = before.filter { $0.medicationIDs == [a.id] && $0.date > now.addingTimeInterval(60) }.map { $0.key(snoozeMinutes: 9, language: .en) }
        let scheduled = Dictionary(uniqueKeysWithValues: before.enumerated().map { ("\($0.offset)", $0.element.key(snoozeMinutes: 9, language: .en)) })
        let diff = AlertDiff.diff(scheduled: scheduled, planned: after)
        #expect(!keysOfA.isEmpty)
        #expect(Set(keysOfA).isSubset(of: Set(after)))
        #expect(diff.add.count < after.count)
        #expect(diff.cancel.allSatisfy { before[Int($0)!].medicationIDs != [a.id] || before[Int($0)!].date <= now.addingTimeInterval(60) })
    }
}
