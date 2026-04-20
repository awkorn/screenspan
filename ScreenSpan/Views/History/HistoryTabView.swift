import SwiftUI
import DeviceActivity

/// Premium-gated history tab showing trends over time.
///
/// PRIVACY MODEL
/// -------------
/// Historical screen time trends are Screen Time data and must only be
/// processed inside the `DeviceActivityReport` extension. The free /
/// premium gate uses the user's subscription status (allowed in the host
/// app). When the user is premium, the host embeds the extension via
/// `DeviceActivityReport(.history, filter:)` — the trend chart, deltas,
/// and life-reclaimed values are all drawn inside the extension process
/// and handed back as pixels.
struct HistoryTabView: View {
    @EnvironmentObject private var authService: AuthorizationService
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
    /// Premium users see the DeviceActivityReport extension embedded here.
    /// All trend values, weekly averages, and deltas are rendered inside
    /// the extension process — the host never receives numeric usage data.
    private var premiumContent: some View {
        Group {
            if authService.isAuthorized {
                DeviceActivityReport(
                    .history,
                    filter: .screenSpanHistory
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                authorizationRequiredView
            }
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

    private var authorizationRequiredView: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "chart.line.uptrend.xyaxis.circle")
                .font(.geist(size: 40, weight: .semibold))
                .foregroundColor(Color(hex: "#1B2A4A"))

            VStack(spacing: 8) {
                Text("Enable Screen Time to view trends")
                    .font(.geist(.headline))
                    .foregroundColor(Color(hex: "#1B2A4A"))

                Text("History is now rendered by the Device Activity report extension, so we need Screen Time access before those trend screens can load.")
                    .font(.geist(.subheadline))
                    .foregroundColor(Color(hex: "#A8DADC"))
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await authService.requestAuthorization()
                }
            } label: {
                Text("Allow Screen Time Access")
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
