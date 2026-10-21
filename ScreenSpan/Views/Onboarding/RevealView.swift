import DeviceActivity
import SwiftUI

/// Five reveal panels. With Screen Time access they are one report rendered by
/// the extension (the host only moves the viewport); in estimate mode the host
/// renders the same panels from the user's own guess.
struct RevealView: View {
    var viewModel: OnboardingViewModel
    @State private var filter = DeviceActivityFilter.screenSpanProjectionAverage
    @State private var showsEstimateFallback = false

    private var isLastPanel: Bool { viewModel.revealPanel == OnboardingRevealPanels.panelCount - 1 }

    var body: some View {
        OnboardingScaffold(viewModel: viewModel) {
            ZStack {
                if !viewModel.usesEstimate {
                    AnalyzingPlaceholder()
                }
                OnboardingReportViewport(panel: viewModel.revealPanel, panelCount: OnboardingRevealPanels.panelCount) {
                    if viewModel.usesEstimate {
                        OnboardingRevealPanels(data: viewModel.estimateRevealData)
                    } else {
                        DeviceActivityReport(.onboardingOverview, filter: filter)
                    }
                }
            }
            .padding(.top, 12)
        } footer: {
            OnboardingPrimaryButton(title: isLastPanel ? "Choose my goal" : "Continue") { viewModel.advance() }
            if showsEstimateFallback && !viewModel.usesEstimate && viewModel.revealPanel == 0 {
                OnboardingSecondaryButton(title: "Report not showing? Use my estimate") {
                    withAnimation { viewModel.usesEstimate = true }
                }
            }
        }
        .task {
            // No readiness signal crosses from the report, so offer the
            // fallback after a fixed wait; it is harmless once the report shows.
            try? await Task.sleep(for: .seconds(20))
            withAnimation { showsEstimateFallback = true }
        }
    }
}

/// Sits behind the report until the extension paints over it. It only
/// describes what the report is doing; it never infers that it has finished.
private struct AnalyzingPlaceholder: View {
    private let steps = ["Reading your last 7 days", "Projecting to age 80", "Building your life chart", "Finding your top apps"]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.6)) { timeline in
            let active = Int(timeline.date.timeIntervalSinceReferenceDate / 1.6) % steps.count
            VStack(spacing: 28) {
                ZStack {
                    Circle().stroke(Color(hex: "#F0DADA"), lineWidth: 6).frame(width: 84, height: 84)
                    ProgressView().controlSize(.large).tint(OnboardingStyle.red)
                }
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(spacing: 12) {
                            Image(systemName: index == active ? "circle.dotted" : "circle.fill")
                                .font(.system(size: index == active ? 14 : 6))
                                .foregroundStyle(index == active ? OnboardingStyle.red : Color(hex: "#C5CCD6"))
                                .frame(width: 18)
                            Text(step)
                                .font(.geist(size: 16, weight: index == active ? .semibold : .regular))
                                .foregroundStyle(index == active ? OnboardingStyle.navy : OnboardingStyle.muted)
                        }
                        .animation(.easeInOut, value: active)
                    }
                }
                Text("The first report can take up to 30 seconds while iOS prepares it privately.")
                    .font(.geist(size: 13))
                    .foregroundStyle(OnboardingStyle.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preparing your private Screen Time report. This can take up to 30 seconds.")
    }
}
