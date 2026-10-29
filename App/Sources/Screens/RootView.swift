import SwiftUI

struct RootView: View {
    /// Opens on this tab (screenshots). `nil` keeps the last one.
    var selectedTab: Int?

    // SceneStorage keeps the tab when a language change rebuilds the tree.
    @SceneStorage("tab") private var tab = 0

    private var tabs: [(title: String, icon: String)] {
        [(L("Hôm nay", "Today"), "sun.max.fill"), (L("Thuốc", "Meds"), "pills.fill"),
         (L("Lịch sử", "History"), "calendar"), (L("Cài đặt", "Settings"), "gearshape.fill")]
    }

    var body: some View {
        Group {
            switch tab {
            case 1: MedsView()
            case 2: HistoryView()
            case 3: SettingsView()
            default: TodayView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
        .onAppear { if let selectedTab { tab = selectedTab } }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(tabs.indices, id: \.self) { index in
                let selected = tab == index
                Button { tab = index } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tabs[index].icon)
                            .font(.system(size: 18, weight: .bold))
                        Text(tabs[index].title)
                            .font(.caption2.weight(.heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(selected ? Palette.onFill : Palette.text)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(selected ? Palette.yellow : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        if selected { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(6)
        .neo(Palette.surface, radius: 20)
        // Four labels in a fixed bar cannot grow forever.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(Palette.background.ignoresSafeArea(edges: .bottom))
        .sensoryFeedback(.selection, trigger: tab)
    }
}
