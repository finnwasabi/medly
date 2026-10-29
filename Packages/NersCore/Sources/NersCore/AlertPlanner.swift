import Foundation

/// A decided alert: an AlarmKit alarm or a plain notification, with its texts.
public struct PlannedAlert: Equatable, Sendable {
    public var date: Date
    /// True: an AlarmKit alarm that rings on silent and in Focus. False: a plain notification that follows the phone's mode.
    public var usesAlarm: Bool
    public var title: String
    /// Secondary line, only plain notifications can show it.
    public var body: String
}

public enum AlertPlanner {
    /// iOS keeps only 64 pending notifications per app.
    public static let notificationLimit = 64

    /// Turns reminder events into alerts.
    /// `vibrateOnly`: reminders are plain notifications, but from the deadline on they are always ringing alarms.
    /// `alarmsAvailable` false (no AlarmKit permission): everything becomes a notification so reminders still happen.
    /// Only the earliest `notificationLimit` notifications are kept; the app refills on every launch and every "Taken".
    public static func alerts(
        for events: [ReminderEvent], vibrateOnly: Bool, alarmsAvailable: Bool = true, refillMessage: String?,
        missedMessage: String? = nil, language: Language = .vi
    ) -> [PlannedAlert] {
        var notifications = 0
        var result: [PlannedAlert] = []
        for event in events.sorted(by: { $0.date < $1.date }) {
            let usesAlarm = alarmsAvailable && (!vibrateOnly || event.requiresSound)
            if !usesAlarm {
                guard notifications < notificationLimit else { continue }
                notifications += 1
            }
            var title = title(for: event.kind, language: language)
            for line in [missedMessage, refillMessage].compactMap({ $0 }) {
                title += ". " + line.prefix(1).uppercased() + line.dropFirst()
            }
            let deadline = TimeFormatting.vietnamTime(event.deadlineAt, language: language)
            let body = language == .en ? "Deadline \(deadline)." : "Hạn chót \(deadline)."
            result.append(PlannedAlert(date: event.date, usesAlarm: usesAlarm, title: title, body: body))
        }
        return result
    }

    /// Line added to every alert while missed doses are not made up. Short because alarm titles get truncated; it gives no advice,
    /// the pointer to the leaflet lives on the missed card in the app.
    public static func missedMessage(count: Int, language: Language = .vi) -> String? {
        guard count > 0 else { return nil }
        return language == .en ? "\(count) missed \(count == 1 ? "pill" : "pills") not made up" : "còn \(count) viên hụt chưa uống bù"
    }

    static func title(for kind: ReminderKind, language: Language = .vi) -> String {
        if language == .en {
            switch kind {
            case .main: return "Time to take your pill"
            case .repeat: return "Reminder: pill not taken yet"
            case .hourly: return "Still haven't taken your pill"
            case .final: return "Deadline soon, take it now"
            case .deadline: return "Pill deadline reached"
            case .overdue: return "Past the deadline, take it now"
            }
        }
        return switch kind {
        case .main: "Tới giờ uống thuốc"
        case .repeat: "Nhắc lại: chưa uống thuốc"
        case .hourly: "Vẫn chưa uống thuốc"
        case .final: "Sắp tới hạn chót, uống ngay nhé"
        case .deadline: "Đã tới hạn chót uống thuốc"
        case .overdue: "Đã quá hạn chót, uống ngay"
        }
    }
}
