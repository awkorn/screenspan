import SwiftUI

struct WelcomeView: View {
    var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Text("ScreenSpan")
                    .font(.custom("Geist", size: 48, relativeTo: .body).weight(.bold))
                    .foregroundColor(Color(hex: "#051425"))

                Text("How much of your life will you spend\non your phone?")
                    .font(.custom("Geist", size: 38, relativeTo: .body).weight(.semibold))
                    .foregroundColor(Color(hex: "#595959"))
                    .lineSpacing(4)

                Text("Gain it back.")
                    .font(.custom("Geist", size: 34, relativeTo: .body).weight(.semibold))
                    .foregroundColor(Color(hex: "#C82020"))
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 80)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.advance()
                }
            }) {
                Text("Get Started")
                    .font(.custom("Geist", size: 25, relativeTo: .body).weight(.bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(Color(hex: "#051425"))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color(hex: "#F3F4F6").ignoresSafeArea())
    }
}
