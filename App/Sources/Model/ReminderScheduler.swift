import AlarmKit
import AppIntents
import NersCore
import SwiftUI
import UserNotifications

/// Feeds planned alerts into AlarmKit (ringing alarms) and UserNotifications (plain notifications).
/// Times are always absolute: `.fixed` for alarms and seconds from now for notifications,
/// so changing the phone's time zone never shifts them.
nonisolated struct ReminderScheduler: Sendable {
    static let doseCategory = "dose"
    static let takenAction = "taken"

    /// Returns how many alerts could not be scheduled.
    func apply(_ alerts: [PlannedAlert], cancelActive: Bool, snooze: TimeInterval) async -> Int {
        var failures = 0
        // Notification button titles follow the selected language.
        Self.registerCategory()
        let manager = AlarmManager.shared
        // ponytail: cancel and reschedule everything each time (a few hundred alarms); measure on a device and switch to diffing if slow.
        for alarm in (try? manager.alarms) ?? [] where cancelActive || alarm.state == .scheduled {
            try? manager.cancel(id: alarm.id)
        }
        for alert in alerts where alert.usesAlarm {
            do {
                _ = try await manager.schedule(id: UUID(), configuration: Self.configuration(for: alert, snooze: snooze))
            } catch {
                failures += 1
            }
        }

        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        if cancelActive { center.removeAllDeliveredNotifications() }
        for alert in alerts where !alert.usesAlarm {
            let interval = alert.date.timeIntervalSinceNow
            guard interval >= 1 else { continue }
            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body = alert.body
            content.sound = .default
            content.categoryIdentifier = Self.doseCategory
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger))
            } catch {
                failures += 1
            }
        }
        return failures
    }

    private static func configuration(for alert: PlannedAlert, snooze: TimeInterval) -> AlarmManager.AlarmConfiguration<DoseAlarmMetadata> {
        let presentation = AlarmPresentation(
            alert: AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: alert.title),
                stopButton: AlarmButton(text: LocalizedStringResource(stringLiteral: L("Đã uống", "Taken")), textColor: .white, systemImageName: "checkmark"),
                secondaryButton: AlarmButton(text: LocalizedStringResource(stringLiteral: L("Hoãn", "Snooze")), textColor: .white, systemImageName: "zzz"),
                secondaryButtonBehavior: .countdown
            ),
            countdown: AlarmPresentation.Countdown(title: LocalizedStringResource(stringLiteral: L("Đang hoãn", "Snoozed")))
        )
        return AlarmManager.AlarmConfiguration(
            countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: snooze),
            schedule: .fixed(alert.date),
            attributes: AlarmAttributes<DoseAlarmMetadata>(
                presentation: presentation, metadata: DoseAlarmMetadata(language: AppLanguage.current.rawValue), tintColor: Palette.primary),
            stopIntent: MarkTakenIntent()
        )
    }

    /// A "Taken" button right on the notification, without opening the app.
    static func registerCategory() {
        let taken = UNNotificationAction(identifier: takenAction, title: L("Đã uống", "Taken"), options: [])
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: doseCategory, actions: [taken], intentIdentifiers: []),
        ])
    }
}

/// The alarm's "Taken" button. Runs in the background without opening the app.
struct MarkTakenIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Đã uống thuốc"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        await AppModel.shared.markTaken()
        return .result()
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if response.actionIdentifier == ReminderScheduler.takenAction {
            await AppModel.shared.markTaken()
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
