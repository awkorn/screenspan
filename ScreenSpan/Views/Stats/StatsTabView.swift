import SwiftUI
import DeviceActivity

/// Statistics tab.
///
/// PRIVACY MODEL
/// -------------
/// Per Apple's Screen Time privacy model, all per-app and per-category
/// usage data must be processed inside the `DeviceActivityReport`
/// extension. This view therefore contains **no** rendering of usage
/// values — it is a thin host that embeds the `ScreenSpanReport`
/// extension via `DeviceActivityReport(.stats, filter:)`. Hero years,
/// donut chart, and stat cards are all drawn by the extension process
/// and delivered to the host as pixels.
struct StatsTabView: View {
    @EnvironmentObject private var authService: AuthorizationService

    var body: some View {
        Group {
            if authService.isAuthorized {
                DeviceActivityReport(
                    .stats,
                    filter: .screenSpanDaily
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                authorizationRequiredView
            }
        }
        .background(Color.white.ignoresSafeArea())
    }

    private var authorizationRequiredView: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "hourglass.badge.exclamationmark")
                .font(.geist(size: 40, weight: .semibold))
                .foregroundStyle(Color(hex: "#102847"))

            VStack(spacing: 8) {
                Text("Screen Time access is required")
                    .font(.geist(size: 22, weight: .bold))
                    .foregroundStyle(Color(hex: "#102847"))

                Text("Your stats now render through the Device Activity report extension, so the app needs Screen Time permission before it can display them.")
                    .font(.geist(size: 15))
                    .foregroundStyle(Color(hex: "#595959"))
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await authService.requestAuthorization()
                }
            } label: {
                Text("Allow Screen Time Access")
                    .onboardingPrimaryButtonStyle()
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}
