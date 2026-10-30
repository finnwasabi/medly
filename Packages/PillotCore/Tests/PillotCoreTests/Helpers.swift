import Foundation
@testable import PillotCore

/// Builds a moment in Vietnam time, for readable tests.
func vn(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    VietnamClock.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

func utc(_ text: String) -> Date { UTCTimestamp.date(from: text)! }

let hour: TimeInterval = 3600
let minute: TimeInterval = 60

/// Seeded random numbers (SplitMix64) so the tests are repeatable.
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

extension Planner {
    /// The snapshot of this schedule as a single unnamed medication.
    func snapshot(now: Date) -> MedicationSnapshot {
        Medication(name: "", settings: settings, history: history).snapshot(now: now)
    }
}
