import PillotCore
import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    /// 0 is this month, -1 the previous one.
    @State private var monthOffset = 0
    /// `nil` shows every medication.
    @State private var filter: UUID?
    @State private var editing: Entry?

    /// A history row with the medication it belongs to.
    struct Entry: Identifiable {
        var medication: Medication
        var record: DoseRecord
        /// Two medications can miss at the same moment, so the id needs both.
        var id: String { "\(medication.id)\(record.id)" }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private var calendar: Calendar { VietnamClock.calendar }

    var body: some View {
        let now = Date.now
        let shown = model.medications.filter { filter == nil || $0.id == filter }
        // One walk over each history per redraw.
        let summaries = shown.map { ($0, $0.planner.summary(now: now)) }
        let month = monthStart(now: now)
        Group {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(L("Lịch sử", "History"))
                        .font(.largeTitle.weight(.black))
                        .foregroundStyle(Palette.text)
                        .padding(.top, 12)
                    if model.medications.count > 1 { filterBar }
                    calendarCard(days: mergedDayStatuses(summaries.map { $0.1.dayStatuses() }), month: month, now: now)
                    // Under the calendar: the counts follow the month it shows.
                    summaryCard(summaries.flatMap(\.1.timeline), month: month)
                    entriesCard(summaries.flatMap { med, summary in summary.timeline.map { Entry(medication: med, record: $0) } }
                        .sorted { moment($0.record) > moment($1.record) }
                        .prefix(20).map { $0 })
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Palette.background)
            .sheet(item: $editing) { entry in
                EditTakenTimeSheet(medicationID: entry.medication.id, record: entry.record)
            }
            .onChange(of: model.medications.map(\.id)) { _, ids in
                if let filter, !ids.contains(filter) { self.filter = nil }
            }
        }
    }

    private func moment(_ record: DoseRecord) -> Date {
        record.status == .madeUp ? record.scheduledAt : (record.takenAt ?? record.scheduledAt)
    }

    /// The first day of the month on screen, Vietnam time.
    private func monthStart(now: Date) -> Date {
        calendar.date(byAdding: .month, value: monthOffset, to: calendar.date(from: calendar.dateComponents([.year, .month], from: now))!)!
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(L("Tất cả", "All"), fill: Palette.yellow, selected: filter == nil) { filter = nil }
                ForEach(model.medications) { med in
                    chip(med.name, fill: Swatch.color(med.color), selected: filter == med.id) { filter = med.id }
                }
            }
            .padding(.vertical, 4)
            .padding(.trailing, 6)
        }
    }

    private func chip(_ title: String, fill: Color, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.heavy))
                .lineLimit(1)
                .foregroundStyle(selected ? Palette.onFill : Palette.text)
                .padding(.horizontal, 14)
                .frame(minHeight: 38)
                .neo(selected ? fill : Palette.surface, radius: 12, shadow: selected ? 0 : 2.5)
                .offset(x: selected ? 2.5 : 0, y: selected ? 2.5 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Counts for the month on screen, like the calendar below. Before 0.3.5 "taken" counted only since pills were last
    /// added, so adding a pack reset it to 0. A record belongs to the dose it was for: a late or made-up dose to its dose time.
    private func summaryCard(_ timeline: [DoseRecord], month: Date) -> some View {
        let end = calendar.date(byAdding: .month, value: 1, to: month)!
        let inMonth = timeline.filter { record in
            let moment = [.madeUp, .late, .skipped].contains(record.status) ? record.scheduledAt : (record.takenAt ?? record.scheduledAt)
            return moment >= month && moment < end
        }
        let count = { (statuses: [PillotCore.DoseStatus]) in inMonth.count(where: { statuses.contains($0.status) }) }
        // Top alignment keeps the numbers level even if one label wraps.
        return HStack(alignment: .top, spacing: 8) {
            stat(value: count([.taken, .late]), label: L("đã uống", "taken"), status: .taken)
            stat(value: count([.late]), label: L("lần trễ", "late"), status: .late)
            stat(value: count([.madeUp]), label: L("uống bù", "made up"), status: .madeUp)
            stat(value: count([.missed]), label: L("lần hụt", "missed"), status: .missed)
        }
        // Four columns: cap the text size so labels never break mid-word.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    private func stat(value: Int, label: String, status: DoseStatus) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title.weight(.black).monospacedDigit())
            Text(label)
                .font(.footnote.weight(.heavy))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(Palette.onFill)
        .frame(maxWidth: .infinity, minHeight: 76)
        .neo(status.fill, radius: 14)
        .accessibilityElement(children: .combine)
    }

    private func calendarCard(days: [Date: PillotCore.DoseStatus], month: Date, now: Date) -> some View {
        let today = calendar.startOfDay(for: now)
        let parts = calendar.dateComponents([.year, .month], from: month)
        let dayCount = calendar.range(of: .day, in: .month, for: month)!.count
        // Weeks start on Monday: weekday 2 gives 0 blank cells, Sunday (1) gives 6.
        let leading = (calendar.component(.weekday, from: month) + 5) % 7
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(TodayText.monthTitle(month: parts.month!, year: parts.year!))
                    .font(.headline.weight(.black))
                    .foregroundStyle(Palette.text)
                Spacer()
                Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(ChipButtonStyle())
                    .accessibilityLabel(L("Tháng trước", "Previous month"))
                Button { monthOffset += 1 } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(ChipButtonStyle())
                    .accessibilityLabel(L("Tháng sau", "Next month"))
                    .disabled(monthOffset >= 0)
            }
            LazyVGrid(columns: columns, spacing: 6) {
                // Three kinds of cells share one grid, so ids use separate ranges: weekday headers -1 to -7, blanks from -100, days from 1.
                ForEach([-2, -3, -4, -5, -6, -7, -1], id: \.self) { weekday in
                    Text(TodayText.shortWeekday(-weekday))
                        .font(.caption.weight(.heavy))
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

    @ViewBuilder
    private func dayCell(day: Int, status: DoseStatus?, isToday: Bool) -> some View {
        let label = Text("\(day)")
            .font(.callout.weight(.heavy).monospacedDigit())
            .frame(maxWidth: .infinity, minHeight: 40)
        Group {
            if let status {
                label.foregroundStyle(Palette.onFill).neo(status.fill, radius: 10, shadow: 0)
            } else if isToday {
                label.foregroundStyle(Palette.text).neo(Palette.background, radius: 10, shadow: 0)
            } else {
                label.foregroundStyle(Palette.textSecondary)
            }
        }
        .accessibilityLabel(L("Ngày \(day), \(status?.label ?? "chưa có")", "Day \(day), \(status?.label ?? "no record")"))
    }

    private var legend: some View {
        // Wraps to two rows on narrow screens.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach([DoseStatus.taken, .late, .madeUp, .missed, .skipped, .paused], id: \.self) { status in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4).fill(status.fill)
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Palette.ink, lineWidth: 1.5))
                        .frame(width: 14, height: 14)
                    Text(status.label)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.text)
                }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .padding(.top, 4)
    }

    private func entryDetail(_ record: DoseRecord) -> String {
        guard let takenAt = record.takenAt else { return L("giờ uống \(TimeFormatting.vn(record.scheduledAt))", "dose time \(TimeFormatting.vn(record.scheduledAt))") }
        if record.status == .skipped { return L("bỏ qua lúc \(TimeFormatting.vn(takenAt))", "skipped at \(TimeFormatting.vn(takenAt))") }
        if record.status == .madeUp { return L("uống bù lúc \(TimeFormatting.vn(takenAt)), \(TodayText.dayTitle(takenAt))", "made up at \(TimeFormatting.vn(takenAt)), \(TodayText.dayTitle(takenAt))") }
        return TimeFormatting.vn(takenAt)
    }

    private func entriesCard(_ entries: [Entry]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("Gần đây", "Recent"))
                .font(.headline.weight(.black))
                .foregroundStyle(Palette.text)
                .padding(.bottom, 8)
            if entries.isEmpty {
                Text(L("Chưa có lần uống nào.", "No doses yet."))
                    .font(.body.weight(.medium))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.vertical, 10)
            }
            ForEach(entries) { entry in
                let record = entry.record
                // Missed or paused rows are not editable: no button wrapper, so the text is not dimmed like a disabled button.
                let row = HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 3).fill(Swatch.color(entry.medication.color))
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Palette.ink, lineWidth: 1.5))
                        .frame(width: 8)
                        .padding(.vertical, 4)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.medication.name)
                            .font(.footnote.weight(.heavy))
                            .foregroundStyle(Palette.textSecondary)
                        Text(TodayText.dayTitle(moment(record)))
                            .font(.body.weight(.bold))
                            .foregroundStyle(Palette.text)
                        Text(entryDetail(record))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Spacer()
                    StatusPill(status: DoseStatus(record.status))
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
                if record.takenAt != nil {
                    Button { editing = entry } label: { row }
                        .buttonStyle(.plain)
                        .accessibilityHint(L("Sửa giờ uống", "Edit time"))
                } else {
                    row
                }
                if entry.id != entries.last?.id { InkDivider() }
            }
            if !entries.isEmpty {
                Text(L("Chạm vào một lần uống để sửa giờ.", "Tap a dose to edit its time."))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, 8)
            }
        }
        .card()
    }
}

