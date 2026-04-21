import SwiftUI

struct OnboardingContainerView: View {
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                Group {
                    switch viewModel.currentStep {
                    case .welcome:
                        WelcomeView(viewModel: viewModel)
                    case .ageInput:
                        AgeInputView(viewModel: viewModel)
                    case .permission:
                        PermissionRequestView(viewModel: viewModel)
                    case .lifeGridReveal:
                        ProjectionRevealView(viewModel: viewModel)
                    case .comparisons:
                        LifeGridRevealView(viewModel: viewModel)
                    case .goalSetting:
                        GoalSettingView(viewModel: viewModel)
                    case .paywall:
                        PaywallView(viewModel: viewModel)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
    }
}
