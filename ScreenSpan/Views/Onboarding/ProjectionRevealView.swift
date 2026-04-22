import DeviceActivity
import SwiftUI

struct ProjectionRevealView: View {
    var viewModel: OnboardingViewModel

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                DeviceActivityReport(
                    .onboardingProjection,
                    filter: .screenSpanProjectionAverage
                )
                .frame(
                    maxWidth: .infinity,
                    minHeight: 0,
                    maxHeight: max(proxy.size.height - 110, 0),
                    alignment: .top
                )

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.advance()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("See your life, visualized")
                            .font(.geist(size: 15, weight: .semibold))

                        Image(systemName: "arrow.right")
                            .font(.geist(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .onboardingPrimaryButtonStyle()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Color.white.ignoresSafeArea())
    }
}
