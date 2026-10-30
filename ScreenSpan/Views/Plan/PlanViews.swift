import DeviceActivity
import FamilyControls
import SwiftUI

/// Shown on the dashboard when a week at a limit is done. The plan's dates
/// are the user's own, so the host knows a check-in is due without usage.
struct PlanCheckInBanner: View {
    let apps: [PlannedApp]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 18, weight: .semibold))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly check-in")
                        .font(.geist(size: 14, weight: .semibold))
                    Text(apps.count == 1 ? "A week at this limit is done. Choose your next step."
                                         : "\(apps.count) apps finished a week. Choose your next steps.")
                        .font(.geist(size: 12))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.7)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#1F7A4D"), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens your weekly check-in.")
    }
}

/// The weekly decision: step down, hold, or ease back. The report above the
/// choices shows how the week went; the host never learns it.
struct PlanCheckInView: View {
    /// The apps due when the sheet opened, so a decided app keeps its row.
    let apps: [PlannedApp]

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var blocking: BlockingService
    @State private var filter = DeviceActivityFilter.screenSpanDashboard
    @State private var decisions: [UUID: String] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("How did the week go?")
                            .font(.geist(size: 26, weight: .bold))
                            .foregroundStyle(OnboardingStyle.navy)
                        Text("Small steps that hold beat big ones that don’t. Whatever you choose starts at midnight.")
                            .font(.geist(size: 15))
                            .foregroundStyle(OnboardingStyle.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ZStack {
                        ProgressView()
                        DeviceActivityReport(.planCheckIn, filter: filter)
                    }
                    .frame(height: CGFloat(apps.count) * 188)
                    ForEach(apps) { app in
                        choices(for: app)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(decisions.count == apps.count ? "Done" : "Later") { dismiss() }
                }
            }
        }
        .tint(OnboardingStyle.navy)
        .screenSpanLightSurface()
    }

    @ViewBuilder
    private func choices(for app: PlannedApp) -> some View {
        let course = blocking.configuration.plan.apps.first { $0.id == app.id }?.course ?? app.course
        VStack(alignment: .leading, spacing: 12) {
            PlanItemLabel(selection: app.selection)
            if let decision = decisions[app.id] {
                Label(decision, systemImage: "checkmark.circle.fill")
                    .font(.geist(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#1F7A4D"))
            } else {
                if let next = course.nextMinutes {
                    OnboardingPrimaryButton(title: "Step down to \(PlanFormat.duration(next)) a day") {
                        blocking.stepDown(app)
                        decide(app, "\(PlanFormat.duration(next)) a day from tomorrow")
                    }
                }
                HStack(spacing: 10) {
                    choiceButton("Not yet") {
                        blocking.hold(app)
                        decide(app, "Holding at \(PlanFormat.duration(course.latestMinutes)) for another week")
                    }
                    if let eased = course.easedBackMinutes {
                        choiceButton("Ease back to \(PlanFormat.duration(eased))") {
                            blocking.easeBack(app)
                            decide(app, "\(PlanFormat.duration(eased)) a day from tomorrow")
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OnboardingStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func decide(_ app: PlannedApp, _ text: String) {
        withAnimation(.snappy) { decisions[app.id] = text }
    }

    private func choiceButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.geist(size: 14, weight: .semibold))
                .foregroundStyle(OnboardingStyle.navy)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.white, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// The plan in Blocking: each app's limit today, any change due at midnight,
/// and ways to adjust between check-ins.
struct PlanBlockingSection: View {
    @EnvironmentObject private var blocking: BlockingService
    @State private var removing: PlannedApp?
    @State private var easing: PlannedApp?

    private var apps: [PlannedApp] { blocking.configuration.plan.apps }

    var body: some View {
        if !apps.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("YOUR PLAN")
                    .font(.geist(size: 12, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(OnboardingStyle.muted)
                    .accessibilityAddTraits(.isHeader)
                TimelineView(.everyMinute) { context in
                    VStack(spacing: 10) {
                        ForEach(apps) { app in row(app, now: context.date) }
                    }
                }
                Text("Plan limits change at midnight, so each one covers whole days.")
                    .font(.geist(size: 12))
                    .foregroundStyle(OnboardingStyle.muted)
            }
            .confirmationDialog("Remove this app from your plan?", isPresented: Binding(
                get: { removing != nil }, set: { if !$0 { removing = nil } }
            ), titleVisibility: .visible, presenting: removing) { app in
                Button(blocking.configuration.isStrict() ? "Remove at midnight" : "Remove", role: .destructive) {
                    blocking.removeFromPlan(app)
                }
            } message: { _ in
                Text(blocking.configuration.isStrict()
                     ? "Strict mode is on, so its limit stays until midnight."
                     : "Its daily limit ends now. You can add it again later.")
            }
            .confirmationDialog("Ease back from tomorrow?", isPresented: Binding(
                get: { easing != nil }, set: { if !$0 { easing = nil } }
            ), titleVisibility: .visible, presenting: easing) { app in
                if let eased = app.course.easedBackMinutes {
                    Button("\(PlanFormat.duration(eased)) a day from tomorrow") { blocking.easeBack(app) }
                }
            } message: { _ in
                Text("Today’s limit stays. The new one starts at midnight, and its week starts over.")
            }
        }
    }

    private func row(_ app: PlannedApp, now: Date) -> some View {
        let course = app.course
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                PlanItemLabel(selection: app.selection)
                Spacer(minLength: 8)
                menu(app, now: now)
            }
            Text(summary(course, now: now))
                .font(.geist(size: 13))
                .foregroundStyle(OnboardingStyle.muted)
            if app.removesAt != nil {
                pending("Leaves your plan at midnight", action: "Keep it") { blocking.cancelRemoval(app) }
            } else if course.hasScheduledChange(at: now), course.steps.count > 1 {
                pending("From tomorrow: \(PlanFormat.duration(course.latestMinutes)) a day",
                        action: "Keep today’s") { blocking.cancelScheduledChange(app) }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OnboardingStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func summary(_ course: ReductionCourse, now: Date) -> String {
        let today = course.limit(at: now).map { "\(PlanFormat.duration($0)) a day" } ?? "Starts at midnight"
        return "\(today) · target \(PlanFormat.duration(course.targetMinutes)) · started at \(PlanFormat.duration(course.baselineMinutes))"
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

    private func menu(_ app: PlannedApp, now: Date) -> some View {
        let course = app.course
        let lower = max(((course.targetMinutes - 1) / 15) * 15, ReductionCourse.minimumTargetMinutes)
        let higher = min((course.targetMinutes / 15 + 1) * 15, course.baselineMinutes - ReductionCourse.minimumCut)
        return Menu {
            if course.easedBackMinutes != nil, !course.hasScheduledChange(at: now), app.removesAt == nil {
                Button("Ease back…", systemImage: "arrow.uturn.up") { easing = app }
            }
            if lower < course.targetMinutes {
                Button("Lower target to \(PlanFormat.duration(lower))", systemImage: "arrow.down") {
                    blocking.retarget(app, minutes: lower)
                }
            }
            if higher > course.targetMinutes {
                Button("Raise target to \(PlanFormat.duration(higher))", systemImage: "arrow.up") {
                    blocking.retarget(app, minutes: higher)
                }
            }
            if app.removesAt == nil {
                Button("Remove from plan", systemImage: "minus.circle", role: .destructive) { removing = app }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(OnboardingStyle.navy)
                .frame(width: 32, height: 32)
        }
        .accessibilityLabel("Plan options")
    }
}
