import SwiftUI

/// Main tab view showing all app sections
struct MainTabView: View {
    @State private var selectedTab: MainTab = .lifeGrid

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            currentTabView
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            tabBar
        }
    }

    @ViewBuilder
    private var currentTabView: some View {
        switch selectedTab {
        case .lifeGrid:
            ChartTabView()
        case .stats:
            StatsTabView()
        case .progress:
            HistoryTabView()
        case .settings:
            SettingsView()
        }
    }

    private var tabBar: some View {
        HStack(alignment: .bottom, spacing: 18) {
            HStack(spacing: 6) {
                tabButton(for: .lifeGrid, title: "Life Grid", systemImage: "waveform.path.ecg.rectangle")
                tabButton(for: .stats, title: "Stats", systemImage: "clock")
                tabButton(for: .progress, title: "Progress", systemImage: "chart.line.uptrend.xyaxis")
            }
            .padding(8)
            .background(Color(hex: "#F0F2F6"))
            .clipShape(Capsule())

            Button {
                selectedTab = .settings
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(selectedTab == .settings ? .white : Color(hex: "#5E5E5E"))
                    .frame(width: 62, height: 62)
                    .background(selectedTab == .settings ? Color(hex: "#102847") : Color(hex: "#F0F2F6"))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(Color.white)
    }

    private func tabButton(for tab: MainTab, title: String, systemImage: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .medium))

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(selectedTab == tab ? .white : Color(hex: "#5E5E5E"))
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(selectedTab == tab ? Color(hex: "#102847") : Color.clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private enum MainTab {
    case lifeGrid
    case stats
    case progress
    case settings
}
