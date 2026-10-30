import SwiftUI

/// The plan, step by step, with the time it gives back. Without Screen Time
/// access there's no plan to enforce, so it summarizes the daily goal instead.
struct PlanView: View {
    @Bindable var viewModel: OnboardingViewModel
    @EnvironmentObject private var store: StoreKitService
    @EnvironmentObject private var blocking: BlockingService
    @State private var isFinishing = false

    var body: some View {
        if viewModel.buildsPlan {
            reductionPlan
        } else {
            goalSummary
        }
    }

    // MARK: - Reduction plan

    private var start: Date { BlockingConfiguration.nextMidnight() }
    private var targetAge: Int { SharedConstants.DefaultValues.targetAge }
    private var courses: [ReductionCourse] { viewModel.planItems.compactMap { $0.course(start: start) } }

    private var reductionPlan: some View {
        OnboardingScaffold(
            viewModel: viewModel,
            title: "Your plan",
            subtitle: "Small cuts, a week at a time. Each week you choose: step down, hold, or ease back."
        ) {
            ScrollView {
                VStack(spacing: 12) {
                    hero
                    ForEach($viewModel.planItems) { $item in
                        if let course = item.course(start: start) {
                            PlanCourseCard(item: $item, course: course, start: start,
                                           currentAge: viewModel.selectedAge, targetAge: targetAge)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
        } footer: {
            Text("Your first limits start tonight at midnight.")
                .font(.geist(size: 13))
                .foregroundStyle(OnboardingStyle.muted)
            OnboardingPrimaryButton(title: "Start my plan", isEnabled: !isFinishing && viewModel.planIsReady) {
                viewModel.savePlanDraft()
                // Subscribers (a reinstall, say) skip the offer.
                guard !store.isPro else {
                    isFinishing = true
                    viewModel.startPlan(with: blocking)
                    Task { await viewModel.completeOnboarding() }
                    return
                }
                viewModel.advance()
            }
        }
    }

    private var hero: some View {
        let regained = courses.regainedAtTarget(currentAge: viewModel.selectedAge, targetAge: targetAge)
        let finish = courses.compactMap { $0.projectedTargetDate() }.max()
        return VStack(alignment: .leading, spacing: 6) {
            Text("+\(PlanFormat.years(regained.yearsReclaimed))")
                .font(.geist(size: 44, weight: .heavy))
                .foregroundStyle(Color(hex: "#1F7A4D"))
                .monospacedDigit()
            Text("of your life back by age \(targetAge) once you reach your targets.")
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
        guard let finish else { return daily + " from tomorrow." }
        return daily + " by \(finish.formatted(.dateTime.month(.wide).day())), if you step down each week."
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

/// One app's steps from where it starts to its target, which the user can move.
private struct PlanCourseCard: View {
    @Binding var item: PlanDraftItem
    let course: ReductionCourse
    let start: Date
    let currentAge: Int
    let targetAge: Int

    private var limits: [Int] { [course.latestMinutes] + course.remainingLimits }
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
                    Text("Target")
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
        withAnimation(.snappy) { item.targetMinutes = min(max(moved, lowestTarget), highestTarget) }
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
        .accessibilityLabel(icon == "plus" ? "Raise target" : "Lower target")
    }
}
