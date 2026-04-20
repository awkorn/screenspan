import SwiftUI
import DeviceActivity

/// Chart (Life Grid) view rendered inside the `DeviceActivityReport` extension.
///
/// IMPORTANT: This view is the ONLY place allowed to render raw numeric
/// screen-time values in grid form. The host app passes no usage data in;
/// it embeds this whole view via `DeviceActivityReport(.chart, filter:)`.
///
/// Inputs:
///  • `dailyAverageHours` — scalar produced by the extension's
///    `DeviceActivityReportScene` from `DeviceActivityResults`. This is the
///    user's actual measured average and becomes the slider's max.
///  • `currentAge` / `targetAge` — user-entered, read from App Group.
///  • `screenTimeGoalMinutes` — user-entered goal, read from App Group.
///    The slider writes back to this key so dragging updates the user's
///    saved goal (no usage-derived values ever flow outward).
///
/// Visuals mirror the original `ChartTabView` from the host app:
///  • `GoalComparisonSlider` with current goal thumb + fixed goal marker
///  • `LifeGridView` driven by `ProjectionCalculator.calculateLifeGrid`
///  • Lived / Screen time / Remaining legend
struct ChartReportView: View {
    let dailyAverageHours: Double

    @AppStorage(SharedConstants.UserDefaultsKey.currentAge.rawValue, store: .appGroup)
    private var currentAge: Int = 30

    @AppStorage(SharedConstants.UserDefaultsKey.targetAge.rawValue, store: .appGroup)
    private var targetAge: Int = SharedConstants.DefaultValues.targetAge

    @AppStorage(SharedConstants.UserDefaultsKey.screenTimeGoalMinutes.rawValue, store: .appGroup)
    private var screenTimeGoalMinutes: Int = 120

    /// Transient slider position in hours — starts at the stored goal,
    /// commits back when the drag settles.
    @State private var draftGoalHours: Double = 0

    private var resolvedCurrentAge: Int { max(currentAge, 1) }
    private var resolvedTargetAge: Int { max(targetAge, resolvedCurrentAge) }

    private var maxSliderHours: Double {
        max(dailyAverageHours, 0.1)
    }

    private var storedGoalHours: Double {
        Double(screenTimeGoalMinutes) / 60.0
    }

    private var fixedGoalProgress: Double {
        guard maxSliderHours > 0 else { return 0 }
        return min(max(storedGoalHours / maxSliderHours, 0), 1)
    }

    private var goalGridData: LifeGridData {
        let projection = ProjectionCalculator.calculateProjectionFromDaily(
            currentAge: resolvedCurrentAge,
            targetAge: resolvedTargetAge,
            dailyHours: max(draftGoalHours, 0)
        )

        return ProjectionCalculator.calculateLifeGrid(
            currentAge: resolvedCurrentAge,
            targetAge: resolvedTargetAge,
            monthsOnPhone: projection.monthsOnPhone
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                sliderSection
                    .padding(.top, 28)

                LifeGridView(goalGridData: goalGridData)

                legendSection
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color.white.ignoresSafeArea())
        .onAppear {
            draftGoalHours = min(max(storedGoalHours, 0), maxSliderHours)
        }
    }

    private var sliderSection: some View {
        VStack(spacing: 8) {
            GoalComparisonSlider(
                value: Binding(
                    get: { draftGoalHours },
                    set: { newValue in
                        let clamped = min(max(newValue, 0), maxSliderHours)
                        draftGoalHours = clamped
                        screenTimeGoalMinutes = Int((clamped * 60).rounded())
                    }
                ),
                maxValue: maxSliderHours,
                goalMarkerProgress: fixedGoalProgress
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

// MARK: - Goal Comparison Slider

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
