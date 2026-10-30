import AlarmKit
import AppIntents
import PillotCore
import SwiftUI
import UserNotifications

/// Feeds planned alerts into AlarmKit (ringing alarms) and UserNotifications (plain notifications).
/// Times are always absolute: `.fixed` for alarms and seconds from now for notifications,
/// so changing the phone's time zone never shifts them.
nonisolated struct ReminderScheduler: Sendable {
    static let doseCategory = "dose"
    static let takenAction = "taken"
    static let medicationsKey = "medications"
    /// Which medications each scheduled alarm is for. AlarmKit does not hand the metadata back, so it lives here.
    private static let alarmMedicationsKey = "alarmMedications"

    /// Returns how many alerts could not be scheduled.
    /// `cancelActiveFor`: alarms of these medications that are ringing or snoozed are stopped too. Others keep ringing,
    /// so taking one medication never silences another one's reminder.
    func apply(_ alerts: [PlannedAlert], cancelActiveFor taken: Set<UUID>, snooze: TimeInterval) async -> Int {
        var failures = 0
        // Notification button titles follow the selected language.
        Self.registerCategory()
        let manager = AlarmManager.shared
        let defaults = UserDefaults.standard
        let known = defaults.dictionary(forKey: Self.alarmMedicationsKey) as? [String: [String]] ?? [:]
        let takenIDs = Set(taken.map(\.uuidString))
        var kept: [String: [String]] = [:]
        // ponytail: cancel and reschedule everything each time (up to AlertPlanner.alarmLimit); switch to diffing if slow on a device.
        for alarm in (try? manager.alarms) ?? [] {
            let meds = known[alarm.id.uuidString]
            // An active alarm without a record comes from a version before medications; any "Taken" stops it.
            let belongsToTaken = meds.map { !takenIDs.isDisjoint(with: $0) } ?? !taken.isEmpty
            if alarm.state == .scheduled || belongsToTaken {
                try? manager.cancel(id: alarm.id)
            } else if let meds {
                kept[alarm.id.uuidString] = meds
            }
        }
        for alert in alerts where alert.usesAlarm {
            let id = UUID()
            do {
                _ = try await manager.schedule(id: id, configuration: Self.configuration(for: alert, snooze: snooze))
                kept[id.uuidString] = alert.medicationIDs.map(\.uuidString)
            } catch {
                failures += 1
            }
        }
        defaults.set(kept, forKey: Self.alarmMedicationsKey)

        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        if !taken.isEmpty {
            let delivered = await center.deliveredNotifications().filter { note in
                let meds = note.request.content.userInfo[Self.medicationsKey] as? [String] ?? []
                return meds.isEmpty || !takenIDs.isDisjoint(with: meds)
            }
            center.removeDeliveredNotifications(withIdentifiers: delivered.map(\.request.identifier))
        }
        for alert in alerts where !alert.usesAlarm {
            let interval = alert.date.timeIntervalSinceNow
            guard interval >= 1 else { continue }
            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body = alert.body
            content.sound = .default
            content.categoryIdentifier = Self.doseCategory
            content.userInfo = [Self.medicationsKey: alert.medicationIDs.map(\.uuidString)]
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
        // The only way to stop the alarm is "Taken". Snooze rings again after `snooze`, as often as needed.
        let presentation = AlarmPresentation(
            alert: AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: alert.title),
                stopButton: AlarmButton(text: LocalizedStringResource(stringLiteral: L("Đã uống", "Taken")), textColor: .black, systemImageName: "checkmark"),
                secondaryButton: AlarmButton(text: LocalizedStringResource(stringLiteral: L("Hoãn \(Int(snooze / 60)) phút", "Snooze \(Int(snooze / 60)) min")), textColor: .white, systemImageName: "zzz"),
                secondaryButtonBehavior: .countdown
            ),
            countdown: AlarmPresentation.Countdown(title: LocalizedStringResource(stringLiteral: L("Đang hoãn: \(alert.names)", "Snoozed: \(alert.names)")))
        )
        return AlarmManager.AlarmConfiguration(
            countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: snooze),
            schedule: .fixed(alert.date),
            attributes: AlarmAttributes<DoseAlarmMetadata>(
                presentation: presentation,
                metadata: DoseAlarmMetadata(language: AppLanguage.current.rawValue, names: alert.names),
                tintColor: Palette.primary),
            stopIntent: MarkTakenIntent(ids: alert.medicationIDs)
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
    static let title: LocalizedStringResource = "Taken"
    static let isDiscoverable = false

    /// Medication ids separated by commas. Empty for alarms from before medications existed.
    @Parameter(title: "Medications")
    var medications: String

    init() { medications = "" }

    init(ids: [UUID]) { medications = ids.map(\.uuidString).joined(separator: ",") }

    @MainActor
    func perform() async throws -> some IntentResult {
        await AppModel.shared.markTaken(medications.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
        return .result()
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if response.actionIdentifier == ReminderScheduler.takenAction {
            let ids = (response.notification.request.content.userInfo[ReminderScheduler.medicationsKey] as? [String] ?? []).compactMap(UUID.init(uuidString:))
            await AppModel.shared.markTaken(ids)
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
