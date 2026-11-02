import DeviceActivity
import FamilyControls
import SwiftUI

/// The plan at the top of the Plan tab: what reaching the goals is worth,
/// then each app from where it started to its goal. Usage and comparisons
/// stay in this extension; the plan itself is the user's choices, read from
/// the App Group.
struct PlanReportSection: View {
    let payload: ScreenTimeReportPayload
    let currentAge: Int
    let targetAge: Int

    private var progress: [(app: PlannedApp, progress: PlanAppProgress)] {
        payload.plan.apps.map { ($0, PlanAppProgress(course: $0.course, usage: payload.planUsage[$0.id] ?? [])) }
    }

    var body: some View {
        let progress = progress
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your plan")
                    .font(.geist(size: 20, weight: .semibold))
                Text("Your limits drop each week until you reach your goal.")
                    .font(.geist(size: 13))
                    .foregroundStyle(ScreenSpanAppearance.secondaryText)
            }
            goalCard(progress.map(\.progress))
            ForEach(progress, id: \.app.id) { item in
                PlanAppCard(app: item.app, progress: item.progress, todayMinutes: payload.planToday[item.app.id],
                            currentAge: currentAge, targetAge: targetAge)
            }
            if let shift = otherAppsShift, shift >= 20 {
                Label("Other apps went up \(PlanReportFormat.duration(shift)) a day since your plan started. If one app took over, add it to your plan.",
                      systemImage: "arrow.left.arrow.right")
                    .font(.geist(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "#8A5A00"))
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#FFF6E5"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    /// The payoff for reaching every goal, and how much of the daily time
    /// is back so far.
    private func goalCard(_ apps: [PlanAppProgress]) -> some View {
        let courses = apps.map(\.course)
        let atGoal = courses.minutesBackAtTarget
        let years = courses.regainedAtTarget(currentAge: currentAge, targetAge: targetAge).yearsReclaimed
        let measured = apps.compactMap(\.minutesBackSinceStart)
        let back = measured.isEmpty ? nil : max(measured.reduce(0, +), 0)
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("+\(PlanReportFormat.years(years))")
                    .font(.geist(size: 40, weight: .heavy))
                    .foregroundStyle(PlanReportStyle.green)
                    .monospacedDigit()
                Text("of your life back by age \(targetAge) at your \(courses.count == 1 ? "goal" : "goals")")
                    .font(.geist(size: 14, weight: .medium))
                    .foregroundStyle(ScreenSpanAppearance.secondaryText)
            }
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white)
                        Capsule().fill(PlanReportStyle.brightGreen)
                            .frame(width: proxy.size.width * min((back ?? 0) / Double(max(atGoal, 1)), 1))
                    }
                }
                .frame(height: 10)
                Text(back.map { "\(PlanReportFormat.duration($0)) of \(PlanReportFormat.duration(Double(atGoal))) a day back so far" }
                     ?? "\(PlanReportFormat.duration(Double(atGoal))) a day back at your \(courses.count == 1 ? "goal" : "goals")")
                    .font(.geist(size: 13, weight: .semibold))
                    .monospacedDigit()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#EEF8F2"), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var otherAppsShift: Double? {
        guard let start = payload.plan.apps.map({ $0.course.steps[0].startedAt }).min() else { return nil }
        return PlanProgress.otherAppsChangeMinutes(
            total: payload.history,
            planned: payload.plan.apps.map { payload.planUsage[$0.id] ?? [] },
            planStart: start)
    }
}

enum PlanReportStyle {
    static let green = Color(hex: "#1F7A4D")
    static let brightGreen = Color(hex: "#2BB673")
    static let amber = Color(hex: "#F2A93B")
    static let card = Color(hex: "#F6F7FA")
    static let line = Color(hex: "#D5DBE3")
}

/// One planned app: what's left of today's limit, this week's days, and
/// every week from where it started to its goal.
private struct PlanAppCard: View {
    let app: PlannedApp
    let progress: PlanAppProgress
    /// Minutes used so far today.
    let todayMinutes: Double?
    let currentAge: Int
    let targetAge: Int
    @State private var showsWeeks = false

    private var course: ReductionCourse { progress.course }

