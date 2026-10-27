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

            TimelineView(.periodic(from: .now, by: 15)) { context in
                BlockingStatusBanner(
                    block: store.isPro ? blocking.currentBlock(at: context.date) : nil,
                    now: context.date,
                    action: openBlocking
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 12)

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
                VStack(spacing: 0) {
                    Spacer()
                    Image(uiImage: BlockScreenStyle.mark(side: 64))
                    Text("Your life, in perspective")
                        .font(.geist(size: 26, weight: .bold))
                        .foregroundStyle(ScreenSpanAppearance.text)
                        .padding(.top, 24)
                    Text("Allow Screen Time access to see your life chart and recent iPhone activity.")
                        .font(.geist(size: 16))
                        .foregroundStyle(ScreenSpanAppearance.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                    if let message = authService.authorizationErrorMessage {
                        Text(message)
                            .font(.geist(size: 13))
                            .foregroundStyle(ScreenSpanAppearance.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.top, 12)
                    }
                    Spacer()
                    OnboardingPrimaryButton(title: "Allow Screen Time Access") {
                        Task { await authService.requestAuthorization() }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
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

/// A dedicated entry into blocking below the header, with the current state
/// and its end time kept separate from the dashboard's navigation controls.
private struct BlockingStatusBanner: View {
    let block: (end: Date, isFocus: Bool)?
    let now: Date
    let action: () -> Void

    private var title: String { block == nil ? "Apps unblocked" : "Apps blocked" }
    private var detail: String { block.map { Self.status($0, now: now) } ?? "Manage blocking" }
    private var foreground: Color {
        block == nil ? ScreenSpanAppearance.secondaryText : Color(hex: "#188253")
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: block == nil ? "shield" : "checkmark.shield")
                    .font(.system(size: 17, weight: .medium))
                    .accessibilityHidden(true)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        Text(title)
                            .font(.geist(size: 13, weight: .semibold))
                            .fixedSize()
                        Spacer(minLength: 0)
                        Text(detail)
                            .font(.geist(size: 12))
                            .fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.geist(size: 13, weight: .semibold))
                        Text(detail).font(.geist(size: 12))
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.65)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, minHeight: 49)
            .background(block == nil ? Color(hex: "#F4F6FA") : Color(hex: "#EDF7F1"),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(detail)")
        .accessibilityHint("Opens Blocking.")
    }

    /// "42m left" for a focus block, "Until 7:00 AM" for a schedule.
    private static func status(_ block: (end: Date, isFocus: Bool), now: Date) -> String {
        guard block.isFocus else { return "Until \(block.end.formatted(date: .omitted, time: .shortened))" }
        let minutes = max(Int((block.end.timeIntervalSince(now) / 60).rounded(.up)), 1)
        return minutes < 60 ? "\(minutes)m left" : "\(minutes / 60)h \(minutes % 60)m left"
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
