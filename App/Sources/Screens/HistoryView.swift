import SwiftUI

struct HistoryView: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summaryCard
                    calendarCard
                    entriesCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Palette.background)
            .navigationTitle("Lịch sử")
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 0) {
            stat(value: "26", label: "ngày đã uống", color: DoseStatus.taken.foreground)
            Divider().frame(height: 40)
            stat(value: "2", label: "lần trễ", color: DoseStatus.late.foreground)
            Divider().frame(height: 40)
            stat(value: "1", label: "viên hụt", color: DoseStatus.missed.foreground)
        }
        .card()
    }

    private func stat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.footnote)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tháng 10, 2026")
                    .font(.headline)
                    .foregroundStyle(Palette.text)
                Spacer()
                Image(systemName: "chevron.left")
                Image(systemName: "chevron.right")
                    .padding(.leading, 16)
            }
            .foregroundStyle(Palette.primary)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(["T2", "T3", "T4", "T5", "T6", "T7", "CN"], id: \.self) { day in
                    Text(day)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                }
                // 01/10/2026 là Thứ Năm: chừa 3 ô trống.
                ForEach(0..<3, id: \.self) { _ in Color.clear.frame(height: 40) }
                ForEach(Mock.month) { day in
                    // Ngày chưa tới để trống nền cho khỏi lẫn với Tạm dừng.
                    let future = day.status == .upcoming
                    Text("\(day.day)")
                        .font(.callout.weight(.semibold).monospacedDigit())
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .foregroundStyle(future ? Palette.textSecondary : day.status.foreground)
                        .background(future ? Color.clear : day.status.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            if day.day == Mock.today {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Palette.primary, lineWidth: 2)
                            }
                        }
                        .accessibilityLabel("Ngày \(day.day), \(future ? "chưa tới" : day.status.label)")
                }
            }
            legend
        }
        .card()
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach([DoseStatus.taken, .late, .missed, .paused], id: \.self) { status in
                Label(status.label, systemImage: status.icon)
                    .font(.caption)
                    .foregroundStyle(status.foreground)
            }
        }
        .padding(.top, 4)
    }

    private var entriesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Gần đây")
                .font(.headline)
                .foregroundStyle(Palette.text)
                .padding(.bottom, 8)
            ForEach(Mock.entries) { entry in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.date)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Palette.text)
                        Text("\(entry.time) giờ VN" + (entry.note.map { ", \($0)" } ?? ""))
                            .font(.footnote)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Spacer()
                    StatusPill(status: entry.status)
                }
                .padding(.vertical, 10)
                if entry.id != Mock.entries.last?.id { Divider() }
            }
            Text("Chạm vào một ngày để sửa giờ uống.")
                .font(.footnote)
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 8)
        }
        .card()
    }
}

#Preview { HistoryView() }
