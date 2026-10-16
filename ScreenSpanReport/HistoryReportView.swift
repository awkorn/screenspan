import SwiftUI
import Charts

/// Progress since the user started ScreenSpan. Daily totals, the measured
/// starting pace, and every comparison stay inside this extension; the host
/// supplies only the start date and an optional starting point the user typed.
struct HistoryReportView: View {
    let payload: ScreenTimeReportPayload
    @AppStorage(SharedConstants.UserDefaultsKey.screenTimeGoalMinutes.rawValue, store: .appGroup)
    private var goalMinutes: Double = 120
    @AppStorage(SharedConstants.UserDefaultsKey.currentAge.rawValue, store: .appGroup)
    private var currentAge = 25
    @AppStorage(SharedConstants.UserDefaultsKey.targetAge.rawValue, store: .appGroup)
    private var targetAge = 80
    @AppStorage(SharedConstants.UserDefaultsKey.trackingStartDate.rawValue, store: .appGroup)
    private var trackingStartSeconds: Double = 0
    @AppStorage(SharedConstants.UserDefaultsKey.startingDailyMinutes.rawValue, store: .appGroup)
    private var savedStartingMinutes: Double = 0

    private let lineColor = Color(hex: "#0063D6")
    private let startingPaceColor = Color(hex: "#F63232")
    private let cardColor = Color(hex: "#F6F7FA")
    private let iconColor = Color(hex: "#235187")

    private var trackingStart: Date {
        trackingStartSeconds > 0 ? Date(timeIntervalSince1970: trackingStartSeconds) : Date()
    }

    private var progress: LifeRegainedProgress {
        LifeRegainedProgress(days: payload.history, trackingStart: trackingStart,
                             savedStartingMinutes: savedStartingMinutes)
    }

