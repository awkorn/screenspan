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
    var topAppHours: Double?
    var topAppLabel: AnyView?
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

/// The five reveal panels stacked vertically at equal heights. The host owns
/// navigation and shows one panel at a time through `OnboardingReportViewport`.
struct OnboardingRevealPanels: View {
    static let panelCount = 5
    let data: RevealData

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height / CGFloat(Self.panelCount)
            VStack(spacing: 0) {
                RealityCheckPanel(data: data).panelFrame(height: height)
                LifetimePanel(data: data).panelFrame(height: height)
                LifeGridPanel(data: data).panelFrame(height: height)
                YearlyCostPanel(data: data).panelFrame(height: height)
                PotentialPanel(data: data).panelFrame(height: height)
            }
        }
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

private struct LifetimePanel: View {
    let data: RevealData

    var body: some View {
        let projection = data.projection
        VStack(alignment: .leading, spacing: 18) {
            eyebrow("YOUR FUTURE")
            Text("At \(formatDuration(data.dailyHours)) a day, by age \(data.targetAge) you’ll spend")
                .font(.geist(size: 26, weight: .bold))
                .foregroundStyle(RevealStyle.navy)
                .fixedSize(horizontal: false, vertical: true)
            TapToReveal(prompt: "Tap to reveal your number") {
                VStack(alignment: .leading, spacing: 4) {
                    CountUpText(target: projection.yearsOnPhone) { String(format: "%.1f", $0) }
                        .font(.geist(size: 84, weight: .heavy))
                        .foregroundStyle(RevealStyle.red)
                        .monospacedDigit()
                    Text("YEARS ON YOUR PHONE")
                        .font(.geist(size: 18, weight: .bold))
                        .foregroundStyle(RevealStyle.navy)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 10) {
                fact(value: "\(formatCount(projection.percentOfWakingLife))%", label: "of your waking hours")
                fact(value: formatCount(projection.monthsOnPhone), label: "months of your life")
            }
            Text(data.isMeasured
                 ? "Projection if your last 7 days continue. 24-hour years; 16 waking hours a day."
                 : "Projection from your estimate. 24-hour years; 16 waking hours a day.")
                .font(.geist(size: 12))
                .foregroundStyle(RevealStyle.muted)
        }
    }

    private func fact(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.geist(size: 22, weight: .bold)).foregroundStyle(RevealStyle.navy).monospacedDigit()
            Text(label).font(.geist(size: 13)).foregroundStyle(RevealStyle.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RevealStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            if data.pickupsPerDay != nil || data.topAppHours != nil {
                VStack(spacing: 0) {
                    if let pickups = data.pickupsPerDay, pickups >= 1 {
                        detailRow(icon: "hand.tap", title: "\(formatCount(pickups * 365)) pickups a year",
                                  detail: "\(formatCount(pickups)) a day")
                    }
                    if let hours = data.topAppHours, let label = data.topAppLabel {
                        HStack(spacing: 12) {
                            label.font(.geist(size: 15, weight: .semibold)).lineLimit(1)
                            Spacer(minLength: 8)
                            Text(String(format: "%.1f years by %d", data.years(atDailyHours: hours), data.targetAge))
                                .font(.geist(size: 14, weight: .semibold))
                                .foregroundStyle(RevealStyle.red)
                                .monospacedDigit()
                        }
                        .padding(16)
                    }
                }
                .background(RevealStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            Text("That’s enough time to:")
                .font(.geist(size: 16, weight: .semibold))
                .foregroundStyle(RevealStyle.navy)
            VStack(spacing: 10) {
                ForEach(data.intentions.prefix(3)) { intention in
                    let count = intention.unitsPerYear(dailyHours: data.dailyHours)
                    HStack(spacing: 14) {
                        Image(systemName: intention.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(RevealStyle.green)
                            .frame(width: 36, height: 36)
                            .background(Color(hex: "#E7F5EC"), in: RoundedRectangle(cornerRadius: 10))
                        (Text(formatCount(count)).font(.geist(size: 18, weight: .bold))
                         + Text(" \(intention.unitLabel(count: count))").font(.geist(size: 15, weight: .medium)))
                            .foregroundStyle(RevealStyle.navy)
                        Spacer()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Text("Per year. Assumes " + data.intentions.prefix(3).map(\.assumption).joined(separator: ", ") + ".")
                .font(.geist(size: 11))
                .foregroundStyle(RevealStyle.muted)
        }
    }

    private func detailRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Color(hex: "#235187")).frame(width: 22)
            Text(title).font(.geist(size: 15, weight: .semibold))
            Spacer()
            Text(detail).font(.geist(size: 13)).foregroundStyle(RevealStyle.muted)
        }
        .padding(16)
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
            Text("Next, pick the daily goal you want to commit to.")
                .font(.geist(size: 16, weight: .semibold))
                .foregroundStyle(RevealStyle.navy)
        }
    }
}
