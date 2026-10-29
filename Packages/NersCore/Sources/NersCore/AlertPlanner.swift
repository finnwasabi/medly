import Foundation

/// Một lần báo đã quyết xong: dùng báo thức AlarmKit hay noti thường, kèm chữ hiển thị.
public struct PlannedAlert: Equatable, Sendable {
    public var date: Date
    /// Đúng: báo thức AlarmKit, kêu cả khi im lặng và Focus. Sai: noti thường, theo chế độ máy.
    public var usesAlarm: Bool
    public var title: String
    /// Dòng phụ, chỉ noti thường hiện được.
    public var body: String
}

public enum AlertPlanner {
    /// iOS chỉ giữ 64 noti đang chờ mỗi app.
    public static let notificationLimit = 64

    /// Đổi chuỗi mốc nhắc thành các lần báo.
    /// `vibrateOnly`: mọi lần nhắc là noti thường, riêng từ hạn chót trở đi luôn là báo thức có tiếng.
    /// `alarmsAvailable` sai (chưa có quyền AlarmKit): tất cả thành noti thường để ít nhất vẫn có nhắc.
    /// Noti chỉ lấy `notificationLimit` lần sớm nhất; app nạp lại mỗi lần mở hoặc bấm "Đã uống".
    public static func alerts(
        for events: [ReminderEvent], vibrateOnly: Bool, alarmsAvailable: Bool = true, refillMessage: String?
    ) -> [PlannedAlert] {
        var notifications = 0
        var result: [PlannedAlert] = []
        for event in events.sorted(by: { $0.date < $1.date }) {
            let usesAlarm = alarmsAvailable && (!vibrateOnly || event.requiresSound)
            if !usesAlarm {
                guard notifications < notificationLimit else { continue }
                notifications += 1
            }
            var title = title(for: event.kind)
            if let refillMessage { title += ". " + refillMessage.prefix(1).uppercased() + refillMessage.dropFirst() }
            let body = "Hạn chót \(TimeFormatting.vietnamTime(event.deadlineAt))."
            result.append(PlannedAlert(date: event.date, usesAlarm: usesAlarm, title: title, body: body))
        }
        return result
    }

    static func title(for kind: ReminderKind) -> String {
        switch kind {
        case .main: "Tới giờ uống thuốc"
        case .repeat: "Nhắc lại: chưa uống thuốc"
        case .hourly: "Vẫn chưa uống thuốc"
        case .final: "Sắp tới hạn chót, uống ngay nhé"
        case .deadline: "Đã tới hạn chót uống thuốc"
        case .overdue: "Đã quá hạn chót, uống ngay"
        }
    }
}
