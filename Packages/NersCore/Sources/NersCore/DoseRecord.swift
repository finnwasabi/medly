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
