import StoreKit
import SwiftUI

/// Only controls with implemented behavior are exposed in the working prototype.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthorizationService
    @EnvironmentObject private var store: StoreKitService
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
    @State private var showsPaywall = false
    @State private var showsManageSubscription = false
    @State private var isRestoring = false
    @State private var restoreMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                proSection
                Section("Your life chart") {
                    Stepper("Current age: \(age)", value: $age, in: 13...120)
                    Stepper("Planning age: \(targetAge)", value: $targetAge, in: 1...120)
                    Text("Planning age is an assumption you choose, not a prediction of your lifespan.")
                        .font(.footnote).foregroundStyle(ScreenSpanAppearance.secondaryText)
                }
                Section("Daily goal") {
                    Text("\(Int(goalMinutes) / 60)h \(Int(goalMinutes) % 60)m per day")
                        .font(.geist(size: 22, weight: .semibold))
                    Slider(value: $goalMinutes, in: 30...720, step: 15)
                        .accessibilityLabel("Daily screen time goal in minutes")
                    Text("This is the reference line in your activity chart. To hold yourself to it, add a daily limit in Blocking.")
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
                    Text("Time you're on track to regain compares your daily average since starting with your starting pace over the same years. Activity stays in Apple's private Screen Time report. ScreenSpan stores only your age, planning age, goal, start date, any starting point you enter, and your blocking setup. Apps you choose to block are saved as private Screen Time tokens that don't reveal which apps they are.")
                }
                .font(.footnote)
                Section {
                    Link("Terms of Use", destination: AppConstants.Legal.termsOfUse)
                    Link("Privacy Policy", destination: AppConstants.Legal.privacyPolicy)
                }
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
            .fullScreenCover(isPresented: $showsPaywall) {
                PaywallView { _ in showsPaywall = false }
            }
            .manageSubscriptionsSheet(isPresented: $showsManageSubscription)
            .alert("Restore Purchases", isPresented: Binding(
                get: { restoreMessage != nil },
                set: { if !$0 { restoreMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(restoreMessage ?? "")
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

    private var proSection: some View {
        Section {
            if store.isPro {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ScreenSpan Pro").font(.geist(size: 17, weight: .semibold))
                        if let plan = store.activePlan {
                            Text(planDetail(plan))
                                .font(.footnote).foregroundStyle(ScreenSpanAppearance.secondaryText)
                        }
                    }
                } icon: {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Color(hex: "#2BB673"))
                }
                Button("Manage subscription") { showsManageSubscription = true }
            } else {
                Button {
                    showsPaywall = true
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Get ScreenSpan Pro").font(.geist(size: 17, weight: .semibold))
                            Text("Focus blocks, schedules, daily limits, and strict mode.")
                                .font(.footnote).foregroundStyle(ScreenSpanAppearance.secondaryText)
                        }
                    } icon: {
                        Image(systemName: "lock.shield.fill").foregroundStyle(Color(hex: "#E5322D"))
                    }
                }
                .foregroundStyle(ScreenSpanAppearance.text)
                Button(isRestoring ? "Restoring…" : "Restore purchases") {
                    Task {
                        isRestoring = true
                        let restored = await store.restore()
                        isRestoring = false
                        restoreMessage = restored
                            ? "ScreenSpan Pro is active again."
                            : "We couldn’t find an active ScreenSpan Pro subscription for this Apple Account."
                    }
                }
                .disabled(isRestoring)
            }
        } footer: {
            Text("Your life chart, stats, and progress are free. Pro adds app blocking.")
        }
    }

    private func planDetail(_ plan: StoreKitService.ActivePlan) -> String {
        guard let end = plan.expirationDate?.formatted(date: .abbreviated, time: .omitted) else { return plan.name }
        if plan.isTrial { return plan.willAutoRenew ? "Free trial · \(plan.name.lowercased()) plan starts \(end)" : "Free trial · ends \(end)" }
        return plan.willAutoRenew ? "\(plan.name) · renews \(end)" : "\(plan.name) · ends \(end)"
    }

    private var trackingStart: Binding<Date> {
        Binding(
            get: { trackingStartSeconds > 0 ? Date(timeIntervalSince1970: trackingStartSeconds) : Date() },
            set: { trackingStartSeconds = Calendar.current.startOfDay(for: $0).timeIntervalSince1970 }
        )
    }
}
