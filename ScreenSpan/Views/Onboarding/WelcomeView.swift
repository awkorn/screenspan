import SwiftUI

struct WelcomeView: View {
    var viewModel: OnboardingViewModel

    private let backgroundColor = Color.white
    private let titleColor = Color(hex: "#051425")
    private let subtitleColor = Color(hex: "#3F4854")
    private let accentColor = Color(hex: "#D93025")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                Text("ScreenSpan")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(titleColor)

                Text("How much of your life will you spend on your phone?")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(subtitleColor)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Gain it back.")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(accentColor)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 76)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .background(backgroundColor.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.advance()
                }
            }) {
                Text("Get Started")
                    .onboardingPrimaryButtonStyle()
            }
            .padding(.horizontal, 38)
            .padding(.top, 12)
            .padding(.bottom, 18)
            .background(backgroundColor)
        }
    }
}
