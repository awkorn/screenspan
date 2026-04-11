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
                    VStack(spacing: 8) {
                        Text("Set your goal")
                            .font(.custom("Geist", size: 40, relativeTo: .body).weight(.semibold))
                            .foregroundColor(.screenSpanNavy)

                        Text("How much time would you like\nto spend on your phone?")
                            .font(.custom("Geist", size: 24, relativeTo: .body))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 32)

                    VStack(spacing: 12) {
                        HStack {
                            Text("0h")
                                .font(.custom("Geist", size: 14, relativeTo: .body).weight(.medium))
                                .foregroundColor(.secondary)

                            Spacer()

                            Text("\(Int(viewModel.estimatedDailyScreenTime.rounded()))h")
                                .font(.custom("Geist", size: 14, relativeTo: .body).weight(.medium))
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
                                .font(.custom("Geist", size: 13, relativeTo: .body))
                                .foregroundColor(.secondary)

                            HStack(spacing: 4) {
                                Text(currentUsageFormatted)
                                    .font(.custom("Geist", size: 22, relativeTo: .body).weight(.semibold))
                                    .foregroundColor(currentUsageColor)
                                    .monospacedDigit()

                                Text("hours/day")
                                    .font(.custom("Geist", size: 15, relativeTo: .body))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "arrow.right")
                            .font(.custom("Geist", size: 20, relativeTo: .body).weight(.semibold))
                            .foregroundColor(.secondary)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            Text("Your new goal")
                                .font(.custom("Geist", size: 13, relativeTo: .body))
                                .foregroundColor(.secondary)

                            HStack(spacing: 4) {
                                Text(goalUsageFormatted)
                                    .font(.custom("Geist", size: 22, relativeTo: .body).weight(.semibold))
                                    .foregroundColor(goalUsageColor)
                                    .monospacedDigit()

                                Text("hours/day")
                                    .font(.custom("Geist", size: 15, relativeTo: .body))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(10)
                    .padding(.horizontal, 24)

                    HStack(spacing: 12) {
                        Image(systemName: "figure.walk")
                            .font(.custom("Geist", size: 22, relativeTo: .body).weight(.semibold))
                            .foregroundColor(goalUsageColor)

                        Text("You'd reclaim \(reclaimedYearsRounded) years of your life!")
                            .font(.custom("Geist", size: 20, relativeTo: .body).weight(.semibold))
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
                    .font(.custom("Geist", size: 17, relativeTo: .body).weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.screenSpanNavy)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.screenSpanOffWhite.ignoresSafeArea())
        .onAppear {
            sliderValue = viewModel.selectedDailyLimit > 0 ? viewModel.selectedDailyLimit : viewModel.estimatedDailyScreenTime
            sliderValue = min(max(sliderValue, 0), maxSliderValue)
            viewModel.calculateReclaim(newDailyHours: sliderValue)
        }
    }
}
