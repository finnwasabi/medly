import Foundation
import Testing
@testable import NersCore

@Suite struct InvariantTests {
    /// Lịch sử ngẫu nhiên có seed cố định: sau lần uống cuối, luôn có báo thức có tiếng
    /// trong khoảng (now, lần uống cuối + khoảng tối đa], và hai báo thức có tiếng liên tiếp
    /// không bao giờ cách nhau quá khoảng tối đa.
    @Test func soundAlarmNeverMissingBeforeDeadline() {
        var rng = SeededGenerator(seed: 20_261_027)
        let maxIntervals: [TimeInterval] = [18 * hour, 24 * hour, 26 * hour, 30 * hour, 36 * hour]
        var checked = 0

        for _ in 0..<600 {
            let settings = ReminderSettings(
                mainHour: Int.random(in: 0...23, using: &rng),
                mainMinute: Int.random(in: 0...59, using: &rng),
                maxInterval: maxIntervals.randomElement(using: &rng)!,
                repeatCount: Int.random(in: 0...4, using: &rng)
            )
            var planner = Planner(settings: settings)
            var t = vn(2026, 1, 1, 0).addingTimeInterval(TimeInterval.random(in: 0...(365 * 24 * hour), using: &rng))
            for _ in 0..<Int.random(in: 1...10, using: &rng) {
                planner.markTaken(at: t)
                t = t.addingTimeInterval(TimeInterval.random(in: (1 * hour)...(60 * hour), using: &rng).rounded())
            }
            let last = planner.lastTaken(now: .distantFuture)!.takenAt!
            let deadline = last.addingTimeInterval(settings.maxInterval)

            // Trường hợp 1: còn trong hạn.
            let now = last.addingTimeInterval(TimeInterval.random(in: 0..<settings.maxInterval, using: &rng).rounded(.down))
            #expect(planner.currentDose(now: now).deadlineAt == deadline)
            let events = planner.events(now: now)
            #expect(events.contains { $0.requiresSound && $0.date > now && $0.date <= deadline })
            checkSoundGaps(events, maxInterval: settings.maxInterval, firstBy: deadline)

            // Trường hợp 2: đã quá hạn, chuỗi sau các lần hụt vẫn giữ bất biến.
            let later = deadline.addingTimeInterval(TimeInterval.random(in: 1...(72 * hour), using: &rng).rounded())
            #expect(planner.missedCount(now: later) >= 1)
            checkSoundGaps(planner.events(now: later), maxInterval: settings.maxInterval, firstBy: later.addingTimeInterval(settings.maxInterval))
            checked += 1
        }
        #expect(checked == 600)
    }

    private func checkSoundGaps(_ events: [ReminderEvent], maxInterval: TimeInterval, firstBy limit: Date) {
        let dates = events.map(\.date)
        #expect(dates == dates.sorted())
        #expect(Set(dates).count == dates.count)
        let sound = events.filter(\.requiresSound).map(\.date)
        #expect(sound.first.map { $0 <= limit } == true)
        for (a, b) in zip(sound, sound.dropFirst()) {
            #expect(b.timeIntervalSince(a) <= maxInterval)
        }
        for event in events {
            #expect(event.date >= event.dueAt && event.date <= event.deadlineAt)
            #expect(event.requiresSound == (event.kind == .deadline))
        }
    }
}
