import NersCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var pillsSheet = false
    @State private var confirmStopCounting = false
    @State private var confirmDisconnect = false
    @State private var code = ""
    @State private var badCode = false

    var body: some View {
        @Bindable var model = model
        let settings = model.planner.settings
        let now = Date.now
        NavigationStack {
            Form {
                Section {
                    DatePicker("Giờ uống (giờ VN)", selection: mainTime, displayedComponents: .hourAndMinute)
                        .environment(\.timeZone, VietnamClock.timeZone)
                    if let local = TodayText.localLine(VietnamClock.calendar.date(bySettingHour: settings.mainHour, minute: settings.mainMinute, second: 0, of: now)!) {
                        LabeledContent("Ở nơi đang đứng", value: local)
                    }
                    LabeledContent("Cách nhau tối đa", value: TodayText.duration(settings.maxInterval))
                } header: {
                    Text("Lịch uống")
                } footer: {
                    Text("Giờ uống luôn tính theo giờ Việt Nam, dù máy đang ở múi giờ nào.")
                }

                Section {
                    Picker("Âm thanh", selection: $model.vibrateOnly) {
                        Text("Có tiếng").tag(false)
                        Text("Theo chế độ máy").tag(true)
                    }
                    .pickerStyle(.segmented)
                    LabeledContent("Nhắc lại", value: "\(settings.repeatCount) lần, mỗi \(TodayText.duration(settings.repeatInterval))")
                    LabeledContent("Hoãn", value: TodayText.duration(settings.snoozeInterval))
                    LabeledContent("Quá hạn vẫn nhắc thêm", value: TodayText.duration(settings.lateWindow))
                    pauseRow(until: settings.pausedUntil(now: now))
                } header: {
                    Text("Nhắc nhở")
                } footer: {
                    Text(model.vibrateOnly
                         ? "Nhắc bằng thông báo, im lặng thì chỉ rung. Tới hạn chót vẫn là báo thức có tiếng."
                         : "Mọi lần nhắc là báo thức, kêu cả khi máy im lặng hay bật Focus.")
                }

                Section {
                    Toggle("Đếm số viên", isOn: Binding(
                        get: { settings.pills != nil },
                        set: { on in if on { pillsSheet = true } else { confirmStopCounting = true } }
                    ))
                    if let pills = settings.pills {
                        LabeledContent("Còn lại", value: "\(pills.remaining)/\(pills.total) viên")
                        Button("Thêm viên") { pillsSheet = true }
                        Toggle("Nhắc mua thêm", isOn: Binding(
                            get: { settings.refillReminder.enabled },
                            set: { on in model.update { $0.settings.refillReminder.enabled = on } }
                        ))
                        if settings.refillReminder.enabled {
                            Stepper("Nhắc khi còn \(settings.refillReminder.daysBefore) viên", value: Binding(
                                get: { settings.refillReminder.daysBefore },
                                set: { days in model.update { $0.settings.refillReminder.daysBefore = days } }
                            ), in: 1...28)
                        }
                    }
                } header: {
                    Text("Số viên")
                } footer: {
                    Text("Tắt đếm thì app chỉ nhắc uống mỗi ngày.")
                }

                Section {
                    if let connection = model.connection {
                        Toggle("Chia sẻ với Tùng", isOn: $model.shareEnabled)
                        LabeledContent("Server", value: connection.endpoint.host() ?? "")
                        LabeledContent("Đồng bộ gần nhất", value: model.lastSync.map { "\(TodayText.dayTitle($0)), \(TimeFormatting.vietnamTime($0))" } ?? "chưa")
                        if let issue = model.syncIssue {
                            Text(issue).foregroundStyle(DoseStatus.missed.foreground)
                        }
                        Button("Gỡ kết nối", role: .destructive) { confirmDisconnect = true }
                    } else {
                        TextField("Dán mã kết nối", text: $code)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Kết nối") {
                            Task { badCode = !(await model.connect(code: code)) }
                        }
                        .disabled(code.isEmpty)
                        if badCode {
                            Text("Mã không đúng dạng. Mã bắt đầu bằng https:// và có dấu #.")
                                .foregroundStyle(DoseStatus.missed.foreground)
                        }
                    }
                } header: {
                    Text("Theo dõi cùng")
                } footer: {
                    Text("Khi có mạng, app gửi trạng thái mới nhất để Tùng xem qua Telegram. Không có mạng thì vẫn nhắc bình thường. Mã kết nối lấy bằng lệnh /link của bot.")
                }

                Section("Ứng dụng") {
                    LabeledContent("Phiên bản", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .tint(Palette.primary)
            .navigationTitle("Cài đặt")
            .sheet(isPresented: $pillsSheet) { PillsSheet() }
            .confirmationDialog("Gỡ kết nối với Tùng?", isPresented: $confirmDisconnect, titleVisibility: .visible) {
                Button("Gỡ kết nối", role: .destructive) { model.disconnect() }
            } message: {
                Text("App ngừng gửi dữ liệu. Muốn nối lại thì dán lại mã kết nối.")
            }
            .confirmationDialog("Tắt đếm số viên?", isPresented: $confirmStopCounting, titleVisibility: .visible) {
                Button("Tắt đếm", role: .destructive) { model.update { $0.settings.pills = nil } }
            } message: {
                Text("Số viên đang đếm sẽ mất. Lịch sử uống vẫn giữ nguyên.")
            }
        }
    }

    /// Giờ chính dưới dạng `Date` hôm nay theo giờ VN, để dùng với DatePicker.
    private var mainTime: Binding<Date> {
        Binding(
            get: {
                let s = model.planner.settings
                return VietnamClock.calendar.date(bySettingHour: s.mainHour, minute: s.mainMinute, second: 0, of: .now)!
            },
            set: { date in
                let parts = VietnamClock.calendar.dateComponents([.hour, .minute], from: date)
                model.update {
                    $0.settings.mainHour = parts.hour ?? 21
                    $0.settings.mainMinute = parts.minute ?? 0
                }
            }
        )
    }

    @ViewBuilder
    private func pauseRow(until: Date?) -> some View {
        if let until {
            LabeledContent("Đang tạm dừng tới", value: "\(TodayText.dayTitle(until)), \(TimeFormatting.vietnamTime(until))")
            Button("Nhắc lại ngay") { model.update { $0.resume(now: .now) } }
        } else {
            Menu("Tạm dừng nhắc") {
                ForEach([1, 3, 7], id: \.self) { days in
                    Button("\(days) ngày") { model.update { $0.pause(days: days, now: .now) } }
                }
            }
        }
    }
}

/// Nhập số viên lần đầu, hoặc thêm viên khi mua vỉ mới.
struct PillsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var count = 28

    var body: some View {
        let counting = model.planner.settings.pills != nil
        NavigationStack {
            Form {
                Stepper("\(count) viên", value: $count, in: 1...200)
                Text(counting ? "Cộng vào số viên còn lại." : "Mỗi lần bấm Đã uống trừ một viên.")
                    .foregroundStyle(Palette.textSecondary)
            }
            .navigationTitle(counting ? "Thêm viên" : "Bắt đầu đếm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Huỷ") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        model.update { $0.addPills(count, now: .now) }
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .tint(Palette.primary)
    }
}

#Preview { SettingsView().environment(AppModel.shared) }
