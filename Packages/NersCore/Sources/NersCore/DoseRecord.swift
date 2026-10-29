import Foundation

public enum DoseStatus: String, Codable, Sendable {
    /// Đã xác nhận uống. Chỉ bản ghi loại này được lưu trong lịch sử.
    case taken
    /// Uống sau hạn chót nhưng còn trong cửa sổ trễ. Chỉ xuất hiện trong `Planner.timeline`.
    case late
    /// Qua hạn chót mà không xác nhận. Chỉ xuất hiện trong `Planner.timeline`.
    case missed
    /// Rơi vào khoảng tạm dừng, không tính hụt. Chỉ xuất hiện trong `Planner.timeline`.
    case paused
}

public struct DoseRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    /// Mốc nhắc của lần uống này.
    public var scheduledAt: Date
    /// Thời điểm uống thật, sửa được trong lịch sử.
    public var takenAt: Date?
    public var status: DoseStatus
    /// Đúng khi lần uống này đã trừ một viên, để hoàn tác trả lại đúng.
    public var consumedPill: Bool
    /// Người dùng chọn "về lại giờ gốc" cho lần kế sau lần uống này.
    public var nextAtMainTime: Bool

    public init(
        id: UUID = UUID(),
        scheduledAt: Date,
        takenAt: Date?,
        status: DoseStatus,
        consumedPill: Bool = false,
        nextAtMainTime: Bool = false
    ) {
        self.id = id
        self.scheduledAt = scheduledAt
        self.takenAt = takenAt
        self.status = status
        self.consumedPill = consumedPill
        self.nextAtMainTime = nextAtMainTime
    }
}
