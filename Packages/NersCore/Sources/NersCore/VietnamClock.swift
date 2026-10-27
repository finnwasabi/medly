import Foundation

/// Lịch cố định theo giờ Việt Nam. Mọi phép tính ngày giờ trong package đi qua đây,
/// không bao giờ dùng múi giờ của máy.
public enum VietnamClock {
    public static let timeZone: TimeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!

    public static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }()

    static let day: TimeInterval = 24 * 3600

    /// Giờ chính (giờ VN) của ngày VN chứa `date`.
    static func mainTime(onDayOf date: Date, hour: Int, minute: Int) -> Date {
        let start = calendar.startOfDay(for: date)
        return start.addingTimeInterval(TimeInterval(hour * 3600 + minute * 60))
    }

    /// Giờ chính đầu tiên lớn hơn hẳn `date`.
    static func firstMainTime(after date: Date, hour: Int, minute: Int) -> Date {
        let candidate = mainTime(onDayOf: date, hour: hour, minute: minute)
        return candidate > date ? candidate : mainTime(onDayOf: candidate.addingTimeInterval(day), hour: hour, minute: minute)
    }

    /// Giờ chính đầu tiên lớn hơn hoặc bằng `date`.
    static func firstMainTime(atOrAfter date: Date, hour: Int, minute: Int) -> Date {
        let candidate = mainTime(onDayOf: date, hour: hour, minute: minute)
        return candidate >= date ? candidate : firstMainTime(after: date, hour: hour, minute: minute)
    }
}

/// Định dạng giờ hiển thị. Không phụ thuộc locale hay múi giờ của máy.
public enum TimeFormatting {
    /// "HH:mm" theo múi giờ truyền vào.
    public static func clockTime(_ date: Date, in timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// Ví dụ "21:00 giờ VN".
    public static func vietnamTime(_ date: Date) -> String {
        clockTime(date, in: VietnamClock.timeZone) + " giờ VN"
    }

    /// Giờ VN kèm giờ nơi máy đang ở, ví dụ "21:00 giờ VN, 23:00 giờ máy".
    /// App truyền `TimeZone.current` vào đây, package không tự đọc.
    public static func dualTime(_ date: Date, deviceTimeZone: TimeZone) -> String {
        vietnamTime(date) + ", " + clockTime(date, in: deviceTimeZone) + " giờ máy"
    }
}

/// Chuỗi thời điểm UTC ISO 8601 không phần lẻ giây, dùng cho JSON đồng bộ.
enum UTCTimestamp {
    static func floorToSecond(_ date: Date) -> Date {
        Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
    }

    static func string(from date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let p = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: floorToSecond(date))
        return String(
            format: "%04d-%02d-%02dT%02d:%02d:%02dZ",
            p.year ?? 0, p.month ?? 0, p.day ?? 0, p.hour ?? 0, p.minute ?? 0, p.second ?? 0
        )
    }

    static func date(from string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string).map(floorToSecond)
    }
}
