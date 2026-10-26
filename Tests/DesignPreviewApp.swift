import SwiftUI
@main
struct PreviewApp: App {
    @State private var onboardingPage = 0
    init() {
        AppGroupManager.shared.currentAge = 25
        AppGroupManager.shared.targetAge = 80
        AppGroupManager.shared.screenTimeGoalMinutes = 120
        AppGroupManager.shared.estimatedDailyMinutes = 150
        AppGroupManager.shared.timeIntentions = [.read, .language, .family]
        AppGroupManager.shared.trackingStartDate = Calendar.current.date(byAdding: .day, value: -21, to: Date())
    }
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 0) {
                Text("DESIGN PREVIEW · SAMPLE DATA").font(.caption2)
                    .foregroundStyle(ScreenSpanAppearance.text).padding(8)
                if CommandLine.arguments.contains("--shield") {
                    ShieldPreview()
                } else if CommandLine.arguments.contains("--onboarding") {
                    if onboardingPage < OnboardingRevealPanels.panelCount {
                        GeometryReader { proxy in
                            OnboardingReportWindow(
                                contentHeight: OnboardingRevealLayout.totalHeight(panelHeight: proxy.size.height),
                                offset: OnboardingRevealLayout.panelOffset(onboardingPage, panelHeight: proxy.size.height)
                            ) {
                                OnboardingOverviewReportView(payload: fixture)
                            }
                        }
                        Button("Continue") {
                            onboardingPage += 1
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    } else {
                        Text("Goal setting reached").foregroundStyle(ScreenSpanAppearance.text)
                        Spacer()
                    }
                } else {
                    DashboardReportView(payload: fixture)
                }
            }
            .background(Color.white)
            .preferredColorScheme(CommandLine.arguments.contains("--dark") ? .dark : .light)
        }
    }
    /// Seven sample days before a start 21 days ago, then a gradual decline.
    var fixture: ScreenTimeReportPayload {
        let today = Calendar.current.startOfDay(for: Date())
        let hours = [5.4, 4.8, 5.9, 5.1, 4.6, 5.3, 4.9,
                     4.7, 4.1, 4.9, 3.8, 4.2, 3.5, 4.0, 3.6, 3.1, 3.9, 3.3, 2.9, 3.4,
                     3.0, 2.6, 3.2, 2.4, 2.8, 3.1, 2.5, 2.7]
        let history = hours.enumerated().map {
            ActivityDay(date: Calendar.current.date(byAdding: .day, value: $0.offset - hours.count, to: today)!, hours: $0.element)
        }
        let days = history.within(ActivitySummary.projectionInterval())
        let apps = [("Instagram", 0.9), ("Safari", 0.45), ("Messages", 0.35), ("YouTube", 0.3), ("Mail", 0.15)]
            .map { AppUsage(application: nil, fallbackName: $0.0, dailyHours: $0.1) }
        return ScreenTimeReportPayload(dailyAverageHours: ActivityDay.averageHours(of: days), days: days, history: history,
                                       topApps: apps, pickupsPerDay: 84)
    }
}

/// A stand-in for the system shield, laid out the way iOS draws one, with the
/// shield extension's real copy and mark. Real shields only show on a device.
/// Tap to step through the block reasons.
struct ShieldPreview: View {
    @State private var index = 0

    var body: some View {
        let now = Date()
        let reasons: [(String?, BlockReason)] = [
            ("LinkedIn", .focus(until: now.addingTimeInterval(14 * 60))),
            ("Instagram", .schedule(name: "Work hours", until: now.addingTimeInterval(3 * 60 * 60))),
            ("TikTok", .limit(minutes: 30)),
            (nil, .unknown),
        ]
        let reason = reasons[index % reasons.count]
        let copy = BlockScreenCopy(appName: reason.0, reason: reason.1, intentions: AppGroupManager.shared.timeIntentions,
                                   now: now, nudge: { $0[index % $0.count] })
        VStack(spacing: 0) {
            Spacer()
            Image(uiImage: BlockScreenStyle.mark())
            Text(copy.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(BlockScreenStyle.navy))
                .padding(.top, 20)
            Text(copy.subtitle)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(BlockScreenStyle.slate))
                .padding(.top, 6)
            Spacer()
            Text(copy.button)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color(BlockScreenStyle.navy), in: Capsule())
                .padding(.horizontal, 8)
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(BlockScreenStyle.background))
        .contentShape(Rectangle())
        .onTapGesture { index += 1 }
    }
}
