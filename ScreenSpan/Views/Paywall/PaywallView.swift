import StoreKit
import SwiftUI

/// ScreenSpan Pro: blocking is the paid experience; insights stay free.
/// Prices, trial length, and renewal terms all come from StoreKit, and the
/// terms sit next to the button, as App Review requires.
struct PaywallView: View {
    /// Replaces the goal-based title, for example with the plan's time back.
    var headline: String?
    /// Called with true after a purchase or restore, false when dismissed.
    var onFinish: (_ purchased: Bool) -> Void

    @EnvironmentObject private var store: StoreKitService
    @AppStorage(SharedConstants.UserDefaultsKey.screenTimeGoalMinutes.rawValue, store: .appGroup)
    private var goalMinutes = 0.0
    @State private var selectedID = AppConstants.ProductID.annualSubscription
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var notice: Notice?

    private var selected: Product? { store.products.first { $0.id == selectedID } }
    private var trial: String? { store.isEligibleForTrial ? selected?.freeTrialLength : nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                WinBackGrid()
                    .padding(.top, 52)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.geist(size: 28, weight: .bold))
                    .foregroundStyle(OnboardingStyle.navy)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 24)
                Text("Cut back on the apps that pull you in, a little each week, with limits that hold.")
                    .font(.geist(size: 15))
                    .foregroundStyle(OnboardingStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 14) {
                    feature("chart.line.downtrend.xyaxis", "Your step-down plan", "Daily limits for your top apps that get a little lower each week.")
                    feature("hourglass", "Focus blocks", "Lock distracting apps for 15 minutes or the whole afternoon.")
                    feature("moon.zzz", "Schedules", "Bedtime and work hours turn on by themselves.")
                    feature("timer", "Daily limits", "Give an app 30 minutes a day. Then it waits until tomorrow.")
                    feature("lock.shield", "Strict mode", "No ending a block early when willpower runs low.")
                }
                .padding(.top, 24)

                if let trial, let selected {
                    TrialTimeline(trial: trial, price: selected.displayPrice, period: selected.periodName)
                        .padding(.top, 20)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) { footer }
        .overlay(alignment: .topTrailing) { closeButton }
        .background(Color.white.ignoresSafeArea())
        .screenSpanLightSurface()
        .task { await store.loadProducts() }
        .alert(item: $notice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("OK")))
        }
        .interactiveDismissDisabled(isPurchasing)
    }

    private var title: String {
        if let headline { return headline }
        return goalMinutes > 0 ? "Make your \(Self.format(minutes: goalMinutes)) goal stick" : "Take your time back"
    }

    // MARK: - Sections

    private var closeButton: some View {
        Button { onFinish(false) } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(OnboardingStyle.muted)
                .frame(width: 32, height: 32)
                .background(OnboardingStyle.card, in: Circle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.top, 12)
        .disabled(isPurchasing)
        .accessibilityLabel("Close")
    }

    private func feature(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(OnboardingStyle.red)
                .frame(width: 32, height: 32)
                .background(Color(hex: "#FDECEC"), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.geist(size: 15, weight: .semibold)).foregroundStyle(OnboardingStyle.navy)
                Text(text).font(.geist(size: 13)).foregroundStyle(OnboardingStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var plans: some View {
        switch store.loadState {
        case .failed:
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Couldn’t reach the App Store")
                        .font(.geist(size: 15, weight: .semibold))
                        .foregroundStyle(OnboardingStyle.navy)
                    Text("Check your connection, then try again.")
                        .font(.geist(size: 13))
                        .foregroundStyle(OnboardingStyle.muted)
                }
                Spacer(minLength: 0)
                Button("Try again") { Task { await store.loadProducts() } }
                    .font(.geist(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#0063D6"))
            }
            .padding(16)
            .background(OnboardingStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .loaded:
            VStack(spacing: 8) {
                ForEach(store.products, id: \.id) { product in
                    PlanCard(product: product,
                             isSelected: product.id == selectedID,
                             badge: badge(for: product),
                             trial: store.isEligibleForTrial ? product.freeTrialLength : nil) {
                        withAnimation(.snappy) { selectedID = product.id }
                    }
                }
            }
        case .idle, .loading:
            VStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(OnboardingStyle.card)
                        .frame(height: PlanCard.height)
                }
            }
            .overlay { ProgressView() }
            .accessibilityLabel("Loading plans")
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            // Plans sit with the button so the price is always beside it.
            plans.padding(.bottom, 4)
            OnboardingPrimaryButton(title: buttonTitle, isEnabled: selected != nil && !isPurchasing && !isRestoring) {
                Task { await purchase() }
            }
            .overlay(alignment: .trailing) {
                if isPurchasing { ProgressView().tint(.white).padding(.trailing, 22) }
            }
            Text(terms)
                .font(.geist(size: 11))
                .foregroundStyle(OnboardingStyle.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 14) {
                Button(isRestoring ? "Restoring…" : "Restore Purchases") { Task { await restore() } }
                    .disabled(isPurchasing || isRestoring)
                Text("·").accessibilityHidden(true)
                Link("Terms of Use", destination: AppConstants.Legal.termsOfUse)
                Text("·").accessibilityHidden(true)
                Link("Privacy Policy", destination: AppConstants.Legal.privacyPolicy)
            }
            .font(.geist(size: 12, weight: .medium))
            .foregroundStyle(OnboardingStyle.muted)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background {
            Rectangle()
                .fill(Color.white.shadow(.drop(color: .black.opacity(0.06), radius: 12, y: -4)))
                .ignoresSafeArea()
        }
    }

    private var buttonTitle: String {
        guard let selected else { return "Continue" }
        if let trial { return "Start my \(trial) free trial" }
        return "Subscribe for \(selected.displayPrice)/\(selected.periodName)"
    }

    private var terms: String {
        guard let selected else { return "Subscriptions renew automatically until canceled." }
        let price = "\(selected.displayPrice) per \(selected.periodName)"
        let duration = store.isEligibleForTrial ? selected.freeTrialDuration : nil
        let lead = duration.map { "Free for \($0), then \(price)." } ?? "\(price)."
        return "\(lead) Renews automatically unless canceled at least 24 hours before the end of the current period. Cancel anytime in Settings › Apple Account › Subscriptions."
    }

    private func badge(for product: Product) -> String? {
        guard product.id == AppConstants.ProductID.annualSubscription, let monthly = store.monthly,
              monthly.price > 0 else { return nil }
        let yearly = NSDecimalNumber(decimal: monthly.price * 12).doubleValue
        let saving = 1 - NSDecimalNumber(decimal: product.price).doubleValue / yearly
        return saving >= 0.1 ? "Save \(Int((saving * 100).rounded(.down)))%" : nil
    }

    // MARK: - Actions

    private func purchase() async {
        guard let selected else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        switch await store.purchase(selected) {
        case .purchased:
            onFinish(true)
        case .pending:
            notice = Notice(title: "Waiting for approval",
                            message: "Your purchase needs approval. ScreenSpan Pro unlocks as soon as it goes through.")
        case .cancelled:
            break
        case .failed(let message):
            notice = Notice(title: "Purchase didn’t go through", message: message)
        }
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        if await store.restore() {
            onFinish(true)
        } else {
            notice = Notice(title: "Nothing to restore",
                            message: "We couldn’t find an active ScreenSpan Pro subscription for this Apple Account.")
        }
    }

    static func format(minutes: Double) -> String {
        let minutes = Int(minutes.rounded())
        if minutes < 60 { return "\(minutes)m" }
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }
}

private struct Notice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct PlanCard: View {
    let product: Product
    let isSelected: Bool
    let badge: String?
    let trial: String?
    let action: () -> Void

    static let height: CGFloat = 64
    private let blue = Color(hex: "#0063D6")

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? blue : Color(hex: "#C5CCD6"))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(product.subscription?.subscriptionPeriod.unit == .year ? "Yearly" : "Monthly")
                            .font(.geist(size: 16, weight: .semibold))
                            .foregroundStyle(OnboardingStyle.navy)
                        if let badge {
                            Text(badge)
                                .font(.geist(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color(hex: "#2BB673"), in: Capsule())
                        }
                    }
                    Text(detail)
                        .font(.geist(size: 13))
                        .foregroundStyle(OnboardingStyle.muted)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.geist(size: 17, weight: .bold))
                        .foregroundStyle(OnboardingStyle.navy)
                    Text("per \(product.periodName)")
                        .font(.geist(size: 12))
                        .foregroundStyle(OnboardingStyle.muted)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: Self.height)
            .background(isSelected ? Color(hex: "#F0F6FF") : OnboardingStyle.card,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? blue : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var detail: String {
        var parts: [String] = []
        if let trial { parts.append("\(trial) free trial") }
        if let perMonth = product.monthlyEquivalent { parts.append("\(perMonth)/month") }
        return parts.isEmpty ? "Cancel anytime" : parts.joined(separator: " · ")
    }
}

