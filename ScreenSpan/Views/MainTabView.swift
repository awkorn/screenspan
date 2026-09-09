import DeviceActivity
import SwiftUI

/// One stable report hosts the three dashboard pages. Settings stays in the
/// app, and presenting it does not unmount the report. No usage crosses back.
struct MainTabView: View {
    @EnvironmentObject private var authService: AuthorizationService
    @Environment(\.scenePhase) private var scenePhase
    @State private var filter = DeviceActivityFilter.screenSpanProjectionAverage
    @State private var reportID = UUID()
    @State private var reportDay = Calendar.current.startOfDay(for: Date())
    @State private var showSettings = false
    @State private var showHelp = false
    @State private var settingsBeforePresentation = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ScreenSpan").font(.geist(size: 21, weight: .bold))
                Spacer()
                Button("Refresh", systemImage: "arrow.clockwise", action: refresh)
                    .labelStyle(.iconOnly)
                    .disabled(!authService.isAuthorized)
                Button("Report help", systemImage: "questionmark.circle") { showHelp = true }
                    .labelStyle(.iconOnly)
                    .padding(.horizontal, 12)
                Button("Settings", systemImage: "ellipsis") {
                    settingsBeforePresentation = settingsSignature
                    showSettings = true
                }
                .labelStyle(.iconOnly)
            }
            .foregroundStyle(Color(hex: "#0A1F38"))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            if authService.isAuthorized {
                ZStack {
                    ReportLoadingPlaceholder()
                    DeviceActivityReport(.dashboard, filter: filter)
                        .id(reportID)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 18) {
                    Image(systemName: "chart.bar.xaxis").font(.system(size: 38))
                    Text("Your life, in perspective").font(.geist(size: 26, weight: .bold))
                    Text("Allow Screen Time access to see your life chart and recent iPhone activity.")
                        .multilineTextAlignment(.center)
                    Button("Allow Screen Time Access") {
                        Task { await authService.requestAuthorization() }
                    }
                    .buttonStyle(.borderedProminent)
                    if let message = authService.authorizationErrorMessage {
                        Text(message).font(.footnote).foregroundStyle(ScreenSpanAppearance.secondaryText)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .sheet(isPresented: $showSettings, onDismiss: {
            if settingsBeforePresentation != settingsSignature { refresh() }
        }) {
            SettingsView()
        }
        .alert("Waiting for Screen Time?", isPresented: $showHelp) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("iOS prepares your activity privately, and the first report can take a while. Once it appears, all three tabs use the same report. If it remains blank, try Refresh once or check Screen Time access in Settings. Settings remains available while you wait.")
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            authService.refreshAuthorizationStatus()
            if reportDay != Calendar.current.startOfDay(for: Date()) { refresh() }
        }
    }

    private var settingsSignature: String {
        let settings = AppGroupManager.shared
        return "\(settings.currentAge)|\(settings.targetAge)|\(settings.screenTimeGoalMinutes)"
    }

    private func refresh() {
        reportDay = Calendar.current.startOfDay(for: Date())
        filter = .screenSpanProjectionAverage
        reportID = UUID()
    }
}

struct ReportLoadingPlaceholder: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
            Text("Preparing your Screen Time report")
                .font(.geist(size: 21, weight: .semibold))
            Text("Your life chart, stats, and progress will appear here. The first report may take a moment.")
                .font(.geist(size: 15))
                .foregroundStyle(ScreenSpanAppearance.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}
