import AppIntents
import PillotCore

/// "I took my meds" for Siri, Shortcuts and Spotlight: marks every medication that is due now.
/// Runs in the app's process, which also reschedules the alarms.
struct TakeDueMedicationsIntent: AppIntent {
    static let title: LocalizedStringResource = "Log the doses due now"
    static let description = IntentDescription("Marks every medication that is due now as taken.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let now = Date.now
        let due = AppModel.shared.medications.filter { $0.planner.restingUntil(now: now) == nil && now >= $0.planner.currentDose(now: now).dueAt }
        guard !due.isEmpty else {
            return .result(dialog: IntentDialog(stringLiteral: L("Chưa tới giờ uống thuốc nào.", "Nothing is due right now.")))
        }
        await AppModel.shared.markTaken(due.map(\.id), now: now)
        let names = due.map(\.name).joined(separator: ", ")
        return .result(dialog: IntentDialog(stringLiteral: L("Đã ghi: \(names).", "Logged \(names).")))
    }
}

struct PillotShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TakeDueMedicationsIntent(),
            phrases: ["I took my meds in \(.applicationName)", "Log my meds in \(.applicationName)", "I took my pill in \(.applicationName)"],
            shortTitle: "Took my meds",
            systemImageName: "checkmark.circle.fill"
        )
    }
}
