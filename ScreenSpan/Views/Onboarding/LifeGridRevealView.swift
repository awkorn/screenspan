import DeviceActivity
import SwiftUI

struct LifeGridRevealView: View {
    var viewModel: OnboardingViewModel

    @State private var arrowPulse = false

    private let titleColor = Color(hex: "051425")
    private let columnCount = 26
    private let spacing: CGFloat = 3
    private let horizontalPadding: CGFloat = 24

    private var gridWidth: CGFloat {
        UIScreen.main.bounds.width - (horizontalPadding * 2)
    }

    private var cellSize: CGFloat {
        max((gridWidth - (CGFloat(columnCount - 1) * spacing)) / CGFloat(columnCount), 4)
    }

    private var rowCount: Int {
        Int(ceil(Double(SharedConstants.DefaultValues.targetAge * 12) / Double(columnCount)))
    }

    private var gridHeight: CGFloat {
        (CGFloat(rowCount) * cellSize) + (CGFloat(max(rowCount - 1, 0)) * spacing)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your projected life chart")
                    .font(.geist(size: 28, weight: .bold))
                    .foregroundStyle(titleColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 24)
            .padding(.horizontal, horizontalPadding)

            Text("1 square = 1 month")
                .font(.geist(size: 11))
                .foregroundStyle(titleColor.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
                .padding(.horizontal, horizontalPadding)

            DeviceActivityReport(
                .onboardingLifeChart,
                filter: .screenSpanRecentDailyAverage
            )
            .frame(height: gridHeight)
                .padding(.top, 14)
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 18)

            Spacer(minLength: 20)

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.advance()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Reclaim your life")
                        .font(.geist(size: 15, weight: .semibold))

                    Image(systemName: "arrow.right")
                        .font(.geist(size: 15, weight: .semibold))
                        .scaleEffect(arrowPulse ? 1.15 : 0.95)
                        .opacity(arrowPulse ? 1 : 0.7)
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: arrowPulse
                        )
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .onboardingPrimaryButtonStyle()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 26)
        }
        .background(Color.white.ignoresSafeArea())
        .onAppear {
            arrowPulse = true
        }
    }
}
