import NersCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmDisconnect = false
    @State private var code = ""
    @State private var badCode = false

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(L("Cài đặt", "Settings"))
                        .font(.largeTitle.weight(.black))
                        .foregroundStyle(Palette.text)
                        .padding(.top, 12)

                    section(L("Tên", "Names")) {
                        VStack(alignment: .leading, spacing: 12) {
                            label(L("Tên bạn", "Your name"))
                            NeoField(title: L("Nhập tên", "Enter name"), text: $model.userName)
                                .textContentType(.givenName)
                            label(L("Partner", "Partner"))
                            NeoField(title: L("Tuỳ chọn", "Optional"), text: $model.partnerName)
                        }
                    }

                    section(L("Nhắc nhở", "Reminders"), footer: model.vibrateOnly
                        ? L("Nhắc bằng thông báo, im lặng thì chỉ rung. Tới hạn chót vẫn là báo thức có tiếng.", "Reminders are notifications, so they only vibrate on silent. From the deadline on it is always a ringing alarm.")
                        : L("Mọi lần nhắc là báo thức, kêu cả khi máy im lặng hay bật Focus.", "Every reminder is an alarm that rings even on silent or in Focus.")) {
                        VStack(alignment: .leading, spacing: 14) {
                            label(L("Âm thanh", "Sound"))
                            NeoSegmented(options: [(false, L("Luôn kêu", "Always ring")), (true, L("Theo chế độ máy", "Follow phone"))], selection: $model.vibrateOnly)
                            InkDivider()
                            NeoRow(title: L("Hoãn", "Snooze"), detail: L("mặc định 9 phút như Đồng hồ iPhone", "9 min by default, like the iPhone Clock")) {
                                NeoStepper(label: L("\(model.snoozeMinutes) phút", "\(model.snoozeMinutes) min"), value: $model.snoozeMinutes, range: AppModel.snoozeRange)
                            }
                            Callout(text: L("Hoãn bao nhiêu lần cũng được, nhưng chỉ bấm Đã uống mới tắt hẳn. Chưa uống thì app nhắc lại 3 lần mỗi 5 phút, rồi mỗi giờ, rồi dồn dập trước hạn chót.",
                                            "Snooze as often as you like, but only Taken stops it for good. Until then the app repeats 3 times every 5 minutes, then hourly, then faster before the deadline."),
                                    icon: "bell.and.waves.left.and.right.fill", fill: Palette.lavender)
                        }
                    }

                    section(L("Theo dõi cùng", "Shared tracking"), footer: L("Khi có mạng, app gửi trạng thái mới nhất để \(model.partner) xem qua Telegram. Không có mạng thì vẫn nhắc bình thường. Mã kết nối lấy bằng lệnh /link của bot.", "When online, the app sends the latest status so \(model.partner) can follow it on Telegram. Offline, reminders work as usual. Get the connection code with the bot's /link command.")) {
                        sharing
                    }

                    section(L("Ứng dụng", "App")) {
                        VStack(alignment: .leading, spacing: 14) {
                            label(L("Ngôn ngữ", "Language"))
                            NeoSegmented(options: [(Language.vi, "Tiếng Việt"), (Language.en, "English")], selection: $model.language)
                            InkDivider()
                            NeoRow(title: L("Phiên bản", "Version")) {
                                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                                    .font(.body.weight(.heavy).monospacedDigit())
                                    .foregroundStyle(Palette.text)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Palette.background)
            .scrollDismissesKeyboard(.interactively)
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog(L("Gỡ kết nối với \(model.partner)?", "Disconnect from \(model.partner)?"), isPresented: $confirmDisconnect, titleVisibility: .visible) {
                Button(L("Gỡ kết nối", "Disconnect"), role: .destructive) { model.disconnect() }
            } message: {
                Text(L("App ngừng gửi dữ liệu. Muốn nối lại thì dán lại mã kết nối.", "The app stops sending data. Paste the connection code again to reconnect."))
            }
        }
    }

    @ViewBuilder
    private var sharing: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 14) {
            if let connection = model.connection {
                Toggle(L("Chia sẻ với \(model.partner)", "Share with \(model.partner)"), isOn: $model.shareEnabled)
                    .toggleStyle(NeoToggleStyle())
                InkDivider()
                NeoRow(title: "Server", detail: connection.endpoint.host() ?? "") { EmptyView() }
                NeoRow(title: L("Đồng bộ gần nhất", "Last sync"), detail: model.lastSync.map { "\(TodayText.dayTitle($0)), \(TimeFormatting.vn($0))" } ?? L("chưa", "never")) { EmptyView() }
                if let issue = model.syncIssue { Callout(text: issue, icon: "wifi.exclamationmark") }
                Button(L("Gỡ kết nối", "Disconnect"), role: .destructive) { confirmDisconnect = true }
                    .buttonStyle(ChipButtonStyle(fill: Palette.coral))
            } else {
                NeoField(title: L("Dán mã kết nối", "Paste connection code"), text: $code, limit: 500)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button(L("Kết nối", "Connect")) {
                    Task { badCode = !(await model.connect(code: code)) }
                }
                .buttonStyle(NeoButtonStyle(fill: Palette.sky, large: false))
                .disabled(code.isEmpty)
                if badCode {
                    Callout(text: L("Mã không đúng dạng. Mã bắt đầu bằng https:// và có dấu #.", "Invalid code. It starts with https:// and contains #."), icon: "xmark.octagon.fill")
                }
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.body.weight(.semibold))
            .foregroundStyle(Palette.text)
    }

    private func section<Content: View>(_ title: String, footer: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline.weight(.black))
                .foregroundStyle(Palette.text)
                .accessibilityAddTraits(.isHeader)
            content()
                .card()
            if let footer {
                Text(footer)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }
}

#Preview { SettingsView().environment(AppModel.shared) }
