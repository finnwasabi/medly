import AlarmKit
import Foundation
import Network
import NersCore
import Observation

/// Trạng thái app: đọc, ghi dữ liệu và nạp lại lịch nhắc sau mỗi thay đổi.
/// Dùng chung cho màn hình, App Intent của báo thức và nút trên noti.
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    private(set) var planner: Planner
    /// Lỗi đọc, ghi hoặc hẹn nhắc. Hiện lên màn Hôm nay, không nuốt lỗi.
    var issue: String? { scheduleIssue ?? dataIssue }
    private var dataIssue: String?
    private var scheduleIssue: String?
    /// Lời nhắn mới nhất Tùng gửi qua bot, nhận về khi đồng bộ.
    private(set) var message: String? = UserDefaults.standard.string(forKey: "message")

    /// Ngôn ngữ chữ trong app, noti và báo thức. Đổi là hẹn lại toàn bộ để chữ báo theo ngôn ngữ mới.
    var language: Language = AppLanguage.current {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.key)
            Task { await resync() }
        }
    }

    /// Chỉ rung: các lần nhắc là noti thường theo chế độ máy, riêng hạn chót vẫn là báo thức có tiếng.
    var vibrateOnly: Bool {
        didSet {
            UserDefaults.standard.set(vibrateOnly, forKey: "vibrateOnly")
            Task { await resync() }
        }
    }

    // MARK: Theo dõi cùng

    private(set) var connection: SyncConnection? = ConnectionKeychain.load().flatMap(SyncConnection.init(code:))
    var shareEnabled: Bool = UserDefaults.standard.object(forKey: "shareEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(shareEnabled, forKey: "shareEnabled")
            Task { await sync() }
        }
    }
    private(set) var lastSync: Date? = UserDefaults.standard.object(forKey: "lastSync") as? Date
    /// Lỗi đồng bộ gần nhất, chỉ hiện trong Cài đặt: mất mạng là chuyện thường, không làm phiền màn Hôm nay.
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
            // Cất file hỏng lại để cứu sau, chạy tiếp bằng mặc định để vẫn nhắc.
            let backup = directory.appending(path: "state-corrupt-\(Int(Date.now.timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: store.url, to: backup)
            planner = Planner()
            dataIssue = L("Không đọc được dữ liệu cũ, đã cất vào \(backup.lastPathComponent). App chạy lại từ cài đặt mặc định.", "Could not read old data, saved it as \(backup.lastPathComponent). The app restarted with default settings.")
        }
        // Có mạng trở lại (xuống máy bay) thì gửi bản mới nhất.
        network.pathUpdateHandler = { path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in await AppModel.shared.sync() }
        }
        network.start(queue: .global(qos: .utility))
    }

    /// Dán mã kết nối từ lệnh /link. Trả `false` nếu mã sai dạng.
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
            let reply = try await syncClient.send(planner.snapshot(now: .now), to: connection)
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
        // Bấm ở báo thức rồi bấm lại trong app chỉ tính một lần.
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

    /// Bấm "Đã uống bù" cho một lần hụt.
    func markMadeUp(missedAt scheduledAt: Date) {
        update { $0.markMadeUp(missedAt: scheduledAt, at: .now) }
    }

    /// Mọi thay đổi cài đặt, số viên, tạm dừng, sửa giờ uống đi qua đây: lưu rồi nạp lại lịch nhắc.
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

    // MARK: Nạp lại lịch nhắc

    private var syncing = false
    private var syncAgain = false
    private var cancelActivePending = false

    /// Huỷ và hẹn lại toàn bộ báo thức, noti. Gọi chồng nhau thì gộp, chạy lại một lần nữa sau lượt đang chạy.
    /// `cancelActive`: huỷ cả báo thức đang kêu hoặc đang hoãn (sau khi đã uống).
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
