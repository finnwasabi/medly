import Foundation

public enum DoseStatus: String, Codable, Sendable {
    /// Confirmed as taken. The only kind stored in history besides make-ups.
    case taken
    /// Taken after the deadline but within the late window. Only appears in `Planner.timeline`.
    case late
    /// Not confirmed by the end of the late window. Only appears in `Planner.timeline`.
    case missed
    /// Fell inside a pause, never counted as missed. Only appears in `Planner.timeline`.
    case paused
    /// A make-up for a missed dose. Stored in history but ignored by the schedule.
    case madeUp
}

extension DoseStatus {
    /// How bad a status is when several share a day: missed, made up, late, taken, paused.
    public var severity: Int {
        switch self {
        case .missed: 4
        case .madeUp: 3
        case .late: 2
        case .taken: 1
        case .paused: 0
        }
    }
}

/// Merges several medications' day statuses, keeping the worst status of each day.
public func mergedDayStatuses(_ days: [[Date: DoseStatus]]) -> [Date: DoseStatus] {
    days.reduce(into: [:]) { result, statuses in
        result.merge(statuses) { $0.severity >= $1.severity ? $0 : $1 }
    }
}

public struct DoseRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    /// The reminder time of this dose.
    public var scheduledAt: Date
    /// When it was actually taken, editable in History.
    public var takenAt: Date?
    public var status: DoseStatus
    /// True when this dose consumed a pill, so undo gives the right one back.
    public var consumedPill: Bool
    /// The user chose "back to the main time" for the dose after this one.
    public var nextAtMainTime: Bool
    /// For a make-up: the `scheduledAt` of the missed dose it covers.
    public var makesUpFor: Date?

    public init(
        id: UUID = UUID(),
        scheduledAt: Date,
        takenAt: Date?,
        status: DoseStatus,
        consumedPill: Bool = false,
        nextAtMainTime: Bool = false,
        makesUpFor: Date? = nil
    ) {
        self.id = id
        self.scheduledAt = scheduledAt
        self.takenAt = takenAt
        self.status = status
        self.consumedPill = consumedPill
        self.nextAtMainTime = nextAtMainTime
        self.makesUpFor = makesUpFor
    }
}
