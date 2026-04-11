import SwiftUI

struct PermissionRequestView: View {
    var viewModel: OnboardingViewModel

    private let backgroundColor = Color(hex: "F3F4F6")
    private let titleColor = Color(hex: "051425")
    private let subtitleColor = Color(hex: "595959")
    private let cardBackgroundColor = Color.white.opacity(0.6)
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
                        .font(.custom("Geist", size: 18, relativeTo: .body).weight(.regular))
                        .foregroundColor(titleColor)
                        .frame(width: 28, height: 28)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            VStack(spacing: 8) {
                Text("Screen Time Access")
                    .font(.custom("Geist", size: 42, relativeTo: .body).weight(.bold))
                    .foregroundColor(titleColor)
                    .multilineTextAlignment(.center)

                Text("We need your permission")
                    .font(.custom("Geist", size: 23, relativeTo: .body).weight(.regular))
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

            Button(action: requestScreenTimeAccess) {
                Text("Allow Screen Time Access")
                    .font(.custom("Geist", size: 28, relativeTo: .body).weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(buttonColor)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
        }
        .background(backgroundColor.ignoresSafeArea())
    }

    private func requestScreenTimeAccess() {
        // TODO: Implement actual Screen Time permission request
        // In production, this would request access to Screen Time data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            viewModel.screenTimePermissionGranted = true
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.advance()
            }
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
                .font(.custom("Geist", size: 15, relativeTo: .body).weight(.semibold))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)
                .background(iconBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Geist", size: 31, relativeTo: .body).weight(.semibold))
                    .foregroundColor(titleColor)
                    .lineLimit(2)

                Text(description)
                    .font(.custom("Geist", size: 23, relativeTo: .body).weight(.regular))
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
