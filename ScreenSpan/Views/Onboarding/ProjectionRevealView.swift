import SwiftUI

struct ProjectionRevealView: View {
    var viewModel: OnboardingViewModel
    var animation: Namespace.ID

    @State private var displayedYears: Double = 0
    @State private var timerRotation: Double = 0
    @State private var countingTask: Task<Void, Never>?

    private let backgroundColor = Color.white
    private let titleColor = Color(hex: "051425")
    private let mutedColor = Color(hex: "797979")
    private let blurredRedColor = Color(hex: "F63232")
    private let yearsTextColor = Color.white
    private let boxBackground = Color(hex: "FFC2C2")
    private let boxStroke = Color(hex: "C82020")
    private var targetYears: Double {
        max(viewModel.projectedYearsOnPhone, 0)
    }

    private var targetPercent: Double {
        max(viewModel.percentageOfWakingHours, 0)
    }

    private var yearsFormatted: String {
        String(format: "%.1f", displayedYears)
    }

    private var percentageFormatted: String {
        String(format: "%.0f", targetPercent)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            // Top status pill
            HStack(spacing: 8) {
                Image(systemName: "hourglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "C82020"))
                    .rotationEffect(.degrees(timerRotation))

                Text("TIME ANALYSIS COMPLETE")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "575757"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(Color(hex: "ECECEF"))
                    .overlay(
                        Capsule()
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
            )

            Spacer(minLength: 44)

            VStack(spacing: 10) {
                Text(yearsFormatted)
                    .font(.system(size: 80, weight: .bold))
                    .foregroundStyle(yearsTextColor)
                    .monospacedDigit()
                    .shadow(color: .black.opacity(0.20), radius: 2, x: 0, y: 2)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Circle()
                            .fill(blurredRedColor.opacity(0.42))
                            .frame(width: 270, height: 210)
                            .blur(radius: 36)
                    )

                Text("YEARS")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(hex: "C82020"))

                Text("of your waking life")
                    .font(.system(size: 20, weight: .semibold))
                    .italic()
                    .foregroundStyle(mutedColor)

                Text("staring at your phone.")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(titleColor)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)

            Spacer(minLength: 36)

            HStack(spacing: 10) {
                Image(systemName: "clock")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: "D92A2A"))

                Text("That’s \(percentageFormatted)% of every waking hour you have left.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(boxBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(boxStroke, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.advance()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("See your life, visualized")
                        .font(.system(size: 15, weight: .semibold))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .onboardingPrimaryButtonStyle()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
        }
        .background(backgroundColor.ignoresSafeArea())
        .onAppear {
            viewModel.calculateProjection()
            startAnimations()
        }
        .onDisappear {
            countingTask?.cancel()
        }
    }

    private func startAnimations() {
        withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
            timerRotation = 360
        }

        countingTask?.cancel()
        countingTask = Task {
            let steps = 55
            for step in 1...steps {
                if Task.isCancelled { return }
                let progress = Double(step) / Double(steps)
                let eased = 1 - pow(1 - progress, 3)

                await MainActor.run {
                    displayedYears = targetYears * eased
                }

                try? await Task.sleep(nanoseconds: 28_000_000)
            }

            await MainActor.run {
                displayedYears = targetYears
            }
        }
    }
}
