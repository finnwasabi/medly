import AlarmKit
import Foundation
import Network
import NersCore
import Observation

/// App state: loads and saves data and reschedules reminders after every change.
/// Shared by the screens, the alarm App Intent and the notification action.
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    private(set) var planner: Planner
    /// Load, save or scheduling errors. Shown on the Today screen, never swallowed.
    var issue: String? { scheduleIssue ?? dataIssue }
    private var dataIssue: String?
    private var scheduleIssue: String?
    /// The latest message the partner sent through the bot, received on sync.
    private(set) var message: String? = UserDefaults.standard.string(forKey: "message")

    /// Language of the app, notifications and alarms. Changing it reschedules everything so alert texts follow.
    var language: Language = AppLanguage.current {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.key)
            Task { await resync() }
        }
    }

    // MARK: Names

    /// The main user's name, entered on first launch or in Settings. Sent with the snapshot so the bot uses it.
    // No sync here because this changes on every keystroke; the name goes out with the next sync.
    var userName: String = UserDefaults.standard.string(forKey: "userName") ?? "" {
        didSet { UserDefaults.standard.set(userName, forKey: "userName") }
    }

    /// The partner's name, optional.
    var partnerName: String = UserDefaults.standard.string(forKey: "partnerName") ?? "" {
        didSet { UserDefaults.standard.set(partnerName, forKey: "partnerName") }
    }

    /// Greeting with the user's name, or a neutral one without it.
    var greeting: String {
        let name = userName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? L("Chào bạn", "Hi there") : L("Chào \(name)", "Hi \(name)")
    }

    /// How texts refer to the partner: the entered name, or "your partner" without one.
    var partner: String {
        let name = partnerName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? L("người ấy", "your partner") : name
    }

    /// Follow phone: reminders are plain notifications that respect the phone's mode, but the deadline is still a ringing alarm.
    var vibrateOnly: Bool {
        didSet {
            UserDefaults.standard.set(vibrateOnly, forKey: "vibrateOnly")
            Task { await resync() }
        }
    }

    // MARK: Shared tracking

    private(set) var connection: SyncConnection? = ConnectionKeychain.load().flatMap(SyncConnection.init(code:))
    var shareEnabled: Bool = UserDefaults.standard.object(forKey: "shareEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(shareEnabled, forKey: "shareEnabled")
            Task { await sync() }
        }
    }
    private(set) var lastSync: Date? = UserDefaults.standard.object(forKey: "lastSync") as? Date
    /// The latest sync error, shown only in Settings: being offline is normal and should not clutter Today.
    private(set) var syncIssue: String?

    private let store: PlanStore
    private let scheduler = ReminderScheduler()
    private let syncClient = SyncClient()
    private let network = NWPathMonitor()

    init() {
        let directory = URL.applicationSupportDirectory
        store = PlanStore(url: directory.appending(path: "state.json"))
        vibrateOnly = UserDefaults.standard.bool(forKey: "vibrateOnly")
        do {
            planner = try store.load()
        } catch {
            // Keep the corrupt file for recovery and continue with defaults so reminders still run.
            let backup = directory.appending(path: "state-corrupt-\(Int(Date.now.timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: store.url, to: backup)
            planner = Planner()
            dataIssue = L("Không đọc được dữ liệu cũ, đã cất vào \(backup.lastPathComponent). App chạy lại từ cài đặt mặc định.", "Could not read old data, saved it as \(backup.lastPathComponent). The app restarted with default settings.")
        }
        // When the network comes back (after landing), send the latest snapshot.
        network.pathUpdateHandler = { path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in await AppModel.shared.sync() }
        }
        network.start(queue: .global(qos: .utility))
    }

    /// Paste the connection code from the /link command. Returns `false` if the code is malformed.
    func connect(code: String) async -> Bool {
        guard let parsed = SyncConnection(code: code) else { return false }
        ConnectionKeychain.save(code.trimmingCharacters(in: .whitespacesAndNewlines))
        connection = parsed
        await sync()
        return true
    }

    func disconnect() {
        ConnectionKeychain.save(nil)
        connection = nil
        syncIssue = nil
    }

    func sync() async {
        guard shareEnabled, let connection else { return }
        do {
            var snapshot = planner.snapshot(now: .now)
            let name = userName.trimmingCharacters(in: .whitespaces)
            snapshot.name = name.isEmpty ? nil : String(name.prefix(60))
            let reply = try await syncClient.send(snapshot, to: connection)
            message = reply.message
            UserDefaults.standard.set(reply.message, forKey: "message")
            lastSync = .now
            UserDefaults.standard.set(lastSync, forKey: "lastSync")
            syncIssue = nil
        } catch {
            syncIssue = L("Chưa đồng bộ được: \(error.localizedDescription) App sẽ gửi lại khi có mạng.", "Not synced yet: \(error.localizedDescription) The app retries when online.")
        }
    }

    func markTaken(now: Date = .now) async {
        // Tapping on the alarm and again in the app counts once.
        if let last = planner.lastTaken(now: now)?.takenAt, now.timeIntervalSince(last) < planner.settings.undoWindow {
            await resync(cancelActive: true)
            return
        }
        planner.markTaken(at: now)
        persist()
        await resync(cancelActive: true)
    }

    func undo(now: Date = .now) async {
        guard planner.undoLastTaken(now: now) else { return }
        persist()
        await resync()
    }

    /// "Mark made up" for a missed dose.
    func markMadeUp(missedAt scheduledAt: Date) {
        update { $0.markMadeUp(missedAt: scheduledAt, at: .now) }
    }

    /// Every change to settings, pills, pauses or taken times goes through here: save, then reschedule.
    func update(_ change: (inout Planner) -> Void) {
        change(&planner)
        persist()
        Task { await resync() }
    }

    private func persist() {
        do {
            try store.save(planner)
        } catch {
            dataIssue = L("Không lưu được lần uống: \(error.localizedDescription)", "Could not save the dose: \(error.localizedDescription)")
        }
    }

    // MARK: Rescheduling

    private var syncing = false
    private var syncAgain = false
    private var cancelActivePending = false

    /// Cancels and reschedules all alarms and notifications. Overlapping calls coalesce into one more pass after the running one.
    /// `cancelActive`: also cancel alarms that are ringing or snoozed (after a dose is taken).
    func resync(cancelActive: Bool = false) async {
        cancelActivePending = cancelActivePending || cancelActive
        guard !syncing else {
            syncAgain = true
            return
        }
        syncing = true
        repeat {
            syncAgain = false
            let cancel = cancelActivePending
            cancelActivePending = false
            let now = Date.now
            let settings = planner.settings
            let alarmsAvailable = AlarmManager.shared.authorizationState == .authorized
            let alerts = AlertPlanner.alerts(
                for: planner.events(now: now),
                vibrateOnly: vibrateOnly,
                alarmsAvailable: alarmsAvailable,
                refillMessage: settings.pills?.refillMessage(settings.refillReminder, language: language),
                missedMessage: AlertPlanner.missedMessage(count: planner.outstandingMissed(now: now).count, language: language),
                language: language
            )
            let failures = await scheduler.apply(alerts, cancelActive: cancel, snooze: settings.snoozeInterval)
            if !alarmsAvailable {
                scheduleIssue = L("Chưa có quyền báo thức nên máy im lặng hay bật Focus sẽ không kêu. Bật trong Cài đặt > Ner's Daily.", "Alarms are not allowed, so nothing rings on silent or in Focus. Turn them on in Settings > Ner's Daily.")
            } else if failures > 0 {
                scheduleIssue = L("Có \(failures) lần nhắc không hẹn được. Mở lại app để thử lại.", "\(failures) reminders could not be scheduled. Reopen the app to retry.")
            } else {
                scheduleIssue = nil
            }
        } while syncAgain
        syncing = false
        await sync()
    }
}
