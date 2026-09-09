import SwiftUI

// MARK: - Goal Setting View
struct GoalSettingView: View {
    var viewModel: OnboardingViewModel

    @State private var draftGoalHours = Double(AppConstants.Defaults.screenTimeGoal) / 60.0

    private let minimumGoalHours = 0.5
    private let maximumGoalHours = 12.0
    private let titleColor = Color(hex: "#051425")
    private let subtitleColor = Color(hex: "#595959")
    private let accentColor = Color(hex: "#C82020")
    private let selectedColor = Color(hex: "#0063D6")
    private let presetGoals = [1.0, 2.0, 3.0, 4.0]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    goalControl

                    presetRow

                    privacyNote
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 24)
            }

            Spacer(minLength: 0)

            Button(action: commitGoalAndAdvance) {
                Text("Set My Goal")
                    .onboardingPrimaryButtonStyle()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.white.ignoresSafeArea())
        .onAppear {
            loadSavedGoal()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Set your goal")
                .font(.geist(size: 28, weight: .bold))
                .foregroundColor(titleColor)

            Text("Choose the daily screen time you want to aim for.")
                .font(.geist(size: 18))
                .foregroundColor(subtitleColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var goalControl: some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text(formattedGoal)
                    .font(.geist(size: 42, weight: .bold))
                    .foregroundColor(selectedColor)
                    .monospacedDigit()
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)

                Text("per day")
                    .font(.geist(size: 16, weight: .medium))
                    .foregroundColor(subtitleColor)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 10) {
                Slider(
                    value: Binding(
                        get: { draftGoalHours },
                        set: { newValue in
                            let stepped = (newValue * 4).rounded() / 4
                            draftGoalHours = min(max(stepped, minimumGoalHours), maximumGoalHours)
                            viewModel.selectedDailyLimit = draftGoalHours
                        }
                    ),
                    in: minimumGoalHours...maximumGoalHours,
                    step: 0.25
                )
                .tint(accentColor)

                HStack {
                    Text("30m")
                    Spacer()
                    Text("12h")
                }
                .font(.geist(size: 13, weight: .medium))
                .foregroundColor(subtitleColor)
            }
        }
        .padding(18)
        .background(Color.screenSpanCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var presetRow: some View {
        HStack(spacing: 10) {
            ForEach(presetGoals, id: \.self) { hours in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        draftGoalHours = hours
                        viewModel.selectedDailyLimit = hours
                    }
                } label: {
                    Text(formatPreset(hours))
                        .font(.geist(size: 14, weight: .semibold))
                        .foregroundColor(isSelectedPreset(hours) ? .white : titleColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(isSelectedPreset(hours) ? selectedColor : Color.screenSpanCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock")
                .font(.geist(size: 15, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: 22, height: 22)

            Text("Your goal is a reference for your charts. It does not block apps.")
                .font(.geist(size: 14, weight: .medium))
                .foregroundColor(subtitleColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color(hex: "#FFF1F1"))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var formattedGoal: String {
        let totalMinutes = Int((draftGoalHours * 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if minutes == 0 {
            return "\(hours)h"
        }

        if hours == 0 {
            return "\(minutes)m"
        }

        return "\(hours)h \(minutes)m"
    }

    private func formatPreset(_ hours: Double) -> String {
        "\(Int(hours))h"
    }

    private func isSelectedPreset(_ hours: Double) -> Bool {
        abs(draftGoalHours - hours) < 0.01
    }

    private func loadSavedGoal() {
        let storedGoalMinutes = AppGroupManager.shared.screenTimeGoalMinutes
        let fallbackGoalMinutes = Double(AppConstants.Defaults.screenTimeGoal)
        let resolvedMinutes = storedGoalMinutes > 0 ? storedGoalMinutes : fallbackGoalMinutes
        draftGoalHours = min(max(resolvedMinutes / 60.0, minimumGoalHours), maximumGoalHours)
        viewModel.selectedDailyLimit = draftGoalHours
    }

    private func commitGoalAndAdvance() {
        viewModel.selectedDailyLimit = draftGoalHours
        AppGroupManager.shared.screenTimeGoalMinutes = draftGoalHours * 60
        viewModel.calculateReclaim()

        Task { await viewModel.completeOnboarding() }
    }
}
