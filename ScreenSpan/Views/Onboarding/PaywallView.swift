import SwiftUI

// MARK: - Plan Model
struct PricingPlan: Identifiable {
    let id = UUID()
    let name: String
    let price: String
    let period: String
    let pricePerMonth: Double
    let isPopular: Bool
}

// MARK: - Paywall View
struct PaywallView: View {
    var viewModel: OnboardingViewModel
    @State private var selectedPlan: PricingPlan?
    @State private var isAnimating = false
    @State private var showTrialDetails = false

    private var reclaimedYearsFormatted: String {
        String(format: "%.1f", viewModel.reclaimedYears)
    }

    private let plans = [
        PricingPlan(
            name: "Monthly",
            price: "$4.99",
            period: "per month",
            pricePerMonth: 4.99,
            isPopular: false
        ),
        PricingPlan(
            name: "Annual",
            price: "$29.99",
            period: "per year",
            pricePerMonth: 2.50,
            isPopular: true
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Text("Get your time back")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.screenSpanNavy)

                        Text("You could reclaim \(reclaimedYearsFormatted) years with your goal")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 32)

                    // Benefits
                    VStack(spacing: 12) {
                        BenefitRow(
                            icon: "target.circle.fill",
                            title: "Customized daily limits",
                            subtitle: "Based on your usage patterns"
                        )

                        BenefitRow(
                            icon: "bell.badge.fill",
                            title: "Smart reminders",
                            subtitle: "Get notified when approaching limits"
                        )

                        BenefitRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Detailed analytics",
                            subtitle: "Track your progress over time"
                        )
                    }
                    .padding(.horizontal, 24)

                    // Trial Timeline
                    TrialTimelineView()
                        .padding(.horizontal, 24)

                    // Pricing Plans
                    VStack(spacing: 12) {
                        ForEach(plans) { plan in
                            PlanCard(
                                plan: plan,
                                isSelected: selectedPlan?.id == plan.id,
                                action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedPlan = plan
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }

            Spacer()

            // CTA Section
            VStack(spacing: 16) {
                Button(action: {
                    // TODO: Integrate StoreKit for purchases
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.advance()
                    }
                }) {
                    Text("Start Free Trial")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.screenSpanRed)
                        .cornerRadius(12)
                }

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.advance()
                    }
                }) {
                    Text("Maybe later")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.screenSpanBlue)
                }

                // Footer Links
                HStack(spacing: 12) {
                    Link("Restore Purchases", destination: URL(string: "https://example.com/restore") ?? URL(fileURLWithPath: ""))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Divider()
                        .frame(height: 12)

                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy") ?? URL(fileURLWithPath: ""))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Divider()
                        .frame(height: 12)

                    Link("Terms", destination: URL(string: "https://example.com/terms") ?? URL(fileURLWithPath: ""))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.screenSpanOffWhite.ignoresSafeArea())
        .onAppear {
            withAnimation {
                selectedPlan = plans[1] // Default to Annual
                isAnimating = true
            }
        }
    }
}

// MARK: - Benefit Row
struct BenefitRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.screenSpanRed)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.screenSpanNavy)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(8)
    }
}

// MARK: - Trial Timeline View
struct TrialTimelineView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Free trial: 7 days")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                VStack(spacing: 8) {
                    Circle()
                        .fill(Color.screenSpanRed)
                        .frame(width: 12, height: 12)

                    Text("Today")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 0) {
                    Divider()
                        .frame(height: 2)
                        .background(Color.screenSpanRed.opacity(0.3))
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 8) {
                    Circle()
                        .fill(Color.screenSpanRed.opacity(0.5))
                        .frame(width: 12, height: 12)

                    Text("Day 5")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 0) {
                    Divider()
                        .frame(height: 2)
                        .background(Color.screenSpanRed.opacity(0.3))
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 8) {
                    Circle()
                        .fill(Color.screenSpanBlue)
                        .frame(width: 12, height: 12)

                    Text("Day 7")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
    }
}

// MARK: - Plan Card
struct PlanCard: View {
    let plan: PricingPlan
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.screenSpanNavy)

                        if plan.isPopular {
                            Text("Save 58%")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.screenSpanRed)
                                .cornerRadius(4)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(plan.price)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.screenSpanRed)

                        Text(plan.period)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                if plan.isPopular {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Recommended")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.screenSpanRed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.screenSpanRed.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.screenSpanRed : Color.screenSpanNavy.opacity(0.1),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
    }
}
