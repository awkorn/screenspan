import SwiftUI

struct WelcomeView: View {
    var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ScreenSpan")
                .font(.geist(size: 40, weight: .heavy))
                .foregroundStyle(OnboardingStyle.navy)
                .padding(.top, 24)

            Spacer(minLength: 20)

            SpreadingLifeGrid()
                .accessibilityLabel("A grid of 960 squares, one for each month of an 80-year life, with red squares spreading across it.")

            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 10) {
                Text("This is an 80-year life.")
                    .font(.geist(size: 30, weight: .bold))
                    .foregroundStyle(OnboardingStyle.navy)
                Text("960 months. One square for each.")
                    .font(.geist(size: 17))
                    .foregroundStyle(OnboardingStyle.muted)
                Text("How many will you spend on your phone?")
                    .font(.geist(size: 20, weight: .semibold))
                    .foregroundStyle(OnboardingStyle.red)
                    .padding(.top, 6)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 24)

            OnboardingPrimaryButton(title: "Find out") { viewModel.advance() }
            Label("Your Screen Time stays private on your iPhone.", systemImage: "lock.fill")
                .font(.geist(size: 12))
                .foregroundStyle(OnboardingStyle.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .background(Color.white.ignoresSafeArea())
    }
}

/// 960 months; red squares appear in a fixed scattered order over a few
/// seconds until about a fifth of the life is red.
private struct SpreadingLifeGrid: View {
    private static let months = 960
    private static let columns = 36
    private static let order: [Int] = {
        var generator = SeededGenerator(seed: 960)
        return Array(0..<months).shuffled(using: &generator)
    }()
    private let finalShare = 0.2
    private let duration = 3.2
    @State private var start = Date()
    @State private var isFinished = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: isFinished)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            let progress = min(max((elapsed - 0.4) / duration, 0), 1)
            let eased = 1 - pow(1 - progress, 2)
            let redCount = Int(Double(Self.months) * finalShare * eased)
            let red = Set(Self.order.prefix(redCount))
            Canvas { context, size in
                let gap: CGFloat = 2
                let cell = (size.width - CGFloat(Self.columns - 1) * gap) / CGFloat(Self.columns)
                for month in 0..<Self.months {
                    let rect = CGRect(x: CGFloat(month % Self.columns) * (cell + gap),
                                      y: CGFloat(month / Self.columns) * (cell + gap),
                                      width: cell, height: cell)
                    let color = red.contains(month) ? LifeGridView.phoneColor : Color(hex: "#E3E6EB")
                    context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color))
                }
            }
        }
        .aspectRatio(CGFloat(Self.columns) / CGFloat((Self.months + Self.columns - 1) / Self.columns), contentMode: .fit)
        .task {
            start = Date()
            try? await Task.sleep(for: .seconds(duration + 0.6))
            isFinished = true
        }
    }
}

/// Deterministic shuffle so the pattern is the same every launch.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
