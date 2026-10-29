import SwiftUI

@main
struct NersDailyApp: App {
    var body: some Scene {
        WindowGroup {
            launchScreen
                .fontDesign(.rounded)
        }
    }

    // Tham số `-screen` chỉ dùng để chụp mockup P2 (today, taken, overdue, history, settings, onboarding).
    @ViewBuilder
    private var launchScreen: some View {
        switch UserDefaults.standard.string(forKey: "screen") {
        case "onboarding": OnboardingView()
        case "taken": RootView(todayState: .taken)
        case "overdue": RootView(todayState: .overdue)
        case "history": RootView(selectedTab: 1)
        case "settings": RootView(selectedTab: 2)
        default: RootView()
        }
    }
}
