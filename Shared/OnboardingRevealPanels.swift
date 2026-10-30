import SwiftUI

/// Inputs to the onboarding reveal. With measured activity these come from
/// the report extension and are rendered only there. In estimate mode the
/// host builds them from the user's own guess, which is user-entered.
struct RevealData {
    let dailyHours: Double
    let isMeasured: Bool
    let guessHours: Double?
    let currentAge: Int
    let targetAge: Int
    var pickupsPerDay: Double?
    /// Up to three apps by daily average, with labels rendered by the caller.
    var topApps: [RevealApp] = []
    var intentions: [TimeIntention] = TimeIntention.defaults

    var projection: ProjectionResult {
        ProjectionCalculator.calculateProjectionFromDaily(
            currentAge: currentAge, targetAge: max(targetAge, currentAge), dailyHours: dailyHours)
    }

    func years(atDailyHours hours: Double) -> Double {
        ProjectionCalculator.calculateProjectionFromDaily(
            currentAge: currentAge, targetAge: max(targetAge, currentAge), dailyHours: hours).yearsOnPhone
    }
}

struct RevealApp: Identifiable {
    let id = UUID()
    let dailyHours: Double
    let label: AnyView
}

/// Every reveal panel plus the goal strip. See `OnboardingRevealLayout`.
struct OnboardingRevealPanels: View {
    static let panelCount = OnboardingRevealLayout.panelCount
    let data: RevealData

    var body: some View {
        GeometryReader { proxy in
            let strip = OnboardingRevealLayout.goalRowHeight * CGFloat(OnboardingRevealLayout.goalValues.count)
            let height = max((proxy.size.height - strip) / CGFloat(Self.panelCount), 0)
            VStack(spacing: 0) {
                RealityCheckPanel(data: data).panelFrame(height: height)
                LifetimePanel(data: data).panelFrame(height: height)
                LifeGridPanel(data: data).panelFrame(height: height)
                YearlyCostPanel(data: data).panelFrame(height: height)
                PotentialPanel(data: data).panelFrame(height: height)
                ForEach(OnboardingRevealLayout.goalValues, id: \.self) { goal in
                    GoalImpactRow(data: data, goalHours: goal)
                        .frame(height: OnboardingRevealLayout.goalRowHeight)
                }
            }
        }
        // The report is far taller than the screen; bottom insets would
        // shrink every panel and drift the host's window out of alignment.
        .ignoresSafeArea()
        .background(Color.white)
        .screenSpanLightSurface()
    }
}

private enum RevealStyle {
    static let navy = Color(hex: "#051425")
    static let muted = Color(hex: "#595959")
    static let red = Color(hex: "#E5322D")
    static let green = Color(hex: "#1F7A4D")
    static let card = Color(hex: "#F6F7FA")
}

private extension View {
    func panelFrame(height: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            self
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: height, alignment: .top)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: height)
        .clipped()
    }
}

private func eyebrow(_ text: String) -> some View {
    Text(text)
        .font(.geist(size: 12, weight: .semibold))
        .tracking(1.4)
        .foregroundStyle(RevealStyle.red)
}

private func formatDuration(_ hours: Double) -> String {
    let minutes = max(Int((hours * 60).rounded()), 0)
    if minutes < 60 { return "\(minutes)m" }
    return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
}

private func formatCount(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(value < 10 && value.rounded() != value ? 1 : 0)))
}

/// Big number hidden behind a tap. The reveal is in-panel state, so it works
/// the same inside the report and in the host.
private struct TapToReveal<Revealed: View>: View {
    let prompt: String
    @ViewBuilder let revealed: () -> Revealed
    @State private var isRevealed = false

