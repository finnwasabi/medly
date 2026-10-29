import NersCore
import SwiftUI

/// The very first screen: pick a language. Written in both languages since we do not know which one the user reads yet.
struct LanguageView: View {
    var onChoose: (Language) -> Void

    var body: some View {
        FullScreenScroll {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "globe")
                    .font(.system(size: 56))
                    .foregroundStyle(Palette.primary)
                    .frame(width: 120, height: 120)
                    .background(Palette.primarySoft, in: Circle())
                VStack(spacing: 8) {
                    Text("Chọn ngôn ngữ")
                        .font(.title.bold())
                    Text("Choose your language")
                        .font(.title3)
                        .foregroundStyle(Palette.textSecondary)
                }
                .foregroundStyle(Palette.text)
                Spacer()
                Button("Tiếng Việt") { onChoose(.vi) }
                    .buttonStyle(PrimaryButtonStyle())
                Button("English") { onChoose(.en) }
                    .buttonStyle(SecondaryButtonStyle())
                Text("Đổi được trong Cài đặt. You can change it in Settings.")
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Palette.background)
    }
}

#Preview { LanguageView { _ in } }
