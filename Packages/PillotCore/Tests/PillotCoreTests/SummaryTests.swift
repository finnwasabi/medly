import Foundation
import Testing
@testable import PillotCore

@Suite struct SummaryTests {
    /// The one-walk summary must answer exactly like the separate queries, on random histories.
    @Test func summaryMatchesSeparateQueries() {
        var rng = SeededGenerator(seed: 2026_10_30)
        for _ in 0..<60 {
            var settings = ReminderSettings(mainHour: Int.random(in: 0...23, using: &rng), mainMinute: Int.random(in: 0...59, using: &rng),
                                            dosesPerDay: ReminderSettings.allowedDosesPerDay.randomElement(using: &rng)!)
            settings.maxInterval = settings.period * [1, 1.25, 1.5, 2].randomElement(using: &rng)!
            if Bool.random(using: &rng) { settings.pills = PillCounter(count: 30, at: vn(2026, 1, 1, 0)) }
            if Bool.random(using: &rng) { settings.cycle = DoseCycle(activeDays: 5, breakDays: 2, startDay: vn(2026, 1, 3, 0)) }
            var planner = Planner(settings: settings)
            var now = vn(2026, 1, 1, 0).addingTimeInterval(TimeInterval.random(in: 0...(30 * 24 * hour), using: &rng).rounded())
            for _ in 0..<30 {
                now = now.addingTimeInterval(TimeInterval.random(in: 60...(30 * hour), using: &rng).rounded())
                switch Int.random(in: 0..<8, using: &rng) {
                case 0...3: planner.markTaken(at: now)
                case 4: planner.skip(at: now)
                case 5: planner.pause(days: 1, now: now)
                case 6: if let missed = planner.outstandingMissed(now: now).first { planner.markMadeUp(missedAt: missed.scheduledAt, at: now) }
                default: planner.resetToMainTime(now: now)
                }
                let at = now.addingTimeInterval(TimeInterval.random(in: 0...(12 * hour), using: &rng).rounded())
                let s = planner.summary(now: at)
                #expect(s.dose == planner.currentDose(now: at))
                #expect(s.lastTaken == planner.lastTaken(now: at))
                #expect(s.timeline == planner.timeline(now: at))
                #expect(s.missedCount == planner.missedCount(now: at))
                #expect(s.lateCount == planner.lateCount(now: at))
                #expect(s.skippedCount == planner.skippedCount(now: at))
                #expect(s.madeUpCount == planner.madeUpCount(now: at))
                #expect(s.daysTaken == planner.daysTaken(now: at))
                #expect(s.undoableSkip == planner.undoableSkip(now: at))
                #expect(s.resetPreview == planner.resetPreview(now: at))
                #expect(s.restingUntil == planner.restingUntil(now: at))
                #expect(s.outstandingMissed() == planner.outstandingMissed(now: at))
                #expect(s.dayStatuses() == planner.dayStatuses(now: at))
                #expect(s.events() == planner.events(now: at))
            }
        }
    }

    /// Misses keep their id from one computation to the next, so lists do not rebuild their rows every minute.
    @Test func derivedRecordsKeepTheirID() {
        var planner = Planner()
        planner.markTaken(at: vn(2026, 3, 1, 21))
        let later = vn(2026, 3, 6, 12)
        let first = planner.timeline(now: later).filter { $0.status == .missed }
        #expect(first.count >= 3)
        #expect(first.map(\.id) == planner.timeline(now: later.addingTimeInterval(60)).filter { $0.status == .missed }.map(\.id))
        #expect(Set(first.map(\.id)).count == first.count)
    }

    @Test func arithmeticStartOfDayMatchesCalendar() {
        var rng = SeededGenerator(seed: 7)
        for _ in 0..<2000 {
            let date = vn(2026, 1, 1, 0).addingTimeInterval(TimeInterval.random(in: -(3650 * 24 * hour)...(3650 * 24 * hour), using: &rng))
            #expect(VietnamClock.startOfDay(date) == VietnamClock.calendar.startOfDay(for: date))
        }
    }

    @Test func showsAsTakenForTheRestOfTheDayWhenDaily() {
        let daily = ReminderSettings(mainHour: 8, dosesPerDay: 1)
        #expect(daily.showsAsTaken(vn(2026, 3, 1, 8), now: vn(2026, 3, 1, 23, 30)))
        #expect(!daily.showsAsTaken(vn(2026, 3, 1, 8), now: vn(2026, 3, 2, 0, 30)))
        let twice = ReminderSettings(mainHour: 8, dosesPerDay: 2)
        #expect(twice.showsAsTaken(vn(2026, 3, 1, 8), now: vn(2026, 3, 1, 13, 59)))
        #expect(!twice.showsAsTaken(vn(2026, 3, 1, 8), now: vn(2026, 3, 1, 14, 1)))
    }

    /// Guards against the quadratic walk coming back (0.3.4 copied the records on every step). 40,000 records is about
    /// 18 years of a 6-a-day dose: the linear walk takes well under the budget even in a debug build on CI, the quadratic one did not.
    @Test func walkStaysLinear() {
        var planner = Planner(settings: ReminderSettings(mainHour: 0, dosesPerDay: 6))
        var t = vn(2026, 1, 1, 0)
        for _ in 0..<40_000 {
            planner.history.append(DoseRecord(scheduledAt: t, takenAt: t, status: .taken))
            t = t.addingTimeInterval(4 * hour)
        }
        let clock = ContinuousClock()
        let elapsed = (0..<3).map { _ in clock.measure { _ = planner.currentDose(now: t) } }.min()!
        #expect(elapsed < .milliseconds(400), "40,000 records took \(elapsed)")
    }
}
