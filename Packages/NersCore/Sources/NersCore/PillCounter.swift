import Foundation

/// Bộ đếm số viên. Chỉ tồn tại khi người dùng có nhập số viên.
public struct PillCounter: Codable, Equatable, Sendable {
    /// Tổng số viên đã nhập và thêm.
    public private(set) var total: Int
    public private(set) var remaining: Int
    /// Lần nhập hoặc thêm viên gần nhất, mốc để tính `daysTaken`.
    public private(set) var countingSince: Date

    /// Nhập số viên ban đầu.
    public init(count: Int, at date: Date) {
        total = max(0, count)
        remaining = max(0, count)
        countingSince = date
    }

    /// Trừ một viên khi uống. Trả `false` nếu đã hết viên để trừ.
    @discardableResult
    public mutating func consume() -> Bool {
        guard remaining > 0 else { return false }
        remaining -= 1
        return true
    }

    /// Trả lại một viên khi hoàn tác "Đã uống".
    public mutating func restore() {
        remaining = min(total, remaining + 1)
    }

    /// "Thêm viên": cộng vào số còn lại và tổng.
    public mutating func add(_ count: Int, at date: Date) {
        guard count > 0 else { return }
        total += count
        remaining += count
        countingSince = date
    }

    public func needsRefill(_ reminder: RefillReminder) -> Bool {
        reminder.enabled && remaining <= reminder.daysBefore
    }

    /// Dòng kèm theo mỗi lần báo uống khi tới ngưỡng mua thêm.
    public func refillMessage(_ reminder: RefillReminder, language: Language = .vi) -> String? {
        guard needsRefill(reminder) else { return nil }
        return language == .en ? "\(remaining) \(remaining == 1 ? "pill" : "pills") left, time to buy more" : "còn \(remaining) viên, nhớ mua thêm"
    }
}