/// What happens when, so the trial holds no surprises.
private struct TrialTimeline: View {
    let trial: String
    let price: String
    let period: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            step(icon: "lock.open.fill", color: Color(hex: "#2BB673"), title: "Today",
                 text: "Full access to focus blocks, schedules, and limits.", showsLine: true)
            step(icon: "creditcard.fill", color: OnboardingStyle.navy,
                 title: "After your \(trial) trial",
                 text: "\(price) per \(period) begins, unless you cancel before then.", showsLine: false)
        }
        .padding(16)
        .background(OnboardingStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func step(icon: String, color: Color, title: String, text: String, showsLine: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(color, in: Circle())
                if showsLine {
                    Rectangle().fill(Color(hex: "#D9DDE3")).frame(width: 2).frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.geist(size: 14, weight: .semibold)).foregroundStyle(OnboardingStyle.navy)
                Text(text).font(.geist(size: 13)).foregroundStyle(OnboardingStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, showsLine ? 16 : 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// A strip of life-grid months: phone months (red) turn back into the
/// user's (green), the same visual language as the dashboard.
private struct WinBackGrid: View {
    private static let columns = 30
    private static let rows = 6
    private static let gap: CGFloat = 2
    @State private var start = Date()
    @State private var isFinished = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: isFinished)) { timeline in
            let progress = min(max((timeline.date.timeIntervalSince(start) - 0.5) / 1.8, 0), 1)
            Canvas { context, size in
                let cell = (size.width - CGFloat(Self.columns - 1) * Self.gap) / CGFloat(Self.columns)
                for index in 0..<(Self.columns * Self.rows) {
                    let rect = CGRect(x: CGFloat(index % Self.columns) * (cell + Self.gap),
                                      y: CGFloat(index / Self.columns) * (cell + Self.gap),
                                      width: cell, height: cell)
                    // A fixed scatter: about a quarter are phone months, and
                    // most of those are won back as the strip animates.
                    let hash = (index * 7919 + 104_729) % 97
                    let color: Color
                    if hash < 24 {
                        color = Double(hash) / 24 < progress * 0.8 ? LifeGridView.regainedColor : LifeGridView.phoneColor
                    } else {
                        color = Color(hex: "#E3E6EB")
                    }
                    context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color))
                }
            }
        }
        // Full width; rows of square cells, close enough to their real height.
        .aspectRatio(CGFloat(Self.columns) / (CGFloat(Self.rows) * 1.03), contentMode: .fit)
        .task {
            start = Date()
            try? await Task.sleep(for: .seconds(2.6))
            isFinished = true
        }
    }
}
