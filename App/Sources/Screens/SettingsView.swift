import MedlyCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmDisconnect = false
    @State private var code = ""
    @State private var badCode = false
    @State private var exporting: BackupDocument?
    @State private var importing = false
    @State private var pendingRestore: Backup?
    @State private var backupIssue: String?

    var body: some View {
        @Bindable var model = model
        Group {
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
                                NeoStepper(value: $model.snoozeMinutes, range: AppModel.snoozeRange, unit: L("phút", "min"))
                            }
                            Callout(text: L("Hoãn bao nhiêu lần cũng được, nhưng chỉ bấm Đã uống hoặc Bỏ qua lần này mới tắt hẳn. Chưa uống thì app nhắc lại 3 lần mỗi 5 phút, rồi mỗi giờ, rồi dồn dập trước hạn chót.",
                                            "Snooze as often as you like, but only Taken or Skip this dose stops it for good. Until then the app repeats 3 times every 5 minutes, then hourly, then faster before the deadline."),
                                    icon: "bell.and.waves.left.and.right.fill", fill: Palette.lavender)
                        }
                    }

                    section(L("Theo dõi cùng", "Shared tracking"), footer: L("Khi có mạng, app gửi trạng thái mới nhất để \(model.partner) xem qua Telegram. Không có mạng thì vẫn nhắc bình thường. Mã kết nối lấy bằng lệnh /link của bot.", "When online, the app sends the latest status so \(model.partner) can follow it on Telegram. Offline, reminders work as usual. Get the connection code with the bot's /link command.")) {
                        sharing
                    }

                    section(L("Sao lưu", "Backup"), footer: L("Dữ liệu chỉ nằm trên máy này. Lưu file sao lưu vào iCloud Drive, Google Drive hay gửi cho chính mình, để đổi máy hay cài lại vẫn còn lịch sử. Mã kết nối không nằm trong file.",
                                                             "Your data lives only on this phone. Save the backup to iCloud Drive, Google Drive or send it to yourself, so a new phone or a reinstall keeps your history. The connection code is not in the file.")) {
                        backup
                    }

                    section(L("Ứng dụng", "App")) {
                        VStack(alignment: .leading, spacing: 14) {
                            label(L("Giao diện", "Appearance"))
                            NeoSegmented(options: [(AppTheme.system, L("Theo máy", "System")), (AppTheme.light, L("Sáng", "Light")), (AppTheme.dark, L("Tối", "Dark"))],
                                         selection: $model.theme)
                            InkDivider()
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
            .fileExporter(isPresented: Binding(get: { exporting != nil }, set: { if !$0 { exporting = nil } }), document: exporting,
                          contentType: .json, defaultFilename: Backup.fileName(at: .now)) { result in
                switch result {
                case .success: model.backupSaved()
                case .failure(let error): backupIssue = L("Không lưu được: \(error.localizedDescription)", "Could not save: \(error.localizedDescription)")
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    pendingRestore = try Backup.read(Data(contentsOf: url))
                    backupIssue = nil
                } catch Backup.Failure.tooNew {
                    backupIssue = L("File này do bản Medly mới hơn tạo. Cập nhật app rồi thử lại.", "This file is from a newer Medly. Update the app and try again.")
                } catch {
                    backupIssue = L("Không đọc được file này. Chọn file sao lưu của Medly (.json).", "Could not read this file. Pick a Medly backup (.json).")
                }
            }
            .alert(L("Khôi phục bản sao lưu?", "Restore this backup?"), isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
                   presenting: pendingRestore) { backup in
                Button(L("Thay bằng bản sao lưu", "Replace with the backup"), role: .destructive) { model.restore(backup) }
                Button(L("Huỷ", "Cancel"), role: .cancel) {}
            } message: { backup in
                let when = backup.createdAt == .distantPast ? "" : L(" ngày \(TodayText.dayTitle(backup.createdAt))", " from \(TodayText.dayTitle(backup.createdAt))")
                Text(L("Bản sao lưu\(when) có \(backup.medications.count) thuốc. Toàn bộ thuốc và lịch sử hiện tại trên máy sẽ bị thay thế.",
                       "The backup\(when) has \(backup.medications.count) medications. Every medication and all history on this phone is replaced."))
            }
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

    @ViewBuilder
    private var backup: some View {
        VStack(alignment: .leading, spacing: 12) {
            NeoRow(title: L("Lần sao lưu gần nhất", "Last backup"),
                   detail: model.lastBackup.map { "\(TodayText.dayTitle($0)), \(TimeFormatting.vn($0))" } ?? L("chưa có", "never")) { EmptyView() }
            if !model.medications.isEmpty, (model.lastBackup.map { Date.now.timeIntervalSince($0) > 30 * 24 * 3600 } ?? true) {
                Callout(text: L("Lâu rồi chưa sao lưu. Lưu một bản để khỏi mất lịch sử.", "No recent backup. Save one so your history is safe."),
                        icon: "externaldrive.badge.exclamationmark", fill: Palette.yellow)
            }
            if let backupIssue { Callout(text: backupIssue, icon: "xmark.octagon.fill") }
            Button { exporting = BackupDocument(data: (try? model.makeBackup().data()) ?? Data()) } label: {
                Label(L("Lưu bản sao lưu", "Save a backup"), systemImage: "square.and.arrow.up")
            }
            .buttonStyle(NeoButtonStyle(fill: Palette.mint, large: false))
            Button { importing = true } label: {
                Label(L("Khôi phục từ file", "Restore from a file"), systemImage: "square.and.arrow.down")
            }
            .buttonStyle(NeoButtonStyle(fill: Palette.surfaceOnFill, large: false))
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

/// The backup as a file for the system's save panel.
struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
