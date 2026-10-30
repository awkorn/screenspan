import SwiftUI

struct OnboardingContainerView: View {
    @State private var viewModel = OnboardingViewModel()
    @EnvironmentObject private var blocking: BlockingService

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
                case .planApps: PlanAppsView(draft: viewModel.planDraft, chrome: viewModel.planChrome)
                case .planBaselines: PlanBaselinesView(draft: viewModel.planDraft, chrome: viewModel.planChrome)
                case .plan: PlanView(viewModel: viewModel)
                case .paywall:
                    PaywallView(headline: viewModel.paywallHeadline) { purchased in
                        // Without Pro the plan stays a draft the user can start later.
                        if purchased {
                            if viewModel.buildsPlan && viewModel.planDraft.isReady {
                                viewModel.planDraft.start(with: blocking)
                            } else {
                                AppGroupManager.shared.pendingBlockingSetup = true
                            }
                        }
                        Task { await viewModel.completeOnboarding() }
                    }
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .opacity))
        }
    }
}
