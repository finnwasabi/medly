import AlarmKit
import SwiftUI
import UserNotifications

// Màn đầu tiên khi mở app: giải thích vì sao cần quyền báo thức rồi xin quyền.
struct OnboardingView: View {
    var onFinish: () -> Void

    @Environment(AppModel.self) private var model
    @State private var asking = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "alarm.fill")
                .font(.system(size: 64))
                .foregroundStyle(Palette.primary)
                .frame(width: 128, height: 128)
                .background(Palette.primarySoft, in: Circle())
            VStack(spacing: 12) {
                Text("Nhắc uống thuốc đúng giờ")
                    .font(.title.bold())
                    .foregroundStyle(Palette.text)
                    .multilineTextAlignment(.center)
                Text("Ner's Daily đặt báo thức theo giờ Việt Nam, kêu cả khi máy đang im lặng hay bật Focus.")
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 14) {
                point(icon: "globe.asia.australia.fill", text: "Bay đi đâu cũng nhắc đúng giờ VN")
                point(icon: "bell.and.waves.left.and.right.fill", text: "Nhắc lại tới khi bạn bấm Đã uống")
                point(icon: "airplane", text: "Không cần mạng, chế độ máy bay vẫn nhắc")
            }
            .card()
            Spacer()
            Button("Cho phép báo thức") {
                asking = true
                Task {
                    // Từ chối vẫn cho vào app; màn Hôm nay sẽ báo lỗi hẹn nhắc.
                    _ = try? await AlarmManager.shared.requestAuthorization()
                    _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                    await model.resync()
                    onFinish()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(asking)
            Text("Máy sẽ hỏi hai lần: báo thức và thông báo.")
                .font(.footnote)
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
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