/// Edits the taken time of a dose, entered in Vietnam time.
struct EditTakenTimeSheet: View {
    let medicationID: UUID
    let record: DoseRecord
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now
    @State private var confirmRemove = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if record.status == .skipped {
                    Text(L("Đã bỏ qua lần uống này. Xoá thì lần đó quay lại như chưa uống.", "This dose was skipped. Deleting the skip brings the dose back as not taken."))
                        .font(.body.weight(.medium))
                        .foregroundStyle(Palette.text)
                        .card()
                    Button(L("Xoá lần bỏ qua", "Delete skip"), role: .destructive) { confirmRemove = true }
                        .buttonStyle(NeoButtonStyle(fill: Palette.coral, large: false))
                } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("Giờ uống (giờ VN)", "Dose time (VN time)"))
                        .font(.headline.weight(.black))
                        .foregroundStyle(Palette.text)
                    DatePicker("", selection: $date, in: ...Date.now)
                        .labelsHidden()
                        .environment(\.timeZone, VietnamClock.timeZone)
                }
                .card()
                if record.status == .madeUp {
                    Button(L("Xoá lần uống bù", "Delete make-up"), role: .destructive) { confirmRemove = true }
                        .buttonStyle(NeoButtonStyle(fill: Palette.coral, large: false))
                }
                }
                Spacer()
            }
            .padding(16)
            .background(Palette.background)
            .confirmationDialog(record.status == .skipped ? L("Xoá lần bỏ qua này?", "Delete this skip?") : L("Xoá lần uống bù này?", "Delete this make-up?"),
                                isPresented: $confirmRemove, titleVisibility: .visible) {
                Button(L("Xoá", "Delete"), role: .destructive) {
                    model.update(medicationID) { $0.planner.removeRecord(id: record.id) }
                    dismiss()
                }
            } message: {
                Text(record.status == .skipped
                     ? L("Lần đó quay lại như chưa uống: còn trong giờ thì app nhắc tiếp, quá giờ thì tính hụt.", "The dose comes back as not taken: reminded again if there is still time, missed if not.")
                     : L("Lần đó sẽ hiện lại là hụt. Nếu đang đếm viên thì được trả lại một viên.", "That dose shows as missed again. If you count pills, one pill is given back."))
            }
            .navigationTitle(record.status == .skipped ? L("Lần bỏ qua", "Skipped dose") : L("Sửa giờ uống", "Edit time"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Huỷ", "Cancel")) { dismiss() } }
                if record.status != .skipped {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L("Lưu", "Save")) {
                            model.update(medicationID) { $0.planner.editTakenTime(id: record.id, to: date) }
                            dismiss()
                        }
                        .fontWeight(.heavy)
                    }
                }
            }
            .onAppear { date = record.takenAt ?? .now }
        }
        .presentationDetents([.medium])
        .tint(Palette.ink)
    }
}

#Preview { HistoryView().environment(AppModel.shared) }
