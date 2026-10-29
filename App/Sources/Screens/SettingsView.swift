import SwiftUI

struct SettingsView: View {
    @State private var doseTime = Calendar.current.date(from: DateComponents(hour: 21, minute: 0)) ?? .now
    @State private var soundMode = 0
    @State private var countPills = true
    @State private var refillReminder = true
    @State private var shareWithTung = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Giờ uống (giờ VN)", selection: $doseTime, displayedComponents: .hourAndMinute)
                    LabeledContent("Tức là ở \(Mock.localPlace)", value: "16:00")
                    LabeledContent("Cách nhau tối đa", value: "24 giờ")
                } header: {
                    Text("Lịch uống")
                } footer: {
                    Text("Giờ uống luôn tính theo giờ Việt Nam, dù máy đang ở múi giờ nào.")
                }

                Section("Nhắc nhở") {
                    Picker("Âm thanh", selection: $soundMode) {
                        Text("Có tiếng").tag(0)
                        Text("Chỉ rung").tag(1)
                    }
                    .pickerStyle(.segmented)
                    LabeledContent("Nhắc lại", value: "3 lần, mỗi 5 phút")
                    LabeledContent("Hoãn", value: "10 phút")
                    LabeledContent("Tạm dừng nhắc", value: "Không")
                }

                Section {
                    Toggle("Đếm số viên", isOn: $countPills)
                    if countPills {
                        LabeledContent("Còn lại", value: "\(Mock.pillsRemaining) viên")
                        Toggle("Nhắc mua thêm", isOn: $refillReminder)
                        if refillReminder {
                            LabeledContent("Nhắc trước", value: "\(Mock.refillDaysBefore) ngày")
                        }
                    }
                } header: {
                    Text("Số viên")
                } footer: {
                    Text("Tắt đếm thì app chỉ nhắc uống mỗi ngày.")
                }

                Section {
                    Toggle("Chia sẻ với Tùng", isOn: $shareWithTung)
                    LabeledContent("Đồng bộ gần nhất", value: "20:59 giờ VN")
                } header: {
                    Text("Theo dõi cùng")
                } footer: {
                    Text("Khi có mạng, app gửi trạng thái mới nhất để Tùng xem qua Telegram. Không có mạng thì vẫn nhắc bình thường.")
                }

                Section("Lời nhắn") {
                    Text(Mock.message)
                        .foregroundStyle(Palette.textSecondary)
                }

                Section("Ứng dụng") {
                    LabeledContent("Chữ ký hết hạn sau", value: "5 ngày")
                    LabeledContent("Phiên bản", value: "0.1.0")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .tint(Palette.primary)
            .navigationTitle("Cài đặt")
        }
    }
}

#Preview { SettingsView() }
