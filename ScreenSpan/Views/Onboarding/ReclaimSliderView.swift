import SwiftUI

struct ReclaimSliderView: View {
    var viewModel: OnboardingViewModel
    @State private var sliderValue: Double = 0
    @State private var isAnimating = false

    private var currentDailyLimit: Double {
        sliderValue
    }

    private var reclaimedYearsFormatted: String {
        String(format: "%.1f", viewModel.reclaimedYears)
    }

    private var dailyLimitFormatted: String {
        String(format: "%.1f", currentDailyLimit)
    }

    private var lifeGridData: LifeGridData {
        let totalMonths = Int(viewModel.remainingYearsOfLife * 12)
        let phoneMonths = min(Int(viewModel.reclaimedYears * 12), totalMonths)

        return LifeGridData(
            totalMonths: totalMonths,
            monthsLived: 0,
            phoneMonths: phoneMonths,
            freeMonths: max(totalMonths - phoneMonths, 0)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Text("Adjust your goal")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.screenSpanNavy)

                        Text("How many hours per day would you like to spend on your phone?")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 32)

                    // Mini Life Grid Visualization
                    VStack(spacing: 16) {
                        LifeGridView(gridData: lifeGridData)

                        // Daily hours display
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current daily usage")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)

                                HStack(spacing: 4) {
                                    Text(String(format: "%.1f", viewModel.estimatedDailyScreenTime))
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.screenSpanRed)

                                    Text("hours/day")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.screenSpanBlue)

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Your new goal")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)

                                HStack(spacing: 4) {
                                    Text(dailyLimitFormatted)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.screenSpanBlue)

                                    Text("hours/day")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)

                    // Slider Section
                    VStack(spacing: 20) {
                        VStack(spacing: 12) {
                            HStack {
                                Text("0.5h")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text(String(format: "%.1f", viewModel.estimatedDailyScreenTime) + "h")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }

                            Slider(
                                value: $sliderValue,
                                in: 0.5...viewModel.estimatedDailyScreenTime,
                                step: 0.1
                            )
                            .tint(.screenSpanRed)
                            .onChange(of: sliderValue) { oldValue, newValue in
                                viewModel.calculateReclaim(newDailyHours: newValue)
                            }
                        }

                        // Reclaim Callout
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.screenSpanRed)

                                Text("You'd reclaim \(reclaimedYearsFormatted) years of your life")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.screenSpanNavy)

                                Spacer()
                            }
                            .padding(12)
                            .background(Color.screenSpanRed.opacity(0.08))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }

            Spacer()

            // CTA Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.advance()
                }
            }) {
                Text("Set My Goal")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.screenSpanRed)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.screenSpanOffWhite.ignoresSafeArea())
        .onAppear {
            sliderValue = viewModel.estimatedDailyScreenTime * 0.5
            viewModel.calculateReclaim(newDailyHours: sliderValue)
        }
    }
}
