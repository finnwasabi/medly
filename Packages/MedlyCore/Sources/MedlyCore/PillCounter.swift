import Foundation

/// Pill counter. Only exists when the user entered a pill count.
public struct PillCounter: Codable, Equatable, Sendable {
    /// Total pills entered and added.
    public private(set) var total: Int
    public private(set) var remaining: Int
    /// The latest time pills were entered or added, the start for `daysTaken`.
    public private(set) var countingSince: Date
    /// Pills in one pack, the default for "add a pack". `nil` in data from before 0.3.0.
    public var packSize: Int?

    /// The usual pack, when no size was entered yet.
    public static let defaultPackSize = 28

    /// Enter the initial pill count. It is also taken as the pack size unless one is given.
    public init(count: Int, at date: Date, packSize: Int? = nil) {
        total = max(0, count)
        remaining = max(0, count)
        countingSince = date
        self.packSize = packSize ?? (count > 0 ? count : nil)
    }

    /// The pack size to suggest.
    public var pack: Int { packSize ?? Self.defaultPackSize }

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

    /// Sets the remaining count from the editor. More pills count as added (total and `countingSince` move);
    /// fewer is a correction and leaves both alone.
    public mutating func setRemaining(_ count: Int, at date: Date) {
        let target = max(0, count)
        if target > remaining {
            add(target - remaining, at: date)
        } else {
            remaining = target
        }
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