    var body: some View {
        ZStack {
            if isRevealed {
                revealed()
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            } else {
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { isRevealed = true }
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .symbolEffect(.pulse, options: .repeating)
                        Text(prompt)
                            .font(.geist(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .background(
                        LinearGradient(colors: [Color(hex: "#E5322D"), Color(hex: "#B3161B")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
    }
}

/// Counts up to `target` once it appears.
private struct CountUpText: View {
    let target: Double
    let format: (Double) -> String
    @State private var value = 0.0

    var body: some View {
        Text(format(value))
            .contentTransition(.numericText(value: value))
            .onAppear {
                withAnimation(.easeOut(duration: 1.4)) { value = target }
            }
            .accessibilityLabel(format(target))
    }
}

// MARK: - 1. Reality check

private struct RealityCheckPanel: View {
    let data: RevealData

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            eyebrow("REALITY CHECK")
            Text("How close was your guess?")
                .font(.geist(size: 28, weight: .bold))
                .foregroundStyle(RevealStyle.navy)
            if let guess = data.guessHours {
                row(title: "You guessed", value: "\(formatDuration(guess)) a day", color: RevealStyle.navy)
            }
            if data.isMeasured {
                TapToReveal(prompt: "Tap to see what Screen Time measured") {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Screen Time measured")
                                .font(.geist(size: 14, weight: .medium))
                                .foregroundStyle(RevealStyle.muted)
                            CountUpText(target: data.dailyHours) { "\(formatDuration($0)) a day" }
                                .font(.geist(size: 40, weight: .heavy))
                                .foregroundStyle(RevealStyle.red)
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(Color(hex: "#FDECEC"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        Text(verdict)
                            .font(.geist(size: 17, weight: .semibold))
                            .foregroundStyle(RevealStyle.navy)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text("Average of your last 7 days on this iPhone.")
                    .font(.geist(size: 12))
                    .foregroundStyle(RevealStyle.muted)
            } else {
                Text("Screen Time hasn’t reported recent activity yet, so we’ll use your estimate for now. Once it has a few days of data, your dashboard switches to real numbers.")
                    .font(.geist(size: 15))
                    .foregroundStyle(RevealStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var verdict: String {
        guard let guess = data.guessHours else {
            return "That’s \(formatDuration(data.dailyHours)) every single day."
        }
        let gap = RevealMath.underestimateHours(guess: guess, actual: data.dailyHours)
        if gap >= 0.25 {
            return "That’s \(formatDuration(gap)) more than you thought, every single day. Most people underestimate their screen time."
        } else if gap <= -0.25 {
            return "You overestimated by \(formatDuration(-gap)). Even so, here’s what that time adds up to."
        }
        return "You were within 15 minutes. Here’s what that time adds up to."
    }

    private func row(title: String, value: String, color: Color) -> some View {
        HStack {
            Text(title).font(.geist(size: 15, weight: .medium)).foregroundStyle(RevealStyle.muted)
            Spacer()
            Text(value).font(.geist(size: 20, weight: .bold)).foregroundStyle(color).monospacedDigit()
        }
        .padding(18)
        .background(RevealStyle.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - 2. Lifetime

/// The eye-opener. One tap counts up the years; the two supporting stats then
/// unseal one at a time, and a closing line makes the total concrete.
private struct LifetimePanel: View {
    let data: RevealData
    /// 0 sealed, 1 years, 2 waking share, 3 months, 4 closing line.
    @State private var stage = 0

    var body: some View {
        let projection = data.projection
        VStack(alignment: .leading, spacing: 16) {
            eyebrow("YOUR FUTURE")
            Text("At \(formatDuration(data.dailyHours)) a day, by age \(data.targetAge) you’ll spend")
                .font(.geist(size: 26, weight: .bold))
                .foregroundStyle(RevealStyle.navy)
                .fixedSize(horizontal: false, vertical: true)

            yearsCard(projection)

            HStack(spacing: 10) {
                SealedStat(isRevealed: stage >= 2, placeholder: "00%") {
                    VStack(alignment: .leading, spacing: 10) {
                        CountUpText(target: projection.percentOfWakingLife) { "\(formatCount($0))%" }
                            .font(.geist(size: 24, weight: .bold))
                            .foregroundStyle(RevealStyle.navy)
                            .monospacedDigit()
                        WakingShareBar(share: projection.percentOfWakingLife / 100)
                    }
                } label: {
                    "of every waking hour"
                }
                SealedStat(isRevealed: stage >= 3, placeholder: "000") {
                    CountUpText(target: projection.monthsOnPhone) { formatCount($0) }
                        .font(.geist(size: 24, weight: .bold))
                        .foregroundStyle(RevealStyle.navy)
                        .monospacedDigit()
                } label: {
                    "months of your life"
                }
            }

            if stage >= 4 {
                Text(closingLine(projection))
                    .font(.geist(size: 17, weight: .semibold))
                    .foregroundStyle(RevealStyle.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Text(data.isMeasured
                 ? "Projection if your last 7 days continue. 24-hour years; 16 waking hours a day."
                 : "Projection from your estimate. 24-hour years; 16 waking hours a day.")
                .font(.geist(size: 12))
                .foregroundStyle(RevealStyle.muted)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: stage)
    }

    @ViewBuilder
    private func yearsCard(_ projection: ProjectionResult) -> some View {
        if stage == 0 {
            Button(action: startReveal) {
                VStack(spacing: 10) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .symbolEffect(.pulse, options: .repeating)
                    Text("Tap to reveal your future")
                        .font(.geist(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .background(
                    LinearGradient(colors: [Color(hex: "#E5322D"), Color(hex: "#B3161B")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Reveals your projected years on your phone and two related numbers.")
        } else {
            VStack(alignment: .leading, spacing: 2) {
                CountUpText(target: projection.yearsOnPhone) { String(format: "%.1f", $0) }
                    .font(.geist(size: 80, weight: .heavy))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text("YEARS ON YOUR PHONE")
                    .font(.geist(size: 16, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
            .padding(.horizontal, 22)
            .background(
                LinearGradient(colors: [Color(hex: "#E5322D"), Color(hex: "#8E1014")],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }

    private func startReveal() {
        Task { @MainActor in
            for (next, delay) in zip(1..., OnboardingRevealLayout.lifetimeRevealDelays) {
                try? await Task.sleep(for: .seconds(delay))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { stage = next }
            }
        }
    }

    /// The total as one unbroken stretch at the end of the planning horizon.
    private func closingLine(_ projection: ProjectionResult) -> String {
        let startAge = Double(data.targetAge) - projection.yearsOnPhone
        guard projection.yearsOnPhone >= 0.5, startAge > Double(data.currentAge) else {
            return "That’s time you can start taking back today."
        }
        return "Back to back, that’s every moment from age \(Int(startAge.rounded())) to \(data.targetAge), on your phone."
    }
}

/// A stat that stays blurred behind a seal until its turn.
private struct SealedStat<Value: View>: View {
    let isRevealed: Bool
    let placeholder: String
    @ViewBuilder let value: () -> Value
    let label: () -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .leading) {
                if isRevealed {
                    value().transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
                } else {
                    Text(placeholder)
                        .font(.geist(size: 24, weight: .bold))
                        .foregroundStyle(RevealStyle.navy)
                        .blur(radius: 7)
                        .overlay(alignment: .leading) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(RevealStyle.muted)
                                .padding(.leading, 18)
                        }
                        .accessibilityLabel("Hidden until revealed")
                }
            }
            .frame(minHeight: 30, alignment: .leading)
            Text(label())
                .font(.geist(size: 13))
                .foregroundStyle(RevealStyle.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RevealStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Fills to the waking-hours share once revealed.
private struct WakingShareBar: View {
    let share: Double
    @State private var shown = 0.0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hex: "#E3E7EE"))
                Capsule().fill(RevealStyle.red).frame(width: proxy.size.width * shown)
            }
        }
        .frame(height: 6)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) { shown = min(max(share, 0), 1) }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - 3. Life grid

private struct LifeGridPanel: View {
    let data: RevealData

    var body: some View {
        let grid = ProjectionCalculator.calculateLifeGrid(
            currentAge: data.currentAge, targetAge: max(data.targetAge, data.currentAge),
            monthsOnPhone: data.projection.monthsOnPhone)
        VStack(alignment: .leading, spacing: 14) {
            eyebrow("YOUR LIFE IN MONTHS")
            Text("Every red square is a month spent on your phone.")
                .font(.geist(size: 24, weight: .bold))
                .foregroundStyle(RevealStyle.navy)
                .fixedSize(horizontal: false, vertical: true)
            LifeGridView(goalGridData: grid)
            HStack(spacing: 14) {
                legend(LifeGridView.livedColor, "Lived")
                legend(LifeGridView.phoneColor, "Phone")
                legend(LifeGridView.remainingColor, "Yours to spend")
            }
        }
    }

    private func legend(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(label).font(.geist(size: 12, weight: .medium)).foregroundStyle(RevealStyle.navy)
        }
    }
}

// MARK: - 4. Yearly cost

private struct YearlyCostPanel: View {
    let data: RevealData

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            eyebrow("EVERY SINGLE YEAR")
            VStack(alignment: .leading, spacing: 2) {
                Text("\(formatCount(RevealMath.daysPerYear(dailyHours: data.dailyHours))) days")
                    .font(.geist(size: 56, weight: .heavy))
                    .foregroundStyle(RevealStyle.red)
                    .monospacedDigit()
                Text("of every year on your phone, counting 24 hours a day.")
                    .font(.geist(size: 16, weight: .semibold))
                    .foregroundStyle(RevealStyle.navy)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if data.pickupsPerDay != nil || !data.topApps.isEmpty {
                VStack(spacing: 0) {
                    if let pickups = data.pickupsPerDay, pickups >= 1 {
                        detailRow(icon: "hand.tap", title: "\(formatCount(pickups * 365)) pickups a year",
                                  detail: "\(formatCount(pickups)) a day")
                    }
                    ForEach(Array(data.topApps.prefix(3).enumerated()), id: \.element.id) { index, app in
                        if index > 0 || data.pickupsPerDay != nil { Divider().padding(.leading, 16) }
                        HStack(spacing: 12) {
                            app.label
                                .font(.geist(size: 15, weight: .medium))
                                .lineLimit(1)
                                .frame(maxHeight: 26)
                            Spacer(minLength: 8)
                            Text(String(format: "%.1f yrs by %d", data.years(atDailyHours: app.dailyHours), data.targetAge))
                                .font(.geist(size: 14, weight: .semibold))
                                .foregroundStyle(RevealStyle.red)
                                .monospacedDigit()
                                .fixedSize()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .background(RevealStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            HabitBudget(intentions: Array(data.intentions.prefix(3)), dailyHours: data.dailyHours)
        }
    }

    private func detailRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Color(hex: "#235187")).frame(width: 22)
            Text(title).font(.geist(size: 15, weight: .semibold))
            Spacer()
            Text(detail).font(.geist(size: 13)).foregroundStyle(RevealStyle.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

/// What a year of this phone time could pay for instead: one realistic habit
/// per intention, a bar the size of the year, and what's left over.
private struct HabitBudget: View {
    let intentions: [TimeIntention]
    let dailyHours: Double

    var body: some View {
        let plan = HabitPlan(intentions: intentions, dailyHours: dailyHours)
        if !plan.items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text(plan.fitsTogether ? "Every year, that time could cover all of this:"
                                       : "Every year, that time could cover any one of these:")
                    .font(.geist(size: 16, weight: .semibold))
                    .foregroundStyle(RevealStyle.navy)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 10) {
                    ForEach(plan.items, id: \.intention) { item in
                        row(icon: item.intention.icon, habit: item.habit)
                    }
                }
                if plan.fitsTogether {
                    BudgetBar(budget: plan.budgetHours, segments: plan.habits.map(\.hoursPerYear))
                    if let spare = spareText(plan.spareHours) {
                        Text(spare)
                            .font(.geist(size: 15, weight: .semibold))
                            .foregroundStyle(RevealStyle.navy)
                    }
                }
                Text(plan.fitsTogether ? "Hours per year. The bar is one year of your phone time." : "Hours per year.")
                    .font(.geist(size: 11))
                    .foregroundStyle(RevealStyle.muted)
            }
        }
    }

    private func row(icon: String, habit: Habit) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(RevealStyle.green)
                .frame(width: 36, height: 36)
                .background(Color(hex: "#E7F5EC"), in: RoundedRectangle(cornerRadius: 10))
            Text(habit.title)
                .font(.geist(size: 15, weight: .medium))
                .foregroundStyle(RevealStyle.navy)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text("\(formatCount(habit.hoursPerYear)) h")
                .font(.geist(size: 13, weight: .medium))
                .foregroundStyle(RevealStyle.muted)
                .monospacedDigit()
                .fixedSize()
        }
        .accessibilityElement(children: .combine)
    }

    private func spareText(_ hours: Double) -> String? {
        let days = Int(hours / 24)
        if days >= 2 { return "And you’d still have \(days) days left over." }
        if hours >= 1 { return "And you’d still have \(Int(hours)) hours left over." }
        return nil
    }
}

/// One year of phone time, with each habit's share filled in and the rest
/// left grey. Fills once revealed, like the waking-hours bar.
private struct BudgetBar: View {
    let budget: Double
    let segments: [Double]
    @State private var shown = false

    var body: some View {
        GeometryReader { proxy in
            let gap: CGFloat = 3
            let usable = max(proxy.size.width - gap * CGFloat(segments.count), 0)
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hex: "#E3E7EE"))
                HStack(spacing: gap) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, hours in
                        Rectangle()
                            .fill(Color(hex: "#2BB673"))
                            .frame(width: budget > 0 ? usable * hours / budget * (shown ? 1 : 0) : 0)
                    }
                }
                .clipShape(Capsule())
            }
        }
        .frame(height: 10)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) { shown = true }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - 5. Potential

private struct PotentialPanel: View {
    let data: RevealData

    var body: some View {
        let targets = RevealMath.potentialTargets(currentDailyHours: data.dailyHours)
        let current = data.projection.yearsOnPhone
        VStack(alignment: .leading, spacing: 18) {
            eyebrow("THE GOOD NEWS")
            Text(targets.isEmpty ? "You’re already ahead." : "You can get years of your life back.")
                .font(.geist(size: 28, weight: .bold))
                .foregroundStyle(RevealStyle.navy)
                .fixedSize(horizontal: false, vertical: true)
            if targets.isEmpty {
                Text("You’re under an hour a day. ScreenSpan will help you keep it that way and show you the time you protect.")
                    .font(.geist(size: 16))
                    .foregroundStyle(RevealStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                let best = current - data.years(atDailyHours: targets.first ?? 0)
                VStack(spacing: 14) {
                    ForEach(targets.reversed(), id: \.self) { target in
                        let back = current - data.years(atDailyHours: target)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("At \(formatDuration(target)) a day")
                                    .font(.geist(size: 15, weight: .semibold))
                                    .foregroundStyle(RevealStyle.navy)
                                Spacer()
                                Text(String(format: "+%.1f years", back))
                                    .font(.geist(size: 20, weight: .heavy))
                                    .foregroundStyle(RevealStyle.green)
                                    .monospacedDigit()
                            }
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color(hex: "#E3E7EE"))
                                    Capsule().fill(Color(hex: "#2BB673"))
                                        .frame(width: proxy.size.width * (best > 0 ? back / best : 0))
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding(16)
                        .background(RevealStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .accessibilityElement(children: .combine)
                    }
                }
                Text("Years back by age \(data.targetAge), compared with \(formatDuration(data.dailyHours)) a day.")
                    .font(.geist(size: 12))
                    .foregroundStyle(RevealStyle.muted)
            }
            Text("Next, let’s make a plan you can stick to.")
                .font(.geist(size: 16, weight: .semibold))
                .foregroundStyle(RevealStyle.navy)
        }
    }
}

// MARK: - Goal strip

/// Years back at one goal value. The host shows the row for the goal the user
/// has selected by moving its window; the report never learns the selection.
private struct GoalImpactRow: View {
    let data: RevealData
    let goalHours: Double

    var body: some View {
        let back = max(data.projection.yearsOnPhone - data.years(atDailyHours: goalHours), 0)
        VStack(alignment: .leading, spacing: 6) {
            if back >= 0.05 {
                Text(String(format: "+%.1f years", back))
                    .font(.geist(size: 44, weight: .heavy))
                    .foregroundStyle(RevealStyle.green)
                    .monospacedDigit()
                Text("of your life back by age \(data.targetAge) at \(formatDuration(goalHours)) a day, compared with \(formatDuration(data.dailyHours)) now.")
                    .font(.geist(size: 14, weight: .medium))
                    .foregroundStyle(RevealStyle.navy)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No time back yet")
                    .font(.geist(size: 30, weight: .heavy))
                    .foregroundStyle(RevealStyle.muted)
                Text("\(formatDuration(goalHours)) is at or above your \(formatDuration(data.dailyHours)) a day now. Pick a lower goal to win time back.")
                    .font(.geist(size: 14, weight: .medium))
                    .foregroundStyle(RevealStyle.navy)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .background(Color(hex: back >= 0.05 ? "#EEF8F2" : "#F6F7FA"),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
