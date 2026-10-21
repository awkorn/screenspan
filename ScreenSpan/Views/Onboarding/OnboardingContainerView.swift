import SwiftUI

struct OnboardingContainerView: View {
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            Group {
                switch viewModel.currentStep {
                case .welcome: WelcomeView(viewModel: viewModel)
                case .age: AgeInputView(viewModel: viewModel)
                case .estimate: EstimateView(viewModel: viewModel)
                case .intentions: IntentionsView(viewModel: viewModel)
                case .permission: PermissionRequestView(viewModel: viewModel)
                case .reveal: RevealView(viewModel: viewModel)
                case .goal: GoalSettingView(viewModel: viewModel)
                case .plan: PlanView(viewModel: viewModel)
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .opacity))
        }
    }
}
