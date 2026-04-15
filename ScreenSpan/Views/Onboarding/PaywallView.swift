import SwiftUI

// MARK: - Paywall View (Step 8)
struct PaywallView: View {
    var viewModel: OnboardingViewModel

    @State private var selectedPlan: Plan = .annual

    private let titleColor = Color(hex: "#051425")
    private let subtitleColor = Color(hex: "#595959")
    private let iconColor = Color(hex: "#C82020")
    private let moneyColor = Color(hex: "#0063D6")
    private let cardTitleColor = Color(hex: "#051425")
    private let cardSubtitleColor = Color(hex: "#595959")

    private var reclaimedYearsRounded: Int {
        Int(viewModel.reclaimedYears.rounded())
    }

    enum Plan {
        case monthly
        case annual
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    headerSection
                        .padding(.top, 24)

                    benefitCard(
                        icon: "shield.lefthalf.filled.badge.checkmark",
                        title: "Customize daily limits",
                        subtitle: "Block apps based on your goals"
                    )

                    benefitCard(
                        icon: "bell",
                        title: "Smart reminders",
                        subtitle: "Get notified when approaching limits"
                    )

                    benefitCard(
                        icon: "chart.xyaxis.line",
                        title: "Detailed analytics",
                        subtitle: "See your progress over time"
                    )

                    trialCard
                        .padding(.top, 8)

                    planCard(plan: .monthly)
                    planCard(plan: .annual)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }

            VStack(spacing: 14) {
                Button {
                    Task {
                        await viewModel.completeOnboarding()
                    }
                } label: {
                    Text("Start free trial")
                        .onboardingPrimaryButtonStyle()
                }

                Button {
                    Task {
                        await viewModel.completeOnboarding()
                    }
                } label: {
                    Text("Maybe later")
                        .font(.geist(size: 15))
                        .foregroundColor(subtitleColor)
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    legalButton(title: "Restore Purchases")
                    legalDivider
                    legalButton(title: "Privacy Policy")
                    legalDivider
                    legalButton(title: "Terms")
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color.white.ignoresSafeArea())
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Get your time back")
                .font(.geist(size: 28, weight: .bold))
                .foregroundColor(titleColor)

            Text("Reclaim those \(reclaimedYearsRounded) years of your life")
                .font(.geist(size: 18))
                .foregroundColor(subtitleColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func benefitCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.geist(size: 16, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.geist(size: 16, weight: .semibold))
                    .foregroundColor(cardTitleColor)

                Text(subtitle)
                    .font(.geist(size: 12))
                    .foregroundColor(cardSubtitleColor)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.screenSpanCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var trialCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Free trial: 7 days")
                .font(.geist(size: 16, weight: .semibold))
                .foregroundColor(cardTitleColor)

            VStack(spacing: 4) {
                HStack(spacing: 0) {
                    Circle()
                        .fill(titleColor)
                        .frame(width: 10, height: 10)

                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 1)
                        .overlay {
                            Rectangle()
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                                .foregroundColor(titleColor.opacity(0.6))
                        }

                    Circle()
                        .fill(titleColor)
                        .frame(width: 10, height: 10)
                }

                HStack {
                    Text("Today")
                    Spacer()
                    Text("Cancel anytime")
                    Spacer()
                    Text("Day 7")
                }
                .font(.geist(size: 12))
                .foregroundColor(cardSubtitleColor)
            }
        }
        .padding(16)
        .background(Color.screenSpanCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func planCard(plan: Plan) -> some View {
        let isSelected = selectedPlan == plan

        return Button {
            selectedPlan = plan
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan == .monthly ? "Monthly" : "Annual")
                        .font(.geist(size: 16, weight: .semibold))
                        .foregroundColor(cardTitleColor)

                    if plan == .annual {
                        Text("Save 58%")
                            .font(.geist(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#F63232"))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(plan == .monthly ? "$4.99" : "$29.99")
                        .font(.geist(size: 16, weight: .semibold))
                        .foregroundColor(moneyColor)

                    Text(plan == .monthly ? "per month" : "per year")
                        .font(.geist(size: 13))
                        .foregroundColor(cardSubtitleColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Color.screenSpanCardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? moneyColor : Color(hex: "#D9DDE3"), lineWidth: isSelected ? 2 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var legalDivider: some View {
        Text("|")
            .foregroundColor(cardSubtitleColor.opacity(0.6))
    }

    private func legalButton(title: String) -> some View {
        Button {
            // TODO: Wire legal actions
        } label: {
            Text(title)
                .font(.geist(size: 12))
                .foregroundColor(cardSubtitleColor)
        }
        .buttonStyle(.plain)
    }
}
