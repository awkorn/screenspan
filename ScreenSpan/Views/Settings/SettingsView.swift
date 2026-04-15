import SwiftUI

/// Settings view with user profile, goals, notifications, and subscription management
/// Organized into sections: Profile, Goal, Notifications, Subscription, About
struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var showRestorePurchases = false
    @State private var showResetOnboardingAlert = false
    @AppStorage("userAge") private var userAge: Int = 25
    @AppStorage("targetLifespan") private var targetLifespan: Int = 80
    @AppStorage("dailyGoal") private var dailyGoal: Int = 120
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("isPremium") private var isPremium = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Profile Section
                profileSection

                // MARK: - Goal Section
                goalSection

                // MARK: - Notifications Section
                notificationsSection

                // MARK: - Subscription Section
                subscriptionSection

                // MARK: - About Section
                aboutSection

                #if DEBUG
                // MARK: - Developer Section
                developerSection
                #endif
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(hex: "#F8F9FA"))
            .scrollContentBackground(.hidden)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.geist(.headline, weight: .semibold))
                        .foregroundStyle(Color(hex: "#1B2A4A"))
                }
            }
        }
    }

    // MARK: - Profile Section
    private var profileSection: some View {
        Section(header: Text("PROFILE").font(.geist(.caption)).fontWeight(.semibold).foregroundColor(Color(hex: "#A8DADC"))) {
            VStack(spacing: 16) {
                // Age Editor
                HStack {
                    Text("Current Age")
                        .foregroundColor(Color(hex: "#1B2A4A"))

                    Spacer()

                    HStack(spacing: 8) {
                        Button(action: { userAge = max(1, userAge - 1) }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(Color(hex: "#457B9D"))
                        }

                        TextField("Age", value: $userAge, format: .number)
                            .keyboardType(.numberPad)
                            .frame(width: 50)
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color(hex: "#1B2A4A"))

                        Button(action: { userAge = min(150, userAge + 1) }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Color(hex: "#457B9D"))
                        }
                    }
                }

                Divider()

                // Target Lifespan Slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Target Lifespan")
                            .foregroundColor(Color(hex: "#1B2A4A"))

                        Spacer()

                        Text("\(targetLifespan) years")
                            .font(.geist(.headline))
                            .foregroundColor(Color(hex: "#457B9D"))
                    }

                    Slider(value: Binding<Double>(
                        get: { Double(targetLifespan) },
                        set: { targetLifespan = Int($0) }
                    ), in: 70...100, step: 1)
                    .tint(Color(hex: "#457B9D"))

                    HStack(spacing: 20) {
                        Text("70")
                            .font(.geist(.caption2))
                            .foregroundColor(Color(hex: "#A8DADC"))

                        Spacer()

                        Text("100")
                            .font(.geist(.caption2))
                            .foregroundColor(Color(hex: "#A8DADC"))
                    }
                }
            }
        }
    }

    // MARK: - Goal Section
    private var goalSection: some View {
        Section(header: Text("GOAL").font(.geist(.caption)).fontWeight(.semibold).foregroundColor(Color(hex: "#A8DADC"))) {
            VStack(spacing: 16) {
                // Daily Goal Slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Daily Screen Time Goal")
                            .foregroundColor(Color(hex: "#1B2A4A"))

                        Spacer()

                        Text(formatMinutes(dailyGoal))
                            .font(.geist(.headline))
                            .foregroundColor(Color(hex: "#E63946"))
                    }

                    Slider(value: Binding<Double>(
                        get: { Double(dailyGoal) },
                        set: { dailyGoal = Int($0) }
                    ), in: 30...480, step: 5)
                    .tint(Color(hex: "#E63946"))

                    HStack(spacing: 20) {
                        Text("30m")
                            .font(.geist(.caption2))
                            .foregroundColor(Color(hex: "#A8DADC"))

                        Spacer()

                        Text("8h")
                            .font(.geist(.caption2))
                            .foregroundColor(Color(hex: "#A8DADC"))
                    }
                }

                Divider()

                // Selected Categories
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tracked Categories")
                        .font(.geist(.subheadline))
                        .foregroundColor(Color(hex: "#1B2A4A"))

                    HStack(spacing: 8) {
                        categoryBadge("Social Media", Color(hex: "#E63946"))
                        categoryBadge("Entertainment", Color(hex: "#457B9D"))
                        categoryBadge("Shopping", Color(hex: "#A8DADC"))
                    }
                }

                // Pending Plan Banner (Free Users)
                if !isPremium {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(Color(hex: "#457B9D"))

                            Text("Upgrade to customize categories")
                                .font(.geist(.caption))
                                .foregroundColor(Color(hex: "#1B2A4A"))

                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(hex: "#457B9D").opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Notifications Section
    private var notificationsSection: some View {
        Section(header: Text("NOTIFICATIONS").font(.geist(.caption)).fontWeight(.semibold).foregroundColor(Color(hex: "#A8DADC"))) {
            Toggle("Weekly Summary", isOn: $notificationsEnabled)
                .tint(Color(hex: "#457B9D"))
        }
    }

    // MARK: - Subscription Section
    private var subscriptionSection: some View {
        Section(header: Text("SUBSCRIPTION").font(.geist(.caption)).fontWeight(.semibold).foregroundColor(Color(hex: "#A8DADC"))) {
            VStack(spacing: 12) {
                // Status Display
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Status")
                            .textCase(.uppercase)
                            .font(.geist(.caption))
                            .foregroundColor(Color(hex: "#A8DADC"))

                        Text(isPremium ? "Premium" : "Free")
                            .font(.geist(.headline))
                            .foregroundColor(Color(hex: "#1B2A4A"))
                    }

                    Spacer()

                    Image(systemName: isPremium ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isPremium ? Color(hex: "#457B9D") : Color(hex: "#A8DADC"))
                }

                Divider()

                // Manage Subscription Button
                if isPremium {
                    Button(action: { viewModel.openManageSubscription() }) {
                        HStack {
                            Text("Manage Subscription")
                                .foregroundColor(Color(hex: "#457B9D"))

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .foregroundColor(Color(hex: "#457B9D"))
                        }
                    }
                }

                // Restore Purchases Button
                Button(action: { showRestorePurchases = true }) {
                    HStack {
                        Text("Restore Purchases")
                            .foregroundColor(Color(hex: "#457B9D"))

                        Spacer()

                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(Color(hex: "#457B9D"))
                    }
                }
                .alert("Restore Purchases", isPresented: $showRestorePurchases) {
                    Button("Restore") {
                        viewModel.restorePurchases()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Restore your previous purchases from the App Store")
                }
            }
        }
    }

    // MARK: - About Section
    private var aboutSection: some View {
        Section(header: Text("ABOUT").font(.geist(.caption)).fontWeight(.semibold).foregroundColor(Color(hex: "#A8DADC"))) {
            Link(destination: URL(string: "https://screenspan.app/methodology")!) {
                HStack {
                    Text("Methodology")
                        .foregroundColor(Color(hex: "#457B9D"))

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .foregroundColor(Color(hex: "#457B9D"))
                }
            }

            Link(destination: URL(string: "https://screenspan.app/privacy")!) {
                HStack {
                    Text("Privacy Policy")
                        .foregroundColor(Color(hex: "#457B9D"))

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .foregroundColor(Color(hex: "#457B9D"))
                }
            }

            HStack {
                Text("Version")
                    .foregroundColor(Color(hex: "#1B2A4A"))

                Spacer()

                Text("1.0.0")
                    .foregroundColor(Color(hex: "#A8DADC"))
            }
        }
    }



#if DEBUG
    // MARK: - Developer Section
    private var developerSection: some View {
        Section(header: Text("DEVELOPER").font(.geist(.caption)).fontWeight(.semibold).foregroundColor(Color(hex: "#A8DADC"))) {
            Button(role: .destructive) {
                showResetOnboardingAlert = true
            } label: {
                Text("Reset Onboarding")
            }
            .alert("Reset Onboarding?", isPresented: $showResetOnboardingAlert) {
                Button("Reset", role: .destructive) {
                    Task {
                        await viewModel.deleteAllData()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear onboarding progress and return you to onboarding on next app launch.")
            }
        }
    }
#endif

    // MARK: - Helpers
    private func categoryBadge(_ title: String, _ color: Color) -> some View {
        Text(title)
            .font(.geist(.caption))
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(6)
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(mins)m"
    }
}
