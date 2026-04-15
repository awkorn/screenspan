import SwiftUI

/// Life grid chart tab
struct ChartTabView: View {
    @State private var viewModel = ChartViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                sliderSection
                    .padding(.top, 28)

                LifeGridView(goalGridData: viewModel.goalGridData)

                legendSection
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color.white.ignoresSafeArea())
        .task {
            viewModel.loadData()
        }
    }

    private var sliderSection: some View {
        VStack(spacing: 8) {
            GoalComparisonSlider(
                value: Binding(
                    get: { viewModel.selectedGoalHours },
                    set: { viewModel.updateGoalHours($0) }
                ),
                maxValue: viewModel.maxSliderHours,
                goalMarkerProgress: viewModel.fixedGoalProgress
            )
        }
    }

    private var legendSection: some View {
        HStack(spacing: 24) {
            legendItem(color: Color(hex: "#0063D6"), label: "Lived")
            legendItem(color: Color(hex: "#F63232"), label: "Screen time")
            legendItem(color: Color(hex: "#D9D9D9"), label: "Remaining")
        }
        .frame(maxWidth: .infinity)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)

            Text(label)
                .font(.geist(size: 14, weight: .medium))
                .foregroundStyle(.black)
        }
    }
}

private struct GoalComparisonSlider: View {
    @Binding var value: Double
    let maxValue: Double
    let goalMarkerProgress: Double

    private let trackHeight: CGFloat = 7
    private let thumbWidth: CGFloat = 34
    private let thumbHeight: CGFloat = 22

    private var normalizedProgress: Double {
        guard maxValue > 0 else { return 0 }
        return min(max(value / maxValue, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let progress = normalizedProgress
            let thumbX = progress * width
            let goalMarkerX = goalMarkerProgress * width

            VStack(spacing: 10) {
                HStack {
                    Text("0h")
                    Spacer()
                    Text(formattedHours(maxValue))
                }
                .font(.geist(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: "#595959"))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: "#D9D9D9"))
                        .frame(height: trackHeight)

                    Capsule()
                        .fill(Color(hex: "#C82020"))
                        .frame(width: max(thumbX, 0), height: trackHeight)

                    Rectangle()
                        .fill(Color(hex: "#595959"))
                        .frame(width: 2, height: 18)
                        .offset(x: min(max(goalMarkerX - 1, 0), max(width - 2, 0)))

                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color(hex: "#F4F4F4"))
                        .frame(width: thumbWidth, height: thumbHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                        .offset(x: min(max(thumbX - (thumbWidth / 2), 0), width - thumbWidth))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let clampedX = min(max(gesture.location.x, 0), width)
                            let newValue = (clampedX / width) * maxValue
                            value = (newValue * 10).rounded() / 10
                        }
                )

                ZStack(alignment: .leading) {
                    Text("Goal")
                        .font(.geist(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "#595959"))
                        .position(
                            x: min(max(goalMarkerX, 24), max(width - 24, 24)),
                            y: 10
                        )

                    Text("Avg")
                        .font(.geist(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "#595959"))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(height: 20)
            }
        }
        .frame(height: 70)
    }

    private func formattedHours(_ hours: Double) -> String {
        let roundedHours = (hours * 10).rounded() / 10
        if roundedHours == roundedHours.rounded() {
            return "\(Int(roundedHours))h"
        }

        return String(format: "%.1fh", roundedHours)
    }
}
