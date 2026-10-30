import SwiftUI
import DeviceActivity

/// Chart (Life Grid) view rendered inside the `DeviceActivityReport` extension.
///
/// IMPORTANT: This view is the ONLY place allowed to render raw numeric
/// screen-time values in grid form. The host app passes no usage data in;
/// it embeds this whole view via `DeviceActivityReport(.chart, filter:)`.
///
/// Inputs:
///  • `dailyAverageHours` — the last seven completed days; the slider's
///    starting position ("Now").
///  • Starting pace — measured from the week before the user started, or
///    their saved entry (see `LifeRegainedProgress`); the "Start" marker.
///  • `currentAge` / `targetAge` / `screenTimeGoalMinutes` — user-entered,
///    read from App Group. The slider is a what-if preview and never writes.
///
/// The grid shows lived months, projected phone months at the slider's pace,
/// and months won back compared with the starting pace.
struct ChartReportView: View {
    let payload: ScreenTimeReportPayload

    @AppStorage(SharedConstants.UserDefaultsKey.currentAge.rawValue, store: .appGroup)
    private var currentAge: Int = 30

    @AppStorage(SharedConstants.UserDefaultsKey.targetAge.rawValue, store: .appGroup)
    private var targetAge: Int = SharedConstants.DefaultValues.targetAge

    @AppStorage(SharedConstants.UserDefaultsKey.screenTimeGoalMinutes.rawValue, store: .appGroup)
    private var screenTimeGoalMinutes: Double = 120

    @AppStorage(SharedConstants.UserDefaultsKey.trackingStartDate.rawValue, store: .appGroup)
    private var trackingStartSeconds: Double = 0

    @AppStorage(SharedConstants.UserDefaultsKey.startingDailyMinutes.rawValue, store: .appGroup)
    private var savedStartingMinutes: Double = 0

    /// Transient what-if preview. Saving goals belongs to the host app.
    @State private var draftHours: Double = 0

    private var dailyAverageHours: Double { payload.dailyAverageHours ?? 0 }
    private var resolvedCurrentAge: Int { max(currentAge, 1) }
    private var resolvedTargetAge: Int { max(targetAge, resolvedCurrentAge) }
    /// With a plan, the marker is where its targets would bring the day:
    /// the starting pace less every app's cut. Otherwise the daily goal.
    private var goalHours: Double {
        guard !payload.plan.apps.isEmpty else { return screenTimeGoalMinutes / 60 }
        let cut = Double(payload.plan.courses.minutesBackAtTarget) / 60
        return max((startingPaceHours ?? dailyAverageHours) - cut, 0)
    }

    private var startingPaceHours: Double? {
        payload.progress(trackingStartSeconds: trackingStartSeconds,
                         savedStartingMinutes: savedStartingMinutes).startingPaceHours
    }

    private var maxSliderHours: Double {
        max(dailyAverageHours, startingPaceHours ?? 0, goalHours, 0.5)
    }

    private func yearsOnPhone(_ hours: Double) -> Double {
        ProjectionCalculator.calculateProjectionFromDaily(
            currentAge: resolvedCurrentAge, targetAge: resolvedTargetAge, dailyHours: hours
        ).yearsOnPhone
    }

    private var wonBackYears: Double {
        guard let startingPaceHours else { return 0 }
        return max(yearsOnPhone(startingPaceHours) - yearsOnPhone(draftHours), 0)
    }

    private var gridData: LifeGridData {
        ProjectionCalculator.calculateLifeGrid(
            currentAge: resolvedCurrentAge,
            targetAge: resolvedTargetAge,
            monthsOnPhone: yearsOnPhone(draftHours) * 12,
            regainedMonths: wonBackYears * 12
        )
    }

    private var markers: [SliderMarker] {
        var markers = [SliderMarker(label: "Now", hours: dailyAverageHours),
                       SliderMarker(label: payload.plan.apps.isEmpty ? "Goal" : "Plan", hours: goalHours)]
        if let startingPaceHours { markers.append(SliderMarker(label: "Start", hours: startingPaceHours)) }
        return markers
    }

    var body: some View {
        Group {
            if payload.isAvailable {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        readout
                        GoalComparisonSlider(value: $draftHours, maxValue: maxSliderHours, markers: markers)
                        LifeGridView(goalGridData: gridData)
                        legendSection
                        ReportSourceNote(payload: payload)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
                .onAppear {
                    draftHours = dailyAverageHours
                }
            } else {
                ScreenTimeUnavailableView(
                    title: "We couldn't access your Screen Time data",
                    message: "We need actual Screen Time activity before we can build your chart or compare it to your goal."
                )
            }
        }
        .background(Color.white.ignoresSafeArea())
        .screenSpanLightSurface()
    }

