import SwiftUI

/// The user's guess, asked before they see real numbers. It sets up the
/// reality check and is the fallback if Screen Time access is declined.
struct EstimateView: View {
    @Bindable var viewModel: OnboardingViewModel
    private let presets: [Double] = [1, 2, 3, 4, 5, 6]

    var body: some View {
        OnboardingScaffold(
            viewModel: viewModel,
            title: "How much time do you think you spend on your phone each day?",
            subtitle: "Go with your gut. We’ll compare it with your real numbers."
        ) {
            VStack(spacing: 28) {
                Spacer(minLength: 12)
                VStack(spacing: 4) {
                    Text(formatted(viewModel.estimatedHours))
                        .font(.geist(size: 64, weight: .heavy))
                        .foregroundStyle(OnboardingStyle.navy)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: viewModel.estimatedHours))
                    Text("a day")
                        .font(.geist(size: 17, weight: .medium))
                        .foregroundStyle(OnboardingStyle.muted)
                }
                VStack(spacing: 8) {
                    Slider(value: $viewModel.estimatedHours, in: 0.5...12, step: 0.25)
                        .tint(OnboardingStyle.red)
                        .accessibilityLabel("Your daily phone time estimate")
                        .accessibilityValue(formatted(viewModel.estimatedHours))
                    HStack {
                        Text("30m")
                        Spacer()
                        Text("12h")
                    }
                    .font(.geist(size: 12, weight: .medium))
                    .foregroundStyle(OnboardingStyle.muted)
                }
                .padding(.horizontal, 24)
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { hours in
                        Button {
                            withAnimation(.snappy) { viewModel.estimatedHours = hours }
                        } label: {
                            Text("\(Int(hours))h")
                                .font(.geist(size: 14, weight: .semibold))
                                .foregroundStyle(viewModel.estimatedHours == hours ? .white : OnboardingStyle.navy)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(viewModel.estimatedHours == hours ? OnboardingStyle.navy : OnboardingStyle.card,
                                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                Spacer()
            }
        } footer: {
            OnboardingPrimaryButton(title: "Continue") {
                viewModel.saveEstimate()
                viewModel.advance()
            }
        }
    }

    private func formatted(_ hours: Double) -> String {
        let minutes = Int((hours * 60).rounded())
        if minutes < 60 { return "\(minutes)m" }
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }
}
