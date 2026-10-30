import SwiftUI

/// Explains Screen Time access, then shows the system prompt. Per App Review
/// guidance the pre-prompt offers no way to skip or delay the request, and
/// its button says "Continue". Only after the system prompt is declined can
/// the user carry on with their own estimate.
struct PermissionRequestView: View {
    var viewModel: OnboardingViewModel
    @EnvironmentObject private var authService: AuthorizationService
    @State private var isRequesting = false
    @State private var wasDeclined = false

    var body: some View {
        OnboardingScaffold(
            viewModel: viewModel,
            title: "See your real numbers",
            subtitle: "Connect Screen Time to compare your guess with how you actually use your iPhone."
        ) {
            VStack(spacing: 12) {
                point(icon: "lock.shield", title: "Private by design",
                      text: "Apple keeps your activity inside a secure Screen Time report on this iPhone. ScreenSpan never sees, stores, or uploads it.")
                point(icon: "chart.bar.xaxis", title: "Built from your last 7 days",
                      text: "Your projection, life chart, and top apps come from real activity, not averages.")
                point(icon: "hand.raised", title: "You’re in control",
                      text: "You can turn access off anytime in Settings → Screen Time.")
                if wasDeclined {
                    Text(authService.authorizationErrorMessage ?? "Screen Time access wasn’t allowed. You can try again, or continue with your estimate and connect later in Settings.")
                        .font(.geist(size: 13))
                        .foregroundStyle(OnboardingStyle.muted)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
        } footer: {
            OnboardingPrimaryButton(title: isRequesting ? "Waiting for Screen Time…" : (wasDeclined ? "Try again" : "Continue"),
                                    isEnabled: !isRequesting, action: request)
            if wasDeclined {
                OnboardingSecondaryButton(title: "Continue with my estimate") {
                    viewModel.usesEstimate = true
                    viewModel.buildsPlan = false
                    viewModel.revealPanel = 0
                    viewModel.advance()
                }
            }
        }
    }

    private func point(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OnboardingStyle.red)
                .frame(width: 36, height: 36)
                .background(Color(hex: "#FDECEC"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    private func request() {
        Task { @MainActor in
            if !authService.isAuthorized {
                isRequesting = true
                await authService.requestAuthorization()
                isRequesting = false
            }
            guard authService.isAuthorized else {
                wasDeclined = true
                return
            }
            viewModel.usesEstimate = false
            viewModel.buildsPlan = true
            viewModel.revealPanel = 0
            viewModel.advance()
        }
    }
}
