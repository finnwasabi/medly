import SwiftUI

/// The very first screen: light, dark or the phone's setting. Shown in both languages, since the language comes next.
/// Tapping a choice applies it at once, so the screen previews it.
struct ThemeView: View {
    var onFinish: () -> Void

    @Environment(AppModel.self) private var model

    var body: some View {
        FullScreenScroll {
            VStack(spacing: 24) {
                Spacer()
                IconBadge(icon: "circle.lefthalf.filled", fill: Palette.yellow, size: 112)
                    .rotationEffect(.degrees(-4))
                VStack(spacing: 8) {
                    Text("Chọn giao diện")
                        .font(.largeTitle.weight(.black))
                    Text("Pick a look")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Palette.textSecondary)
                }
                .foregroundStyle(Palette.text)
                VStack(spacing: 12) {
                    option(.light, "Sáng · Light", icon: "sun.max.fill", fill: Palette.yellow)
                    option(.dark, "Tối · Dark", icon: "moon.fill", fill: Palette.lavender)
                    option(.system, "Theo máy · System", icon: "iphone", fill: Palette.mint)
                }
                Spacer()
                Button("Tiếp tục · Continue", action: onFinish)
                    .buttonStyle(NeoButtonStyle())
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

    private func option(_ theme: AppTheme, _ title: String, icon: String, fill: Color) -> some View {
        let selected = model.theme == theme
        return Button { model.theme = theme } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3.weight(.bold))
                    .frame(width: 28)
                Text(title)
                    .font(.headline.weight(.heavy))
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.bold))
            }
            .foregroundStyle(Palette.onFill)
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .neo(selected ? fill : Palette.surfaceOnFill, radius: 14, shadow: selected ? 0 : Neo.shadow)
            .offset(x: selected ? Neo.shadow : 0, y: selected ? Neo.shadow : 0)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview { ThemeView {}.environment(AppModel.shared) }