    private var readout: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("At \(duration(draftHours)) a day")
                    .font(.geist(size: 17, weight: .semibold))
                    .monospacedDigit()
                Text(String(format: "%.1f years on your phone by %d", yearsOnPhone(draftHours), resolvedTargetAge))
                    .font(.geist(size: 13))
                    .foregroundStyle(ScreenSpanAppearance.secondaryText)
                    .monospacedDigit()
            }
            Spacer(minLength: 12)
            if wonBackYears >= 0.05 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "+%.1f years", wonBackYears))
                        .font(.geist(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "#1F7A4D"))
                        .monospacedDigit()
                    Text("won back vs. start")
                        .font(.geist(size: 13))
                        .foregroundStyle(ScreenSpanAppearance.secondaryText)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var legendSection: some View {
        HStack(spacing: 14) {
            legendItem(color: LifeGridView.livedColor, label: "Lived")
            legendItem(color: LifeGridView.phoneColor, label: "Screen time")
            if gridData.regainedMonths > 0 {
                legendItem(color: LifeGridView.regainedColor, label: "Won back")
            }
            legendItem(color: LifeGridView.remainingColor, label: "Remaining")
        }
        .frame(maxWidth: .infinity)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)

            Text(label)
                .font(.geist(size: 12, weight: .medium))
                .foregroundStyle(ScreenSpanAppearance.text)
                .lineLimit(1)
        }
    }

    private func duration(_ hours: Double) -> String {
        let minutes = Int((hours * 60).rounded())
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}

// MARK: - Goal Comparison Slider

private struct SliderMarker: Identifiable {
    let label: String
    let hours: Double
    var id: String { label }
}

/// Drag to preview any daily pace; tap a marker label to jump to it.
private struct GoalComparisonSlider: View {
    @Binding var value: Double
    let maxValue: Double
    let markers: [SliderMarker]

    private let trackHeight: CGFloat = 7
    private let thumbWidth: CGFloat = 34
    private let thumbHeight: CGFloat = 22
    private let minimumLabelSpacing: CGFloat = 46

    private func progress(_ hours: Double) -> Double {
        guard maxValue > 0 else { return 0 }
        return min(max(hours / maxValue, 0), 1)
    }

    /// Marker labels left to right, dropping any that would overlap the
    /// previous one. Their ticks still show on the track.
    private func visibleLabels(width: CGFloat) -> [(SliderMarker, CGFloat)] {
        var shown: [(SliderMarker, CGFloat)] = []
        for marker in markers.sorted(by: { $0.hours < $1.hours }) {
            let x = progress(marker.hours) * width
            if let last = shown.last, x - last.1 < minimumLabelSpacing { continue }
            shown.append((marker, x))
        }
        return shown
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let thumbX = progress(value) * width

            VStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: "#D9D9D9"))
                        .frame(height: trackHeight)

                    Capsule()
                        .fill(Color(hex: "#C82020"))
                        .frame(width: max(thumbX, 0), height: trackHeight)

                    ForEach(markers) { marker in
                        Rectangle()
                            .fill(Color(hex: "#595959"))
                            .frame(width: 2, height: 16)
                            .offset(x: min(max(progress(marker.hours) * width - 1, 0), max(width - 2, 0)))
                    }

                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color(hex: "#F4F4F4"))
                        .frame(width: thumbWidth, height: thumbHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                        .offset(x: min(max(thumbX - (thumbWidth / 2), 0), width - thumbWidth))
                }
                .frame(height: thumbHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let clampedX = min(max(gesture.location.x, 0), width)
                            let hours = (clampedX / width) * maxValue
                            value = (hours * 4).rounded() / 4
                        }
                )

                ZStack(alignment: .topLeading) {
                    ForEach(visibleLabels(width: width), id: \.0.id) { marker, x in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { value = marker.hours }
                        } label: {
                            Text(marker.label)
                                .font(.geist(size: 12, weight: .semibold))
                                .foregroundStyle(Color(hex: "#235187"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: "#EEF2F8"), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        .position(x: min(max(x, 24), max(width - 24, 24)), y: 12)
                    }
                }
                .frame(height: 24)
            }
        }
        .frame(height: 62)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview daily phone time")
        .accessibilityValue(formattedHours(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + 0.25, maxValue)
            case .decrement: value = max(value - 0.25, 0)
            @unknown default: break
            }
        }
        .accessibilityActions {
            ForEach(markers) { marker in
                Button("Jump to \(marker.label)") { value = marker.hours }
            }
        }
    }

    private func formattedHours(_ hours: Double) -> String {
        let minutes = Int((hours * 60).rounded())
        return "\(minutes / 60) hours \(minutes % 60) minutes a day"
    }
}
