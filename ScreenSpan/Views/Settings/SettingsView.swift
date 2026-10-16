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
    @AppStorage(SharedConstants.UserDefaultsKey.trackingStartDate.rawValue, store: .appGroup)
    private var trackingStartSeconds = 0.0
    @AppStorage(SharedConstants.UserDefaultsKey.startingDailyMinutes.rawValue, store: .appGroup)
    private var startingMinutes = 0.0
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
                Section("Your progress") {
                    DatePicker("Started ScreenSpan", selection: trackingStart, in: ...Date(), displayedComponents: .date)
                    Toggle("Enter my starting point", isOn: Binding(
                        get: { startingMinutes > 0 },
                        set: { startingMinutes = $0 ? 240 : 0 }
                    ))
                    if startingMinutes > 0 {
                        Text("\(Int(startingMinutes) / 60)h \(Int(startingMinutes) % 60)m per day before ScreenSpan")
                            .font(.geist(size: 17, weight: .semibold))
                        Slider(value: $startingMinutes, in: 30...960, step: 15)
                            .accessibilityLabel("Starting daily screen time in minutes")
                    }
                    Text("Progress compares your days since starting with the week before. Screen Time keeps about a month of history, so once that week is gone, Progress uses the starting point you enter here. Copy the “You started at” value from Progress before then.")
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
                    Text("Life Grid and Stats use iPhone activity from the last seven completed days. Progress also uses up to four weeks since you started, plus the week before. Missing activity is excluded from averages. If several iPhones report activity, their time is combined.")
                        .font(.footnote).foregroundStyle(ScreenSpanAppearance.secondaryText)
                }
                Section("How projections work") {
                    Text("Your daily average × 365 × years until your planning age gives projected phone hours. Divide by 8,760 for equivalent years. The percentage of waking time assumes 16 waking hours a day.")
                    Text("Time you're on track to regain compares your daily average since starting with your starting pace over the same years. Activity stays in Apple's private Screen Time report. ScreenSpan stores only your age, planning age, goal, start date, and any starting point you enter.")
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

    private var trackingStart: Binding<Date> {
        Binding(
            get: { trackingStartSeconds > 0 ? Date(timeIntervalSince1970: trackingStartSeconds) : Date() },
            set: { trackingStartSeconds = Calendar.current.startOfDay(for: $0).timeIntervalSince1970 }
        )
    }
}
