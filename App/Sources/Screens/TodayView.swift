import NersCore
import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var pillsSheet = false

    var body: some View {
        NavigationStack {
            // Vẽ lại mỗi phút cho đếm ngược. Dùng giờ thật chứ không dùng `context.date` (mốc đầu phút),
            // không thì lần vừa bấm "Đã uống" nằm sau `now` và bị bỏ qua.
            TimelineView(.everyMinute) { _ in
                let now = Date.now
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header(now: now)
                        if let issue = model.issue { issueBanner(issue) }
                        if let message = model.message { messageCard(message) }
                        let missed = model.planner.outstandingMissed(now: now)
                        if !missed.isEmpty { missedCard(missed) }
                        doseCard(now: now)
                        if let pills = model.planner.settings.pills { pillsCard(pills) }
                        weekCard(now: now)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .background(Palette.background)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $pillsSheet) { PillsSheet() }
        }
    }

    private func header(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(TodayText.dayTitle(now))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.textSecondary)
            Text("Chào Ner")
                .font(.largeTitle.bold())
                .foregroundStyle(Palette.text)
        }
        .padding(.top, 12)
    }

    private func issueBanner(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.octagon.fill")
            .font(.callout.weight(.semibold))
            .foregroundStyle(DoseStatus.missed.foreground)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DoseStatus.missed.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func messageCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "heart.fill")
                .foregroundStyle(Palette.primary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("Lời nhắn từ Tùng")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.primary)
                Text(message)
                    .font(.body)
                    .foregroundStyle(Palette.text)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.primarySoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private func doseCard(now: Date) -> some View {
        let planner = model.planner
        let dose = planner.currentDose(now: now)
        let last = planner.lastTaken(now: now)
        VStack(alignment: .leading, spacing: 16) {
            if now >= dose.dueAt {
                StatusPill(status: .late)
                timeBlock(title: "Đã quá giờ uống", time: TodayText.duration(now.timeIntervalSince(dose.dueAt)), showsVN: false,
                          local: "giờ uống \(TimeFormatting.vietnamTime(dose.dueAt))")
                warning(now < dose.deadlineAt
                    ? "Còn \(TodayText.duration(dose.deadlineAt.timeIntervalSince(now))) tới hạn chót 24 giờ"
                    : "Đã quá hạn chót \(TodayText.duration(now.timeIntervalSince(dose.deadlineAt))). Xem tờ hướng dẫn thuốc hoặc hỏi bác sĩ, dược sĩ.")
                takeButton
            } else if let last, let takenAt = last.takenAt, TodayText.isRecent(takenAt, now: now, undoWindow: planner.settings.undoWindow) {
                StatusPill(status: .taken)
                timeBlock(title: "Đã uống lúc", time: TimeFormatting.clockTime(takenAt, in: VietnamClock.timeZone), showsVN: true,
                          local: TodayText.localLine(takenAt))
                Text("Lần sau: \(TodayText.relativeDay(dose.dueAt, from: now)) \(TimeFormatting.vietnamTime(dose.dueAt)), hạn chót \(TimeFormatting.clockTime(dose.deadlineAt, in: VietnamClock.timeZone)).")
                    .font(.callout)
                    .foregroundStyle(Palette.textSecondary)
                let undoLeft = planner.settings.undoWindow - now.timeIntervalSince(takenAt)
                if undoLeft > 0 {
                    Button("Hoàn tác (còn \(TodayText.duration(undoLeft)))") { Task { await model.undo() } }
                        .buttonStyle(SecondaryButtonStyle())
                }
            } else {
                StatusPill(status: .upcoming)
                let day = TodayText.relativeDay(dose.dueAt, from: now)
                timeBlock(title: "\(day.prefix(1).uppercased() + day.dropFirst()) lúc",
                          time: TimeFormatting.clockTime(dose.dueAt, in: VietnamClock.timeZone), showsVN: true,
                          local: TodayText.localLine(dose.dueAt))
                Text("Còn \(TodayText.duration(dose.dueAt.timeIntervalSince(now)))")
                    .font(.headline)
                    .foregroundStyle(Palette.textSecondary)
                takeButton
                Text("Uống sớm cũng được, lần sau sẽ nhắc sớm theo.")
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .card()
    }

    /// Các lần hụt trong 7 ngày gần nhất chưa uống bù. App không khuyên bù hay không, chỉ trỏ về tờ hướng dẫn.
    private func missedCard(_ records: [DoseRecord]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusPill(status: .missed)
            Text(records.count == 1 ? "Có 1 lần hụt chưa uống bù" : "Có \(records.count) lần hụt chưa uống bù")
                .font(.headline)
                .foregroundStyle(Palette.text)
            ForEach(records) { record in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(TodayText.dayTitle(record.scheduledAt))
                            .font(.body.weight(.medium))
                            .foregroundStyle(Palette.text)
                        Text("giờ uống \(TimeFormatting.vietnamTime(record.scheduledAt))")
                            .font(.footnote)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Spacer()
                    Button("Đã uống bù") { model.markMadeUp(missedAt: record.scheduledAt) }
                        .buttonStyle(.bordered)
                        .tint(DoseStatus.madeUp.foreground)
                }
            }
            Text("Có nên uống bù hay không, uống thế nào: xem tờ hướng dẫn thuốc hoặc hỏi bác sĩ, dược sĩ. Bấm nhầm thì xoá trong Lịch sử.")
                .font(.footnote)
                .foregroundStyle(Palette.textSecondary)
        }
        .card()
    }

    private var takeButton: some View {
        Button("Đã uống") { Task { await model.markTaken() } }
            .buttonStyle(PrimaryButtonStyle())
    }

    private func warning(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(text)
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(DoseStatus.missed.foreground)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DoseStatus.missed.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func timeBlock(title: String, time: String, showsVN: Bool, local: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.callout)
                .foregroundStyle(Palette.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(time)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(Palette.text)
                if showsVN {
                    Text("giờ VN")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            if let local {
                Text(local)
                    .font(.callout)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    private func pillsCard(_ pills: PillCounter) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Số viên", systemImage: "pills.fill")
                    .font(.headline)
                    .foregroundStyle(Palette.text)
                Spacer()
                Text("\(pills.remaining)/\(pills.total) viên")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Palette.text)
            }
            ProgressView(value: Double(pills.remaining), total: Double(max(1, pills.total)))
                .tint(Palette.primary)
            if let refill = pills.refillMessage(model.planner.settings.refillReminder) {
                HStack(spacing: 8) {
                    Image(systemName: "cart.fill")
                    Text(refill.prefix(1).uppercased() + refill.dropFirst())
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(DoseStatus.late.foreground)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DoseStatus.late.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Button("Thêm viên") { pillsSheet = true }
                .buttonStyle(SecondaryButtonStyle())
        }
        .card()
    }

    private func weekCard(now: Date) -> some View {
        let calendar = VietnamClock.calendar
        let today = calendar.startOfDay(for: now)
        let statuses = model.planner.dayStatuses(now: now)
        let shortNames = ["CN", "T2", "T3", "T4", "T5", "T6", "T7"]
        let days: [(name: String, status: DoseStatus)] = (0..<7).reversed().map { back in
            let day = calendar.date(byAdding: .day, value: -back, to: today)!
            let name = shortNames[calendar.component(.weekday, from: day) - 1]
            return (name, statuses[day].map(DoseStatus.init) ?? .upcoming)
        }
        return VStack(alignment: .leading, spacing: 12) {
            Text("7 ngày qua")
                .font(.headline)
                .foregroundStyle(Palette.text)
            HStack(spacing: 0) {
                ForEach(days, id: \.name) { day, status in
                    VStack(spacing: 6) {
                        Image(systemName: status.icon)
                            .font(.title2)
                            .foregroundStyle(status.foreground)
                            .accessibilityLabel(status.label)
                        Text(day)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .card()
    }
}

/// Chữ hiển thị trên màn Hôm nay. Ngày và giờ chính luôn theo giờ VN.
enum TodayText {
    private static let weekdays = ["Chủ Nhật", "Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy"]

    static func dayTitle(_ date: Date) -> String {
        let parts = VietnamClock.calendar.dateComponents([.weekday, .day, .month], from: date)
        return "\(weekdays[(parts.weekday ?? 1) - 1]), \(parts.day ?? 1) tháng \(parts.month ?? 1)"
    }

    /// "hôm nay", "mai", hoặc thứ trong tuần, theo ngày VN.
    static func relativeDay(_ date: Date, from now: Date) -> String {
        let calendar = VietnamClock.calendar
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return "hôm nay"
        case 1: return "mai"
        default: return dayTitle(date)
        }
    }

    /// "2 giờ 10 phút", "45 phút". Làm tròn lên phút để đếm ngược không hiện "0 phút".
    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((max(0, seconds) / 60).rounded(.up))
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) phút" }
        return m == 0 ? "\(h) giờ" : "\(h) giờ \(m) phút"
    }

    /// Giờ nơi máy đang ở, ẩn khi máy đang theo giờ VN.
    static func localLine(_ date: Date) -> String? {
        let zone = TimeZone.autoupdatingCurrent
        guard zone.secondsFromGMT(for: date) != VietnamClock.timeZone.secondsFromGMT(for: date) else { return nil }
        let place = zone.identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? zone.identifier
        return "tức \(TimeFormatting.clockTime(date, in: zone)) tại \(place)"
    }

    /// Còn hiện trạng thái "Đã uống": cùng ngày VN, hoặc còn trong thời gian hoàn tác.
    static func isRecent(_ takenAt: Date, now: Date, undoWindow: TimeInterval) -> Bool {
        VietnamClock.calendar.isDate(takenAt, inSameDayAs: now) || now.timeIntervalSince(takenAt) <= undoWindow
    }
}

#Preview { TodayView().environment(AppModel.shared) }
