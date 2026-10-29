import SwiftUI
import UIKit

// Bảng màu 3 tầng: một màu chính (hồng đất), một dải xám ấm, các màu trạng thái dịu.
// Mỗi màu có bản sáng và bản tối, chữ trên nền đều đạt WCAG AA.
enum Palette {
    static let primary = Color(light: 0xC8435E, dark: 0xF07A92)
    static let onPrimary = Color(light: 0xFFFFFF, dark: 0x2A0F17)
    static let primarySoft = Color(light: 0xFBE6EA, dark: 0x3A1E27)

    static let background = Color(light: 0xFBF6F3, dark: 0x17121A)
    static let surface = Color(light: 0xFFFFFF, dark: 0x241D26)
    static let border = Color(light: 0xEADFDA, dark: 0x3A3039)
    static let text = Color(light: 0x2B2226, dark: 0xF5EEF0)
    static let textSecondary = Color(light: 0x6E6166, dark: 0xB8AAB0)
}

// Trạng thái một lần uống. Màu cố định: xanh lá = đã uống, vàng = trễ, đỏ = hụt, xám = tạm dừng.
// Luôn đi kèm chữ và biểu tượng, không dùng màu một mình.
enum DoseStatus {
    case taken, late, missed, paused, upcoming

    var label: String {
        switch self {
        case .taken: "Đã uống"
        case .late: "Uống trễ"
        case .missed: "Hụt"
        case .paused: "Tạm dừng"
        case .upcoming: "Sắp tới"
        }
    }

    var icon: String {
        switch self {
        case .taken: "checkmark.circle.fill"
        case .late: "clock.badge.exclamationmark.fill"
        case .missed: "xmark.circle.fill"
        case .paused: "pause.circle.fill"
        case .upcoming: "circle.dotted"
        }
    }

    var background: Color {
        switch self {
        case .taken: Color(light: 0xE3F3E9, dark: 0x1E3A2A)
        case .late: Color(light: 0xFFF1D6, dark: 0x3D2F12)
        case .missed: Color(light: 0xFDE4E4, dark: 0x42191C)
        case .paused, .upcoming: Color(light: 0xEEE9E7, dark: 0x2E2730)
        }
    }

    var foreground: Color {
        switch self {
        case .taken: Color(light: 0x1F6B41, dark: 0x8FD9AE)
        case .late: Color(light: 0x8A5A00, dark: 0xF2C46B)
        case .missed: Color(light: 0xA8282E, dark: 0xF39A9E)
        case .paused, .upcoming: Color(light: 0x5F5559, dark: 0xC9BEC3)
        }
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
    }
}

struct StatusPill: View {
    let status: DoseStatus

    var body: some View {
        Label(status.label, systemImage: status.icon)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(status.foreground)
            .background(status.background, in: Capsule())
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.border))
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.bold))
            .frame(maxWidth: .infinity, minHeight: 60)
            .foregroundStyle(Palette.onPrimary)
            .background(Palette.primary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(Palette.primary)
            .background(Palette.primarySoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
