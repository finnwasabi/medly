import AlarmKit
import SwiftUI
import UserNotifications

@main
struct NersDailyApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = AppModel.shared
    @State private var needsOnboarding = AlarmManager.shared.authorizationState == .notDetermined
    @State private var languageChosen = AppLanguage.isChosen
    @State private var profileDone = UserDefaults.standard.bool(forKey: "profileDone")

    private static let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = Self.notificationDelegate
        ReminderScheduler.registerCategory()
    }

    var body: some Scene {
        WindowGroup {
            launchScreen
                // Đổi ngôn ngữ thì dựng lại cả cây để mọi chữ L(...) đọc lại.
                .id(model.language)
                .environment(model)
                .environment(\.locale, AppLanguage.locale)
                .fontDesign(.rounded)
        }
        .onChange(of: scenePhase) { _, phase in
            // Mở app là nạp lại lịch nhắc cho đủ H ngày tới.
            if phase == .active { Task { await model.resync() } }
        }
    }

    // Tham số `-screen` chỉ dùng để chụp ảnh màn hình (language, profile, onboarding, history, settings).
    @ViewBuilder
    private var launchScreen: some View {
        switch UserDefaults.standard.string(forKey: "screen") {
        case "language": LanguageView { _ in }
        case "profile": ProfileView {}
        case "onboarding": OnboardingView {}
        case "history": RootView(selectedTab: 1)
        case "settings": RootView(selectedTab: 2)
        default:
            if !languageChosen {
                LanguageView { language in
                    model.language = language
                    languageChosen = true
                }
            } else if !profileDone {
                ProfileView {
                    UserDefaults.standard.set(true, forKey: "profileDone")
                    profileDone = true
                }
            } else if needsOnboarding {
                OnboardingView { needsOnboarding = false }
            } else {
                RootView()
            }
        }
    }
}
