import SwiftUI

// MARK: - Goal Setting View
struct GoalSettingView: View {
    var viewModel: OnboardingViewModel
    @State private var sliderValue: Double = 0

    private let goalSliderColor = Color(hex: "#C82020")
    private let currentUsageColor = Color(hex: "#F63232")
    private let goalUsageColor = Color(hex: "#0063D6")
    private let reclaimBackgroundColor = Color(hex: "#D7EAFF")

    private var maxSliderValue: Double {
        max(viewModel.estimatedDailyScreenTime, 0.1)
    }

    private var currentUsageFormatted: String {
        String(format: "%.1f", viewModel.estimatedDailyScreenTime)
    }

    private var goalUsageFormatted: String {
        String(format: "%.1f", sliderValue)
    }

    private var reclaimedYearsRounded: Int {
        Int(viewModel.reclaimedYears.rounded())
    }

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
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 32)

                    VStack(spacing: 12) {
                    HStack {
                            Text("0h")
                                .font(.geist(size: 14, weight: .medium))
                                .foregroundColor(.secondary)

                            Spacer()

                            Text("\(Int(viewModel.estimatedDailyScreenTime.rounded()))h")
                                .font(.geist(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $sliderValue, in: 0...maxSliderValue, step: 0.1)
                            .tint(goalSliderColor)
                            .onChange(of: sliderValue) { _, newValue in
                                viewModel.calculateReclaim(newDailyHours: newValue)
                            }
                    }
                    .padding(.horizontal, 24)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Current daily usage")
                                .font(.geist(size: 13))
                                .foregroundColor(.secondary)

                            HStack(spacing: 4) {
                                Text(currentUsageFormatted)
                                    .font(.geist(size: 16, weight: .semibold))
                                    .foregroundColor(currentUsageColor)
                                    .monospacedDigit()

                                Text("hours/day")
                                    .font(.geist(size: 15))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "arrow.right")
                            .font(.geist(size: 20, weight: .semibold))
                            .foregroundColor(.secondary)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            Text("Your new goal")
                                .font(.geist(size: 13))
                                .foregroundColor(.secondary)

                            HStack(spacing: 4) {
                                Text(goalUsageFormatted)
                                    .font(.geist(size: 16, weight: .semibold))
                                    .foregroundColor(goalUsageColor)
                                    .monospacedDigit()

                                Text("hours/day")
                                    .font(.geist(size: 15))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.screenSpanCardBackground)
                    .cornerRadius(10)
                    .padding(.horizontal, 24)

                    HStack(spacing: 12) {
                        Image(systemName: "figure.walk")
                            .font(.geist(size: 22, weight: .semibold))
                            .foregroundColor(goalUsageColor)

                        Text("You'd reclaim \(reclaimedYearsRounded) years of your life!")
                            .font(.geist(size: 16, weight: .semibold))
                            .foregroundColor(.screenSpanNavy)

                        Spacer()
                    }
                    .padding(16)
                    .background(reclaimBackgroundColor)
                    .cornerRadius(10)
                    .padding(.horizontal, 24)
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
        .onAppear {
            sliderValue = viewModel.selectedDailyLimit > 0 ? viewModel.selectedDailyLimit : viewModel.estimatedDailyScreenTime
            sliderValue = min(max(sliderValue, 0), maxSliderValue)
            viewModel.calculateReclaim(newDailyHours: sliderValue)
        }
    }
}
