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

    /// The key each scheduled alarm was made from (`PlannedAlert.key`), so the next pass can leave it alone.
    private static let alarmKeysKey = "alarmKeys"

    /// What one pass did, for the Diagnostics section in Settings.
    struct Report: Sendable {
        /// Alarms the app holds after the pass, ringing or snoozed ones included.
        var alarms = 0
        var notifications = 0
        /// Alarms and notifications cancelled or added by this pass; the rest stayed as they were.
        var changed = 0
        var failures = 0
        /// The latest alert that is scheduled: reminders stop after this unless the app runs again.
        var lastAlert: Date?
    }

    /// Brings the scheduled alarms and notifications in line with `alerts`, touching only what differs.
    /// `cancelActiveFor`: alarms of these medications that are ringing or snoozed are stopped too. Others keep ringing,
    /// so taking one medication never silences another one's reminder.
    func apply(_ alerts: [PlannedAlert], cancelActiveFor taken: Set<UUID>, snooze: TimeInterval, language: Language) async -> Report {
        var report = Report()
        let snoozeMinutes = Int(snooze / 60)
        // Notification button titles follow the selected language.
        Self.registerCategory()
        let manager = AlarmManager.shared
        let defaults = UserDefaults.standard
        let known = defaults.dictionary(forKey: Self.alarmMedicationsKey) as? [String: [String]] ?? [:]
        let knownKeys = defaults.dictionary(forKey: Self.alarmKeysKey) as? [String: String] ?? [:]
        let takenIDs = Set(taken.map(\.uuidString))
        var kept: [String: [String]] = [:]
        var keptKeys: [String: String] = [:]
        var scheduled: [String: String] = [:]
        for alarm in (try? manager.alarms) ?? [] {
            let id = alarm.id.uuidString
            let meds = known[id]
            if alarm.state == .scheduled {
                // Alarms from before 0.3.6 have no key: they are replaced once.
                if let key = knownKeys[id] { scheduled[id] = key } else { try? manager.cancel(id: alarm.id) }
                continue
            }
            // Ringing or snoozed. One without a record comes from a version before medications; any "Taken" stops it.
            let belongsToTaken = meds.map { !takenIDs.isDisjoint(with: $0) } ?? !taken.isEmpty
            if belongsToTaken {
                try? manager.cancel(id: alarm.id)
            } else if let meds {
                kept[id] = meds
            }
        }
        let plannedAlarms = alerts.filter(\.usesAlarm)
        let alarmKeys = plannedAlarms.map { $0.key(snoozeMinutes: snoozeMinutes, language: language) }
        let alarmDiff = AlertDiff.diff(scheduled: scheduled, planned: alarmKeys)
        for id in alarmDiff.cancel { try? manager.cancel(id: UUID(uuidString: id)!) }
        let cancelled = Set(alarmDiff.cancel)
        for (id, key) in scheduled where !cancelled.contains(id) {
            kept[id] = known[id]
            keptKeys[id] = key
        }
        var failed: Set<Int> = []
        for index in alarmDiff.add {
            let alert = plannedAlarms[index], id = UUID()
            do {
                _ = try await manager.schedule(id: id, configuration: Self.configuration(for: alert, snooze: snooze))
                kept[id.uuidString] = alert.medicationIDs.map(\.uuidString)
                keptKeys[id.uuidString] = alarmKeys[index]
            } catch {
                failed.insert(index)
                report.failures += 1
            }
        }
        defaults.set(kept, forKey: Self.alarmMedicationsKey)
        defaults.set(keptKeys, forKey: Self.alarmKeysKey)
        report.alarms = kept.count
        report.changed = alarmDiff.cancel.count + alarmDiff.add.count
        report.lastAlert = plannedAlarms.indices.filter { !failed.contains($0) }.map { plannedAlarms[$0].date }.max()

        // Notifications use the key as their identifier, so the pending list itself says what is already scheduled.
        let center = UNUserNotificationCenter.current()
        if !taken.isEmpty {
            let delivered = await center.deliveredNotifications().filter { note in
                let meds = note.request.content.userInfo[Self.medicationsKey] as? [String] ?? []
                return meds.isEmpty || !takenIDs.isDisjoint(with: meds)
            }
            center.removeDeliveredNotifications(withIdentifiers: delivered.map(\.request.identifier))
        }
        let notes = alerts.filter { !$0.usesAlarm && $0.date.timeIntervalSinceNow >= 1 }
        let noteKeys = notes.map { $0.key(snoozeMinutes: snoozeMinutes, language: language) }
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        let noteDiff = AlertDiff.diff(scheduled: Dictionary(uniqueKeysWithValues: pending.map { ($0, $0) }), planned: noteKeys)
        center.removePendingNotificationRequests(withIdentifiers: noteDiff.cancel)
        report.notifications = pending.count - noteDiff.cancel.count
        for index in noteDiff.add {
            let alert = notes[index]
            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body = alert.body
            content.sound = .default
            content.categoryIdentifier = Self.doseCategory
            content.userInfo = [Self.medicationsKey: alert.medicationIDs.map(\.uuidString)]
            // Seconds from now: the absolute time is in the key, so a kept request still fires when planned.
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, alert.date.timeIntervalSinceNow), repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: noteKeys[index], content: content, trigger: trigger))
                report.notifications += 1
            } catch {
                report.failures += 1
            }
        }
        report.changed += noteDiff.cancel.count + noteDiff.add.count
        if let last = notes.last?.date { report.lastAlert = max(report.lastAlert ?? last, last) }
        return report
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
