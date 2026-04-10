import SwiftUI

/// Main tab view showing all app sections
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            StatsTabView()
                .tabItem {
                    Label("Stats", systemImage: "chart.pie")
                }
                .tag(0)

            ChartTabView()
                .tabItem {
                    Label("Life Grid", systemImage: "square.grid.2x2")
                }
                .tag(1)

            HistoryTabView()
                .tabItem {
                    Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
    }
}
