import SwiftUI

/// Only controls with implemented behavior are exposed in the working prototype.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthorizationService
    @AppStorage(SharedConstants.UserDefaultsKey.currentAge.rawValue, store: .appGroup)
    private var age = 25
    @AppStorage(SharedConstants.UserDefaultsKey.targetAge.rawValue, store: .appGroup)
    private var targetAge = 80
    @AppStorage(SharedConstants.UserDefaultsKey.screenTimeGoalMinutes.rawValue, store: .appGroup)
    private var goalMinutes = 120.0
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Your life chart") {
                    Stepper("Current age: \(age)", value: $age, in: 1...120)
                    Stepper("Planning age: \(targetAge)", value: $targetAge, in: 1...120)
                    Text("Planning age is an assumption you choose, not a prediction of your lifespan.")
                        .font(.footnote).foregroundStyle(ScreenSpanAppearance.secondaryText)
                }
                Section("Daily goal") {
                    Text("\(Int(goalMinutes) / 60)h \(Int(goalMinutes) % 60)m per day")
                        .font(.geist(size: 22, weight: .semibold))
                    Slider(value: $goalMinutes, in: 30...720, step: 15)
                        .accessibilityLabel("Daily screen time goal in minutes")
                    Text("This is the reference line in your activity chart. App blocking and limit notifications are not enabled.")
                        .font(.footnote).foregroundStyle(ScreenSpanAppearance.secondaryText)
                }
                Section("Screen Time") {
                    Label(authService.isAuthorized ? "Access allowed" : "Access needed",
                          systemImage: authService.isAuthorized ? "checkmark.shield" : "lock")
                    if !authService.isAuthorized {
                        Button("Allow Screen Time Access") {
                            Task { await authService.requestAuthorization() }
                        }
                    }
                    Text("Reports use iPhone activity from the last seven completed days. Missing activity is excluded from the average. If several iPhones report activity, their time is combined.")
                        .font(.footnote).foregroundStyle(ScreenSpanAppearance.secondaryText)
                }
                Section("How projections work") {
                    Text("Your daily average × 365 × years until your planning age gives projected phone hours. Divide by 8,760 for equivalent years. The percentage of waking time assumes 16 waking hours a day.")
                    Text("Activity stays in Apple's private Screen Time report. ScreenSpan stores only your age, planning age, and chosen goal. Projections are scenarios, not time already saved.")
                }
                .font(.footnote)
                #if DEBUG
                Section("Development") {
                    Button("Restart onboarding", role: .destructive) { confirmReset = true }
                }
                #endif
            }
            .tint(Color(hex: "#0063D6"))
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Restart onboarding?", isPresented: $confirmReset) {
                Button("Restart", role: .destructive) {
                    AppGroupManager.shared.onboardingCompleted = false
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
}
