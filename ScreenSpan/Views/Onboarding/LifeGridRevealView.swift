import SwiftUI

struct LifeGridRevealView: View {
    var viewModel: OnboardingViewModel
    var animation: Namespace.ID
    @State private var showGrid = false
    @State private var animateRedSpread = false

    private var yearsFormatted: String {
        String(format: "%.1f", viewModel.projectedYearsOnPhone)
    }

    private var percentageFormatted: String {
        String(format: "%.0f", viewModel.percentageOfWakingHours)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    // Hero Number
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Text(yearsFormatted)
                                .font(.system(size: 72, weight: .bold, design: .default))
                                .foregroundColor(.screenSpanRed)
                                .monospacedDigit()

                            VStack(alignment: .leading, spacing: 2) {
                                Text("YEARS")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.screenSpanNavy)
                                Text("of your life")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)

                    // Subtitle
                    VStack(spacing: 8) {
                        Text("of your waking life will be spent on your phone")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.screenSpanNavy)
                            .lineSpacing(1)

                        Text("That's \(percentageFormatted)% of every waking hour you have left")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                    // Life Grid
                    VStack(spacing: 12) {
                        OnboardingLifeGrid(
                            years: Int(viewModel.remainingYearsOfLife),
                            projectedPhoneYears: Int(viewModel.projectedYearsOnPhone),
                            showAnimation: showGrid,
                            animateRedSpread: animateRedSpread
                        )
                    }
                    .padding(.horizontal, 24)

                    // Information Box
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.screenSpanBlue)

                            Text("This assumes your current daily screen time of \(String(format: "%.1f", viewModel.estimatedDailyScreenTime)) hours")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)

                            Spacer()
                        }
                        .padding(12)
                        .background(Color.screenSpanBlue.opacity(0.08))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }

            Spacer()

            // Continue Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.advance()
                }
            }) {
                Text("Continue")
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
            withAnimation(.easeOut(duration: 0.6)) {
                showGrid = true
            }
            withAnimation(.easeInOut(duration: 1.2).delay(0.6)) {
                animateRedSpread = true
            }
        }
    }
}

// MARK: - Life Grid Component
struct OnboardingLifeGrid: View {
    let years: Int
    let projectedPhoneYears: Int
    let showAnimation: Bool
    let animateRedSpread: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 12)

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<years, id: \.self) { year in
                HStack(spacing: 4) {
                    ForEach(0..<12, id: \.self) { month in
                        let cellIndex = year * 12 + month
                        let isPhoneTime = cellIndex < (projectedPhoneYears * 12)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(cellColor(isPhoneTime: isPhoneTime))
                            .frame(height: 8)
                            .opacity(showAnimation ? 1 : 0)
                            .scaleEffect(showAnimation ? 1 : 0.5, anchor: .center)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.screenSpanNavy.opacity(0.1), lineWidth: 1)
        )
    }

    private func cellColor(isPhoneTime: Bool) -> Color {
        if isPhoneTime {
            return animateRedSpread ? .screenSpanRed : .screenSpanBlue
        }
        return Color.screenSpanNavy.opacity(0.08)
    }
}
