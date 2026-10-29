import Foundation

/// Refill reminder settings. Field names match `refillReminder` in the snapshot.
public struct RefillReminder: Codable, Equatable, Sendable {
    public var enabled: Bool
    /// Remind when the remaining pills are at or below this.
    public var daysBefore: Int

    public init(enabled: Bool = true, daysBefore: Int = 7) {
        self.enabled = enabled
        self.daysBefore = daysBefore
    }
}

/// A pause in reminders, [start, end).
public struct PausePeriod: Codable, Equatable, Sendable {
    public var start: Date
    public var end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    public func contains(_ date: Date) -> Bool { date >= start && date < end }
}

/// Reminder settings. All intervals are in seconds.
public struct ReminderSettings: Codable, Equatable, Sendable {
    /// Main time in Vietnam time. With several doses a day, the first one; the others follow every `period`.
    public var mainHour: Int
    public var mainMinute: Int
    /// Doses per day, evenly spaced. One of `allowedDosesPerDay`.
    public var dosesPerDay: Int
    /// Maximum gap between two consecutive doses.
    public var maxInterval: TimeInterval
    /// How many repeats follow the main reminder, and their spacing.
    public var repeatCount: Int
    public var repeatInterval: TimeInterval
    /// Cadence after the repeats.
    public var hourlyInterval: TimeInterval
    /// The final window before the deadline and its cadence.
    public var finalWindow: TimeInterval
    public var finalInterval: TimeInterval
    /// Snooze: ring again after this.
    public var snoozeInterval: TimeInterval
    /// How long "Taken" can be undone.
    public var undoWindow: TimeInterval
    /// How long after the deadline an untaken dose becomes missed. Taking it within this counts as late.
    public var lateWindow: TimeInterval
    /// A dose this soon after the deadline still counts as on time, so seconds or minutes do not make it late.
    /// Only affects counting; the alarm still rings at the deadline.
    public var lateTolerance: TimeInterval
    /// The first stretch after the deadline repeats at `finalInterval`, then at `hourlyInterval`.
    public var overdueBurst: TimeInterval
    /// Pill counter; `nil` means not counting.
    public var pills: PillCounter?
    public var refillReminder: RefillReminder
    /// Pauses, including past ones, so nothing inside them counts as missed.
    public var pauses: [PausePeriod]

    public init(
        mainHour: Int = 21,
        mainMinute: Int = 0,
        dosesPerDay: Int = 1,
        maxInterval: TimeInterval = 24 * 3600,
        repeatCount: Int = 3,
        repeatInterval: TimeInterval = 5 * 60,
        hourlyInterval: TimeInterval = 3600,
        finalWindow: TimeInterval = 2 * 3600,
        finalInterval: TimeInterval = 15 * 60,
        snoozeInterval: TimeInterval = 9 * 60,
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
        self.dosesPerDay = Self.allowedDosesPerDay.contains(dosesPerDay) ? dosesPerDay : 1
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

    /// Divisors of 24, so the doses fall on the same clock times every day.
    public static let allowedDosesPerDay = [1, 2, 3, 4, 6]

    /// Time between two scheduled doses: 24 h divided by `dosesPerDay`.
    public var period: TimeInterval { 24 * 3600 / TimeInterval(dosesPerDay) }

    /// The range the maximum gap may be set to: from one period up to one and a half.
    public var maxIntervalRange: ClosedRange<TimeInterval> { period...(period * 1.5) }

    /// When the pause ends, if `now` is inside one.
    public func pausedUntil(now: Date) -> Date? {
        pauses.filter { $0.contains(now) }.map(\.end).max()
    }

    // Tolerant decoding: missing fields fall back to defaults.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ReminderSettings()
        mainHour = try c.decodeIfPresent(Int.self, forKey: .mainHour) ?? d.mainHour
        mainMinute = try c.decodeIfPresent(Int.self, forKey: .mainMinute) ?? d.mainMinute
        let doses = try c.decodeIfPresent(Int.self, forKey: .dosesPerDay) ?? d.dosesPerDay
        dosesPerDay = Self.allowedDosesPerDay.contains(doses) ? doses : d.dosesPerDay
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
