import Foundation
@testable import NersCore

/// Dựng thời điểm theo giờ VN cho dễ đọc trong test.
func vn(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    VietnamClock.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

func utc(_ text: String) -> Date { UTCTimestamp.date(from: text)! }

let hour: TimeInterval = 3600
let minute: TimeInterval = 60

/// Sinh số ngẫu nhiên có seed cố định (SplitMix64) để test lặp lại được.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

func takenRecord(_ date: Date) -> DoseRecord {
    DoseRecord(scheduledAt: date, takenAt: date, status: .taken)
}
