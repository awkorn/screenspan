import SwiftUI

/// A short summary of what happens next, then the dashboard.
struct PlanView: View {
    var viewModel: OnboardingViewModel
    @EnvironmentObject private var store: StoreKitService
    @State private var isFinishing = false

    var body: some View {
        OnboardingScaffold(
            viewModel: viewModel,
            title: "Your plan starts today",
            subtitle: "Every day under your goal is time you get back. Here’s how you’ll see it."
        ) {
            ScrollView {
                VStack(spacing: 12) {
                    HStack {
                        summary(value: formatted(viewModel.goalHours), label: "daily goal")
                        summary(value: Date().formatted(.dateTime.month(.abbreviated).day()), label: "start date")
                    }
                    item(icon: "arrow.uturn.backward.circle", title: "Years you’re regaining",
                         text: "Progress compares every day from now on with the week before today.")
                    item(icon: "flame", title: "Your goal streak",
                         text: "See which days you stayed under \(formatted(viewModel.goalHours)) and keep the streak going.")
                    item(icon: "square.grid.3x3", title: "Your life chart",
                         text: "Watch phone months turn into months that are yours again.")
                    item(icon: "chart.pie", title: "Where your time goes",
                         text: "Your top apps, pickups, and notifications, with what each costs over a lifetime.")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
        } footer: {
            OnboardingPrimaryButton(title: "Start reclaiming my time", isEnabled: !isFinishing) {
                // Subscribers (a reinstall, say) skip the offer.
                guard !store.isPro else {
                    isFinishing = true
                    Task { await viewModel.completeOnboarding() }
                    return
                }
                viewModel.advance()
            }
        }
    }

    private func summary(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.geist(size: 26, weight: .bold)).foregroundStyle(OnboardingStyle.navy)
            Text(label).font(.geist(size: 13)).foregroundStyle(OnboardingStyle.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(hex: "#EEF8F2"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func item(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: "#235187"))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.geist(size: 16, weight: .semibold)).foregroundStyle(OnboardingStyle.navy)
                Text(text).font(.geist(size: 13)).foregroundStyle(OnboardingStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(OnboardingStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func formatted(_ hours: Double) -> String {
        let minutes = Int((hours * 60).rounded())
        if minutes < 60 { return "\(minutes)m" }
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }
}
