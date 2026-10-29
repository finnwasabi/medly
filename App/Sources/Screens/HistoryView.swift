import NersCore
import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    /// 0 is this month, -1 the previous one.
    @State private var monthOffset = 0
    @State private var editing: DoseRecord?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private var calendar: Calendar { VietnamClock.calendar }

    var body: some View {
        let now = Date.now
        let planner = model.planner
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summaryCard(planner: planner, now: now)
                    calendarCard(days: planner.dayStatuses(now: now), now: now)
                    entriesCard(planner.timeline(now: now).reversed().prefix(14).map { $0 })
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Palette.background)
            .navigationTitle(L("Lịch sử", "History"))
            .sheet(item: $editing) { record in
                EditTakenTimeSheet(record: record)
            }
        }
    }

    private func summaryCard(planner: Planner, now: Date) -> some View {
        HStack(spacing: 0) {
            stat(value: planner.daysTaken(now: now), label: L("ngày đã uống", "days taken"), color: DoseStatus.taken.foreground)
            Divider().frame(height: 40)
            stat(value: planner.lateCount(now: now), label: L("lần trễ", "late"), color: DoseStatus.late.foreground)
            Divider().frame(height: 40)
            stat(value: planner.madeUpCount(now: now), label: L("uống bù", "made up"), color: DoseStatus.madeUp.foreground)
            Divider().frame(height: 40)
            stat(value: planner.missedCount(now: now) - planner.madeUpCount(now: now), label: L("viên hụt", "missed"), color: DoseStatus.missed.foreground)
        }
        // Four columns: cap the text size so labels never break mid-word.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .card()
    }

    private func stat(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.footnote)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private func calendarCard(days: [Date: NersCore.DoseStatus], now: Date) -> some View {
        let today = calendar.startOfDay(for: now)
        let month = calendar.date(byAdding: .month, value: monthOffset, to: calendar.date(from: calendar.dateComponents([.year, .month], from: now))!)!
        let parts = calendar.dateComponents([.year, .month], from: month)
        let dayCount = calendar.range(of: .day, in: .month, for: month)!.count
        // Weeks start on Monday: weekday 2 gives 0 blank cells, Sunday (1) gives 6.
        let leading = (calendar.component(.weekday, from: month) + 5) % 7
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(TodayText.monthTitle(month: parts.month!, year: parts.year!))
                    .font(.headline)
                    .foregroundStyle(Palette.text)
                Spacer()
                Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel(L("Tháng trước", "Previous month"))
                Button { monthOffset += 1 } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel(L("Tháng sau", "Next month"))
                    .disabled(monthOffset >= 0)
                    .padding(.leading, 16)
            }
            .foregroundStyle(Palette.primary)
            LazyVGrid(columns: columns, spacing: 6) {
                // Three kinds of cells share one grid, so ids use separate ranges: weekday headers -1 to -7, blanks from -100, days from 1.
                ForEach([-2, -3, -4, -5, -6, -7, -1], id: \.self) { weekday in
                    Text(TodayText.shortWeekday(-weekday))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                }
                ForEach((0..<leading).map { -100 - $0 }, id: \.self) { _ in Color.clear.frame(height: 40) }
                ForEach(1...dayCount, id: \.self) { day in
                    let date = calendar.date(byAdding: .day, value: day - 1, to: month)!
                    dayCell(day: day, status: days[date].map(DoseStatus.init), isToday: date == today)
                }
            }
            // A 7-column grid has a fixed width budget.
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            legend
        }
        .card()
    }

    private func dayCell(day: Int, status: DoseStatus?, isToday: Bool) -> some View {
        Text("\(day)")
            .font(.callout.weight(.semibold).monospacedDigit())
            .frame(maxWidth: .infinity, minHeight: 40)
            .foregroundStyle(status?.foreground ?? Palette.textSecondary)
            .background(status?.background ?? .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Palette.primary, lineWidth: 2)
                }
            }
            .accessibilityLabel(L("Ngày \(day), \(status?.label ?? "chưa có")", "Day \(day), \(status?.label ?? "no record")"))
    }

    private var legend: some View {
        // Wraps to two rows on narrow screens.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), alignment: .leading)], alignment: .leading, spacing: 6) {
            ForEach([DoseStatus.taken, .late, .madeUp, .missed, .paused], id: \.self) { status in
                Label(status.label, systemImage: status.icon)
                    .font(.caption)
                    .foregroundStyle(status.foreground)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .padding(.top, 4)
    }

    private func entryDetail(_ record: DoseRecord) -> String {
        guard let takenAt = record.takenAt else { return L("giờ uống \(TimeFormatting.vn(record.scheduledAt))", "pill time \(TimeFormatting.vn(record.scheduledAt))") }
        if record.status == .madeUp { return L("uống bù lúc \(TimeFormatting.vn(takenAt)), \(TodayText.dayTitle(takenAt))", "made up at \(TimeFormatting.vn(takenAt)), \(TodayText.dayTitle(takenAt))") }
        return TimeFormatting.vn(takenAt)
    }

    private func entriesCard(_ records: [DoseRecord]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("Gần đây", "Recent"))
                .font(.headline)
                .foregroundStyle(Palette.text)
                .padding(.bottom, 8)
            if records.isEmpty {
                Text(L("Chưa có lần uống nào.", "No doses yet."))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.vertical, 10)
            }
            ForEach(records) { record in
                // Missed or paused rows are not editable: no button wrapper, so the text is not dimmed like a disabled button.
                let row = HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                            Text(TodayText.dayTitle(record.status == .madeUp ? record.scheduledAt : (record.takenAt ?? record.scheduledAt)))
                                .font(.body.weight(.medium))
                                .foregroundStyle(Palette.text)
                            Text(entryDetail(record))
                                .font(.footnote)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        Spacer()
                        StatusPill(status: DoseStatus(record.status))
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                if record.takenAt != nil {
                    Button { editing = record } label: { row }
                        .buttonStyle(.plain)
                        .accessibilityHint(L("Sửa giờ uống", "Edit time"))
                } else {
                    row
                }
                if record.id != records.last?.id { Divider() }
            }
            Text(L("Chạm vào một lần uống để sửa giờ.", "Tap a dose to edit its time."))
                .font(.footnote)
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 8)
        }
        .card()
    }
}

