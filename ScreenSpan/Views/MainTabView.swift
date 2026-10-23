import DeviceActivity
import SwiftUI

/// One stable report hosts the three dashboard pages. Settings stays in the
/// app, and presenting it does not unmount the report. No usage crosses back.
struct MainTabView: View {
    @EnvironmentObject private var authService: AuthorizationService
    @EnvironmentObject private var store: StoreKitService
    @EnvironmentObject private var blocking: BlockingService
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SharedConstants.UserDefaultsKey.pendingBlockingSetup.rawValue, store: .appGroup)
    private var pendingBlockingSetup = false
    @AppStorage(SharedConstants.UserDefaultsKey.dashboardBottomInset.rawValue, store: .appGroup)
    private var reportBottomInset = 0.0
    @State private var filter = DeviceActivityFilter.screenSpanDashboard
    @State private var reportID = UUID()
    @State private var reportDay = Calendar.current.startOfDay(for: Date())
    @State private var showSettings = false
    @State private var showHelp = false
    @State private var settingsBeforePresentation = ""
    @State private var showBlocking = false
    @State private var blockingOpensPicker = false
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ScreenSpan").font(.geist(size: 21, weight: .bold))
                Spacer()
                BlockButton(isPro: store.isPro, action: openBlocking)
                    .padding(.trailing, 14)
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
                // Pages scroll to the screen's edge behind the report's tab bar.
                .ignoresSafeArea(.container, edges: .bottom)
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
        .background {
            // The report may not receive the host's safe area, so tell it how
            // far the home indicator reaches.
            GeometryReader { proxy in
                Color.clear
                    .onAppear { reportBottomInset = proxy.safeAreaInsets.bottom }
                    .onChange(of: proxy.safeAreaInsets.bottom) { _, inset in reportBottomInset = inset }
            }
        }
        .sheet(isPresented: $showSettings, onDismiss: {
            if settingsBeforePresentation != settingsSignature { refresh() }
        }) {
            SettingsView()
        }
        .sheet(isPresented: $showBlocking, onDismiss: { blockingOpensPicker = false }) {
            BlockingView(opensPickerOnAppear: blockingOpensPicker)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView { purchased in
                showPaywall = false
                guard purchased else { return }
                // Go straight to choosing apps once the cover has closed.
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    blockingOpensPicker = true
                    showBlocking = true
                }
            }
        }
        .alert("Waiting for Screen Time?", isPresented: $showHelp) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("iOS prepares your activity privately, and the first report can take a while. Once it appears, all three tabs use the same report. If it remains blank, try Refresh once or check Screen Time access in Settings. Settings remains available while you wait.")
        }
        .onAppear {
            // Backfilling today matches the filter already built without a start date.
            AppGroupManager.shared.ensureTrackingStartDate()
            if pendingBlockingSetup, store.isPro {
                pendingBlockingSetup = false
                blockingOpensPicker = true
                showBlocking = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            authService.refreshAuthorizationStatus()
            blocking.reconcile()
            if reportDay != Calendar.current.startOfDay(for: Date()) { refresh() }
        }
    }

    private var settingsSignature: String {
        let settings = AppGroupManager.shared
        let start = settings.trackingStartDate.map { Calendar.current.startOfDay(for: $0).timeIntervalSince1970 } ?? 0
        return "\(settings.currentAge)|\(settings.targetAge)|\(settings.screenTimeGoalMinutes)|\(start)|\(settings.startingDailyMinutes)"
    }

    private func openBlocking() {
        if store.isPro { showBlocking = true } else { showPaywall = true }
    }

    private func refresh() {
        reportDay = Calendar.current.startOfDay(for: Date())
        filter = .screenSpanDashboard
        reportID = UUID()
    }
}

/// The header's way into blocking. It shows when a block is running, so the
/// dashboard says at a glance whether apps are locked right now.
private struct BlockButton: View {
    let isPro: Bool
    let action: () -> Void
    @EnvironmentObject private var blocking: BlockingService

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            let isBlocking = isPro && blocking.isBlocking(at: context.date)
            Button(action: action) {
                Label(isBlocking ? "Blocking" : "Block", systemImage: isBlocking ? "lock.fill" : "lock.open")
                    .font(.geist(size: 14, weight: .semibold))
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(isBlocking ? Color(hex: "#1E8A55") : .white)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(isBlocking ? Color(hex: "#E3F5EB") : Color(hex: "#0A1F38"), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isBlocking ? "Apps are blocked right now. Opens Blocking." : "Opens Blocking.")
        }
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
