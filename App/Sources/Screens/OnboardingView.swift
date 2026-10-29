import AlarmKit
import SwiftUI
import UserNotifications

// Explains why alarm permission is needed, then asks for it.
struct OnboardingView: View {
    var onFinish: () -> Void

    @Environment(AppModel.self) private var model
    @State private var asking = false

    var body: some View {
        FullScreenScroll {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "alarm.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Palette.primary)
                    .frame(width: 128, height: 128)
                    .background(Palette.primarySoft, in: Circle())
                VStack(spacing: 12) {
                    Text(L("Nhắc uống thuốc đúng giờ", "Take your pill on time"))
                        .font(.title.bold())
                        .foregroundStyle(Palette.text)
                        .multilineTextAlignment(.center)
                    Text(L("Ner's Daily đặt báo thức theo giờ Việt Nam, kêu cả khi máy đang im lặng hay bật Focus.", "Ner's Daily sets alarms on Vietnam time that ring even when the phone is on silent or in Focus."))
                        .font(.body)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                }
                VStack(alignment: .leading, spacing: 14) {
                    point(icon: "globe.asia.australia.fill", text: L("Bay đi đâu cũng nhắc đúng giờ VN", "On Vietnam time wherever you fly"))
                    point(icon: "bell.and.waves.left.and.right.fill", text: L("Nhắc lại tới khi bạn bấm Đã uống", "Keeps reminding until you tap Taken"))
                    point(icon: "airplane", text: L("Không cần mạng, chế độ máy bay vẫn nhắc", "No internet needed, works in airplane mode"))
                }
                .card()
                Spacer()
                Button(L("Cho phép báo thức", "Allow alarms")) {
                    asking = true
                    Task {
                        // Declining still lets the user in; Today then shows the scheduling warning.
                        _ = try? await AlarmManager.shared.requestAuthorization()
                        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                        await model.resync()
                        onFinish()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(asking)
                Text(L("Máy sẽ hỏi hai lần: báo thức và thông báo.", "Your phone asks twice: alarms and notifications."))
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Palette.background)
    }

    private func point(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Palette.primary)
                .frame(width: 28)
            Text(text)
                .font(.body)
                .foregroundStyle(Palette.text)
        }
    }
}

#Preview { OnboardingView {}.environment(AppModel.shared) }
