import MedlyCore
import SwiftUI

/// The very first screen: pick a language. Written in both languages since we do not know which one the user reads yet.
struct LanguageView: View {
    var onChoose: (Language) -> Void

    var body: some View {
        FullScreenScroll {
            VStack(spacing: 24) {
                Spacer()
                IconBadge(icon: "globe.asia.australia.fill", fill: Palette.sky, size: 112)
                    .rotationEffect(.degrees(-4))
                VStack(spacing: 8) {
                    Text("Chọn ngôn ngữ")
                        .font(.largeTitle.weight(.black))
                    Text("Choose your language")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Palette.textSecondary)
                }
                .foregroundStyle(Palette.text)
                Spacer()
                Button("Tiếng Việt") { onChoose(.vi) }
                    .buttonStyle(NeoButtonStyle())
                Button("English") { onChoose(.en) }
                    .buttonStyle(NeoButtonStyle(fill: Palette.yellow))
                Text("Đổi được trong Cài đặt. You can change it in Settings.")
                    .font(.footnote.weight(.medium))
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
