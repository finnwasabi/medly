import SwiftUI

struct RootView: View {
    var selectedTab = 0

    // SceneStorage để đổi ngôn ngữ (dựng lại cả cây) không nhảy về tab đầu.
    @SceneStorage("tab") private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            Tab(L("Hôm nay", "Today"), systemImage: "sun.max.fill", value: 0) { TodayView() }
            Tab(L("Lịch sử", "History"), systemImage: "calendar", value: 1) { HistoryView() }
            Tab(L("Cài đặt", "Settings"), systemImage: "gearshape.fill", value: 2) { SettingsView() }
        }
        .tint(Palette.primary)
        .onAppear { if selectedTab != 0 { tab = selectedTab } }
    }
}
