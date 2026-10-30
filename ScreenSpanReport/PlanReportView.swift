import DeviceActivity
import FamilyControls
import SwiftUI

/// The plan at the top of the Plan tab: time back so far, then each app's
/// week against its limit. Usage and comparisons stay in this extension; the
/// plan itself is the user's choices, read from the App Group.
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
                Text("A little less each week, on the apps that take the most.")
                    .font(.geist(size: 13))
                    .foregroundStyle(ScreenSpanAppearance.secondaryText)
            }
            summary(progress.map(\.progress))
            ForEach(progress, id: \.app.id) { item in
                PlanAppCard(app: item.app, progress: item.progress)
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

    @ViewBuilder
    private func summary(_ apps: [PlanAppProgress]) -> some View {
        let measured = apps.compactMap(\.minutesBackSinceStart)
        if measured.isEmpty {
            notice(title: apps.allSatisfy { $0.stepIndex == nil } ? "Your plan starts at midnight" : "Your first day is in progress",
                   message: "Each completed day shows here against its limit. Check back tomorrow.")
        } else {
            let back = measured.reduce(0, +)
            let years = ProjectionCalculator.calculateRegained(
                startingDailyHours: max(back, 0) / 60, currentDailyHours: 0,
                currentAge: currentAge, targetAge: targetAge).yearsReclaimed
            VStack(alignment: .leading, spacing: 4) {
                Text(back > 0 ? "\(PlanReportFormat.duration(back)) a day back" : "No time back yet")
                    .font(.geist(size: 34, weight: .heavy))
                    .foregroundStyle(back > 0 ? Color(hex: "#1F7A4D") : ScreenSpanAppearance.text)
                    .monospacedDigit()
                Text(back > 0
                     ? "on these apps since your plan started, compared with where you said you began. That’s on track for \(PlanReportFormat.years(years)) back by age \(targetAge)."
                     : "These apps are at or above where you said you began. Each day under its limit adds time back.")
                    .font(.geist(size: 14))
                    .foregroundStyle(ScreenSpanAppearance.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: back > 0 ? "#EEF8F2" : "#F6F7FA"), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }

    private var otherAppsShift: Double? {
        guard let start = payload.plan.apps.map({ $0.course.steps[0].startedAt }).min() else { return nil }
        return PlanProgress.otherAppsChangeMinutes(
            total: payload.history,
            planned: payload.plan.apps.map { payload.planUsage[$0.id] ?? [] },
            planStart: start)
    }

    private func notice(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.geist(size: 16, weight: .semibold))
            Text(message)
                .font(.geist(size: 13))
                .foregroundStyle(ScreenSpanAppearance.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#F6F7FA"), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// One planned app: its limit, the week so far, and what comes next.
private struct PlanAppCard: View {
    let app: PlannedApp
    let progress: PlanAppProgress

    private var course: ReductionCourse { progress.course }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                PlannedAppLabel(selection: app.selection)
                Spacer(minLength: 8)
                Text(course.isAtTarget && !course.hasScheduledChange(at: Date())
                     ? "At target" : "Step \(progress.stepNumber) of \(progress.stepCount)")
                    .font(.geist(size: 12, weight: .semibold))
                    .foregroundStyle(ScreenSpanAppearance.secondaryText)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(progress.currentLimit.map { "\(PlanReportFormat.duration(Double($0))) a day" } ?? "Starts at midnight")
                    .font(.geist(size: 22, weight: .bold))
                    .monospacedDigit()
                Spacer()
                if let yesterday = progress.yesterday, let hours = yesterday.hours {
                    Text("Yesterday \(PlanReportFormat.duration(hours * 60))")
                        .font(.geist(size: 13, weight: .medium))
                        .foregroundStyle(ScreenSpanAppearance.secondaryText)
                        .monospacedDigit()
                }
            }
            PlanWeekStrip(days: progress.stepDays)
            Text(statusLine)
                .font(.geist(size: 13))
                .foregroundStyle(ScreenSpanAppearance.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(Color(hex: "#F6F7FA"), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var statusLine: String {
        let now = Date()
        var parts: [String] = []
        if progress.daysReported == 1 {
            parts.append(progress.daysUnder == 1 ? "Under your limit so far." : "You reached your limit so far.")
        } else if progress.daysReported > 1 {
            parts.append("Under your limit on \(progress.daysUnder) of the last \(progress.daysReported) days.")
        }
        if course.hasScheduledChange(at: now), progress.stepIndex != nil {
            parts.append("\(PlanReportFormat.duration(Double(course.latestMinutes))) a day from tomorrow.")
        } else if course.isAtTarget {
            parts.append("You reached your target. Holding here is the win.")
        } else if let checkIn = course.checkInDate(), let next = course.nextMinutes {
            let day = Calendar.current.isDateInToday(checkIn) || checkIn < now
                ? "today" : checkIn.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
            parts.append("Next step, \(PlanReportFormat.duration(Double(next))), is up for check-in \(day).")
        }
        return parts.joined(separator: " ")
    }
}

/// The step's days as bars against the limit: green under it, amber at it,
/// dashed when Screen Time didn't report the day, faint for days still ahead.
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
                .fill(day.reachedLimit ? Color(hex: "#F2A93B") : Color(hex: "#2BB673"))
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

/// The evidence for a weekly check-in, one card per app that's due. The host
/// shows the choices below it; nothing here tells the host what it found.
struct PlanCheckInReportView: View {
    let payload: ScreenTimeReportPayload

    var body: some View {
        let ready = payload.plan.appsReadyForNextStep()
        VStack(spacing: 12) {
            ForEach(ready) { app in
                let progress = PlanAppProgress(course: app.course, usage: payload.planUsage[app.id] ?? [])
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        PlannedAppLabel(selection: app.selection)
                        Spacer(minLength: 8)
                        if let limit = progress.currentLimit {
                            Text("Your week at \(PlanReportFormat.duration(Double(limit)))")
                                .font(.geist(size: 12, weight: .semibold))
                                .foregroundStyle(ScreenSpanAppearance.secondaryText)
                        }
                    }
                    PlanWeekStrip(days: progress.stepDays)
                    Text(advice(progress, next: app.course.nextMinutes))
                        .font(.geist(size: 13, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(height: PlanCheckInReportView.cardHeight, alignment: .top)
                .background(Color(hex: "#F6F7FA"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityElement(children: .combine)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .screenSpanLightSurface()
    }

    static let cardHeight: CGFloat = 176

    private func advice(_ progress: PlanAppProgress, next: Int?) -> String {
        let record = progress.daysReported > 0
            ? "Under your limit on \(progress.daysUnder) of \(progress.daysReported) days. "
            : ""
        if progress.suggestsHolding {
            return record + "You reached the limit on most days, so another week here lets it settle."
        }
        return record + (next.map { "You’re ready for \(PlanReportFormat.duration(Double($0))) a day." } ?? "")
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

struct PlanCheckInReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .planCheckIn
    let content: (ScreenTimeReportPayload) -> PlanCheckInReportView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ScreenTimeReportPayload {
        await extractDailyAverage(from: data)
    }
}
