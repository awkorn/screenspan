import DeviceActivity
import SwiftUI

struct ProjectionRevealView: View {
    var viewModel: OnboardingViewModel
    @State private var filter = DeviceActivityFilter.screenSpanProjectionAverage

    private var showsLifeChart: Bool { viewModel.currentStep == .comparisons }

    private let titleColor = Color(hex: "#051425")
    private let subtitleColor = Color(hex: "#595959")
    private let accentColor = Color(hex: "#C82020")

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(showsLifeChart ? "Your life chart" : "Your Screen Time projection")
                    .font(.geist(size: 28, weight: .bold))
                    .foregroundStyle(titleColor)
                    .fixedSize(horizontal: false, vertical: true)

                Text(showsLifeChart ? "See how your daily screen time adds up over your life." : "Based on your recent iPhone activity. Your first report may take a moment.")
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

                OnboardingReportViewport(showsLifeChart: showsLifeChart) {
                    DeviceActivityReport(.onboardingOverview, filter: filter)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.advance()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(showsLifeChart ? "Reclaim your life" : "See your life chart")
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

            Text(showsLifeChart ? "Your life chart will appear here when Screen Time is ready." : "Your analysis and life chart share the same private report.")
                .font(.geist(size: 15, weight: .medium))
                .foregroundStyle(subtitleColor)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
    }
}
