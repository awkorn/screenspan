import FamilyControls
import SwiftUI
import UserNotifications

/// The plan in Blocking: each app's time today and how it opens up through
/// the day, the week so far, a way to unlock a block early at a cost, and
/// ways to change the plan, add an app, or start one.
struct PlanBlockingSection: View {
    @Binding var showsSetup: Bool
    @EnvironmentObject private var blocking: BlockingService
    @State private var editing: PlannedApp?
    @State private var unlocking: PlannedApp?
    @State private var notificationsDenied = false
    @Environment(\.scenePhase) private var scenePhase

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
                TimelineView(.periodic(from: .now, by: 20)) { context in
                    VStack(spacing: 10) {
                        ForEach(apps) { app in row(app, now: context.date) }
                    }
                }
                PlanSpreadPicker(spread: blocking.configuration.plan.pendingSpread?.spread ?? blocking.configuration.plan.spread,
                                 startsTomorrow: blocking.configuration.plan.pendingSpread != nil) { spread in
                    withAnimation(.snappy) { blocking.setSpread(spread) }
                }
                Text("When a part of the day’s time is used up, the app is blocked until the next part. Time you don’t use carries over to later that day. Keep your limit at least 5 days in a week and it steps down; miss 3 and the week repeats.")
                    .font(.geist(size: 12))
                    .foregroundStyle(OnboardingStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
                warningToggle
            }
        }
        .task(id: scenePhase) { await checkNotifications() }
        .sheet(isPresented: $showsSetup) {
            PlanSetupView(existing: apps)
        }
        .sheet(item: $editing) { app in
            PlanEditSheet(app: app)
        }
        .sheet(item: $unlocking) { app in
            PlanUnlockSheet(app: app)
        }
    }

    private var warningToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { blocking.warnsBeforePlanLimits },
                set: { on in
                    blocking.warnsBeforePlanLimits = on
                    Task { await checkNotifications() }
                }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    Label("\(BlockingRule.planWarningLead)-minute heads-up", systemImage: "bell.badge")
                        .font(.geist(size: 16, weight: .semibold))
                        .foregroundStyle(OnboardingStyle.navy)
                    Text("Get a notification \(BlockingRule.planWarningLead) minutes before an app’s time runs out, with when more opens up.")
                        .font(.geist(size: 13))
                        .foregroundStyle(OnboardingStyle.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Color(hex: "#2BB673"))
            .padding(16)
            .background(OnboardingStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            if blocking.warnsBeforePlanLimits && notificationsDenied {
                HStack(spacing: 8) {
                    Text("Notifications are off for ScreenSpan.")
                        .font(.geist(size: 12))
                        .foregroundStyle(OnboardingStyle.muted)
                    Spacer(minLength: 0)
                    Button("Turn on") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.geist(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "#0063D6"))
                }
            }
        }
        .padding(.top, 6)
    }

    private func checkNotifications() async {
        notificationsDenied = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
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
                    Text("Daily limits for your top apps, spread through the day, that get a little lower each week you keep them.")
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
        let plan = blocking.configuration.plan
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                PlanItemLabel(selection: app.selection)
                Spacer(minLength: 8)
                if app.removesAt == nil {
                    Button("Edit") { editing = app }
                        .font(.geist(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "#0063D6"))
                }
            }
            blockStatus(app, now: now)
            PlanStats(course: course, now: now)
            if app.removesAt == nil {
                PlanDayParts(limit: course.limit(at: now) ?? course.firstMinutes, spread: plan.spread(at: course.hasStarted(at: now) ? now : course.steps[0].startedAt),
                             current: course.hasStarted(at: now) ? DayPart.at(now) : nil)
            }
            if course.hasStarted(at: now) {
                PlanWeekDots(course: course, now: now)
            }
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

    /// Blocked now and until when, with the way to unlock early; or how long
    /// an early unlock has left.
    @ViewBuilder
    private func blockStatus(_ app: PlannedApp, now: Date) -> some View {
        if let until = app.unlockedUntil, now < until {
            Label("Unlocked until \(until.formatted(date: .omitted, time: .shortened)). Today counts as missed.",
                  systemImage: "lock.open")
                .font(.geist(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "#8A5A00"))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#FFF6E5"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else if blocking.isPlanBlocked(app) {
            let end = blocking.configuration.plan.blockEnd(for: app, at: now)
            HStack(spacing: 8) {
                Label(Calendar.current.isDate(end, inSameDayAs: now)
                      ? "Blocked until \(end.formatted(date: .omitted, time: .shortened))" : "Blocked until midnight",
                      systemImage: "lock.fill")
                    .font(.geist(size: 13, weight: .semibold))
                    .foregroundStyle(OnboardingStyle.navy)
                Spacer(minLength: 0)
                if blocking.unlockUnavailableReason(app, at: now) == nil {
                    Button("Unlock early") { unlocking = app }
                        .font(.geist(size: 13, weight: .medium))
                        .foregroundStyle(OnboardingStyle.muted)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    /// When the limit drops next, that it's repeating, or that the goal is reached.
    private func nextLine(_ app: PlannedApp, now: Date) -> String? {
        let course = app.course
        guard app.removesAt == nil else { return nil }
        guard let next = course.nextChange(after: now) else { return "You’ve reached your goal. This limit stays." }
        let day = Calendar.current.isDateInTomorrow(next.startedAt)
            ? "tomorrow" : next.startedAt.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        guard course.hasStarted(at: now) else { return "Starts at midnight." }
        let drop = "Drops to \(PlanFormat.duration(next.dailyMinutes)) a day \(day)"
        if course.isHolding(at: now) {
            return "This limit is repeating a week after 3 missed days. \(drop) if you keep 5 days."
        }
        let left = ReductionCourse.allowedMisses - course.misses(at: now)
        return left == ReductionCourse.allowedMisses ? drop + "."
            : left > 0 ? "\(drop). One more missed day and this week repeats."
            : "\(drop). Another missed day and this week repeats."
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

/// A day's limit as its three parts: what each adds, with the part that's
/// on now highlighted. Hidden when the limit isn't split.
struct PlanDayParts: View {
    let limit: Int
    let spread: DaySpread
    /// The part of the day it is now; nil to highlight none.
    var current: DayPart?
    var boxColor = Color.white

    var body: some View {
        let allowances = spread.allowances(limit: limit)
        if allowances[0] < limit {
            HStack(spacing: 8) {
                ForEach(DayPart.allCases, id: \.self) { part in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(part.title)
                            .font(.geist(size: 11, weight: .medium))
                            .foregroundStyle(OnboardingStyle.muted)
                        Text((part == .morning ? "" : "+") + PlanFormat.duration(allowances[part.rawValue]))
                            .font(.geist(size: 14, weight: .semibold))
                            .foregroundStyle(OnboardingStyle.navy)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(boxColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(part == current ? OnboardingStyle.navy : .clear, lineWidth: 1.5))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(DayPart.allCases.map { "\($0.title): \(PlanFormat.duration(allowances[$0.rawValue]))" }.joined(separator: ", "))
        }
    }
}

extension DayPart {
    /// "Until noon", "Noon – 6 PM", "After 6 PM", in the user's clock style.
    var title: String {
        func hour(_ part: DayPart) -> String {
            part.start(onDayOf: Date()).formatted(.dateTime.hour())
        }
        switch self {
        case .morning: return "Until \(hour(.afternoon))"
        case .afternoon: return "\(hour(.afternoon)) – \(hour(.evening))"
        case .evening: return "After \(hour(.evening))"
        }
    }
}

/// The week that decides the next step down, a circle a day: a green check
/// for a day the limit held, an amber mark for one unlocked early.
struct PlanWeekDots: View {
    let course: ReductionCourse
    let now: Date

    var body: some View {
        let calendar = Calendar.current
        let week = course.currentWeek(at: now)
        let today = calendar.startOfDay(for: now)
        let start = calendar.startOfDay(for: course.steps[0].startedAt)
        let days = (0..<ReductionCourse.stepDays).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
        let kept = days.filter { $0 >= start && $0 < today && !course.isMissed($0) }.count
        HStack(spacing: 6) {
            ForEach(days, id: \.self) { day in
                VStack(spacing: 3) {
                    mark(day: day, today: today, start: start)
                        .frame(width: 24, height: 24)
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(.geist(size: 10, weight: day == today ? .bold : .regular))
                        .foregroundStyle(day == today ? OnboardingStyle.navy : OnboardingStyle.muted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("This week: \(kept) days kept, \(course.misses(at: now)) missed")
    }

    @ViewBuilder
    private func mark(day: Date, today: Date, start: Date) -> some View {
        if day >= start, day <= today, course.isMissed(day) {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(hex: "#8A5A00"))
                .frame(width: 24, height: 24)
                .background(Color(hex: "#FFE9BF"), in: Circle())
        } else if day >= start, day < today {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color(hex: "#2BB673"), in: Circle())
        } else if day == today {
            Circle().strokeBorder(OnboardingStyle.navy, lineWidth: 2)
                .overlay(Circle().fill(OnboardingStyle.navy).frame(width: 6, height: 6))
        } else {
            Circle().strokeBorder(Color(hex: "#C5CCD6"), lineWidth: 1.5)
        }
    }
}

/// How the day's time is shared out. A change waits for midnight once limits run.
struct PlanSpreadPicker: View {
    let spread: DaySpread
    var startsTomorrow = false
    var background = OnboardingStyle.card
    let onChange: (DaySpread) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THROUGH THE DAY")
                .font(.geist(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(OnboardingStyle.muted)
            HStack(spacing: 6) {
                ForEach(DaySpread.allCases) { option in
                    Button { onChange(option) } label: {
                        Text(option.title)
                            .font(.geist(size: 13, weight: .semibold))
                            .foregroundStyle(option == spread ? .white : OnboardingStyle.navy)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(option == spread ? OnboardingStyle.navy : (background == .white ? OnboardingStyle.card : Color.white),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(option == spread ? .isSelected : [])
                }
            }
            Text(spread.detail + (startsTomorrow ? " Starts tomorrow." : ""))
                .font(.geist(size: 12))
                .foregroundStyle(OnboardingStyle.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension DaySpread {
    var title: String {
        switch self {
        case .evening: "Save for evening"
        case .even: "Even"
        case .anytime: "Any time"
        }
    }

    var detail: String {
        switch self {
        case .evening: "A quarter of each limit by noon, another quarter by 6 PM, and half kept for the evening."
        case .even: "A third of each limit in the morning, a third in the afternoon, a third in the evening."
        case .anytime: "The whole limit from midnight. Easy to use up early and have nothing left at night."
        }
    }
}

/// Unlocking a blocked app early. The wait, the cost, and the easy way out
/// are the point: an urge usually passes inside a minute, and being asked
/// before the app opens is when people most often decide not to.
struct PlanUnlockSheet: View {
    let app: PlannedApp

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var blocking: BlockingService
    @State private var startedAt = Date()

    private var course: ReductionCourse { app.course }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let wait = blocking.unlockWaitSeconds(app, at: now)
            let remaining = max(wait - Int(now.timeIntervalSince(startedAt)), 0)
            let end = blocking.configuration.plan.blockEnd(for: app, at: now)
            VStack(alignment: .leading, spacing: 18) {
                PlanItemLabel(selection: app.selection)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Unlock for \(ReductionPlan.unlockMinutes) minutes?")
                        .font(.geist(size: 26, weight: .bold))
                        .foregroundStyle(OnboardingStyle.navy)
                    Text(waitLine(end: end, now: now))
                        .font(.geist(size: 15))
                        .foregroundStyle(OnboardingStyle.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label("Today becomes a missed day", systemImage: "lock.open.fill")
                        .font(.geist(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "#8A5A00"))
                    Text(cost(now: now))
                        .font(.geist(size: 14))
                        .foregroundStyle(OnboardingStyle.navy)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#FFF6E5"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Spacer(minLength: 0)
                VStack(spacing: 10) {
                    OnboardingPrimaryButton(title: Calendar.current.isDate(end, inSameDayAs: now)
                                            ? "I’ll wait until \(end.formatted(date: .omitted, time: .shortened))"
                                            : "I’ll wait until tomorrow") { dismiss() }
                    Button {
                        blocking.unlockEarly(app)
                        dismiss()
                    } label: {
                        Text(remaining > 0
                             ? "Unlock in \(remaining / 60):\(String(format: "%02d", remaining % 60))"
                             : "Unlock \(ReductionPlan.unlockMinutes) minutes")
                            .font(.geist(size: 15, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(remaining > 0 ? OnboardingStyle.muted : OnboardingStyle.navy)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(remaining > 0)
                    .accessibilityLabel(remaining > 0 ? "Unlock available in \(remaining) seconds" : "Unlock \(ReductionPlan.unlockMinutes) minutes")
                }
            }
            .padding(24)
        }
        .background(Color.white.ignoresSafeArea())
        .screenSpanLightSurface()
        .presentationDetents([.medium, .large])
        // Leaving and coming back starts the wait again.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { startedAt = Date() }
        }
    }

    private func waitLine(end: Date, now: Date) -> String {
        guard Calendar.current.isDate(end, inSameDayAs: now) else {
            return "You’ve used today’s \(PlanFormat.duration(course.limit(at: now) ?? 0)). It’s back at midnight."
        }
        let minutes = max(Int((end.timeIntervalSince(now) / 60).rounded(.up)), 1)
        return "More time opens up at \(end.formatted(date: .omitted, time: .shortened)), \(PlanFormat.duration(minutes)) from now."
    }

    private func cost(now: Date) -> String {
        if course.isMissed(now) { return "You’ve already unlocked today, so this one waits longer. The \(ReductionPlan.unlockMinutes) minutes come out of the rest of today’s time." }
        guard let next = course.nextChange(after: now), let limit = course.limit(at: now) else {
            return "Your goal limit stays, but today won’t count as a day you kept it."
        }
        let misses = course.misses(at: now) + 1
        if misses > ReductionCourse.allowedMisses {
            return "That’s \(misses) this week, so \(PlanFormat.duration(limit)) a day repeats for another week instead of dropping to \(PlanFormat.duration(next.dailyMinutes))."
        }
        return "That’s \(misses) of the \(ReductionCourse.allowedMisses) missed days a week can take. One more than that and \(PlanFormat.duration(limit)) a day repeats instead of dropping to \(PlanFormat.duration(next.dailyMinutes))."
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

/// Changes a planned app's goal, pace, and week-by-week limits, and the
/// name its notifications use. Once the app's limits start, the plan only
/// gets stricter: the goal and weeks ahead can go lower, not higher, and the
/// pace is fixed. Before then, anything goes.
struct PlanEditSheet: View {
    let app: PlannedApp

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var blocking: BlockingService
    @State private var course: ReductionCourse
    @State private var name: String
    @State private var confirmsRemove = false
    private let now = Date()

    init(app: PlannedApp) {
        self.app = app
        _course = State(initialValue: app.course)
        _name = State(initialValue: app.name ?? "")
    }

    private var saved: ReductionCourse { app.course }
    private var hasStarted: Bool { saved.hasStarted(at: now) }
    private var lowest: Int { ReductionCourse.minimumTargetMinutes }
    private var highest: Int { hasStarted ? saved.targetMinutes : saved.baselineMinutes - ReductionCourse.minimumCut }
    private var isChanged: Bool { course != saved || PlannedApp.cleaned(name) != app.displayName }

    /// The saved course with a different goal, at the edited pace. Weeks set
    /// by hand in this sheet give way to the new goal.
    private func withGoal(_ minutes: Int) -> ReductionCourse {
        guard minutes != course.targetMinutes else { return course }
        guard hasStarted else {
            return ReductionCourse(baselineMinutes: saved.baselineMinutes, targetMinutes: minutes, pace: course.pace,
                                   start: saved.steps[0].startedAt)
        }
        var lowered = saved
        lowered.lowerGoal(to: minutes, at: now)
        return lowered
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        PlanItemLabel(selection: app.selection)
                        PlanStats(course: saved, now: now, goalMinutes: course.targetMinutes, boxColor: OnboardingStyle.card)
                    }
                    goalCard
                    if !hasStarted {
                        PlanPacePicker(pace: course.pace) { pace in
                            withAnimation(.snappy) { course.setPace(pace, at: now) }
                        }
                    }
                    weeks
                    PlanNameField(name: $name, background: OnboardingStyle.card)
                    Button("Remove from plan", role: .destructive) { confirmsRemove = true }
                        .font(.geist(size: 15, weight: .semibold))
                        .foregroundStyle(OnboardingStyle.red)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
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
                Button(hasStarted ? "Remove at midnight" : "Remove", role: .destructive) {
                    blocking.removeFromPlan(app)
                    dismiss()
                }
            } message: {
                Text(hasStarted
                     ? "Its limit stays until midnight, so leaving the plan isn’t a way around today’s block. You can change your mind before then."
                     : "Its limits haven’t started. You can add it again later.")
            }
        }
        .tint(OnboardingStyle.navy)
        .screenSpanLightSurface()
    }

    private var goalCard: some View {
        let goalMinutes = course.targetMinutes
        let years = course.regained(atLimit: goalMinutes, currentAge: AppGroupManager.shared.currentAge,
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
                Slider(value: Binding(get: { Double(min(max(goalMinutes, lowest), highest)) },
                                      set: { course = withGoal(ReductionCourse.rounded($0)) }),
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
            Text(caption)
                .font(.geist(size: 13))
                .foregroundStyle(OnboardingStyle.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(Color(hex: "#EEF8F2"), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.snappy, value: goalMinutes)
    }

    private var caption: String {
        let reach = course.goalDate() > now
            ? "You’ll reach it \(course.goalDate().formatted(.dateTime.month(.abbreviated).day()))."
            : "You’re at this goal now."
        guard hasStarted else { return reach }
        guard highest > lowest else { return "Your goal is as low as it goes." }
        return reach + " Once a plan starts, goals can go lower but not higher."
    }

    private var weeks: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WEEK BY WEEK")
                .font(.geist(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(OnboardingStyle.muted)
            PlanWeekRows(course: course, now: now, background: OnboardingStyle.card,
                         ceiling: { date in hasStarted ? saved.limit(at: date) : nil }) { changed in
                withAnimation(.snappy) { course = changed }
            }
            Text(hasStarted
                 ? "Tap − to make any week ahead stricter. Weeks that have started stay as they are."
                 : "Use − and + to set any week’s limit. Later weeks follow it down; earlier weeks follow it up.")
                .font(.geist(size: 12))
                .foregroundStyle(OnboardingStyle.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func save() {
        if course != saved { blocking.setCourse(app, to: course) }
        if PlannedApp.cleaned(name) != app.displayName { blocking.rename(app, to: name) }
        dismiss()
    }
}

/// Every limit from the first to the goal, each week ahead with − and + to
/// set it by hand. Used when setting up a plan and when editing one.
struct PlanWeekRows: View {
    let course: ReductionCourse
    let now: Date
    var background = OnboardingStyle.card
    /// The most a week starting at the given date may be raised to, once the
    /// plan has started; nil for no limit beyond the course's own rules.
    var ceiling: (Date) -> Int? = { _ in nil }
    let onChange: (ReductionCourse) -> Void

    var body: some View {
        let entries = course.schedule(at: now)
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                if index > 0 { Divider().padding(.leading, 40) }
                row(entry, index: index)
            }
        }
        .padding(.horizontal, 14)
        .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func row(_ entry: ReductionCourse.ScheduleEntry, index: Int) -> some View {
        let isCurrent = entry.kind == .current
        let lower = changed(index, to: entry.dailyMinutes - ReductionCourse.increment, start: entry.start)
        let higher = changed(index, to: entry.dailyMinutes + ReductionCourse.increment, start: entry.start)
        return HStack(spacing: 10) {
            Image(systemName: entry.isGoal ? "flag.circle.fill"
                  : entry.kind == .past ? "checkmark.circle.fill" : isCurrent ? "largecircle.fill.circle" : "circle")
                .font(.system(size: 18))
                .foregroundStyle(entry.isGoal || entry.kind == .past ? Color(hex: "#2BB673")
                                 : isCurrent ? OnboardingStyle.navy : Color(hex: "#C5CCD6"))
                .frame(width: 26)
            Text(title(entry))
                .font(.geist(size: 14, weight: isCurrent || entry.isGoal ? .semibold : .regular))
                .foregroundStyle(entry.kind == .past ? OnboardingStyle.muted : OnboardingStyle.navy)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 4)
            if entry.kind == .upcoming {
                stepButton("minus", course: lower, label: "Lower \(title(entry))")
            }
            Text(PlanFormat.duration(entry.dailyMinutes))
                .font(.geist(size: 14, weight: isCurrent || entry.isGoal ? .bold : .medium))
                .foregroundStyle(entry.isGoal ? Color(hex: "#1F7A4D") : entry.kind == .past ? OnboardingStyle.muted : OnboardingStyle.navy)
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(minWidth: entry.kind == .upcoming ? 52 : nil, alignment: .trailing)
            if entry.kind == .upcoming {
                stepButton("plus", course: higher, label: "Raise \(title(entry))")
            }
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .contain)
    }

    /// The course with week `index` moved to `minutes`; nil when that changes nothing.
    private func changed(_ index: Int, to minutes: Int, start: Date) -> ReductionCourse? {
        var trial = course
        trial.setLimit(at: index, to: minutes, at: now, ceiling: ceiling(start))
        return trial == course ? nil : trial
    }

    private func stepButton(_ icon: String, course: ReductionCourse?, label: String) -> some View {
        Button { if let course { onChange(course) } } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(course != nil ? OnboardingStyle.navy : OnboardingStyle.muted.opacity(0.35))
                .frame(width: 30, height: 30)
                .background(background == .white ? OnboardingStyle.card : .white, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(course == nil)
        .sensoryFeedback(.selection, trigger: course == nil)
        .accessibilityLabel(label)
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
}

/// How big each week's cut is, before a plan starts.
struct PlanPacePicker: View {
    let pace: ReductionCourse.Pace
    let onChange: (ReductionCourse.Pace) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PACE")
                .font(.geist(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(OnboardingStyle.muted)
            HStack(spacing: 6) {
                ForEach(ReductionCourse.Pace.allCases) { option in
                    Button { onChange(option) } label: {
                        Text(option.title)
                            .font(.geist(size: 14, weight: .semibold))
                            .foregroundStyle(option == pace ? .white : OnboardingStyle.navy)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(option == pace ? OnboardingStyle.navy : Color.white,
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(option == pace ? .isSelected : [])
                }
            }
            Text(pace.detail)
                .font(.geist(size: 12))
                .foregroundStyle(OnboardingStyle.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension ReductionCourse.Pace {
    var title: String {
        switch self {
        case .gentle: "Gentle"
        case .steady: "Steady"
        case .faster: "Faster"
        }
    }

    var detail: String {
        switch self {
        case .gentle: "About 10% less each week (5–15 min). Takes longer, but each week barely feels different."
        case .steady: "About 20% less each week (10–30 min). Big enough to notice, small enough to stick."
        case .faster: "About 30% less each week (15–45 min). Gets you there in fewer weeks."
        }
    }
}

/// What the user calls an app, so its heads-up can name it.
struct PlanNameField: View {
    @Binding var name: String
    var background = OnboardingStyle.card

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("App name, like Instagram", text: $name)
                .font(.geist(size: 15))
                .foregroundStyle(OnboardingStyle.navy)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onChange(of: name) { _, new in
                    if new.count > PlannedApp.maximumNameLength { name = String(new.prefix(PlannedApp.maximumNameLength)) }
                }
            Text("Optional. Your heads-up uses it, since iOS doesn’t tell ScreenSpan app names.")
                .font(.geist(size: 12))
                .foregroundStyle(OnboardingStyle.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
