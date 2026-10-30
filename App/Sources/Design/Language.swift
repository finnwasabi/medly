import Foundation
import PillotCore

/// The selected language. Stored in UserDefaults so any thread can read it (scheduling, App Intents).
nonisolated enum AppLanguage {
    static let key = "language"

    static var current: Language {
        UserDefaults.standard.string(forKey: key).flatMap(Language.init(rawValue:)) ?? .vi
    }

    /// Whether a language was chosen on first launch.
    static var isChosen: Bool { UserDefaults.standard.string(forKey: key) != nil }

    /// en_GB keeps pickers on the 24-hour clock used everywhere else in the app.
    static var locale: Locale { Locale(identifier: current == .en ? "en_GB" : "vi_VN") }
}

/// One sentence in both languages side by side, so no string can miss a translation.
nonisolated func L(_ vi: String, _ en: String) -> String {
    AppLanguage.current == .en ? en : vi
}

extension TimeFormatting {
    /// Vietnam time in the selected language: "21:00 giờ VN" or "21:00 VN time".
    nonisolated static func vn(_ date: Date) -> String {
        vietnamTime(date, language: AppLanguage.current)
    }
}
