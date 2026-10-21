import SwiftUI

enum OnboardingStyle {
    static let navy = Color(hex: "#051425")
    static let muted = Color(hex: "#595959")
    static let red = Color(hex: "#E5322D")
    static let card = Color.screenSpanCardBackground
}

/// Shared chrome for onboarding steps: back button, progress, title, content,
/// and a pinned primary action.
struct OnboardingScaffold<Content: View, Footer: View>: View {
    var viewModel: OnboardingViewModel
    var title: String?
    var subtitle: String?
    var showsBack = true
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                if showsBack {
                    Button {
                        viewModel.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(OnboardingStyle.navy)
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel("Back")
                }
                ProgressView(value: viewModel.progress)
                    .tint(OnboardingStyle.red)
                    .accessibilityLabel("Onboarding progress")
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .frame(height: 44)

            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 8) {
                    if let title {
                        Text(title)
                            .font(.geist(size: 28, weight: .bold))
                            .foregroundStyle(OnboardingStyle.navy)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.geist(size: 16))
                            .foregroundStyle(OnboardingStyle.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 10) {
                footer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(Color.white.ignoresSafeArea())
    }
}

struct OnboardingPrimaryButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.geist(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(isEnabled ? OnboardingStyle.navy : OnboardingStyle.navy.opacity(0.35), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct OnboardingSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.geist(size: 15, weight: .medium))
            .foregroundStyle(OnboardingStyle.muted)
            .frame(height: 36)
    }
}
