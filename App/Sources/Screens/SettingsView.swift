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
                    DatePicker(L("Giờ uống (giờ VN)", "Pill time (VN time)"), selection: mainTime, displayedComponents: .hourAndMinute)
                        .environment(\.timeZone, VietnamClock.timeZone)
                    if let local = TodayText.localLine(VietnamClock.calendar.date(bySettingHour: settings.mainHour, minute: settings.mainMinute, second: 0, of: now)!) {
                        LabeledContent(L("Ở nơi đang đứng", "Where you are"), value: local)
                    }
                    LabeledContent(L("Cách nhau tối đa", "Max gap between doses"), value: TodayText.duration(settings.maxInterval))
                } header: {
                    Text(L("Lịch uống", "Schedule"))
                } footer: {
                    Text(L("Giờ uống luôn tính theo giờ Việt Nam, dù máy đang ở múi giờ nào.", "Pill time always follows Vietnam time, whatever time zone the phone is in."))
                }

                Section {
                    Picker(L("Âm thanh", "Sound"), selection: $model.vibrateOnly) {
                        Text(L("Có tiếng", "Always ring")).tag(false)
                        Text(L("Theo chế độ máy", "Follow phone")).tag(true)
                    }
                    .pickerStyle(.segmented)
                    LabeledContent(L("Nhắc lại", "Repeats"), value: L("\(settings.repeatCount) lần, mỗi \(TodayText.duration(settings.repeatInterval))", "\(settings.repeatCount) times, every \(TodayText.duration(settings.repeatInterval))"))
                    LabeledContent(L("Hoãn", "Snooze"), value: TodayText.duration(settings.snoozeInterval))
                    LabeledContent(L("Quá hạn vẫn nhắc thêm", "Keep reminding after deadline"), value: TodayText.duration(settings.lateWindow))
                    pauseRow(until: settings.pausedUntil(now: now))
                } header: {
                    Text(L("Nhắc nhở", "Reminders"))
                } footer: {
                    Text(model.vibrateOnly
                         ? L("Nhắc bằng thông báo, im lặng thì chỉ rung. Tới hạn chót vẫn là báo thức có tiếng.", "Reminders are notifications, so they only vibrate on silent. From the deadline on it is always a ringing alarm.")
                         : L("Mọi lần nhắc là báo thức, kêu cả khi máy im lặng hay bật Focus.", "Every reminder is an alarm that rings even on silent or in Focus."))
                }

                Section {
                    Toggle(L("Đếm số viên", "Count pills"), isOn: Binding(
                        get: { settings.pills != nil },
                        set: { on in if on { pillsSheet = true } else { confirmStopCounting = true } }
                    ))
                    if let pills = settings.pills {
                        LabeledContent(L("Còn lại", "Remaining"), value: L("\(pills.remaining)/\(pills.total) viên", "\(pills.remaining)/\(pills.total) pills"))
                        Button(L("Thêm viên", "Add pills")) { pillsSheet = true }
                        Toggle(L("Nhắc mua thêm", "Refill reminder"), isOn: Binding(
                            get: { settings.refillReminder.enabled },
                            set: { on in model.update { $0.settings.refillReminder.enabled = on } }
                        ))
                        if settings.refillReminder.enabled {
                            Stepper(L("Nhắc khi còn \(settings.refillReminder.daysBefore) viên", "Remind at \(settings.refillReminder.daysBefore) pills left"), value: Binding(
                                get: { settings.refillReminder.daysBefore },
                                set: { days in model.update { $0.settings.refillReminder.daysBefore = days } }
                            ), in: 1...28)
                        }
                    }
                } header: {
                    Text(L("Số viên", "Pills"))
                } footer: {
                    Text(L("Tắt đếm thì app chỉ nhắc uống mỗi ngày.", "With counting off, the app only reminds you daily."))
                }

                Section {
                    if let connection = model.connection {
                        Toggle(L("Chia sẻ với Tùng", "Share with Tùng"), isOn: $model.shareEnabled)
                        LabeledContent("Server", value: connection.endpoint.host() ?? "")
                        LabeledContent(L("Đồng bộ gần nhất", "Last sync"), value: model.lastSync.map { "\(TodayText.dayTitle($0)), \(TimeFormatting.vn($0))" } ?? L("chưa", "never"))
                        if let issue = model.syncIssue {
                            Text(issue).foregroundStyle(DoseStatus.missed.foreground)
                        }
                        Button(L("Gỡ kết nối", "Disconnect"), role: .destructive) { confirmDisconnect = true }
                    } else {
                        TextField(L("Dán mã kết nối", "Paste connection code"), text: $code)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button(L("Kết nối", "Connect")) {
                            Task { badCode = !(await model.connect(code: code)) }
                        }
                        .disabled(code.isEmpty)
                        if badCode {
                            Text(L("Mã không đúng dạng. Mã bắt đầu bằng https:// và có dấu #.", "Invalid code. It starts with https:// and contains #."))
                                .foregroundStyle(DoseStatus.missed.foreground)
                        }
                    }
                } header: {
                    Text(L("Theo dõi cùng", "Shared tracking"))
                } footer: {
                    Text(L("Khi có mạng, app gửi trạng thái mới nhất để Tùng xem qua Telegram. Không có mạng thì vẫn nhắc bình thường. Mã kết nối lấy bằng lệnh /link của bot.", "When online, the app sends the latest status so Tùng can follow it on Telegram. Offline, reminders work as usual. Get the connection code with the bot's /link command."))
                }

                Section(L("Ứng dụng", "App")) {
                    Picker(L("Ngôn ngữ", "Language"), selection: $model.language) {
                        Text("Tiếng Việt").tag(Language.vi)
                        Text("English").tag(Language.en)
                    }
                    LabeledContent(L("Phiên bản", "Version"), value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .tint(Palette.primary)
            .navigationTitle(L("Cài đặt", "Settings"))
            .sheet(isPresented: $pillsSheet) { PillsSheet() }
            .confirmationDialog(L("Gỡ kết nối với Tùng?", "Disconnect from Tùng?"), isPresented: $confirmDisconnect, titleVisibility: .visible) {
                Button(L("Gỡ kết nối", "Disconnect"), role: .destructive) { model.disconnect() }
            } message: {
                Text(L("App ngừng gửi dữ liệu. Muốn nối lại thì dán lại mã kết nối.", "The app stops sending data. Paste the connection code again to reconnect."))
            }
            .confirmationDialog(L("Tắt đếm số viên?", "Stop counting pills?"), isPresented: $confirmStopCounting, titleVisibility: .visible) {
                Button(L("Tắt đếm", "Stop counting"), role: .destructive) { model.update { $0.settings.pills = nil } }
            } message: {
                Text(L("Số viên đang đếm sẽ mất. Lịch sử uống vẫn giữ nguyên.", "The current pill count is lost. Your history stays."))
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
            LabeledContent(L("Đang tạm dừng tới", "Paused until"), value: "\(TodayText.dayTitle(until)), \(TimeFormatting.vn(until))")
            Button(L("Nhắc lại ngay", "Resume now")) { model.update { $0.resume(now: .now) } }
        } else {
            Menu(L("Tạm dừng nhắc", "Pause reminders")) {
                ForEach([1, 3, 7], id: \.self) { days in
                    Button(L("\(days) ngày", days == 1 ? "1 day" : "\(days) days")) { model.update { $0.pause(days: days, now: .now) } }
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
                Stepper(L("\(count) viên", "\(count) pills"), value: $count, in: 1...200)
                Text(counting ? L("Cộng vào số viên còn lại.", "Added to the remaining pills.") : L("Mỗi lần bấm Đã uống trừ một viên.", "Each tap on Taken subtracts one pill."))
                    .foregroundStyle(Palette.textSecondary)
            }
            .navigationTitle(counting ? L("Thêm viên", "Add pills") : L("Bắt đầu đếm", "Start counting"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Huỷ", "Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Lưu", "Save")) {
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
