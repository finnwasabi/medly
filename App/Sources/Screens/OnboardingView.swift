import SwiftUI

// Màn đầu tiên khi mở app: giải thích vì sao cần quyền báo thức rồi xin quyền.
struct OnboardingView: View {
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
            Button("Cho phép báo thức") {}
                .buttonStyle(PrimaryButtonStyle())
            Text("Bước 1 trên 3")
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

#Preview { OnboardingView() }