/// Edits the taken time of a dose, entered in Vietnam time.
struct EditTakenTimeSheet: View {
    let record: DoseRecord
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now
    @State private var confirmRemove = false

    var body: some View {
        NavigationStack {
            Form {
                DatePicker(L("Giờ uống (giờ VN)", "Pill time (VN time)"), selection: $date, in: ...Date.now)
                    .environment(\.timeZone, VietnamClock.timeZone)
                if record.status == .madeUp {
                    Button(L("Xoá lần uống bù", "Delete make-up"), role: .destructive) { confirmRemove = true }
                }
            }
            .confirmationDialog(L("Xoá lần uống bù này?", "Delete this make-up?"), isPresented: $confirmRemove, titleVisibility: .visible) {
                Button(L("Xoá", "Delete"), role: .destructive) {
                    model.update { $0.removeRecord(id: record.id) }
                    dismiss()
                }
            } message: {
                Text(L("Lần đó sẽ hiện lại là hụt. Nếu đang đếm viên thì được trả lại một viên.", "That dose shows as missed again. If you count pills, one pill is given back."))
            }
            .navigationTitle(L("Sửa giờ uống", "Edit time"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Huỷ", "Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Lưu", "Save")) {
                        model.update { $0.editTakenTime(id: record.id, to: date) }
                        dismiss()
                    }
                }
            }
            .onAppear { date = record.takenAt ?? .now }
        }
        .presentationDetents([.medium])
        .tint(Palette.primary)
    }
}

#Preview { HistoryView().environment(AppModel.shared) }
