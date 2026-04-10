import SwiftUI

struct WelcomeView: View {
    var viewModel: OnboardingViewModel
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                // App Name with animation
                VStack(spacing: 16) {
                    Text("ScreenSpan")
                        .font(.system(size: 56, weight: .bold, design: .default))
                        .foregroundColor(.screenSpanNavy)
                        .scaleEffect(isAnimating ? 1.0 : 0.9)
                        .opacity(isAnimating ? 1.0 : 0.0)

                    // Red accent line
                    Capsule()
                        .fill(Color.screenSpanRed)
                        .frame(width: 80, height: 4)
                        .opacity(isAnimating ? 1.0 : 0.0)
                }

                // Main Tagline
                VStack(spacing: 12) {
                    Text("How much of your life\nwill you spend on\nyour phone?")
                        .font(.system(size: 28, weight: .semibold, design: .default))
                        .tracking(-0.5)
                        .foregroundColor(.screenSpanNavy)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .offset(y: isAnimating ? 0 : 20)

                    Text("Gain it back.")
                        .font(.system(size: 20, weight: .semibold, design: .default))
                        .foregroundColor(.screenSpanRed)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .offset(y: isAnimating ? 0 : 20)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // CTA Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.advance()
                }
            }) {
                Text("Get Started")
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
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                isAnimating = true
            }
        }
    }
}
