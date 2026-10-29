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
            Text(model.greeting)
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
                Text(L("Lời nhắn từ \(model.partner)", "Message from \(model.partner)"))
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
                timeBlock(title: L("Đã quá giờ uống", "Past pill time by"), time: TodayText.duration(now.timeIntervalSince(dose.dueAt)), showsVN: false,
                          local: L("giờ uống \(TimeFormatting.vn(dose.dueAt))", "pill time \(TimeFormatting.vn(dose.dueAt))"))
                warning(now < dose.deadlineAt
                    ? L("Còn \(TodayText.duration(dose.deadlineAt.timeIntervalSince(now))) tới hạn chót 24 giờ", "\(TodayText.duration(dose.deadlineAt.timeIntervalSince(now))) left until the 24-hour deadline")
                    : L("Đã quá hạn chót \(TodayText.duration(now.timeIntervalSince(dose.deadlineAt))). Xem tờ hướng dẫn thuốc hoặc hỏi bác sĩ, dược sĩ.", "Past the deadline by \(TodayText.duration(now.timeIntervalSince(dose.deadlineAt))). Check the leaflet or ask a doctor or pharmacist."))
                takeButton
            } else if let last, let takenAt = last.takenAt, TodayText.isRecent(takenAt, now: now, undoWindow: planner.settings.undoWindow) {
                StatusPill(status: .taken)
                timeBlock(title: L("Đã uống lúc", "Taken at"), time: TimeFormatting.clockTime(takenAt, in: VietnamClock.timeZone), showsVN: true,
                          local: TodayText.localLine(takenAt))
                Text(L("Lần sau: \(TodayText.relativeDay(dose.dueAt, from: now)) \(TimeFormatting.vn(dose.dueAt)), hạn chót \(TimeFormatting.clockTime(dose.deadlineAt, in: VietnamClock.timeZone)).", "Next: \(TodayText.relativeDay(dose.dueAt, from: now)) \(TimeFormatting.vn(dose.dueAt)), deadline \(TimeFormatting.clockTime(dose.deadlineAt, in: VietnamClock.timeZone))."))
                    .font(.callout)
                    .foregroundStyle(Palette.textSecondary)
                let undoLeft = planner.settings.undoWindow - now.timeIntervalSince(takenAt)
                if undoLeft > 0 {
                    Button(L("Hoàn tác (còn \(TodayText.duration(undoLeft)))", "Undo (\(TodayText.duration(undoLeft)) left)")) { Task { await model.undo() } }
                        .buttonStyle(SecondaryButtonStyle())
                }
            } else {
                StatusPill(status: .upcoming)
                let day = TodayText.relativeDay(dose.dueAt, from: now)
                timeBlock(title: L("\(day.prefix(1).uppercased() + day.dropFirst()) lúc", "\(day.prefix(1).uppercased() + day.dropFirst()) at"),
                          time: TimeFormatting.clockTime(dose.dueAt, in: VietnamClock.timeZone), showsVN: true,
                          local: TodayText.localLine(dose.dueAt))
                Text(L("Còn \(TodayText.duration(dose.dueAt.timeIntervalSince(now)))", "In \(TodayText.duration(dose.dueAt.timeIntervalSince(now)))"))
                    .font(.headline)
                    .foregroundStyle(Palette.textSecondary)
                takeButton
                Text(L("Uống sớm cũng được, lần sau sẽ nhắc sớm theo.", "Taking it early is fine, the next reminder moves earlier too."))
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
            Text(records.count == 1 ? L("Có 1 lần hụt chưa uống bù", "1 missed dose not made up") : L("Có \(records.count) lần hụt chưa uống bù", "\(records.count) missed doses not made up"))
                .font(.headline)
                .foregroundStyle(Palette.text)
            ForEach(records) { record in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(TodayText.dayTitle(record.scheduledAt))
                            .font(.body.weight(.medium))
                            .foregroundStyle(Palette.text)
                        Text(L("giờ uống \(TimeFormatting.vn(record.scheduledAt))", "pill time \(TimeFormatting.vn(record.scheduledAt))"))
                            .font(.footnote)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Spacer()
                    Button(L("Đã uống bù", "Mark made up")) { model.markMadeUp(missedAt: record.scheduledAt) }
                        .buttonStyle(.bordered)
                        .tint(DoseStatus.madeUp.foreground)
                }
            }
            Text(L("Có nên uống bù hay không, uống thế nào: xem tờ hướng dẫn thuốc hoặc hỏi bác sĩ, dược sĩ. Bấm nhầm thì xoá trong Lịch sử.", "Whether and how to make up a missed pill: check the leaflet or ask a doctor or pharmacist. Tapped by mistake? Delete it in History."))
                .font(.footnote)
                .foregroundStyle(Palette.textSecondary)
        }
        .card()
    }

    private var takeButton: some View {
        Button(L("Đã uống", "Taken")) { Task { await model.markTaken() } }
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
                    Text(L("giờ VN", "VN time"))
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
                Label(L("Số viên", "Pills"), systemImage: "pills.fill")
                    .font(.headline)
                    .foregroundStyle(Palette.text)
                Spacer()
                Text(L("\(pills.remaining)/\(pills.total) viên", "\(pills.remaining)/\(pills.total) pills"))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Palette.text)
            }
            ProgressView(value: Double(pills.remaining), total: Double(max(1, pills.total)))
                .tint(Palette.primary)
            if let refill = pills.refillMessage(model.planner.settings.refillReminder, language: AppLanguage.current) {
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
            Button(L("Thêm viên", "Add pills")) { pillsSheet = true }
                .buttonStyle(SecondaryButtonStyle())
        }
        .card()
    }

    private func weekCard(now: Date) -> some View {
        let calendar = VietnamClock.calendar
        let today = calendar.startOfDay(for: now)
        let statuses = model.planner.dayStatuses(now: now)
        let days: [(name: String, status: DoseStatus)] = (0..<7).reversed().map { back in
            let day = calendar.date(byAdding: .day, value: -back, to: today)!
            let name = TodayText.shortWeekday(calendar.component(.weekday, from: day))
            return (name, statuses[day].map(DoseStatus.init) ?? .upcoming)
        }
        return VStack(alignment: .leading, spacing: 12) {
            Text(L("7 ngày qua", "Last 7 days"))
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
    private static let weekdaysVI = ["Chủ Nhật", "Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy"]
    private static let weekdaysEN = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private static let monthsEN = ["January", "February", "March", "April", "May", "June", "July", "August",
                                   "September", "October", "November", "December"]
    static let shortWeekdaysVI = ["CN", "T2", "T3", "T4", "T5", "T6", "T7"]
    static let shortWeekdaysEN = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    /// Tên thứ viết tắt theo `weekday` của Calendar (1 là Chủ Nhật).
    static func shortWeekday(_ weekday: Int) -> String {
        (AppLanguage.current == .en ? shortWeekdaysEN : shortWeekdaysVI)[weekday - 1]
    }

    /// "Thứ Năm, 29 tháng 10" hoặc "Thursday, 29 October", theo ngày VN.
    static func dayTitle(_ date: Date) -> String {
        let parts = VietnamClock.calendar.dateComponents([.weekday, .day, .month], from: date)
        let weekday = (parts.weekday ?? 1) - 1, day = parts.day ?? 1, month = parts.month ?? 1
        return L("\(weekdaysVI[weekday]), \(day) tháng \(month)", "\(weekdaysEN[weekday]), \(day) \(monthsEN[month - 1])")
    }

    static func monthTitle(month: Int, year: Int) -> String {
        L("Tháng \(month), \(String(year))", "\(monthsEN[month - 1]) \(String(year))")
    }

    /// "hôm nay", "mai", hoặc thứ trong tuần, theo ngày VN.
    static func relativeDay(_ date: Date, from now: Date) -> String {
        let calendar = VietnamClock.calendar
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return L("hôm nay", "today")
        case 1: return L("mai", "tomorrow")
        default: return dayTitle(date)
        }
    }

    /// "2 giờ 10 phút" hoặc "2 h 10 min". Làm tròn lên phút để đếm ngược không hiện "0 phút".
    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((max(0, seconds) / 60).rounded(.up))
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return L("\(m) phút", "\(m) min") }
        return m == 0 ? L("\(h) giờ", "\(h) h") : L("\(h) giờ \(m) phút", "\(h) h \(m) min")
    }

    /// Giờ nơi máy đang ở, ẩn khi máy đang theo giờ VN.
    static func localLine(_ date: Date) -> String? {
        let zone = TimeZone.autoupdatingCurrent
        guard zone.secondsFromGMT(for: date) != VietnamClock.timeZone.secondsFromGMT(for: date) else { return nil }
        let place = zone.identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? zone.identifier
        let time = TimeFormatting.clockTime(date, in: zone)
        return L("tức \(time) tại \(place)", "that is \(time) in \(place)")
    }

    /// Còn hiện trạng thái "Đã uống": cùng ngày VN, hoặc còn trong thời gian hoàn tác.
    static func isRecent(_ takenAt: Date, now: Date, undoWindow: TimeInterval) -> Bool {
        VietnamClock.calendar.isDate(takenAt, inSameDayAs: now) || now.timeIntervalSince(takenAt) <= undoWindow
    }
}

#Preview { TodayView().environment(AppModel.shared) }
