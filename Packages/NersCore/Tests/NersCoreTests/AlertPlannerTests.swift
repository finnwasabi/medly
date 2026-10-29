import Foundation
import Testing
@testable import NersCore

@Suite struct AlertPlannerTests {
    /// Uống 23:00 nên lần kế có giờ chính 21:00 và hạn chót 23:00, đủ chỗ cho chuỗi nhắc trước hạn.
    let events: [ReminderEvent] = {
        var planner = Planner()
        planner.markTaken(at: vn(2026, 10, 1, 23))
        return planner.events(now: vn(2026, 10, 1, 23, 1))
    }()

    @Test func soundModeUsesAlarmsForEverything() {
        let alerts = AlertPlanner.alerts(for: events, vibrateOnly: false, refillMessage: nil)
        #expect(alerts.count == events.count)
        #expect(alerts.allSatisfy { $0.usesAlarm })
        #expect(alerts.first?.title == "Tới giờ uống thuốc")
        #expect(alerts.first?.date == vn(2026, 10, 2, 21))
    }

    @Test func vibrateOnlyKeepsEveryDeadlineAsAlarm() {
        let alerts = AlertPlanner.alerts(for: events, vibrateOnly: true, refillMessage: nil)
        let deadlines = events.filter(\.requiresSound).map(\.date)
        #expect(!deadlines.isEmpty)
        #expect(alerts.filter(\.usesAlarm).map(\.date) == deadlines)
        #expect(alerts.filter { !$0.usesAlarm }.count == AlertPlanner.notificationLimit)
    }

    @Test func withoutAlarmPermissionEverythingIsNotification() {
        let alerts = AlertPlanner.alerts(for: events, vibrateOnly: false, alarmsAvailable: false, refillMessage: nil)
        #expect(alerts.count == AlertPlanner.notificationLimit)
        #expect(alerts.allSatisfy { !$0.usesAlarm })
        #expect(alerts.first?.date == vn(2026, 10, 2, 21))
    }

    @Test func refillLineIsAppended() {
        let alerts = AlertPlanner.alerts(for: events, vibrateOnly: false, refillMessage: "còn 5 viên, nhớ mua thêm")
        #expect(alerts.first?.title == "Tới giờ uống thuốc. Còn 5 viên, nhớ mua thêm")
        #expect(alerts.first?.body == "Hạn chót 23:00 giờ VN.")
    }
}
