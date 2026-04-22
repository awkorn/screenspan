import DeviceActivity
import SwiftUI

// MARK: - Goal Setting View
struct GoalSettingView: View {
    var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Set your goal")
                            .font(.geist(size: 28, weight: .bold))
                            .foregroundColor(.screenSpanNavy)

                        Text("How much time would you like\nto spend on your phone?")
                            .font(.geist(size: 18))
                            .foregroundColor(.screenSpanGray)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 32)

                    DeviceActivityReport(
                        .onboardingGoal,
                        filter: .screenSpanProjectionAverage
                    )
                    .frame(height: 300)
                }
                .padding(.bottom, 24)
            }

            Spacer()

            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.advance()
                }
            }) {
                Text("Set My Goal")
                    .onboardingPrimaryButtonStyle()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.white.ignoresSafeArea())
    }
}
