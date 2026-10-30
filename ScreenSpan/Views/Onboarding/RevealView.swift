import DeviceActivity
import SwiftUI

/// The reveal panels and the goal step share one report so it loads once.
/// With Screen Time access the report is rendered by the extension and the
/// host only moves a window over it: a full-height panel during the reveal,
/// then the goal-impact row matching the selected goal. In estimate mode the
/// host renders the same layout from the user's own guess.
struct RevealView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var filter = DeviceActivityFilter.screenSpanProjectionAverage
    @State private var showsEstimateFallback = false
    /// The lifetime panel unseals its numbers after a tap inside the report,
    /// which can't tell the host when it's done. So the host notices that tap
    /// and holds Continue until the sequence has played.
    @State private var lifetimeTapped = false
    @State private var lifetimeRevealed = false
    private let goalPresets: [Double] = [1, 1.5, 2, 3]

    private var isGoal: Bool { viewModel.currentStep == .goal }
    private var isLastPanel: Bool { viewModel.revealPanel == OnboardingRevealLayout.panelCount - 1 }
    private var isLifetimePanel: Bool { !isGoal && viewModel.revealPanel == OnboardingRevealLayout.lifetimePanel }

    var body: some View {
        OnboardingScaffold(viewModel: viewModel) {
            GeometryReader { proxy in
                let panelHeight = proxy.size.height
                VStack(alignment: .leading, spacing: 0) {
                    if isGoal {
                        goalHeader
                    }
                    ZStack {
                        if !viewModel.usesEstimate {
                            if isGoal {
                                ProgressView().tint(OnboardingStyle.red)
                            } else {
                                AnalyzingPlaceholder()
                            }
                        }
                        OnboardingReportWindow(
                            contentHeight: OnboardingRevealLayout.totalHeight(panelHeight: panelHeight),
                            offset: isGoal
                                ? OnboardingRevealLayout.goalOffset(viewModel.goalHours, panelHeight: panelHeight)
                                : OnboardingRevealLayout.panelOffset(viewModel.revealPanel, panelHeight: panelHeight)
                        ) {
                            if viewModel.usesEstimate {
                                OnboardingRevealPanels(data: viewModel.estimateRevealData)
                            } else {
                                DeviceActivityReport(.onboardingOverview, filter: filter)
                            }
                        }
                    }
                    .frame(height: isGoal ? OnboardingRevealLayout.goalRowHeight : panelHeight)
                    .simultaneousGesture(TapGesture().onEnded {
                        if isLifetimePanel { lifetimeTapped = true }
                    })
                    if isGoal {
                        goalControls
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.top, 12)
        } footer: {
            if isGoal {
                OnboardingPrimaryButton(title: "Set my goal") {
                    viewModel.saveGoal()
                    viewModel.advance()
                }
            } else {
                OnboardingPrimaryButton(title: isLastPanel ? (viewModel.buildsPlan ? "Build my plan" : "Choose my goal") : "Continue",
                                        isEnabled: !isLifetimePanel || lifetimeRevealed) { viewModel.advance() }
                if showsEstimateFallback && !viewModel.usesEstimate && viewModel.revealPanel == 0 {
                    OnboardingSecondaryButton(title: "Report not showing? Use my estimate") {
                        withAnimation { viewModel.usesEstimate = true }
                    }
                }
            }
        }
        .task {
            // No readiness signal crosses from the report, so offer the
            // fallback after a fixed wait; it is harmless once the report shows.
            try? await Task.sleep(for: .seconds(20))
            withAnimation { showsEstimateFallback = true }
        }
        .task(id: lifetimeTapped) {
            guard lifetimeTapped else { return }
            try? await Task.sleep(for: .seconds(OnboardingRevealLayout.lifetimeRevealDuration))
            withAnimation { lifetimeRevealed = true }
        }
        .task(id: isLifetimePanel) {
            // Never strand anyone if the tap doesn't reach the host.
            guard isLifetimePanel, !lifetimeRevealed else { return }
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled else { return }
            withAnimation { lifetimeRevealed = true }
        }
    }

    private var goalHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Set your daily goal")
                .font(.geist(size: 28, weight: .bold))
                .foregroundStyle(OnboardingStyle.navy)
            Text("Pick a limit that feels challenging but doable. You can change it anytime.")
                .font(.geist(size: 16))
                .foregroundStyle(OnboardingStyle.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    private var goalControls: some View {
        VStack(spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your goal")
                    .font(.geist(size: 15, weight: .medium))
                    .foregroundStyle(OnboardingStyle.muted)
                Spacer()
                Text("\(formatted(viewModel.goalHours)) a day")
                    .font(.geist(size: 22, weight: .bold))
                    .foregroundStyle(OnboardingStyle.navy)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: viewModel.goalHours))
            }
            Slider(value: $viewModel.goalHours,
                   in: OnboardingRevealLayout.goalValues.first!...OnboardingRevealLayout.goalValues.last!,
                   step: 0.25)
                .tint(Color(hex: "#2BB673"))
                .accessibilityLabel("Daily goal")
                .accessibilityValue("\(formatted(viewModel.goalHours)) a day")
            HStack(spacing: 8) {
                ForEach(goalPresets, id: \.self) { hours in
                    Button {
                        withAnimation(.snappy) { viewModel.goalHours = hours }
                    } label: {
                        Text(formatted(hours))
                            .font(.geist(size: 14, weight: .semibold))
                            .foregroundStyle(viewModel.goalHours == hours ? .white : OnboardingStyle.navy)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(viewModel.goalHours == hours ? OnboardingStyle.navy : OnboardingStyle.card,
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    private func formatted(_ hours: Double) -> String {
        let minutes = Int((hours * 60).rounded())
        if minutes < 60 { return "\(minutes)m" }
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
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
