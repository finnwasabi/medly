import SwiftUI

/// First launch, after the language: asks for the user's name, then offers to add a partner (skippable).
struct ProfileView: View {
    var onFinish: () -> Void

    @Environment(AppModel.self) private var model
    @State private var step = 0
    @State private var name = ""
    @State private var partner = ""
    @State private var code = ""
    @State private var badCode = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: step == 0 ? "person.crop.circle.fill" : "heart.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Palette.primary)
                .frame(width: 120, height: 120)
                .background(Palette.primarySoft, in: Circle())
            if step == 0 { nameStep } else { partnerStep }
            Spacer()
            buttons
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .background(Palette.background)
        .onAppear { focused = true }
    }

    private var nameStep: some View {
        VStack(spacing: 12) {
            Text(L("Bạn tên gì?", "What's your name?"))
                .font(.title.bold())
                .foregroundStyle(Palette.text)
                .multilineTextAlignment(.center)
            Text(L("App dùng tên này để chào bạn.", "The app uses it to greet you."))
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
            field(L("Tên bạn", "Your name"), text: $name)
                .textContentType(.givenName)
                .focused($focused)
                .submitLabel(.next)
                .onSubmit(next)
        }
    }

    private var partnerStep: some View {
        VStack(spacing: 12) {
            Text(L("Thêm partner theo dõi cùng?", "Add a partner to follow along?"))
                .font(.title.bold())
                .foregroundStyle(Palette.text)
                .multilineTextAlignment(.center)
            Text(L("Partner xem được bạn đã uống chưa qua Telegram và gửi lời nhắn vào app. Để sau cũng được, trong Cài đặt.",
                   "Your partner can see on Telegram whether you have taken your pill and send you messages in the app. You can also do this later in Settings."))
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
            field(L("Tên partner", "Partner's name"), text: $partner)
                .focused($focused)
            field(L("Mã kết nối partner gửi (nếu có)", "Connection code from your partner (if any)"), text: $code)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if badCode {
                Text(L("Mã không đúng dạng. Mã bắt đầu bằng https:// và có dấu #.", "Invalid code. It starts with https:// and contains #."))
                    .font(.footnote)
                    .foregroundStyle(DoseStatus.missed.foreground)
            }
        }
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .font(.body)
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.border))
    }

    @ViewBuilder
    private var buttons: some View {
        if step == 0 {
            Button(L("Tiếp tục", "Continue"), action: next)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        } else {
            Button(L("Lưu", "Save")) {
                Task {
                    model.partnerName = partner.trimmingCharacters(in: .whitespaces)
                    if !code.isEmpty {
                        guard await model.connect(code: code) else { badCode = true; return }
                    }
                    onFinish()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(partner.trimmingCharacters(in: .whitespaces).isEmpty && code.isEmpty)
            Button(L("Bỏ qua", "Skip"), action: onFinish)
                .buttonStyle(SecondaryButtonStyle())
        }
    }

    private func next() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        model.userName = trimmed
        step = 1
        focused = true
    }
}

#Preview { ProfileView {}.environment(AppModel.shared) }
