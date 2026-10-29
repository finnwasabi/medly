import Foundation
import NersCore

/// Ngôn ngữ đang chọn. Lưu trong UserDefaults nên đọc được từ mọi luồng (lịch nhắc, App Intent).
nonisolated enum AppLanguage {
    static let key = "language"

    static var current: Language {
        UserDefaults.standard.string(forKey: key).flatMap(Language.init(rawValue:)) ?? .vi
    }

    /// Đã chọn ngôn ngữ ở lần mở app đầu tiên chưa.
    static var isChosen: Bool { UserDefaults.standard.string(forKey: key) != nil }

    /// en_GB để giờ hiện 24 giờ giống mọi chỗ khác trong app.
    static var locale: Locale { Locale(identifier: current == .en ? "en_GB" : "vi_VN") }
}

/// Một câu hai thứ tiếng viết cạnh nhau, để không câu nào thiếu bản dịch.
nonisolated func L(_ vi: String, _ en: String) -> String {
    AppLanguage.current == .en ? en : vi
}

extension TimeFormatting {
    /// Giờ VN theo ngôn ngữ đang chọn: "21:00 giờ VN" hoặc "21:00 VN time".
    nonisolated static func vn(_ date: Date) -> String {
        vietnamTime(date, language: AppLanguage.current)
    }
}
