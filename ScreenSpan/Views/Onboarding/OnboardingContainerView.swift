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
                // One branch keeps the same report mounted across both steps.
                case .reveal, .goal: RevealView(viewModel: viewModel)
                case .plan: PlanView(viewModel: viewModel)
                case .paywall:
                    PaywallView { purchased in
                        if purchased { AppGroupManager.shared.pendingBlockingSetup = true }
                        Task { await viewModel.completeOnboarding() }
                    }
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .opacity))
        }
    }
}
