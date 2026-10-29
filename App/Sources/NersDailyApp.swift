import AlarmKit
import SwiftUI
import UserNotifications

@main
struct NersDailyApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = AppModel.shared
    @State private var needsOnboarding = AlarmManager.shared.authorizationState == .notDetermined

    private static let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = Self.notificationDelegate
        ReminderScheduler.registerCategory()
    }

    var body: some Scene {
        WindowGroup {
            launchScreen
                .environment(model)
                .fontDesign(.rounded)
        }
        .onChange(of: scenePhase) { _, phase in
            // Mở app là nạp lại lịch nhắc cho đủ H ngày tới.
            if phase == .active { Task { await model.resync() } }
        }
    }

    // Tham số `-screen` chỉ dùng để chụp ảnh màn hình (history, settings, onboarding).
    @ViewBuilder
    private var launchScreen: some View {
        switch UserDefaults.standard.string(forKey: "screen") {
        case "onboarding": OnboardingView {}
        case "history": RootView(selectedTab: 1)
        case "settings": RootView(selectedTab: 2)
        default:
            if needsOnboarding {
                OnboardingView { needsOnboarding = false }
            } else {
                RootView()
            }
        }
    }
}
