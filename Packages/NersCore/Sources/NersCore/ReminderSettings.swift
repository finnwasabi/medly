import Foundation

/// Cài đặt nhắc mua thêm thuốc. Tên trường khớp `refillReminder` trong snapshot.
public struct RefillReminder: Codable, Equatable, Sendable {
    public var enabled: Bool
    /// Nhắc khi số viên còn lại nhỏ hơn hoặc bằng số này.
    public var daysBefore: Int

    public init(enabled: Bool = true, daysBefore: Int = 7) {
        self.enabled = enabled
        self.daysBefore = daysBefore
    }
}

/// Một khoảng tạm dừng nhắc, [start, end).
public struct PausePeriod: Codable, Equatable, Sendable {
    public var start: Date
    public var end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    public func contains(_ date: Date) -> Bool { date >= start && date < end }
}

/// Cài đặt nhắc uống thuốc. Mọi khoảng thời gian tính bằng giây.
public struct ReminderSettings: Codable, Equatable, Sendable {
    /// Giờ chính theo giờ VN.
    public var mainHour: Int
    public var mainMinute: Int
    /// Khoảng tối đa giữa hai lần uống liên tiếp.
    public var maxInterval: TimeInterval
    /// Số lần nhắc lại ngay sau mốc chính và khoảng cách giữa chúng.
    public var repeatCount: Int
    public var repeatInterval: TimeInterval
    /// Nhịp nhắc sau khi hết các lần nhắc lại.
    public var hourlyInterval: TimeInterval
    /// Cửa sổ cuối trước hạn chót và nhịp nhắc trong cửa sổ đó.
    public var finalWindow: TimeInterval
    public var finalInterval: TimeInterval
    /// Hoãn: kêu lại sau khoảng này.
    public var snoozeInterval: TimeInterval
    /// Thời gian cho phép hoàn tác "Đã uống".
    public var undoWindow: TimeInterval
    /// Sau hạn chót bao lâu thì một lần chưa uống mới tính hụt. Uống trong khoảng này tính trễ.
    public var lateWindow: TimeInterval
    /// Uống sau hạn chót trong khoảng này vẫn tính đúng giờ, để chênh vài giây hay vài phút không thành trễ.
    /// Chỉ ảnh hưởng cách đếm, báo thức vẫn kêu đúng hạn chót.
    public var lateTolerance: TimeInterval
    /// Khoảng đầu sau hạn chót nhắc dồn dập theo `finalInterval`, sau đó theo `hourlyInterval`.
    public var overdueBurst: TimeInterval
    /// Bộ đếm viên, `nil` nghĩa là không đếm.
    public var pills: PillCounter?
    public var refillReminder: RefillReminder
    /// Các khoảng tạm dừng, giữ lại cả khoảng đã qua để không tính hụt trong đó.
    public var pauses: [PausePeriod]

    public init(
        mainHour: Int = 21,
        mainMinute: Int = 0,
        maxInterval: TimeInterval = 24 * 3600,
        repeatCount: Int = 3,
        repeatInterval: TimeInterval = 5 * 60,
        hourlyInterval: TimeInterval = 3600,
        finalWindow: TimeInterval = 2 * 3600,
        finalInterval: TimeInterval = 15 * 60,
        snoozeInterval: TimeInterval = 10 * 60,
        undoWindow: TimeInterval = 10 * 60,
        lateWindow: TimeInterval = 12 * 3600,
        lateTolerance: TimeInterval = 15 * 60,
        overdueBurst: TimeInterval = 3 * 3600,
        pills: PillCounter? = nil,
        refillReminder: RefillReminder = RefillReminder(),
        pauses: [PausePeriod] = []
    ) {
        self.mainHour = mainHour
        self.mainMinute = mainMinute
        self.maxInterval = maxInterval
        self.repeatCount = repeatCount
        self.repeatInterval = repeatInterval
        self.hourlyInterval = hourlyInterval
        self.finalWindow = finalWindow
        self.finalInterval = finalInterval
        self.snoozeInterval = snoozeInterval
        self.undoWindow = undoWindow
        self.lateWindow = lateWindow
        self.lateTolerance = lateTolerance
        self.overdueBurst = overdueBurst
        self.pills = pills
        self.refillReminder = refillReminder
        self.pauses = pauses
    }

    /// Thời điểm hết tạm dừng nếu `now` đang nằm trong một khoảng dừng.
    public func pausedUntil(now: Date) -> Date? {
        pauses.filter { $0.contains(now) }.map(\.end).max()
    }

    // Giải mã chịu được trường thiếu: trường nào không có thì lấy mặc định.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ReminderSettings()
        mainHour = try c.decodeIfPresent(Int.self, forKey: .mainHour) ?? d.mainHour
        mainMinute = try c.decodeIfPresent(Int.self, forKey: .mainMinute) ?? d.mainMinute
        maxInterval = try c.decodeIfPresent(TimeInterval.self, forKey: .maxInterval) ?? d.maxInterval
        repeatCount = try c.decodeIfPresent(Int.self, forKey: .repeatCount) ?? d.repeatCount
        repeatInterval = try c.decodeIfPresent(TimeInterval.self, forKey: .repeatInterval) ?? d.repeatInterval
        hourlyInterval = try c.decodeIfPresent(TimeInterval.self, forKey: .hourlyInterval) ?? d.hourlyInterval
        finalWindow = try c.decodeIfPresent(TimeInterval.self, forKey: .finalWindow) ?? d.finalWindow
        finalInterval = try c.decodeIfPresent(TimeInterval.self, forKey: .finalInterval) ?? d.finalInterval
        snoozeInterval = try c.decodeIfPresent(TimeInterval.self, forKey: .snoozeInterval) ?? d.snoozeInterval
        undoWindow = try c.decodeIfPresent(TimeInterval.self, forKey: .undoWindow) ?? d.undoWindow
        lateWindow = try c.decodeIfPresent(TimeInterval.self, forKey: .lateWindow) ?? d.lateWindow
        lateTolerance = try c.decodeIfPresent(TimeInterval.self, forKey: .lateTolerance) ?? d.lateTolerance
        overdueBurst = try c.decodeIfPresent(TimeInterval.self, forKey: .overdueBurst) ?? d.overdueBurst
        pills = try c.decodeIfPresent(PillCounter.self, forKey: .pills)
        refillReminder = try c.decodeIfPresent(RefillReminder.self, forKey: .refillReminder) ?? d.refillReminder
        pauses = try c.decodeIfPresent([PausePeriod].self, forKey: .pauses) ?? d.pauses
    }
}
