import FamilyControls
import SwiftUI

/// The plan in Blocking: each app's limit today and when it drops next, and
/// ways to lower a goal, add an app, or start a plan.
struct PlanBlockingSection: View {
    @Binding var showsSetup: Bool
    @EnvironmentObject private var blocking: BlockingService
    @State private var editing: PlannedApp?

    private var apps: [PlannedApp] { blocking.configuration.plan.apps }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("YOUR PLAN")
                    .font(.geist(size: 12, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(OnboardingStyle.muted)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if !apps.isEmpty && blocking.canAddToPlan {
                    Button("Add") { showsSetup = true }
                        .font(.geist(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "#0063D6"))
                }
            }
            if apps.isEmpty {
                setupCard
            } else {
                TimelineView(.everyMinute) { context in
                    VStack(spacing: 10) {
                        ForEach(apps) { app in row(app, now: context.date) }
                    }
                }
                Text("When an app’s limit is used up, it’s blocked until midnight. Each week the limit drops on its own until you reach your goal.")
                    .font(.geist(size: 12))
                    .foregroundStyle(OnboardingStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sheet(isPresented: $showsSetup) {
            PlanSetupView(existing: apps)
        }
        .sheet(item: $editing) { app in
            PlanEditSheet(app: app)
        }
    }

    private var setupCard: some View {
        let hasDraft = !PlanDraftItem.load().isEmpty
        return Button { showsSetup = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(OnboardingStyle.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text(hasDraft ? "Finish setting up your plan" : "Set up your plan")
                        .font(.geist(size: 15, weight: .semibold))
                        .foregroundStyle(OnboardingStyle.navy)
                    Text("Daily limits for your top apps that get a little lower each week.")
                        .font(.geist(size: 13))
                        .foregroundStyle(OnboardingStyle.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "#9AA3AE"))
            }
            .padding(16)
            .background(OnboardingStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func row(_ app: PlannedApp, now: Date) -> some View {
        let course = app.course
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                PlanItemLabel(selection: app.selection)
                Spacer(minLength: 8)
                if app.removesAt == nil {
                    Button("Edit") { editing = app }
                        .font(.geist(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "#0063D6"))
                }
            }
            PlanStats(course: course, now: now)
            if let next = nextLine(app, now: now) {
                Text(next)
                    .font(.geist(size: 12))
                    .foregroundStyle(OnboardingStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if app.removesAt != nil {
                pending("Leaves your plan at midnight", action: "Keep it") { blocking.cancelRemoval(app) }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OnboardingStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// When the limit drops next, or that the goal is reached.
    private func nextLine(_ app: PlannedApp, now: Date) -> String? {
        let course = app.course
        guard app.removesAt == nil else { return nil }
        guard let next = course.nextChange(after: now) else { return "You’ve reached your goal. This limit stays." }
        let day = Calendar.current.isDateInTomorrow(next.startedAt)
            ? "tomorrow" : next.startedAt.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        return "Drops to \(PlanFormat.duration(next.dailyMinutes)) a day \(day)."
    }

    private func pending(_ text: String, action: String, perform: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Label(text, systemImage: "clock.arrow.circlepath")
                .font(.geist(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "#235187"))
            Spacer(minLength: 0)
            Button(action, action: perform)
                .font(.geist(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "#0063D6"))
        }
    }
}

/// Started, today's limit, and goal side by side, today's highlighted.
struct PlanStats: View {
    let course: ReductionCourse
    let now: Date
    /// Shown in place of the course's goal, for a change not yet saved.
    var goalMinutes: Int?
    /// The boxes' fill, which needs to differ from what's behind them.
    var boxColor = Color.white

    var body: some View {
        HStack(spacing: 8) {
            stat("Started", course.baselineMinutes)
            stat(course.limit(at: now) == nil ? "From tonight" : "Today’s limit",
                 course.limit(at: now) ?? course.firstMinutes, isCurrent: true)
            stat("Goal", goalMinutes ?? course.targetMinutes)
        }
        .accessibilityElement(children: .combine)
    }

    private func stat(_ label: String, _ minutes: Int, isCurrent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.geist(size: 11, weight: .medium))
                .foregroundStyle(isCurrent ? Color.white.opacity(0.8) : OnboardingStyle.muted)
            Text(PlanFormat.duration(minutes))
                .font(.geist(size: 16, weight: .bold))
                .foregroundStyle(isCurrent ? .white : OnboardingStyle.navy)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isCurrent ? OnboardingStyle.navy : boxColor,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Changes a planned app's goal with a slider, showing the weeks it makes.
/// Once the app's limits start, the goal can only go lower, so the plan only
/// gets stricter; before then, it can go either way.
struct PlanEditSheet: View {
    let app: PlannedApp

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var blocking: BlockingService
    @State private var goal: Double
    @State private var confirmsRemove = false
    private let now = Date()

    init(app: PlannedApp) {
        self.app = app
        _goal = State(initialValue: Double(app.course.targetMinutes))
    }

    private var course: ReductionCourse { app.course }
    private var hasStarted: Bool { course.hasStarted(at: now) }
    private var lowest: Int { ReductionCourse.minimumTargetMinutes }
    private var highest: Int { hasStarted ? course.targetMinutes : course.baselineMinutes - ReductionCourse.minimumCut }
    private var goalMinutes: Int { Int(goal) }
    private var isChanged: Bool { goalMinutes != course.targetMinutes }

    /// The course as it would be with the slider's goal.
    private var preview: ReductionCourse {
        guard isChanged else { return course }
        guard hasStarted else {
            return ReductionCourse(baselineMinutes: course.baselineMinutes, targetMinutes: goalMinutes, start: course.steps[0].startedAt)
        }
        var lowered = course
        lowered.lowerGoal(to: goalMinutes, at: now)
        return lowered
    }

    var body: some View {
        let preview = preview
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        PlanItemLabel(selection: app.selection)
                        PlanStats(course: course, now: now, goalMinutes: preview.targetMinutes, boxColor: OnboardingStyle.card)
                    }
                    goalCard(preview)
                    weeks(preview)
                    Button("Remove from plan", role: .destructive) { confirmsRemove = true }
                        .font(.geist(size: 15, weight: .semibold))
                        .foregroundStyle(OnboardingStyle.red)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationTitle("Edit plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!isChanged)
                }
            }
            .confirmationDialog("Remove this app from your plan?", isPresented: $confirmsRemove, titleVisibility: .visible) {
                Button(blocking.configuration.isStrict() ? "Remove at midnight" : "Remove", role: .destructive) {
                    blocking.removeFromPlan(app)
                    dismiss()
                }
            } message: {
                Text(blocking.configuration.isStrict()
                     ? "Strict mode is on, so its limit stays until midnight."
                     : "Its daily limit ends now. You can add it again later.")
            }
        }
        .tint(OnboardingStyle.navy)
        .screenSpanLightSurface()
    }

    private func goalCard(_ preview: ReductionCourse) -> some View {
        let years = preview.regained(atLimit: preview.targetMinutes, currentAge: AppGroupManager.shared.currentAge,
                                     targetAge: SharedConstants.DefaultValues.targetAge).yearsReclaimed
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GOAL")
                        .font(.geist(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(OnboardingStyle.muted)
                    Text("\(PlanFormat.duration(goalMinutes)) a day")
                        .font(.geist(size: 28, weight: .bold))
                        .foregroundStyle(OnboardingStyle.navy)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                Spacer()
                Text("+\(PlanFormat.years(years))")
                    .font(.geist(size: 17, weight: .bold))
                    .foregroundStyle(Color(hex: "#1F7A4D"))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            if highest > lowest {
                // Rounded by hand: a stepped slider draws a tick for every 5 minutes.
                Slider(value: Binding(get: { goal }, set: { goal = Double(ReductionCourse.rounded($0)) }),
                       in: Double(lowest)...Double(highest)) {
                    Text("Goal")
                } minimumValueLabel: {
                    Text(PlanFormat.duration(lowest)).font(.geist(size: 12)).foregroundStyle(OnboardingStyle.muted)
                } maximumValueLabel: {
                    Text(PlanFormat.duration(highest)).font(.geist(size: 12)).foregroundStyle(OnboardingStyle.muted)
                }
                .tint(Color(hex: "#2BB673"))
                .sensoryFeedback(.selection, trigger: goalMinutes)
                .accessibilityValue("\(PlanFormat.duration(goalMinutes)) a day")
            }
            Text(caption(preview))
                .font(.geist(size: 13))
                .foregroundStyle(OnboardingStyle.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(Color(hex: "#EEF8F2"), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.snappy, value: goalMinutes)
    }

    private func caption(_ preview: ReductionCourse) -> String {
        let reach = preview.goalDate() > now
            ? "You’ll reach it \(preview.goalDate().formatted(.dateTime.month(.abbreviated).day()))."
            : "You’re at this goal now."
        guard hasStarted else { return reach }
        guard highest > lowest else { return "Your goal is as low as it goes." }
        return reach + " Once a plan starts, goals can go lower but not higher."
    }

    private func weeks(_ preview: ReductionCourse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WEEK BY WEEK")
                .font(.geist(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(OnboardingStyle.muted)
            VStack(spacing: 0) {
                ForEach(Array(preview.schedule(at: now).enumerated()), id: \.offset) { index, entry in
                    if index > 0 { Divider().padding(.leading, 40) }
                    weekRow(entry)
                }
            }
            .padding(.horizontal, 14)
            .background(OnboardingStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func weekRow(_ entry: ReductionCourse.ScheduleEntry) -> some View {
        let isCurrent = entry.kind == .current
        return HStack(spacing: 12) {
            Image(systemName: entry.isGoal ? "flag.circle.fill"
                  : entry.kind == .past ? "checkmark.circle.fill" : isCurrent ? "largecircle.fill.circle" : "circle")
                .font(.system(size: 18))
                .foregroundStyle(entry.isGoal || entry.kind == .past ? Color(hex: "#2BB673")
                                 : isCurrent ? OnboardingStyle.navy : Color(hex: "#C5CCD6"))
                .frame(width: 26)
            Text(title(entry))
                .font(.geist(size: 14, weight: isCurrent || entry.isGoal ? .semibold : .regular))
                .foregroundStyle(entry.kind == .past ? OnboardingStyle.muted : OnboardingStyle.navy)
            Spacer()
            Text("\(PlanFormat.duration(entry.dailyMinutes)) a day")
                .font(.geist(size: 14, weight: isCurrent || entry.isGoal ? .bold : .medium))
                .foregroundStyle(entry.isGoal ? Color(hex: "#1F7A4D") : entry.kind == .past ? OnboardingStyle.muted : OnboardingStyle.navy)
                .monospacedDigit()
        }
        .padding(.vertical, 11)
    }

    private func title(_ entry: ReductionCourse.ScheduleEntry) -> String {
        let date = entry.start.formatted(.dateTime.month(.abbreviated).day())
        if entry.isGoal { return entry.kind == .upcoming ? "Goal · \(date)" : "Goal" }
        switch entry.kind {
        case .past: return "Week of \(date)"
        case .current: return "This week"
        case .upcoming: return Calendar.current.isDateInTomorrow(entry.start) ? "From tomorrow" : "Week of \(date)"
        }
    }

    private func save() {
        if hasStarted {
            blocking.lowerGoal(app, minutes: goalMinutes)
        } else {
            blocking.revise(app, baselineMinutes: course.baselineMinutes, targetMinutes: goalMinutes)
        }
        dismiss()
    }
}
