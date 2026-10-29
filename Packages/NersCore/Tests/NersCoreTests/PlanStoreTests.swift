import Foundation
import Testing
@testable import NersCore

@Suite struct PlanStoreTests {
    /// A fresh temporary directory per test; the subdirectory does not exist yet, which also tests creating it.
    let store = PlanStore(url: FileManager.default.temporaryDirectory
        .appendingPathComponent("PlanStoreTests-\(UUID().uuidString)")
        .appendingPathComponent("state.json"))

    private func reload() throws -> Planner { try store.load() }

    @Test func missingFileGivesDefaults() throws {
        let planner = try reload()
        #expect(planner.settings == ReminderSettings())
        #expect(planner.history.isEmpty)
    }

    @Test func saveThenLoadKeepsEverything() throws {
        var planner = Planner(settings: ReminderSettings(mainHour: 20, mainMinute: 30))
        planner.addPills(28, now: vn(2026, 10, 1, 8))
        planner.markTaken(at: vn(2026, 10, 1, 20, 31))
        planner.markTaken(at: vn(2026, 10, 2, 20, 45))
        planner.pause(days: 3, now: vn(2026, 10, 3, 9))
        try store.save(planner)

        let loaded = try reload()
        #expect(loaded.settings == planner.settings)
        #expect(loaded.history == planner.history)
        #expect(loaded.settings.pills?.remaining == 26)
    }

    @Test func editedTimeSurvivesReload() throws {
        var planner = Planner()
        let record = planner.markTaken(at: vn(2026, 10, 1, 21))
        try store.save(planner)

        var loaded = try reload()
        loaded.editTakenTime(id: record.id, to: vn(2026, 10, 1, 21, 40))
        try store.save(loaded)

        #expect(try reload().history.first?.takenAt == vn(2026, 10, 1, 21, 40))
    }

    @Test func undoneRecordStaysDeleted() throws {
        var planner = Planner()
        planner.addPills(10, now: vn(2026, 10, 1, 8))
        planner.markTaken(at: vn(2026, 10, 1, 21))
        try store.save(planner)

        var loaded = try reload()
        let undone = loaded.undoLastTaken(now: vn(2026, 10, 1, 21, 5))
        #expect(undone)
        try store.save(loaded)

        let again = try reload()
        #expect(again.history.isEmpty)
        #expect(again.settings.pills?.remaining == 10)
    }

    @Test func corruptFileThrowsInsteadOfWiping() throws {
        try store.save(Planner())
        try Data("không phải JSON".utf8).write(to: store.url)
        #expect(throws: (any Error).self) { try reload() }
    }
}
