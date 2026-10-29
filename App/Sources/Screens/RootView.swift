import SwiftUI

struct RootView: View {
    var todayState: MockTodayState = .upcoming
    var selectedTab = 0

    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            Tab("Hôm nay", systemImage: "sun.max.fill", value: 0) { TodayView(state: todayState) }
            Tab("Lịch sử", systemImage: "calendar", value: 1) { HistoryView() }
            Tab("Cài đặt", systemImage: "gearshape.fill", value: 2) { SettingsView() }
        }
        .tint(Palette.primary)
        .onAppear { tab = selectedTab }
    }
}
