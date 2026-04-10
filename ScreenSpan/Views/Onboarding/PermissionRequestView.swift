import SwiftUI

struct PermissionRequestView: View {
    var viewModel: OnboardingViewModel
    @State private var permissionDenied = false
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 0) {
            // Scrollable content
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Screen Time Access")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.screenSpanNavy)

                        Text("We need your permission")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Icon
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .font(.system(size: 60))
                        .foregroundColor(.screenSpanBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)

                    // Explanation
                    VStack(spacing: 16) {
                        ExplanationCard(
                            icon: "lock.fill",
                            title: "Your privacy is protected",
                            description: "No data leaves your device. We never send your screen time information to our servers."
                        )

                        ExplanationCard(
                            icon: "checkmark.circle.fill",
                            title: "Calculate your projection",
                            description: "We analyze your usage patterns to show you how much time you'll spend on your phone."
                        )

                        ExplanationCard(
                            icon: "target",
                            title: "Set realistic goals",
                            description: "Based on your actual usage, we help you set achievable daily limits."
                        )
                    }

                    // Permission denied state
                    if permissionDenied {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.screenSpanRed)

                                Text("Permission needed to continue")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.screenSpanRed)

                                Spacer()
                            }
                            .padding(12)
                            .background(Color.screenSpanRed.opacity(0.1))
                            .cornerRadius(8)

                            Button(action: {
                                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsURL)
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "gear")
                                    Text("Open Settings")
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.screenSpanBlue)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }

            Spacer()

            // CTA Button
            Button(action: {
                requestScreenTimeAccess()
            }) {
                Text("Allow Screen Time Access")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.screenSpanRed)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.screenSpanOffWhite.ignoresSafeArea())
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
struct ExplanationCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.screenSpanRed)
                .frame(width: 32, height: 32)
                .background(Color.screenSpanRed.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.screenSpanNavy)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineSpacing(1)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.screenSpanNavy.opacity(0.04))
        .cornerRadius(12)
    }
}
