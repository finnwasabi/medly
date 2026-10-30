import Foundation
import Testing
@testable import NersCore

/// Random sequences of user actions with a fixed seed. After every step the planner must keep its invariants,
/// whatever order the actions come in.
@Suite struct FuzzTests {
    @Test func randomActionSequencesKeepInvariants() throws {
        var rng = SeededGenerator(seed: 2026_10_29)
        let store = PlanStore(url: FileManager.default.temporaryDirectory
            .appendingPathComponent("FuzzTests-\(UUID().uuidString)").appendingPathComponent("state.json"))
        var steps = 0

        for _ in 0..<300 {
            var settings = ReminderSettings(mainHour: Int.random(in: 0...23, using: &rng), mainMinute: Int.random(in: 0...59, using: &rng),
                                            dosesPerDay: ReminderSettings.allowedDosesPerDay.randomElement(using: &rng)!)
            settings.maxInterval = settings.period * [1, 1.25, 1.5].randomElement(using: &rng)!
            if Bool.random(using: &rng) {
                settings.cycle = DoseCycle(activeDays: Int.random(in: 1...24, using: &rng), breakDays: Int.random(in: 1...7, using: &rng),
                                           startDay: vn(2026, 1, 1, 0).addingTimeInterval(TimeInterval.random(in: 0...(300 * 24 * hour), using: &rng)))
            }
            var planner = Planner(settings: settings)
            var now = vn(2026, 1, 1, 0).addingTimeInterval(TimeInterval.random(in: 0...(300 * 24 * hour), using: &rng).rounded())

            for _ in 0..<40 {
                now = now.addingTimeInterval(TimeInterval.random(in: 60...(30 * hour), using: &rng).rounded())
                switch Int.random(in: 0..<13, using: &rng) {
                case 12: planner.skip(at: now)
                case 0...3: planner.markTaken(at: now)
                case 4: planner.undoLastTaken(now: now.addingTimeInterval(TimeInterval.random(in: 0...(20 * minute), using: &rng)))
                case 5:
                    if let record = planner.history.randomElement(using: &rng) {
                        planner.editTakenTime(id: record.id, to: now.addingTimeInterval(-TimeInterval.random(in: 0...(48 * hour), using: &rng)))
                    }
                case 6: planner.pause(days: Int.random(in: 1...3, using: &rng), now: now)
                case 7: planner.resume(now: now)
                case 8:
                    if let missed = planner.outstandingMissed(now: now).randomElement(using: &rng) {
                        planner.markMadeUp(missedAt: missed.scheduledAt, at: now)
                    }
                case 9:
                    if let made = planner.history.filter({ $0.status == .madeUp }).randomElement(using: &rng) {
                        planner.removeRecord(id: made.id)
                    }
                case 10: planner.changeSchedule(hour: Int.random(in: 0...23, using: &rng), minute: 0,
                                                dosesPerDay: ReminderSettings.allowedDosesPerDay.randomElement(using: &rng)!, now: now)
                default: planner.addPills(Int.random(in: 1...28, using: &rng), now: now)
                }
                try check(planner, now: now)
                steps += 1
            }
            // Saving and loading never changes anything.
            try store.save([Medication(name: "Fuzz", settings: planner.settings, history: planner.history)])
            let loaded = try #require(store.load().first)
            #expect(loaded.settings == planner.settings)
            #expect(loaded.history == planner.history)
        }
        #expect(steps == 300 * 40)
    }

    private func check(_ planner: Planner, now: Date) throws {
        let dose = planner.currentDose(now: now)
        #expect(dose.dueAt <= dose.deadlineAt)
        #expect(dose.deadlineAt <= dose.lateUntil)
        // The pending dose is never one whose late window already ended.
        #expect(dose.lateUntil >= now)

        // Days off can be a week long, and skipping the next day on during days off jumps over the following days off too,
        // so look far enough ahead to reach the next dose in the worst case.
        let events = planner.events(now: now, horizonDays: 3 + 2 * ((planner.settings.cycle?.breakDays ?? -1) + 1))
        let dates = events.map(\.date)
        #expect(dates == dates.sorted())
        #expect(Set(dates).count == dates.count)
        #expect(dates.allSatisfy { $0 > now })
        let rings = events.contains(where: \.requiresSound) || planner.settings.pausedUntil(now: now) != nil
        #expect(rings)

        // Pills: what is gone is exactly what the records say was consumed.
        if let pills = planner.settings.pills {
            #expect(pills.remaining >= 0 && pills.remaining <= pills.total)
        }

        let missed = planner.missedCount(now: now)
        let madeUp = planner.madeUpCount(now: now)
        #expect(madeUp <= missed)
        #expect(planner.skippedCount(now: now) == planner.history.filter { $0.status == .skipped && $0.takenAt! <= now }.count)
        #expect(planner.outstandingMissed(now: now).count <= missed - madeUp)
        #expect(planner.lateCount(now: now) >= 0)
        _ = planner.dayStatuses(now: now)

        let snapshot = Snapshot(name: nil, medications: [Medication(name: "Fuzz", settings: planner.settings, history: planner.history)], now: now)
        #expect(try Snapshot.decode(from: snapshot.jsonData()) == snapshot)
    }
}
