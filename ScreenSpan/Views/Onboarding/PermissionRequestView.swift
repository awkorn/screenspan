import SwiftUI

struct PermissionRequestView: View {
    var viewModel: OnboardingViewModel
    @EnvironmentObject private var authService: AuthorizationService
    @State private var isRequestingAuthorization = false
    @State private var authorizationMessage: String?

    private let backgroundColor = Color.white
    private let titleColor = Color(hex: "051425")
    private let subtitleColor = Color(hex: "595959")
    private let cardBackgroundColor = Color.screenSpanCardBackground
    private let iconBackgroundColor = Color(hex: "FDECEC")
    private let iconColor = Color(hex: "E85A5A")
    private let buttonColor = Color(hex: "051425")

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.goBack()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.geist(size: 18))
                        .foregroundColor(titleColor)
                        .frame(width: 28, height: 28)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            VStack(spacing: 8) {
                Text("Screen Time Access")
                    .font(.geist(size: 28, weight: .bold))
                    .foregroundColor(titleColor)
                    .multilineTextAlignment(.center)

                Text("We need your permission")
                    .font(.geist(size: 18))
                    .foregroundColor(subtitleColor)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 26)

            VStack(spacing: 14) {
                PermissionExplanationCard(
                    icon: "lock",
                    title: "Your privacy is protected",
                    description: "No data leaves your device, we never send your screen time information to our servers.",
                    iconColor: iconColor,
                    iconBackgroundColor: iconBackgroundColor,
                    titleColor: titleColor,
                    descriptionColor: subtitleColor,
                    cardBackgroundColor: cardBackgroundColor
                )

                PermissionExplanationCard(
                    icon: "checkmark.seal",
                    title: "Calculate your projection",
                    description: "We analyze your usage patterns to show you how much time you'll spend on your phone.",
                    iconColor: iconColor,
                    iconBackgroundColor: iconBackgroundColor,
                    titleColor: titleColor,
                    descriptionColor: subtitleColor,
                    cardBackgroundColor: cardBackgroundColor
                )

                PermissionExplanationCard(
                    icon: "target",
                    title: "Set realistic goals",
                    description: "Based on your actual usage, we help you set achievable daily limits and gain your life back.",
                    iconColor: iconColor,
                    iconBackgroundColor: iconBackgroundColor,
                    titleColor: titleColor,
                    descriptionColor: subtitleColor,
                    cardBackgroundColor: cardBackgroundColor
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 54)

            Spacer()

            VStack(spacing: 0) {
                Button(action: requestScreenTimeAccess) {
                    Text(isRequestingAuthorization ? "Requesting Access..." : "Allow Screen Time Access")
                        .onboardingPrimaryButtonStyle()
                }
                .disabled(isRequestingAuthorization)
                .padding(.horizontal, 24)

                if let authorizationMessage {
                    Text(authorizationMessage)
                        .font(.geist(size: 13))
                        .foregroundColor(subtitleColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 12)
                }
            }
            .padding(.bottom, 34)
        }
        .background(backgroundColor.ignoresSafeArea())
    }

    private func requestScreenTimeAccess() {
        Task { @MainActor in
            isRequestingAuthorization = true
            authorizationMessage = nil

            await authService.requestAuthorization()
            isRequestingAuthorization = false

            guard authService.isAuthorized else {
                authorizationMessage = authService.authorizationErrorMessage ?? fallbackAuthorizationMessage
                return
            }

            viewModel.screenTimePermissionGranted = true
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.advance()
            }
        }
    }

    private var fallbackAuthorizationMessage: String {
        switch authService.authorizationStatus {
        case .approved:
            return ""
        case .denied:
            return "Screen Time access was denied. Try again, or enable it in Settings if you denied it earlier."
        case .notDetermined:
            return "Screen Time access is still unavailable. Try again once the permission sheet finishes."
        @unknown default:
            return "Screen Time access is still unavailable. Try again, or enable it in Settings if you denied it earlier."
        }
    }
}

// MARK: - Explanation Card
struct PermissionExplanationCard: View {
    let icon: String
    let title: String
    let description: String
    let iconColor: Color
    let iconBackgroundColor: Color
    let titleColor: Color
    let descriptionColor: Color
    let cardBackgroundColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.geist(size: 15, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)
                .background(iconBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.geist(size: 16, weight: .semibold))
                    .foregroundColor(titleColor)
                    .lineLimit(2)

                Text(description)
                    .font(.geist(size: 12))
                    .foregroundColor(descriptionColor)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