    var body: some View {
        let now = Date()
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                PlannedAppLabel(selection: app.selection)
                Spacer(minLength: 8)
                pill(now: now)
            }
            if let limit = progress.currentLimit, let used = todayMinutes {
                today(used: used, limit: limit)
            } else {
                // Before the first limit starts, or before Screen Time reports today.
                Text(progress.currentLimit.map { "\(PlanReportFormat.duration(Double($0))) limit today" }
                     ?? "Starts tonight at \(PlanReportFormat.duration(Double(course.firstMinutes))) a day")
                    .font(.geist(size: 14, weight: .semibold))
                    .monospacedDigit()
            }
            if progress.stepIndex != nil {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        sectionLabel("THIS WEEK")
                        Spacer()
                        if progress.daysReported > 0 {
                            Text("\(progress.daysWithin) of \(progress.daysReported) days on plan")
                                .font(.geist(size: 12, weight: .semibold))
                                .foregroundStyle(progress.daysWithin > 0 ? PlanReportStyle.green : ScreenSpanAppearance.secondaryText)
                        }
                    }
                    PlanWeekStrip(days: progress.stepDays)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.snappy) { showsWeeks.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        sectionLabel("WEEK BY WEEK")
                        Spacer(minLength: 8)
                        Text(goalSummary(now: now))
                            .font(.geist(size: 12, weight: .medium))
                            .foregroundStyle(ScreenSpanAppearance.secondaryText)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ScreenSpanAppearance.secondaryText)
                            .rotationEffect(.degrees(showsWeeks ? 180 : 0))
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Week by week, \(goalSummary(now: now))")
                .accessibilityValue(showsWeeks ? "Shown" : "Hidden")
                if showsWeeks {
                    PlanTimeline(course: course, now: now,
                                 goalYears: course.regained(atLimit: course.targetMinutes, currentAge: currentAge, targetAge: targetAge).yearsReclaimed)
                        .transition(.opacity)
                }
            }
        }
        .padding(18)
        .background(PlanReportStyle.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    /// Time left on today's limit. Using it all is still on plan.
    private func today(used: Double, limit: Int) -> some View {
        let left = Double(limit) - used
        let isUsedUp = left < 1
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                if isUsedUp {
                    Label("Blocked until midnight", systemImage: "lock.fill")
                        .font(.geist(size: 14, weight: .semibold))
                } else {
                    Text("\(PlanReportFormat.duration(left)) left today")
                        .font(.geist(size: 14, weight: .semibold))
                        .foregroundStyle(PlanReportStyle.green)
                }
                Spacer(minLength: 8)
                Text("\(PlanReportFormat.duration(min(used, Double(limit)))) of \(PlanReportFormat.duration(Double(limit))) used")
                    .font(.geist(size: 12))
                    .foregroundStyle(ScreenSpanAppearance.secondaryText)
            }
            .monospacedDigit()
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white)
                    Capsule().fill(isUsedUp ? ScreenSpanAppearance.text : PlanReportStyle.brightGreen)
                        .frame(width: proxy.size.width * min(max(used / Double(max(limit, 1)), 0), 1))
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .combine)
    }

    /// The collapsed timeline's one line: where the plan ends up, and when.
    private func goalSummary(now: Date) -> String {
        let goal = "\(PlanReportFormat.duration(Double(course.targetMinutes))) a day"
        let date = course.goalDate()
        return date > now ? "\(goal) by \(date.formatted(.dateTime.month(.abbreviated).day()))" : "At \(goal)"
    }

    private func pill(now: Date) -> some View {
        let weeks = course.weeksToGoal(at: now)
        let text = weeks.map { $0 == 1 ? "1 week to goal" : "\($0) weeks to goal" } ?? "Goal reached"
        return Text(text)
            .font(.geist(size: 12, weight: .semibold))
            .foregroundStyle(weeks == nil ? PlanReportStyle.green : ScreenSpanAppearance.secondaryText)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(weeks == nil ? Color(hex: "#E3F5EB") : Color.white, in: Capsule())
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.geist(size: 11, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(ScreenSpanAppearance.secondaryText)
    }
}

/// Every limit from where the app started to its goal, as a vertical line:
/// finished weeks checked off, this week highlighted, the rest ahead.
private struct PlanTimeline: View {
    let course: ReductionCourse
    let now: Date
    let goalYears: Double

