import SwiftUI

/// The daily goal the user commits to. The reveal just showed what cutting
/// back could give them; here they choose.
struct GoalSettingView: View {
    @Bindable var viewModel: OnboardingViewModel
    private let presets: [Double] = [1, 1.5, 2, 3]

    var body: some View {
        OnboardingScaffold(
            viewModel: viewModel,
            title: "Set your daily goal",
            subtitle: "Pick a limit that feels challenging but doable. You can change it anytime."
        ) {
            VStack(spacing: 28) {
                Spacer(minLength: 12)
                VStack(spacing: 4) {
                    Text(formatted(viewModel.goalHours))
                        .font(.geist(size: 64, weight: .heavy))
                        .foregroundStyle(Color(hex: "#1F7A4D"))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: viewModel.goalHours))
                    Text("or less a day")
                        .font(.geist(size: 17, weight: .medium))
                        .foregroundStyle(OnboardingStyle.muted)
                }
                Slider(value: $viewModel.goalHours, in: 0.5...8, step: 0.25)
                    .tint(Color(hex: "#2BB673"))
                    .padding(.horizontal, 24)
                    .accessibilityLabel("Daily goal")
                    .accessibilityValue(formatted(viewModel.goalHours))
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { hours in
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
                .padding(.horizontal, 24)
                if viewModel.usesEstimate, viewModel.goalHours < viewModel.estimatedHours {
                    Text(String(format: "Compared with your %@ estimate, that’s about %.1f years back by age 80.",
                                formatted(viewModel.estimatedHours), yearsBack))
                        .font(.geist(size: 14, weight: .medium))
                        .foregroundStyle(OnboardingStyle.navy)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                Spacer()
            }
        } footer: {
            OnboardingPrimaryButton(title: "Set my goal") {
                viewModel.saveGoal()
                viewModel.advance()
            }
        }
    }

    private var yearsBack: Double {
        ProjectionCalculator.calculateRegained(
            startingDailyHours: viewModel.estimatedHours, currentDailyHours: viewModel.goalHours,
            currentAge: viewModel.selectedAge, targetAge: SharedConstants.DefaultValues.targetAge
        ).yearsReclaimed
    }

    private func formatted(_ hours: Double) -> String {
        let minutes = Int((hours * 60).rounded())
        if minutes < 60 { return "\(minutes)m" }
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }
}
