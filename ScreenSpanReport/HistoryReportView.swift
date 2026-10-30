import SwiftUI
import Charts

/// Progress since the user started ScreenSpan, led by the plan when there is
/// one. Daily totals, the measured starting pace, and every comparison stay
/// inside this extension; the host supplies only the start date, an optional
/// starting point the user typed, and the plan the user chose.
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
    private let regainedColor = Color(hex: "#2BB673")
    private let regainedText = Color(hex: "#1F7A4D")
    private let cardColor = Color(hex: "#F6F7FA")
    private let iconColor = Color(hex: "#235187")
    private let goalColor = Color(hex: "#8A94A6")

    private var trackingStart: Date {
        payload.trackingStart(seconds: trackingStartSeconds)
    }

    private var goalHours: Double { goalMinutes / 60 }
    /// The plan's limits take the place of a single daily goal.
    private var hasPlan: Bool { !payload.plan.apps.isEmpty }

    var body: some View {
        let progress = payload.progress(trackingStartSeconds: trackingStartSeconds,
                                        savedStartingMinutes: savedStartingMinutes)
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if hasPlan {
                    PlanReportSection(payload: payload, currentAge: currentAge, targetAge: targetAge)
                }
                regainSection(progress)
                chartSection(progress)
                if !hasPlan { goalSection(progress) }
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

    // MARK: - Regained

    @ViewBuilder
    private func regainSection(_ progress: LifeRegainedProgress) -> some View {
        if let pace = progress.startingPaceHours,
           let current = progress.currentPaceHours,
           let regained = progress.regained(currentAge: currentAge, targetAge: targetAge) {
            let improving = regained.yearsReclaimed > 0
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("You’re on track to regain")
                        .font(.geist(size: 17, weight: .semibold))
                    Text(String(format: "%.1f years", regained.yearsReclaimed))
                        .font(.geist(size: 44, weight: .heavy))
                        .foregroundStyle(improving ? regainedText : ScreenSpanAppearance.text)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(improving
                         ? "of your life back by age \(targetAge). That’s \(wholeNumber(regained.monthsReclaimed)) months, or \(wholeNumber(regained.yearsReclaimed * 365)) days."
                         : "Your average since starting is at or above your starting pace. Every day under \(duration(pace)) adds time back.")
                        .font(.geist(size: 14))
                        .foregroundStyle(ScreenSpanAppearance.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                lifetimeComparison(startingPace: pace, currentPace: current, regained: regained)
                if let back = progress.hoursBackSoFar, back > 0 {
                    Label(alreadyBackText(back, progress: progress), systemImage: "checkmark.circle.fill")
                        .font(.geist(size: 14, weight: .semibold))
                        .foregroundStyle(regainedText)
                }
            }
            .padding(20)
            .background(Color(hex: improving ? "#EEF8F2" : "#F6F7FA"), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else if progress.startingPaceHours == nil {
            notice(icon: "flag",
                   title: "Add your starting point",
                   message: "Screen Time no longer has the week before you started on \(progress.startDay.formatted(date: .abbreviated, time: .omitted)). Enter your daily average from back then in Settings → Your progress to see the time you’re regaining.")
        } else {
            notice(icon: "hourglass",
                   title: "Your first day is in progress",
                   message: "Progress counts completed days. Check back tomorrow to see how much of your life you’re on track to regain.")
        }
    }

    /// Two lifetime bars on one scale: phone time at the starting pace, and
    /// at the current pace with the difference shown as time won back.
    private func lifetimeComparison(startingPace: Double, currentPace: Double, regained: ReclaimResult) -> some View {
        let before = ProjectionCalculator.calculateProjectionFromDaily(
            currentAge: currentAge, targetAge: targetAge, dailyHours: startingPace).yearsOnPhone
        let now = ProjectionCalculator.calculateProjectionFromDaily(
            currentAge: currentAge, targetAge: targetAge, dailyHours: currentPace).yearsOnPhone
        let scale = max(before, now, 0.01)
        return VStack(alignment: .leading, spacing: 12) {
            comparisonRow(title: "Before ScreenSpan", detail: "\(duration(startingPace)) a day", years: before) { width in
                Capsule().fill(startingPaceColor).frame(width: width * before / scale)
            }
            comparisonRow(title: "Now", detail: "\(duration(currentPace)) a day", years: now) { width in
                HStack(spacing: 2) {
                    Capsule().fill(lineColor).frame(width: max(width * now / scale - 1, 0))
                    if regained.yearsReclaimed > 0 {
                        Capsule().fill(regainedColor.opacity(0.35))
                            .overlay(Capsule().strokeBorder(regainedColor, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                            .frame(width: max(width * (before - now) / scale - 1, 0))
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Projected phone time by age \(targetAge): \(String(format: "%.1f", before)) years at your starting pace, \(String(format: "%.1f", now)) years at your current pace.")
    }

    private func comparisonRow<Bar: View>(
        title: String, detail: String, years: Double, @ViewBuilder bar: @escaping (CGFloat) -> Bar
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.geist(size: 13, weight: .semibold))
                Text(detail).font(.geist(size: 12)).foregroundStyle(ScreenSpanAppearance.secondaryText)
                Spacer()
                Text(String(format: "%.1f yrs on phone", years))
                    .font(.geist(size: 12, weight: .medium))
                    .foregroundStyle(ScreenSpanAppearance.secondaryText)
                    .monospacedDigit()
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.9))
                    bar(proxy.size.width)
                }
            }
            .frame(height: 12)
        }
    }

    private func alreadyBackText(_ hours: Double, progress: LifeRegainedProgress) -> String {
        let span = progress.coversWholeSinceStart
            ? "since you started"
            : "in the last \(dayCount(progress.trackedDays.count))"
        let wakingDays = hours / SharedConstants.DefaultValues.wakeHoursPerDay
        let equivalent = wakingDays >= 1
            ? " · about \(wholeNumber(wakingDays)) waking \(wakingDays < 1.5 ? "day" : "days")"
            : ""
        return "\(duration(hours)) back \(span)\(equivalent)"
    }

    // MARK: - Chart

    private func chartSection(_ progress: LifeRegainedProgress) -> some View {
        let domain = ActivitySummary.dashboardInterval(trackingStart: trackingStart)
        let days = payload.history.within(domain)
        let trendRuns = contiguousRuns(ActivityDay.trailingAverages(of: days))
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

            VStack(alignment: .leading, spacing: 12) {
                Chart {
                    if showsStart {
                        RectangleMark(xStart: .value("Before", domain.start), xEnd: .value("Started", progress.startDay))
                            .foregroundStyle(Color(hex: "#E3E7EE").opacity(0.7))
                            .annotation(position: .top, alignment: .leading) {
                                Text("Before").font(.geist(size: 10)).foregroundStyle(ScreenSpanAppearance.secondaryText)
                            }
                    }
                    ForEach(days) { day in
                        BarMark(x: .value("Day", day.date, unit: .day), y: .value("Hours", day.hours), width: .ratio(0.6))
                            .foregroundStyle(lineColor.opacity(0.28))
                            .cornerRadius(2)
                    }
                    ForEach(Array(trendRuns.enumerated()), id: \.offset) { index, run in
                        ForEach(run) { day in
                            LineMark(x: .value("Day", day.date, unit: .day),
                                     y: .value("Seven-day average", day.hours),
                                     series: .value("Run", index))
                                .interpolationMethod(.monotone)
                                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                                .foregroundStyle(lineColor)
                        }
                    }
                    if let pace = progress.startingPaceHours {
                        RuleMark(y: .value("Starting pace", pace))
                            .foregroundStyle(startingPaceColor)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                    }
                    if !hasPlan {
                        RuleMark(y: .value("Daily goal", goalHours))
                            .foregroundStyle(goalColor)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
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
                    AxisMarks(position: .leading) { value in
                        AxisGridLine().foregroundStyle(Color(hex: "#D9DDE5"))
                        AxisValueLabel {
                            if let hours = value.as(Double.self) { Text("\(hours.formatted())h") }
                        }
                        .foregroundStyle(ScreenSpanAppearance.secondaryText)
                    }
                }
                .frame(height: 190)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(chartSummary(progress))

                HStack(spacing: 14) {
                    legendSwatch(Capsule().fill(lineColor.opacity(0.28)).frame(width: 8, height: 12), "Daily")
                    legendSwatch(Capsule().fill(lineColor).frame(width: 16, height: 3), "7-day avg")
                    if progress.startingPaceHours != nil {
                        legendSwatch(dash(startingPaceColor), "Start")
                    }
                    if !hasPlan { legendSwatch(dash(goalColor), "Goal") }
                }
            }
            .padding(18)
            .background(cardColor, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private func dash(_ color: Color) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 1.5))
            path.addLine(to: CGPoint(x: 16, y: 1.5))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
        .frame(width: 16, height: 3)
    }

    private func legendSwatch<Swatch: View>(_ swatch: Swatch, _ title: String) -> some View {
        HStack(spacing: 5) {
            swatch
            Text(title).font(.geist(size: 11)).foregroundStyle(ScreenSpanAppearance.secondaryText)
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
        var parts = ["Daily screen time for \(dayCount(progress.trackedDays.count)) since starting"]
        if let current = progress.currentPaceHours { parts.append("averaging \(duration(current)) a day") }
        if let pace = progress.startingPaceHours { parts.append("starting pace \(duration(pace)) a day") }
        if !hasPlan { parts.append("goal \(duration(goalHours)) a day") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Goal

    @ViewBuilder
    private func goalSection(_ progress: LifeRegainedProgress) -> some View {
        let adherence = GoalAdherence(days: payload.history, goalHours: goalHours, startDay: progress.startDay)
        if adherence.daysReported > 0 {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Daily goal")
                        .font(.geist(size: 20, weight: .semibold))
                    Spacer()
                    Text("\(duration(goalHours)) or less")
                        .font(.geist(size: 13, weight: .medium))
                        .foregroundStyle(ScreenSpanAppearance.secondaryText)
                }
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(adherence.daysMet) of \(dayCount(adherence.daysReported))")
                                .font(.geist(size: 22, weight: .bold))
                                .monospacedDigit()
                            Text("at or under your goal")
                                .font(.geist(size: 13))
                                .foregroundStyle(ScreenSpanAppearance.secondaryText)
                        }
                        Spacer()
                        if adherence.currentStreak > 0 {
                            Label("\(adherence.currentStreak)-day streak", systemImage: "flame.fill")
                                .font(.geist(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: "#C25E00"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(hex: "#FFF1E0"), in: Capsule())
                        }
                    }
                    goalDays(adherence)
                }
                .padding(18)
                .background(cardColor, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func goalDays(_ adherence: GoalAdherence) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(adherence.recent) { day in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(day.met == true ? regainedColor : day.met == false ? startingPaceColor.opacity(0.75) : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(day.met == nil ? Color(hex: "#C5CCD6") : .clear, style: StrokeStyle(lineWidth: 1, dash: [2])))
                        .frame(maxWidth: 22)
                        .frame(height: 22)
                        .accessibilityLabel(goalDayLabel(day))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let first = adherence.recent.first {
                HStack {
                    Text(first.date.formatted(.dateTime.month(.abbreviated).day()))
                    Spacer()
                    Text("Yesterday")
                }
                .font(.geist(size: 10))
                .foregroundStyle(ScreenSpanAppearance.secondaryText)
            }
        }
    }

    private func goalDayLabel(_ day: GoalAdherence.Day) -> String {
        let date = day.date.formatted(.dateTime.weekday(.wide).month().day())
        guard let hours = day.hours else { return "\(date): not reported" }
        return "\(date): \(duration(hours)), \(day.met == true ? "goal met" : "over goal")"
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

    // MARK: - Formatting

    private func duration(_ hours: Double) -> String {
        let minutes = Int((hours * 60).rounded())
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private func shortDuration(_ hours: Double) -> String {
        hours < 1 ? "\(Int((hours * 60).rounded()))m" : String(format: "%.1fh", hours)
    }

    private func wholeNumber(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }

    private func dayCount(_ count: Int) -> String {
        count == 1 ? "1 day" : "\(count) days"
    }
}

extension ScreenTimeReportPayload {
    func trackingStart(seconds: Double) -> Date {
        seconds > 0 ? Date(timeIntervalSince1970: seconds) : Date()
    }

    /// Shared by Progress and Life Grid so both use the same starting pace.
    func progress(trackingStartSeconds: Double, savedStartingMinutes: Double) -> LifeRegainedProgress {
        LifeRegainedProgress(days: history, trackingStart: trackingStart(seconds: trackingStartSeconds),
                             savedStartingMinutes: savedStartingMinutes)
    }
}