    var body: some View {
        let progress = progress
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                chartSection(progress)
                regainSection(progress)
                currentSection(progress)
                Text("Projections compare your daily average since starting with your starting pace, from now until age \(targetAge). Days Screen Time did not report are left out, not counted as zero.")
                    .font(.geist(size: 12))
                    .foregroundStyle(ScreenSpanAppearance.secondaryText)
            }
            .padding(24)
        }
        .background(Color.white)
        .screenSpanLightSurface()
    }

    // MARK: - Chart

    private func chartSection(_ progress: LifeRegainedProgress) -> some View {
        let domain = ActivitySummary.dashboardInterval(trackingStart: trackingStart)
        let runs = contiguousRuns(payload.history.within(domain))
        let showsStart = progress.startDay > domain.start
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Screen time over time")
                    .font(.geist(size: 20, weight: .semibold))
                Text(progress.coversWholeSinceStart
                     ? "Since you started on \(progress.startDay.formatted(.dateTime.month(.abbreviated).day()))"
                     : "Last \(SharedConstants.DefaultValues.progressHistoryDays) days")
                    .font(.geist(size: 13))
                    .foregroundStyle(ScreenSpanAppearance.secondaryText)
            }

            Chart {
                if showsStart {
                    RectangleMark(xStart: .value("Before", domain.start), xEnd: .value("Started", progress.startDay))
                        .foregroundStyle(Color(hex: "#E9EDF3").opacity(0.6))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Before").font(.geist(size: 10)).foregroundStyle(ScreenSpanAppearance.secondaryText)
                        }
                }
                ForEach(Array(runs.enumerated()), id: \.offset) { index, run in
                    ForEach(run) { day in
                        LineMark(x: .value("Day", day.date, unit: .day),
                                 y: .value("Hours", day.hours),
                                 series: .value("Run", index))
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(lineColor)
                        if run.count == 1 {
                            PointMark(x: .value("Day", day.date, unit: .day), y: .value("Hours", day.hours))
                                .foregroundStyle(lineColor)
                        }
                    }
                }
                if let pace = progress.startingPaceHours {
                    RuleMark(y: .value("Starting pace", pace))
                        .foregroundStyle(startingPaceColor)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Start").font(.geist(size: 10)).foregroundStyle(startingPaceColor)
                        }
                }
                RuleMark(y: .value("Daily goal", goalMinutes / 60))
                    .foregroundStyle(Color(hex: "#8A94A6"))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .annotation(position: .bottom, alignment: .trailing) {
                        Text("Goal").font(.geist(size: 10)).foregroundStyle(ScreenSpanAppearance.secondaryText)
                    }
            }
            .chartXScale(domain: domain.start...domain.end)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: domain.duration > 15 * 86_400 ? 7 : 2)) {
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(ScreenSpanAppearance.secondaryText)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisGridLine().foregroundStyle(Color(hex: "#D9DDE5"))
                    AxisValueLabel().foregroundStyle(ScreenSpanAppearance.secondaryText)
                }
            }
            .chartYAxisLabel(position: .leading) {
                Text("hours").foregroundStyle(ScreenSpanAppearance.secondaryText)
            }
            .frame(height: 200)
            .padding(18)
            .background(cardColor, in: RoundedRectangle(cornerRadius: 18))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(chartSummary(progress))
        }
    }

    /// Separate line series per run of consecutive days, so a missing day
    /// shows as a gap instead of an invented straight line.
    private func contiguousRuns(_ days: [ActivityDay]) -> [[ActivityDay]] {
        let calendar = Calendar.current
        var runs: [[ActivityDay]] = []
        for day in days {
            if let previous = runs.last?.last,
               calendar.dateComponents([.day], from: previous.date, to: day.date).day == 1 {
                runs[runs.count - 1].append(day)
            } else {
                runs.append([day])
            }
        }
        return runs
    }

    private func chartSummary(_ progress: LifeRegainedProgress) -> String {
        var parts = ["Daily screen time for \(progress.trackedDays.count) days since starting"]
        if let current = progress.currentPaceHours { parts.append("averaging \(duration(current)) a day") }
        if let pace = progress.startingPaceHours { parts.append("starting pace \(duration(pace)) a day") }
        parts.append("goal \(duration(goalMinutes / 60)) a day")
        return parts.joined(separator: ", ")
    }

    // MARK: - Regained

    private func regainSection(_ progress: LifeRegainedProgress) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("You’re on track to regain")
                .font(.geist(size: 20, weight: .semibold))
            if let pace = progress.startingPaceHours,
               let current = progress.currentPaceHours,
               let regained = progress.regained(currentAge: currentAge, targetAge: targetAge) {
                HStack(spacing: 10) {
                    regainTile(String(format: "%.1f", regained.yearsReclaimed), unit: "years", icon: "calendar")
                    regainTile(String(format: "%.0f", regained.monthsReclaimed), unit: "months", icon: "calendar.badge.clock")
                    regainTile((regained.yearsReclaimed * 365).formatted(.number.precision(.fractionLength(0))),
                               unit: "days", icon: "sun.max")
                }
                Text(current < pace
                     ? "of your life back by age \(targetAge) since starting ScreenSpan, averaging \(duration(current)) a day instead of \(duration(pace))."
                     : "Your daily average since starting is \(duration(current)), at or above your \(duration(pace)) starting pace. Every day under it adds time back.")
                    .font(.geist(size: 13))
                    .foregroundStyle(ScreenSpanAppearance.secondaryText)
                if let back = progress.hoursBackSoFar, back > 0 {
                    Label(progress.coversWholeSinceStart
                          ? "\(duration(back)) back already across \(dayCount(progress.trackedDays.count))"
                          : "\(duration(back)) back in the last \(dayCount(progress.trackedDays.count))",
                          systemImage: "checkmark.circle.fill")
                        .font(.geist(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "#2E7D32"))
                }
            } else if progress.startingPaceHours == nil {
                notice(icon: "flag",
                       title: "Add your starting point",
                       message: "Screen Time no longer has the week before you started on \(progress.startDay.formatted(date: .abbreviated, time: .omitted)). Enter your daily average from back then in Settings → Your progress to keep tracking.")
            } else {
                notice(icon: "hourglass",
                       title: "Your first day is in progress",
                       message: "Progress counts completed days. Check back tomorrow to see the time you’re regaining.")
            }
        }
    }

    private func regainTile(_ value: String, unit: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(iconColor)
            Text(value).font(.geist(size: 26, weight: .bold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(unit).font(.geist(size: 15, weight: .medium)).foregroundStyle(ScreenSpanAppearance.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(cardColor, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    private func notice(icon: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(iconColor).frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.geist(size: 15, weight: .semibold))
                Text(message).font(.geist(size: 13)).foregroundStyle(ScreenSpanAppearance.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardColor, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Current screen time

    private func currentSection(_ progress: LifeRegainedProgress) -> some View {
        let pace = progress.startingPaceHours
        let yesterday = progress.trackedDays(inLast: 1).first
        let lastWeek = progress.trackedDays(inLast: 7)
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current screen time")
                    .font(.geist(size: 20, weight: .semibold))
                if let pace {
                    (Text("You started at: ") + Text("\(duration(pace)) / day").fontWeight(.semibold)
                     + Text(progress.startingPaceSource == .saved ? " (your entry)" : ""))
                        .font(.geist(size: 13))
                }
            }
            if let yesterday {
                metric("Yesterday", hours: yesterday.hours, saved: pace.map { $0 - yesterday.hours }, icon: "clock")
            }
            if !lastWeek.isEmpty {
                let total = lastWeek.map(\.hours).reduce(0, +)
                metric(lastWeek.count == 7 ? "Last 7 days" : "Last \(dayCount(lastWeek.count))",
                       hours: total, saved: pace.map { $0 * Double(lastWeek.count) - total }, icon: "calendar")
            }
            if let current = progress.currentPaceHours {
                metric("Daily average since starting", hours: current,
                       saved: pace.map { $0 - current }, icon: "chart.line.downtrend.xyaxis")
            }
        }
    }

    private func metric(_ title: String, hours: Double, saved: Double?, icon: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.geist(size: 20, weight: .medium))
                .foregroundStyle(ScreenSpanAppearance.text)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.geist(size: 13)).foregroundStyle(iconColor)
                Text(duration(hours)).font(.geist(size: 18, weight: .semibold)).monospacedDigit()
            }
            Spacer()
            if let saved { deltaBadge(saved) }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(cardColor, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func deltaBadge(_ saved: Double) -> some View {
        let isLower = saved >= 0
        return HStack(spacing: 4) {
            Image(systemName: isLower ? "arrow.down" : "arrow.up")
            Text(shortDuration(abs(saved)))
        }
        .font(.geist(size: 14, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(Color(hex: isLower ? "#2E7D32" : "#C82020"))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(hex: isLower ? "#DDF2DC" : "#FDE2E2"), in: RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel("\(duration(abs(saved))) \(isLower ? "less" : "more") than your starting pace")
    }

    // MARK: - Formatting

    private func duration(_ hours: Double) -> String {
        let minutes = Int((hours * 60).rounded())
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private func shortDuration(_ hours: Double) -> String {
        hours < 1 ? "\(Int((hours * 60).rounded()))m" : String(format: "%.1fh", hours)
    }

    private func dayCount(_ count: Int) -> String {
        count == 1 ? "1 day" : "\(count) days"
    }
}
