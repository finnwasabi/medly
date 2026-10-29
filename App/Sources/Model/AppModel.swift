import AlarmKit
import Foundation
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

    /// Chỉ rung: các lần nhắc là noti thường theo chế độ máy, riêng hạn chót vẫn là báo thức có tiếng.
    var vibrateOnly: Bool {
        didSet {
            UserDefaults.standard.set(vibrateOnly, forKey: "vibrateOnly")
            Task { await resync() }
        }
    }

    private let store: PlanStore
    private let scheduler = ReminderScheduler()

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
            dataIssue = "Không đọc được dữ liệu cũ, đã cất vào \(backup.lastPathComponent). App chạy lại từ cài đặt mặc định."
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

    private func persist() {
        do {
            try store.save(planner)
        } catch {
            dataIssue = "Không lưu được lần uống: \(error.localizedDescription)"
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
                refillMessage: settings.pills?.refillMessage(settings.refillReminder)
            )
            let failures = await scheduler.apply(alerts, cancelActive: cancel, snooze: settings.snoozeInterval)
            if !alarmsAvailable {
                scheduleIssue = "Chưa có quyền báo thức nên máy im lặng hay bật Focus sẽ không kêu. Bật trong Cài đặt > Ner's Daily."
            } else if failures > 0 {
                scheduleIssue = "Có \(failures) lần nhắc không hẹn được. Mở lại app để thử lại."
            } else {
                scheduleIssue = nil
            }
        } while syncAgain
        syncing = false
    }
}
