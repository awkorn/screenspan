import SwiftUI

/// The last plan step in onboarding. Without Screen Time access there's no
/// plan to enforce, so it summarizes the daily goal instead.
struct PlanView: View {
    @Bindable var viewModel: OnboardingViewModel
    @EnvironmentObject private var store: StoreKitService
    @EnvironmentObject private var blocking: BlockingService
    @State private var isFinishing = false

    var body: some View {
        if viewModel.buildsPlan {
            PlanPreviewView(draft: viewModel.planDraft, chrome: viewModel.planChrome,
                            isStarting: isFinishing) {
                // Subscribers (a reinstall, say) skip the offer.
                guard !store.isPro else {
                    isFinishing = true
                    viewModel.planDraft.start(with: blocking)
                    Task { await viewModel.completeOnboarding() }
                    return
                }
                viewModel.advance()
            }
        } else {
            goalSummary
        }
    }

    // MARK: - Daily goal

    private var goalSummary: some View {
        OnboardingScaffold(
            viewModel: viewModel,
            title: "Your plan starts today",
            subtitle: "Every day under your goal is time you get back. Here’s how you’ll see it."
        ) {
            ScrollView {
                VStack(spacing: 12) {
                    HStack {
                        summary(value: formatted(viewModel.goalHours), label: "daily goal")
                        summary(value: Date().formatted(.dateTime.month(.abbreviated).day()), label: "start date")
                    }
                    item(icon: "arrow.uturn.backward.circle", title: "Years you’re regaining",
                         text: "Progress compares every day from now on with the week before today.")
                    item(icon: "flame", title: "Your goal streak",
                         text: "See which days you stayed under \(formatted(viewModel.goalHours)) and keep the streak going.")
                    item(icon: "square.grid.3x3", title: "Your life chart",
                         text: "Watch phone months turn into months that are yours again.")
                    item(icon: "chart.pie", title: "Where your time goes",
                         text: "Your top apps, pickups, and notifications, with what each costs over a lifetime.")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
        } footer: {
            OnboardingPrimaryButton(title: "Start reclaiming my time", isEnabled: !isFinishing) {
                // Subscribers (a reinstall, say) skip the offer.
                guard !store.isPro else {
                    isFinishing = true
                    Task { await viewModel.completeOnboarding() }
                    return
                }
                viewModel.advance()
            }
        }
    }

    private func summary(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.geist(size: 26, weight: .bold)).foregroundStyle(OnboardingStyle.navy)
            Text(label).font(.geist(size: 13)).foregroundStyle(OnboardingStyle.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(hex: "#EEF8F2"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func item(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: "#235187"))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.geist(size: 16, weight: .semibold)).foregroundStyle(OnboardingStyle.navy)
                Text(text).font(.geist(size: 13)).foregroundStyle(OnboardingStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(OnboardingStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func formatted(_ hours: Double) -> String {
        let minutes = Int((hours * 60).rounded())
        if minutes < 60 { return "\(minutes)m" }
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }
}

/// The plan, step by step, with the time it gives back. Used in onboarding
/// and when setting up or adding to a plan later.
struct PlanPreviewView: View {
    @Bindable var draft: PlanDraftModel
    let chrome: PlanStepChrome
    var isStarting = false
    let onStart: () -> Void

    private var start: Date { BlockingConfiguration.nextMidnight() }
    private var targetAge: Int { SharedConstants.DefaultValues.targetAge }

    var body: some View {
        OnboardingScaffold(
            title: draft.isAdding ? "Your new limits" : "Your plan",
            subtitle: "Your daily limit drops each week until you reach your goal. Pick a pace, or set each week yourself. When a limit is used up, the app is blocked until midnight.",
            progress: chrome.progress,
            onBack: chrome.back
        ) {
            ScrollView {
                VStack(spacing: 12) {
                    hero
                    ForEach($draft.items) { $item in
                        if let course = item.course(start: start) {
                            PlanCourseCard(item: $item, course: course, start: start,
                                           currentAge: draft.currentAge, targetAge: targetAge)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
        } footer: {
            Text(draft.items.count == 1 ? "Its first limit starts tonight at midnight." : "Your first limits start tonight at midnight.")
                .font(.geist(size: 13))
                .foregroundStyle(OnboardingStyle.muted)
            OnboardingPrimaryButton(title: draft.isAdding ? "Add to my plan" : "Start my plan",
                                    isEnabled: !isStarting && draft.isReady) {
                draft.save()
                onStart()
            }
        }
    }

    private var hero: some View {
        let courses = draft.courses(start: start)
        let finish = courses.map { $0.goalDate() }.max()
        return VStack(alignment: .leading, spacing: 6) {
            Text("+\(PlanFormat.years(draft.yearsBackAtTarget))")
                .font(.geist(size: 44, weight: .heavy))
                .foregroundStyle(Color(hex: "#1F7A4D"))
                .monospacedDigit()
            Text("of your life back by age \(targetAge) once you reach \(courses.count == 1 ? "your goal" : "your goals").")
                .font(.geist(size: 15, weight: .semibold))
                .foregroundStyle(OnboardingStyle.navy)
                .fixedSize(horizontal: false, vertical: true)
            Text(finishLine(minutesBack: courses.minutesBackAtTarget, finish: finish))
                .font(.geist(size: 13))
                .foregroundStyle(OnboardingStyle.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(hex: "#EEF8F2"), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func finishLine(minutesBack: Int, finish: Date?) -> String {
        let daily = "\(PlanFormat.duration(minutesBack)) a day back"
        guard let finish, finish > start else { return daily + " from tomorrow." }
        return daily + " by \(finish.formatted(.dateTime.month(.wide).day()))."
    }
}

/// One app's steps from where it starts to its target. The user can move
/// the target, pick a pace, and set any week's limit by hand.
private struct PlanCourseCard: View {
    @Binding var item: PlanDraftItem
    let course: ReductionCourse
    let start: Date
    let currentAge: Int
    let targetAge: Int
    @State private var showsWeeks = false

    private var limits: [Int] { course.plannedSteps().map(\.dailyMinutes) }
    private var lowestTarget: Int { ReductionCourse.minimumTargetMinutes }
    private var highestTarget: Int { course.baselineMinutes - ReductionCourse.minimumCut }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                PlanItemLabel(selection: item.selection)
                Spacer(minLength: 8)
                Text("\(PlanFormat.duration(course.baselineMinutes)) → \(PlanFormat.duration(course.targetMinutes))")
                    .font(.geist(size: 15, weight: .semibold))
                    .foregroundStyle(OnboardingStyle.navy)
                    .monospacedDigit()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(limits.enumerated()), id: \.offset) { week, minutes in
                        VStack(spacing: 2) {
                            Text(PlanFormat.duration(minutes))
                                .font(.geist(size: 14, weight: .semibold))
                                .foregroundStyle(week == 0 ? .white : OnboardingStyle.navy)
                                .monospacedDigit()
                            Text(weekLabel(week))
                                .font(.geist(size: 11))
                                .foregroundStyle(week == 0 ? Color.white.opacity(0.8) : OnboardingStyle.muted)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(week == 0 ? OnboardingStyle.navy : Color.white,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Goal")
                        .font(.geist(size: 13, weight: .medium))
                        .foregroundStyle(OnboardingStyle.muted)
                    Text("+\(PlanFormat.years(course.regained(atLimit: course.targetMinutes, currentAge: currentAge, targetAge: targetAge).yearsReclaimed)) by \(targetAge)")
                        .font(.geist(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "#1F7A4D"))
                }
                Spacer()
                stepButton("minus", enabled: course.targetMinutes > lowestTarget) { moveTarget(by: -15) }
                Text(PlanFormat.duration(course.targetMinutes))
                    .font(.geist(size: 17, weight: .bold))
                    .foregroundStyle(OnboardingStyle.navy)
                    .monospacedDigit()
                    .frame(minWidth: 64)
                stepButton("plus", enabled: course.targetMinutes < highestTarget) { moveTarget(by: 15) }
            }
            .accessibilityElement(children: .contain)
            PlanPacePicker(pace: course.pace) { pace in
                withAnimation(.snappy) {
                    item.pace = pace
                    item.limits = nil
                }
            }
            Button {
                withAnimation(.snappy) { showsWeeks.toggle() }
            } label: {
                HStack {
                    Text(item.limits == nil ? "Adjust each week" : "Adjust each week · edited")
                        .font(.geist(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "#0063D6"))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "#0063D6"))
                        .rotationEffect(.degrees(showsWeeks ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(showsWeeks ? "Expanded" : "Collapsed")
            if showsWeeks {
                PlanWeekRows(course: course, now: Date(), background: .white) { changed in
                    withAnimation(.snappy) { item.adopt(changed) }
                }
                Text("Lowering a week brings later weeks down with it; raising one lifts earlier weeks. Changing the pace or goal redraws the weeks.")
                    .font(.geist(size: 12))
                    .foregroundStyle(OnboardingStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(OnboardingStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func weekLabel(_ week: Int) -> String {
        guard week > 0 else { return "Tomorrow" }
        let date = Calendar.current.date(byAdding: .day, value: week * ReductionCourse.stepDays, to: start) ?? start
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    /// Moves in quarter hours, landing on one even if the default target didn't.
    private func moveTarget(by delta: Int) {
        let current = course.targetMinutes
        let moved = delta > 0 ? (current / 15 + 1) * 15 : ((current - 1) / 15) * 15
        withAnimation(.snappy) {
            item.targetMinutes = min(max(moved, lowestTarget), highestTarget)
            item.limits = nil
        }
    }

    private func stepButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(enabled ? OnboardingStyle.navy : OnboardingStyle.muted.opacity(0.4))
                .frame(width: 36, height: 36)
                .background(Color.white, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(icon == "plus" ? "Raise goal" : "Lower goal")
    }
}
