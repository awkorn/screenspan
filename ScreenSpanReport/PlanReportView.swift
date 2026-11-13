import DeviceActivity
import FamilyControls
import SwiftUI

/// The plan at the top of the Plan tab, kept to one message: the days the
/// plan was kept, what that pace is worth in years, and what reaching the
/// goals would be worth. Then each app's time today. Usage and comparisons
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
        let now = Date()
        VStack(alignment: .leading, spacing: 14) {
            summaryCard(progress.map(\.progress), now: now)
            ForEach(progress, id: \.app.id) { item in
                PlanAppCard(app: item.app, progress: item.progress, spread: payload.plan.spread(at: now),
                            todayMinutes: payload.planToday[item.app.id], now: now)
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

    // MARK: - The week and the years

    private func summaryCard(_ apps: [PlanAppProgress], now: Date) -> some View {
        let days = PlanProgress.recentDays(apps: payload.plan.apps.map { ($0.course, payload.planUsage[$0.id] ?? []) }, now: now)
        let streak = PlanProgress.streak(days)
        let courses = apps.map(\.course)
        let goalYears = courses.regainedAtTarget(currentAge: currentAge, targetAge: targetAge).yearsReclaimed
        let measured = apps.compactMap(\.minutesBackSinceStart)
        let backMinutes = measured.isEmpty ? nil : max(measured.reduce(0, +), 0)
        let soFarYears = backMinutes.map {
            ProjectionCalculator.calculateRegained(startingDailyHours: $0 / 60, currentDailyHours: 0,
                                                   currentAge: currentAge, targetAge: targetAge).yearsReclaimed
        }
        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Your plan")
                        .font(.geist(size: 20, weight: .semibold))
                    Spacer()
                    if streak >= 2 {
                        Label("\(streak) days in a row", systemImage: "flame.fill")
                            .font(.geist(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: "#C25E00"))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color(hex: "#FFF1E0"), in: Capsule())
                    }
                }
                PlanDayCircles(days: days)
                Text(weekLine(days))
                    .font(.geist(size: 14, weight: .semibold))
                    .foregroundStyle(days.contains { $0.state == .kept } ? PlanReportStyle.green : ScreenSpanAppearance.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Rectangle().fill(Color(hex: "#D3EBDD")).frame(height: 1)
            years(soFar: soFarYears, goal: goalYears, backMinutes: backMinutes, goalMinutes: courses.minutesBackAtTarget,
                  goals: courses.count)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#EEF8F2"), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// What the plan is worth: at the pace kept so far, and at the goals.
    private func years(soFar: Double?, goal: Double, backMinutes: Double?, goalMinutes: Int, goals: Int) -> some View {
        let reach = goals == 1 ? "your goal" : "your goals"
        return VStack(alignment: .leading, spacing: 12) {
            if let soFar, let backMinutes {
                VStack(alignment: .leading, spacing: 2) {
                    Text("+\(PlanReportFormat.years(soFar))")
                        .font(.geist(size: 40, weight: .heavy))
                        .foregroundStyle(soFar > 0 ? PlanReportStyle.green : ScreenSpanAppearance.text)
                        .monospacedDigit()
                    Text(soFar > 0
                         ? "of your life back by age \(targetAge), at the pace you’ve kept so far (\(PlanReportFormat.duration(backMinutes)) less a day)."
                         : "So far you’re using these apps as much as when you started. Every day you keep your limits moves this number.")
                        .font(.geist(size: 14, weight: .medium))
                        .foregroundStyle(ScreenSpanAppearance.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white)
                            Capsule().fill(PlanReportStyle.brightGreen)
                                .frame(width: proxy.size.width * min(soFar / max(goal, 0.0001), 1))
                        }
                    }
                    .frame(height: 10)
                    (Text("+\(PlanReportFormat.years(goal))").fontWeight(.bold)
                     + Text(" if you reach \(reach): \(PlanReportFormat.duration(Double(goalMinutes))) less a day."))
                        .font(.geist(size: 13))
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("+\(PlanReportFormat.years(goal))")
                        .font(.geist(size: 40, weight: .heavy))
                        .foregroundStyle(PlanReportStyle.green)
                        .monospacedDigit()
                    Text("of your life back by age \(targetAge) if you reach \(reach). Your first full day shows here tomorrow.")
                        .font(.geist(size: 14, weight: .medium))
                        .foregroundStyle(ScreenSpanAppearance.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func weekLine(_ days: [PlanDay]) -> String {
        let finished = days.filter { $0.state == .kept || $0.state == .over }
        let kept = finished.filter { $0.state == .kept }.count
        guard !finished.isEmpty else { return "Your first day is under way. Keep today’s limits to earn your first check." }
        let yesterday = days.last { $0.state != .today }?.state
        let count = "\(kept) of the last \(finished.count == 1 ? "day" : "\(finished.count) days") kept"
        if kept == finished.count { return finished.count == 1 ? "Yesterday kept. That’s how it starts." : "\(count). Every one." }
        if yesterday == .kept { return "\(count). Yesterday was one of them." }
        return "\(count). Today is a fresh one."
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

/// The last week, a circle a day: a green check for a kept day, amber for a
/// day over a limit, dashed when Screen Time didn't report it, a ring for today.
struct PlanDayCircles: View {
    let days: [PlanDay]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days) { day in
                VStack(spacing: 4) {
                    mark(day.state)
                        .frame(width: 30, height: 30)
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.geist(size: 11, weight: day.state == .today ? .bold : .regular))
                        .foregroundStyle(day.state == .today ? ScreenSpanAppearance.text : ScreenSpanAppearance.secondaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(days.filter { $0.state == .kept }.count) days kept and \(days.filter { $0.state == .over }.count) over in the last week")
    }

    @ViewBuilder
    private func mark(_ state: PlanDay.State) -> some View {
        switch state {
        case .kept:
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(PlanReportStyle.brightGreen, in: Circle())
        case .over:
            Image(systemName: "minus")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Color(hex: "#8A5A00"))
                .frame(width: 30, height: 30)
                .background(Color(hex: "#FFE3AD"), in: Circle())
        case .today:
            Circle().strokeBorder(ScreenSpanAppearance.text, lineWidth: 2)
                .overlay(Circle().fill(ScreenSpanAppearance.text).frame(width: 7, height: 7))
        case .unreported:
            Circle().strokeBorder(Color(hex: "#A9B4C2"), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
        case .notStarted:
            Circle().fill(Color.white.opacity(0.7))
        }
    }
}

/// One planned app today: how much time is open now, when more opens, and
/// where its limit goes next.
private struct PlanAppCard: View {
    let app: PlannedApp
    let progress: PlanAppProgress
    let spread: DaySpread
    /// Minutes used so far today.
    let todayMinutes: Double?
    let now: Date

    private var course: ReductionCourse { progress.course }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PlannedAppLabel(selection: app.selection)
                Spacer(minLength: 8)
                Text(progress.currentLimit.map { "\(PlanReportFormat.duration(Double($0))) today" }
                     ?? "Starts tonight")
                    .font(.geist(size: 13, weight: .semibold))
                    .foregroundStyle(ScreenSpanAppearance.secondaryText)
                    .monospacedDigit()
            }
            if let limit = progress.currentLimit {
                today(limit: limit)
            } else {
                Text("\(PlanReportFormat.duration(Double(course.firstMinutes))) a day from midnight.")
                    .font(.geist(size: 14, weight: .semibold))
                    .monospacedDigit()
            }
            Text(nextLine)
                .font(.geist(size: 12))
                .foregroundStyle(course.isHolding(at: now) ? Color(hex: "#8A5A00") : ScreenSpanAppearance.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(PlanReportStyle.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// Time open now against the cap for this part of the day, on a bar of
    /// the whole day's limit with a tick where each later part opens.
    private func today(limit: Int) -> some View {
        let caps = spread.caps(limit: limit)
        let cap = spread.cap(limit: limit, at: now)
        let more = spread.moreTime(limit: limit, after: now)
        let used = todayMinutes
        let left = used.map { Double(cap) - $0 }
        let isBlocked = left.map { $0 < 1 } ?? false
        return VStack(alignment: .leading, spacing: 8) {
            Group {
                if app.isUnlocked(at: now) {
                    Label("Unlocked early", systemImage: "lock.open.fill")
                        .foregroundStyle(Color(hex: "#8A5A00"))
                } else if isBlocked {
                    Label(more.map { "Blocked until \($0.formatted(date: .omitted, time: .shortened))" } ?? "Done for today",
                          systemImage: "lock.fill")
                } else if let left {
                    Text("\(PlanReportFormat.duration(left)) left \(more == nil ? "today" : DayPart.at(now).thisName)")
                        .foregroundStyle(PlanReportStyle.green)
                } else {
                    Text("\(PlanReportFormat.duration(Double(cap))) open \(more == nil ? "today" : DayPart.at(now).thisName)")
                }
            }
            .font(.geist(size: 16, weight: .semibold))
            .monospacedDigit()
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white)
                    // What's open so far today.
                    Capsule().fill(Color(hex: "#CFEBDB"))
                        .frame(width: width * Double(cap) / Double(max(limit, 1)))
                    Capsule().fill(isBlocked ? ScreenSpanAppearance.text : PlanReportStyle.brightGreen)
                        .frame(width: width * min(max((used ?? 0) / Double(max(limit, 1)), 0), 1))
                    ForEach(Array(Set(caps.dropLast())).filter { $0 < limit }, id: \.self) { tick in
                        Rectangle().fill(Color(hex: "#9AA3AE"))
                            .frame(width: 1.5, height: 10)
                            .offset(x: width * Double(tick) / Double(limit) - 0.75)
                    }
                }
            }
            .frame(height: 10)
            if let more {
                let added = spread.cap(limit: limit, at: more) - cap
                Text("+\(PlanReportFormat.duration(Double(added))) opens at \(more.formatted(date: .omitted, time: .shortened)). Unused time carries over.")
                    .font(.geist(size: 12))
                    .foregroundStyle(ScreenSpanAppearance.secondaryText)
            }
        }
    }

    private var nextLine: String {
        let goal = "Goal \(PlanReportFormat.duration(Double(course.targetMinutes)))"
        guard let next = course.nextChange(after: now) else { return "Goal reached. \(PlanReportFormat.duration(Double(course.targetMinutes))) a day stays." }
        guard progress.currentLimit != nil else { return "\(goal) a day by \(course.goalDate().formatted(.dateTime.month(.abbreviated).day()))." }
        let day = Calendar.current.isDateInTomorrow(next.startedAt)
            ? "tomorrow" : next.startedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        if course.isHolding(at: now) {
            return "Repeating this limit after 3 missed days. Keep 5 and it drops to \(PlanReportFormat.duration(Double(next.dailyMinutes))) \(day)."
        }
        if next.dailyMinutes <= course.targetMinutes {
            return "Drops to your goal, \(PlanReportFormat.duration(Double(next.dailyMinutes))) a day, \(day)."
        }
        return "Drops to \(PlanReportFormat.duration(Double(next.dailyMinutes))) \(day) · \(goal) by \(course.goalDate().formatted(.dateTime.month(.abbreviated).day()))"
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
