import Foundation

/// Pill counter. Only exists when the user entered a pill count.
public struct PillCounter: Codable, Equatable, Sendable {
    /// Total pills entered and added.
    public private(set) var total: Int
    public private(set) var remaining: Int
    /// The latest time pills were entered or added, the start for `daysTaken`.
    public private(set) var countingSince: Date

    /// Enter the initial pill count.
    public init(count: Int, at date: Date) {
        total = max(0, count)
        remaining = max(0, count)
        countingSince = date
    }

    /// Subtracts a pill for a dose. Returns `false` when none are left.
    @discardableResult
    public mutating func consume() -> Bool {
        guard remaining > 0 else { return false }
        remaining -= 1
        return true
    }

    /// Gives a pill back when "Taken" is undone.
    public mutating func restore() {
        remaining = min(total, remaining + 1)
    }

    /// "Add pills": adds to both the remaining count and the total.
    public mutating func add(_ count: Int, at date: Date) {
        guard count > 0 else { return }
        total += count
        remaining += count
        countingSince = date
    }

    public func needsRefill(_ reminder: RefillReminder) -> Bool {
        reminder.enabled && remaining <= reminder.daysBefore
    }

    /// Line added to every alert once the refill threshold is reached.
    public func refillMessage(_ reminder: RefillReminder, language: Language = .vi) -> String? {
        guard needsRefill(reminder) else { return nil }
        return language == .en ? "\(remaining) \(remaining == 1 ? "pill" : "pills") left, time to buy more" : "còn \(remaining) viên, nhớ mua thêm"
    }
}
