import Foundation
import Testing
@testable import NersCore

@Suite struct AlertPlannerTests {
    /// Taken at 23:00, so the next dose has main time 21:00 and deadline 23:00, leaving room for the pre-deadline chain.
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

@Suite struct EnglishTextTests {
    @Test func everyAlertKindHasBothLanguages() {
        let kinds: [ReminderKind] = [.main, .repeat, .hourly, .final, .deadline, .overdue]
        for kind in kinds {
            let vi = AlertPlanner.title(for: kind, language: .vi)
            let en = AlertPlanner.title(for: kind, language: .en)
            #expect(!vi.isEmpty && !en.isEmpty && vi != en)
        }
    }

    @Test func englishAlertsAndMessages() {
        var planner = Planner()
        planner.markTaken(at: vn(2026, 10, 1, 23))
        let alerts = AlertPlanner.alerts(
            for: planner.events(now: vn(2026, 10, 1, 23, 1)), vibrateOnly: false,
            refillMessage: PillCounter(count: 1, at: vn(2026, 10, 1, 8)).refillMessage(RefillReminder(), language: .en),
            missedMessage: AlertPlanner.missedMessage(count: 2, language: .en), language: .en)
        #expect(alerts.first?.title == "Time to take your pill. 2 missed pills not made up. 1 pill left, time to buy more")
        #expect(alerts.first?.body == "Deadline 23:00 VN time.")
        #expect(TimeFormatting.vietnamTime(vn(2026, 10, 1, 21), language: .en) == "21:00 VN time")
    }
}
