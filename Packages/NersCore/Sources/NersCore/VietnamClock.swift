import Foundation

/// A calendar fixed to Vietnam time. Every date calculation in the package goes through here
/// and never uses the device time zone.
public enum VietnamClock {
    public static let timeZone: TimeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!

    public static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }()

    static let day: TimeInterval = 24 * 3600

    /// The main time (Vietnam time) on the Vietnam day containing `date`.
    static func mainTime(onDayOf date: Date, hour: Int, minute: Int) -> Date {
        let start = calendar.startOfDay(for: date)
        return start.addingTimeInterval(TimeInterval(hour * 3600 + minute * 60))
    }

    /// The first main time strictly after `date`.
    static func firstMainTime(after date: Date, hour: Int, minute: Int) -> Date {
        let candidate = mainTime(onDayOf: date, hour: hour, minute: minute)
        return candidate > date ? candidate : mainTime(onDayOf: candidate.addingTimeInterval(day), hour: hour, minute: minute)
    }

    /// The first main time at or after `date`.
    static func firstMainTime(atOrAfter date: Date, hour: Int, minute: Int) -> Date {
        let candidate = mainTime(onDayOf: date, hour: hour, minute: minute)
        return candidate >= date ? candidate : firstMainTime(after: date, hour: hour, minute: minute)
    }
}

/// Display language. Chosen in the app's Settings, not taken from the device.
public enum Language: String, Codable, CaseIterable, Sendable {
    case vi, en
}

/// Time formatting. Independent of the device locale and time zone.
public enum TimeFormatting {
    /// "HH:mm" in the given time zone.
    public static func clockTime(_ date: Date, in timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// For example "21:00 giờ VN", or "21:00 VN time" in English.
    public static func vietnamTime(_ date: Date, language: Language = .vi) -> String {
        clockTime(date, in: VietnamClock.timeZone) + (language == .en ? " VN time" : " giờ VN")
    }

    /// Vietnam time plus the device time, for example "21:00 giờ VN, 23:00 giờ máy".
    /// The app passes `TimeZone.current` in; the package never reads it.
    public static func dualTime(_ date: Date, deviceTimeZone: TimeZone, language: Language = .vi) -> String {
        vietnamTime(date, language: language) + ", " + clockTime(date, in: deviceTimeZone) + (language == .en ? " device time" : " giờ máy")
    }
}

/// UTC ISO 8601 timestamps without fractional seconds, for the sync JSON.
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
