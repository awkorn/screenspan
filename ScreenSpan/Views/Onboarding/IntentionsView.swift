import SwiftUI

/// What the user would rather do with their time. The reveal converts a year
/// of phone time into these, so the cost is concrete and personal.
struct IntentionsView: View {
    @Bindable var viewModel: OnboardingViewModel
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        OnboardingScaffold(
            viewModel: viewModel,
            title: "What would you do with more time?",
            subtitle: "Pick up to three. We’ll show you what your screen time could become."
        ) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(TimeIntention.allCases) { intention in
                        chip(intention)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
        } footer: {
            OnboardingPrimaryButton(title: viewModel.intentions.isEmpty ? "Skip" : "Continue") {
                viewModel.saveIntentions()
                viewModel.advance()
            }
        }
    }

    private func chip(_ intention: TimeIntention) -> some View {
        let isSelected = viewModel.intentions.contains(intention)
        let isFull = viewModel.intentions.count >= 3 && !isSelected
        return Button {
            withAnimation(.snappy) {
                if isSelected { viewModel.intentions.remove(intention) } else if !isFull { viewModel.intentions.insert(intention) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: intention.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : OnboardingStyle.red)
                Text(intention.title)
                    .font(.geist(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : OnboardingStyle.navy)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(isSelected ? OnboardingStyle.navy : OnboardingStyle.card,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(isFull ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
