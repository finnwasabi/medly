import Foundation
import Testing
@testable import MedlyCore

@Suite struct InvariantTests {
    /// Seeded random histories: after the last take there is always a ringing alarm
    /// in (now, last take + maximum gap], and two consecutive ringing alarms
    /// are never further apart than the maximum gap.
    @Test func soundAlarmNeverMissingBeforeDeadline() {
        var rng = SeededGenerator(seed: 20_261_027)
        let factors: [TimeInterval] = [0.75, 1, 26.0 / 24, 1.25, 1.5]
        var checked = 0

        for _ in 0..<600 {
            var settings = ReminderSettings(
                mainHour: Int.random(in: 0...23, using: &rng),
                mainMinute: Int.random(in: 0...59, using: &rng),
                dosesPerDay: ReminderSettings.allowedDosesPerDay.randomElement(using: &rng)!,
                repeatCount: Int.random(in: 0...4, using: &rng)
            )
            settings.maxInterval = (settings.period * factors.randomElement(using: &rng)!).rounded()
            var planner = Planner(settings: settings)
            var t = vn(2026, 1, 1, 0).addingTimeInterval(TimeInterval.random(in: 0...(365 * 24 * hour), using: &rng))
            for _ in 0..<Int.random(in: 1...10, using: &rng) {
                planner.markTaken(at: t)
                t = t.addingTimeInterval(TimeInterval.random(in: (1 * hour)...(60 * hour), using: &rng).rounded())
            }
            let last = planner.lastTaken(now: .distantFuture)!.takenAt!
            let deadline = last.addingTimeInterval(settings.maxInterval)

            // Case 1: still before the deadline.
            let now = last.addingTimeInterval(TimeInterval.random(in: 0..<settings.maxInterval, using: &rng).rounded(.down))
            #expect(planner.currentDose(now: now).deadlineAt == deadline)
            let events = planner.events(now: now)
            #expect(events.contains { $0.requiresSound && $0.date > now && $0.date <= deadline })
            checkSoundGaps(events, maxInterval: settings.maxInterval, firstBy: deadline)

            // Case 2: past the late window; the chain after misses keeps the invariant.
            let later = deadline.addingTimeInterval(min(settings.lateWindow, settings.period / 2) + TimeInterval.random(in: 1...(72 * hour), using: &rng).rounded())
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
            #expect(event.date >= event.dueAt)
            #expect(event.date <= event.deadlineAt || event.kind == .overdue)
            #expect(event.requiresSound == (event.kind == .deadline || event.kind == .overdue))
        }
    }
}