    var body: some View {
        let entries = course.schedule(at: now)
        VStack(spacing: 0) {
            row(marker: AnyView(Circle().strokeBorder(PlanReportStyle.line, lineWidth: 2).frame(width: 12, height: 12)),
                title: "Where you started", detail: nil,
                minutes: course.baselineMinutes, isFirst: true, isLast: entries.isEmpty, muted: true)
            ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                row(marker: marker(entry), title: title(entry), detail: detail(entry),
                    minutes: entry.dailyMinutes, isFirst: false, isLast: index == entries.count - 1,
                    isCurrent: entry.kind == .current, isGoal: entry.isGoal, muted: entry.kind == .past)
            }
        }
    }

    private func row(marker: AnyView, title: String, detail: String?, minutes: Int,
                     isFirst: Bool, isLast: Bool, isCurrent: Bool = false, isGoal: Bool = false, muted: Bool = false) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 0) {
                Rectangle().fill(isFirst ? Color.clear : PlanReportStyle.line).frame(width: 2).frame(maxHeight: .infinity)
                marker.frame(width: 20, height: 20)
                Rectangle().fill(isLast ? Color.clear : PlanReportStyle.line).frame(width: 2).frame(maxHeight: .infinity)
            }
            .frame(width: 20)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.geist(size: 14, weight: isCurrent || isGoal ? .semibold : .regular))
                        .foregroundStyle(muted ? ScreenSpanAppearance.secondaryText : ScreenSpanAppearance.text)
                    if let detail {
                        Text(detail)
                            .font(.geist(size: 12))
                            .foregroundStyle(isGoal ? PlanReportStyle.green : ScreenSpanAppearance.secondaryText)
                    }
                }
                Spacer(minLength: 8)
                Text("\(PlanReportFormat.duration(Double(minutes))) a day")
                    .font(.geist(size: 14, weight: isCurrent || isGoal ? .bold : .medium))
                    .foregroundStyle(isGoal ? PlanReportStyle.green : muted ? ScreenSpanAppearance.secondaryText : ScreenSpanAppearance.text)
                    .monospacedDigit()
            }
            .padding(.vertical, 9)
            .padding(.horizontal, isCurrent ? 10 : 0)
            .background(isCurrent ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private func marker(_ entry: ReductionCourse.ScheduleEntry) -> AnyView {
        if entry.isGoal {
            return AnyView(Image(systemName: "flag.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(PlanReportStyle.brightGreen))
        }
        switch entry.kind {
        case .past:
            return AnyView(Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(PlanReportStyle.brightGreen))
        case .current:
            return AnyView(Circle().fill(ScreenSpanAppearance.text).frame(width: 14, height: 14)
                .overlay(Circle().strokeBorder(Color.white, lineWidth: 3)))
        case .upcoming:
            return AnyView(Circle().fill(Color.white).frame(width: 12, height: 12)
                .overlay(Circle().strokeBorder(PlanReportStyle.line, lineWidth: 2)))
        }
    }

    private func title(_ entry: ReductionCourse.ScheduleEntry) -> String {
        switch entry.kind {
        case .current: return entry.isGoal ? "Goal reached" : "This week"
        case .past: return range(entry)
        case .upcoming:
            if entry.isGoal { return "Goal" }
            if Calendar.current.isDateInTomorrow(entry.start) || Calendar.current.isDate(entry.start, inSameDayAs: now) {
                return "From tomorrow"
            }
            return "Week of \(entry.start.formatted(.dateTime.month(.abbreviated).day()))"
        }
    }

    private func detail(_ entry: ReductionCourse.ScheduleEntry) -> String? {
        if entry.isGoal {
            let years = "+\(PlanReportFormat.years(goalYears)) of life back"
            return entry.kind == .upcoming ? "From \(entry.start.formatted(.dateTime.month(.abbreviated).day()))\n\(years)" : years
        }
        return entry.kind == .current ? range(entry) : nil
    }

    /// "Oct 24 – 30", inclusive of the last day.
    private func range(_ entry: ReductionCourse.ScheduleEntry) -> String {
        let calendar = Calendar.current
        guard let end = entry.end, let last = calendar.date(byAdding: .day, value: -1, to: end), last > entry.start else {
            return entry.start.formatted(.dateTime.month(.abbreviated).day())
        }
        return (entry.start..<last).formatted(.interval.month(.abbreviated).day())
    }
}

/// The week's days as bars against the limit: green at or under it, amber
/// the rare day well past it, dashed when Screen Time didn't report the day,
/// faint for days still ahead.
struct PlanWeekStrip: View {
    let days: [PlanAppProgress.Day]

    var body: some View {
        let shown = Array(days.suffix(ReductionCourse.stepDays))  // matches PlanAppProgress.recentDays
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(0..<ReductionCourse.stepDays, id: \.self) { index in
                VStack(spacing: 4) {
                    bar(index < shown.count ? shown[index] : nil)
                        .frame(height: 44, alignment: .bottom)
                    Text(index < shown.count ? shown[index].date.formatted(.dateTime.weekday(.narrow)) : " ")
                        .font(.geist(size: 10))
                        .foregroundStyle(ScreenSpanAppearance.secondaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func bar(_ day: PlanAppProgress.Day?) -> some View {
        if let day, let hours = day.hours {
            let share = min(max(hours * 60 / Double(max(day.limitMinutes, 1)), 0.06), 1)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(day.stayedWithin ? PlanReportStyle.brightGreen : PlanReportStyle.amber)
                .frame(height: 44 * share)
        } else if day != nil {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(Color(hex: "#C5CCD6"), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
        } else {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(hex: "#E3E7EE"))
        }
    }
}

/// A planned app's name and icon, drawn by iOS from its token.
struct PlannedAppLabel: View {
    let selection: FamilyActivitySelection

    var body: some View {
        Group {
            if let token = selection.applicationTokens.first {
                Label(token)
            } else if let token = selection.categoryTokens.first {
                Label(token)
            } else if let token = selection.webDomainTokens.first {
                Label(token)
            } else {
                Text("App")
            }
        }
        .labelStyle(.titleAndIcon)
        .font(.geist(size: 15, weight: .semibold))
        .lineLimit(1)
    }
}

enum PlanReportFormat {
    static func duration(_ minutes: Double) -> String {
        let minutes = max(Int(minutes.rounded()), 0)
        if minutes < 60 { return "\(minutes)m" }
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }

    static func years(_ years: Double) -> String {
        if years >= 1 { return String(format: "%.1f years", years) }
        let months = years * 12
        if months >= 1 { return "\(Int(months.rounded())) months" }
        return "\(Int((years * 365).rounded())) days"
    }
}
