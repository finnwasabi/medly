import NersCore
import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    /// 0 là tháng này, -1 là tháng trước.
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
            .navigationTitle("Lịch sử")
            .sheet(item: $editing) { record in
                EditTakenTimeSheet(record: record)
            }
        }
    }

    private func summaryCard(planner: Planner, now: Date) -> some View {
        HStack(spacing: 0) {
            stat(value: planner.daysTaken(now: now), label: "ngày đã uống", color: DoseStatus.taken.foreground)
            Divider().frame(height: 40)
            stat(value: planner.lateCount(now: now), label: "lần trễ", color: DoseStatus.late.foreground)
            Divider().frame(height: 40)
            stat(value: planner.madeUpCount(now: now), label: "uống bù", color: DoseStatus.madeUp.foreground)
            Divider().frame(height: 40)
            stat(value: planner.missedCount(now: now) - planner.madeUpCount(now: now), label: "viên hụt", color: DoseStatus.missed.foreground)
        }
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
        }
        .frame(maxWidth: .infinity)
    }

    private func calendarCard(days: [Date: NersCore.DoseStatus], now: Date) -> some View {
        let today = calendar.startOfDay(for: now)
        let month = calendar.date(byAdding: .month, value: monthOffset, to: calendar.date(from: calendar.dateComponents([.year, .month], from: now))!)!
        let parts = calendar.dateComponents([.year, .month], from: month)
        let dayCount = calendar.range(of: .day, in: .month, for: month)!.count
        // Thứ Hai đầu tuần: weekday 2 thành 0 ô trống, Chủ Nhật (1) thành 6.
        let leading = (calendar.component(.weekday, from: month) + 5) % 7
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tháng \(parts.month!), \(String(parts.year!))")
                    .font(.headline)
                    .foregroundStyle(Palette.text)
                Spacer()
                Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Tháng trước")
                Button { monthOffset += 1 } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel("Tháng sau")
                    .disabled(monthOffset >= 0)
                    .padding(.leading, 16)
            }
            .foregroundStyle(Palette.primary)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(["T2", "T3", "T4", "T5", "T6", "T7", "CN"], id: \.self) { day in
                    Text(day)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                }
                // Id âm để không trùng id các ô ngày trong cùng lưới.
                ForEach(-leading..<0, id: \.self) { _ in Color.clear.frame(height: 40) }
                ForEach(1...dayCount, id: \.self) { day in
                    let date = calendar.date(byAdding: .day, value: day - 1, to: month)!
                    dayCell(day: day, status: days[date].map(DoseStatus.init), isToday: date == today)
                }
            }
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
            .accessibilityLabel("Ngày \(day), \(status?.label ?? "chưa có")")
    }

    private var legend: some View {
        // Hai hàng để vừa màn hẹp.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), alignment: .leading)], alignment: .leading, spacing: 6) {
            ForEach([DoseStatus.taken, .late, .madeUp, .missed, .paused], id: \.self) { status in
                Label(status.label, systemImage: status.icon)
                    .font(.caption)
                    .foregroundStyle(status.foreground)
            }
        }
        .padding(.top, 4)
    }

    private func entryDetail(_ record: DoseRecord) -> String {
        guard let takenAt = record.takenAt else { return "giờ uống \(TimeFormatting.vietnamTime(record.scheduledAt))" }
        if record.status == .madeUp { return "uống bù lúc \(TimeFormatting.vietnamTime(takenAt)), \(TodayText.dayTitle(takenAt))" }
        return TimeFormatting.vietnamTime(takenAt)
    }

    private func entriesCard(_ records: [DoseRecord]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Gần đây")
                .font(.headline)
                .foregroundStyle(Palette.text)
                .padding(.bottom, 8)
            if records.isEmpty {
                Text("Chưa có lần uống nào.")
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.vertical, 10)
            }
            ForEach(records) { record in
                let editable = record.takenAt != nil
                Button {
                    if editable { editing = record }
                } label: {
                    HStack(spacing: 12) {
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
                }
                .buttonStyle(.plain)
                .disabled(!editable)
                if record.id != records.last?.id { Divider() }
            }
            Text("Chạm vào một lần uống để sửa giờ.")
                .font(.footnote)
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 8)
        }
        .card()
    }
}

/// Sửa giờ uống của một lần, nhập theo giờ VN.
struct EditTakenTimeSheet: View {
    let record: DoseRecord
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now
    @State private var confirmRemove = false

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Giờ uống (giờ VN)", selection: $date, in: ...Date.now)
                    .environment(\.timeZone, VietnamClock.timeZone)
                if record.status == .madeUp {
                    Button("Xoá lần uống bù", role: .destructive) { confirmRemove = true }
                }
            }
            .confirmationDialog("Xoá lần uống bù này?", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Xoá", role: .destructive) {
                    model.update { $0.removeRecord(id: record.id) }
                    dismiss()
                }
            } message: {
                Text("Lần đó sẽ hiện lại là hụt. Nếu đang đếm viên thì được trả lại một viên.")
            }
            .navigationTitle("Sửa giờ uống")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Huỷ") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
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
