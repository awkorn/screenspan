import SwiftUI

/// Premium-gated history tab showing trends over time
/// Free users see a locked state with upsell prompt.
/// Premium users see trend analytics and historical data.
struct HistoryTabView: View {
    @State private var viewModel = HistoryViewModel()
    @State private var showPaywall = false
    @AppStorage("isPremium") private var isPremium = false

    var body: some View {
        NavigationStack {
            ZStack {
                if isPremium {
                    premiumContent
                } else {
                    lockedContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(hex: "#F8F9FA"))
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("History")
                        .font(.geist(.headline, weight: .semibold))
                        .foregroundStyle(Color(hex: "#1B2A4A"))
                }
            }
            .sheet(isPresented: $showPaywall) {
                HistoryPaywallSheet(isPresented: $showPaywall)
            }
        }
    }

    // MARK: - Premium Content
    private var premiumContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Time Period Selector
                timePeriodSection

                // MARK: - Trend Indicator
                trendSection

                // MARK: - Line Chart Placeholder
                chartSection

                // MARK: - Life Reclaimed Callout
                lifeReclaimedSection

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Locked Content
    private var lockedContent: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.geist(size: 48))
                    .foregroundColor(Color(hex: "#E63946"))

                VStack(spacing: 8) {
                    Text("Upgrade to unlock trends")
                        .font(.geist(.headline))
                        .foregroundColor(Color(hex: "#1B2A4A"))

                    Text("See how your screen time has evolved over time and identify patterns to improve your digital wellness.")
                        .font(.geist(.subheadline))
                        .foregroundColor(Color(hex: "#A8DADC"))
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)

            Button(action: { showPaywall = true }) {
                HStack {
                    Text("Upgrade to Premium")
                        .font(.geist(.headline))

                    Image(systemName: "arrow.right")
                        .font(.geist(.subheadline))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(hex: "#E63946"))
                .foregroundColor(.white)
                .cornerRadius(10)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Time Period Section
    private var timePeriodSection: some View {
        HStack(spacing: 8) {
            ForEach(["1M", "3M", "6M", "1Y"], id: \.self) { period in
                Button(action: { viewModel.selectedPeriod = period }) {
                    Text(period)
                        .font(.geist(.caption))
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            viewModel.selectedPeriod == period
                                ? Color(hex: "#457B9D")
                                : Color.white
                        )
                        .foregroundColor(
                            viewModel.selectedPeriod == period
                                ? .white
                                : Color(hex: "#1B2A4A")
                        )
                        .cornerRadius(6)
                }
            }

            Spacer()
        }
    }

    // MARK: - Trend Section
    private var trendSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Trend")
                    .textCase( .uppercase )
                    .font(.geist(.caption))
                    .foregroundColor(Color(hex: "#A8DADC"))
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(Color(hex: "#457B9D"))

                    Text("12.5% decrease")
                        .font(.geist(.headline))
                        .foregroundColor(Color(hex: "#1B2A4A"))
                }
            }

            Spacer()

            Text("vs previous period")
                .font(.geist(.caption2))
                .foregroundColor(Color(hex: "#A8DADC"))
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }

    // MARK: - Chart Section (Placeholder)
    private var chartSection: some View {
        VStack(spacing: 12) {
            Text("Screen Time Trend")
                .font(.geist(.headline))
                .foregroundColor(Color(hex: "#1B2A4A"))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Placeholder for line chart
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#457B9D").opacity(0.1),
                            Color(hex: "#E63946").opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 180)
                .overlay(
                    HStack(spacing: 20) {
                        ForEach(0..<5, id: \.self) { _ in
                            VStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: "#457B9D").opacity(0.3))
                                    .frame(width: 4, height: CGFloat.random(in: 60...140))

                                Spacer()
                            }
                        }
                    }
                    .padding()
                )
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }

    // MARK: - Life Reclaimed Section
    private var lifeReclaimedSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Life Reclaimed")
                        .font(.geist(.headline))
                        .foregroundColor(Color(hex: "#1B2A4A"))

                    Text("Last 3 months")
                        .font(.geist(.caption))
                        .foregroundColor(Color(hex: "#A8DADC"))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("28h 30m")
                        .font(.geist(.title3))
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "#457B9D"))

                    Text("of screen time reduced"
                    )
                        .font(.geist(.caption2))
                        .foregroundColor(Color(hex: "#A8DADC"))
                }
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#457B9D").opacity(0.1),
                        Color(hex: "#A8DADC").opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
        }
    }
}

// MARK: - History Paywall Sheet (Placeholder)
struct HistoryPaywallSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack {
                Text("Upgrade to Premium")
                    .font(.geist(.title))
                    .fontWeight(.bold)

                Spacer()

                VStack(spacing: 12) {
                    paymentFeature("Unlimited History", "View trends over time")
                    paymentFeature("Advanced Analytics", "Deep insights into habits")
                    paymentFeature("Custom Goals", "Set and track your own targets")
                }

                Spacer()

                Button(action: { isPresented = false }) {
                    Text("Continue with Premium")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#E63946"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Premium")
                        .font(.geist(.headline, weight: .semibold))
                        .foregroundStyle(Color(hex: "#1B2A4A"))
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isPresented = false
                    } label: {
                        Text("Close")
                            .font(.geist(.body))
                    }
                }
            }
        }
    }

    private func paymentFeature(_ title: String, _ description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(hex: "#457B9D"))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.geist(.headline))
                    .foregroundColor(Color(hex: "#1B2A4A"))

                Text(description)
                    .font(.geist(.caption))
                    .foregroundColor(Color(hex: "#A8DADC"))
            }

            Spacer()
        }
    }
}
