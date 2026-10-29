import SwiftUI

struct TodayView: View {
    let state: MockTodayState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    messageCard
                    doseCard
                    pillsCard
                    weekCard
                    syncFooter
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Palette.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Thứ Năm, 29 tháng 10")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.textSecondary)
            Text("Chào Ner")
                .font(.largeTitle.bold())
                .foregroundStyle(Palette.text)
        }
        .padding(.top, 12)
    }

    private var messageCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "heart.fill")
                .foregroundStyle(Palette.primary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("Lời nhắn từ Tùng")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.primary)
                Text(Mock.message)
                    .font(.body)
                    .foregroundStyle(Palette.text)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.primarySoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private var doseCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch state {
            case .upcoming:
                StatusPill(status: .upcoming)
                timeBlock(title: "Hôm nay lúc", time: "21:00", local: "tức 16:00 tại \(Mock.localPlace)")
                Text("Còn 2 giờ 15 phút")
                    .font(.headline)
                    .foregroundStyle(Palette.textSecondary)
                Button("Đã uống") {}
                    .buttonStyle(PrimaryButtonStyle())
                Text("Uống sớm cũng được, lần sau sẽ nhắc sớm theo.")
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
            case .taken:
                StatusPill(status: .taken)
                timeBlock(title: "Đã uống lúc", time: "20:58", local: "tức 15:58 tại \(Mock.localPlace)")
                Text("Lần sau: mai 21:00 giờ VN, hạn chót 20:58.")
                    .font(.callout)
                    .foregroundStyle(Palette.textSecondary)
                Button("Hoàn tác (còn 8 phút)") {}
                    .buttonStyle(SecondaryButtonStyle())
            case .overdue:
                StatusPill(status: .late)
                timeBlock(title: "Đã quá giờ uống", time: "2 giờ 10 phút", local: "giờ uống 21:00 giờ VN")
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Còn 50 phút tới hạn chót 24 giờ")
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(DoseStatus.missed.foreground)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DoseStatus.missed.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Button("Đã uống") {}
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .card()
    }

    private func timeBlock(title: String, time: String, local: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.callout)
                .foregroundStyle(Palette.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(time)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(Palette.text)
                if state != .overdue {
                    Text("giờ VN")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            Text(local)
                .font(.callout)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private var pillsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Số viên", systemImage: "pills.fill")
                    .font(.headline)
                    .foregroundStyle(Palette.text)
                Spacer()
                Text("\(Mock.pillsRemaining)/\(Mock.pillsTotal) viên")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Palette.text)
            }
            ProgressView(value: Double(Mock.pillsRemaining), total: Double(Mock.pillsTotal))
                .tint(Palette.primary)
            if Mock.pillsRemaining <= Mock.refillDaysBefore {
                HStack(spacing: 8) {
                    Image(systemName: "cart.fill")
                    Text("Còn \(Mock.pillsRemaining) viên, nhớ mua thêm")
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(DoseStatus.late.foreground)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DoseStatus.late.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Button("Thêm viên") {}
                .buttonStyle(SecondaryButtonStyle())
        }
        .card()
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7 ngày qua")
                .font(.headline)
                .foregroundStyle(Palette.text)
            HStack(spacing: 0) {
                ForEach(Array(zip(["T6", "T7", "CN", "T2", "T3", "T4", "T5"], Mock.week)), id: \.0) { day, status in
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

    private var syncFooter: some View {
        Label("Đã đồng bộ lúc 20:59 giờ VN", systemImage: "icloud.and.arrow.up")
            .font(.footnote)
            .foregroundStyle(Palette.textSecondary)
            .frame(maxWidth: .infinity)
    }
}

#Preview("Sắp tới") { TodayView(state: .upcoming) }
#Preview("Đã uống") { TodayView(state: .taken) }
#Preview("Quá giờ") { TodayView(state: .overdue) }
