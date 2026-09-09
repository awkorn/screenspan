import DeviceActivity
import SwiftUI

struct ProjectionRevealView: View {
    var viewModel: OnboardingViewModel

    private let titleColor = Color(hex: "#051425")
    private let subtitleColor = Color(hex: "#595959")
    private let accentColor = Color(hex: "#C82020")

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Screen Time projection")
                    .font(.geist(size: 28, weight: .bold))
                    .foregroundStyle(titleColor)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Based on your recent iPhone activity. Your first report may take a moment.")
                    .font(.geist(size: 16, weight: .medium))
                    .foregroundStyle(subtitleColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 16)

            ZStack {
                reportPlaceholder

                DeviceActivityReport(
                    .onboardingOverview,
                    filter: .screenSpanProjectionAverage
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.currentStep = .goalSetting
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Continue to your goal")
                    Image(systemName: "arrow.right")
                }
                .onboardingPrimaryButtonStyle()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.white.ignoresSafeArea())
    }

    private var reportPlaceholder: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color(hex: "#F0DADA"), lineWidth: 8)
                    .frame(width: 86, height: 86)

                Image(systemName: "hourglass")
                    .font(.geist(size: 24, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            Text("Preparing your private report")
                .font(.geist(size: 20, weight: .bold))
                .foregroundStyle(titleColor)

            Text("You can keep moving while Screen Time catches up.")
                .font(.geist(size: 15, weight: .medium))
                .foregroundStyle(subtitleColor)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
    }
}
