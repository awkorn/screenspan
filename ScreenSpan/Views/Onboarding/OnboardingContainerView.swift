import SwiftUI

struct OnboardingContainerView: View {
    @State private var viewModel = OnboardingViewModel()
    @Namespace private var animation

    var body: some View {
        NavigationStack {
            ZStack {
                Color.screenSpanOffWhite.ignoresSafeArea()

                Group {
                    switch viewModel.currentStep {
                    case .welcome:
                        WelcomeView(viewModel: viewModel)
                    case .ageInput:
                        AgeInputView(viewModel: viewModel)
                    case .permission:
                        PermissionRequestView(viewModel: viewModel)
                    case .lifeGridReveal:
                        LifeGridRevealView(viewModel: viewModel, animation: animation)
                    case .comparisons:
                        ConcreteComparisonsView(viewModel: viewModel)
                    case .reclaimSlider:
                        ReclaimSliderView(viewModel: viewModel)
                    case .goalSetting:
                        GoalSettingView(viewModel: viewModel)
                    case .paywall:
                        PaywallView(viewModel: viewModel)
                    }
                }
                .font(.custom("Geist", size: 17, relativeTo: .body))
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
    }
}
