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
                            .font(.custom("Geist", size: 32, relativeTo: .body).weight(.bold))
                            .foregroundColor(.screenSpanNavy)

                        Text("We need your permission")
                            .font(.custom("Geist", size: 15, relativeTo: .body))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Icon
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .font(.custom("Geist", size: 60, relativeTo: .body))
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
                                    .font(.custom("Geist", size: 16, relativeTo: .body))
                                    .foregroundColor(.screenSpanRed)

                                Text("Permission needed to continue")
                                    .font(.custom("Geist", size: 15, relativeTo: .body).weight(.semibold))
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
                                .font(.custom("Geist", size: 15, relativeTo: .body).weight(.semibold))
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
                    .font(.custom("Geist", size: 17, relativeTo: .body).weight(.semibold))
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
                .font(.custom("Geist", size: 20, relativeTo: .body).weight(.semibold))
                .foregroundColor(.screenSpanRed)
                .frame(width: 32, height: 32)
                .background(Color.screenSpanRed.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Geist", size: 16, relativeTo: .body).weight(.semibold))
                    .foregroundColor(.screenSpanNavy)

                Text(description)
                    .font(.custom("Geist", size: 14, relativeTo: .body))
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
