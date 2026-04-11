import SwiftUI

// MARK: - Goal Activation View (Step 7)
struct PaywallView: View {
    var viewModel: OnboardingViewModel

    private let primaryNavy = Color(hex: "#051425")
    private let iconBlue = Color(hex: "#0063D6")
    private let iconBackground = Color(hex: "#D7EAFF")

    private var goalHoursText: String {
        String(format: "%.1f", viewModel.selectedDailyLimit)
    }

    private let selectableCategories: [UsageCategory] = [
        .social,
        .entertainment,
        .games,
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Let’s make it happen")
                        .font(.custom("Geist", size: 48, relativeTo: .body).weight(.semibold))
                        .foregroundColor(primaryNavy)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 28)

                    goalSummaryCard

                    categoriesCard
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            Spacer(minLength: 16)

            Button(action: {
                Task {
                    await viewModel.completeOnboarding()
                }
            }) {
                Text("Activate My Plan")
                    .font(.custom("Geist", size: 32, relativeTo: .body).weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(primaryNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.screenSpanOffWhite.ignoresSafeArea())
    }

    private var goalSummaryCard: some View {
        HStack(spacing: 14) {
            iconTile(systemName: "target")

            VStack(alignment: .leading, spacing: 4) {
                Text("Daily screen time goal")
                    .font(.custom("Geist", size: 16, relativeTo: .body))
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Text(goalHoursText)
                        .font(.custom("Geist", size: 22, relativeTo: .body).weight(.semibold))
                        .foregroundColor(iconBlue)

                    Text("hours/day")
                        .font(.custom("Geist", size: 22, relativeTo: .body))
                        .foregroundColor(primaryNavy.opacity(0.8))
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Which categories to limit?")
                        .font(.custom("Geist", size: 30, relativeTo: .body).weight(.semibold))
                        .foregroundColor(primaryNavy)

                    Text("We’ll help you manage these categories within your daily goal")
                        .font(.custom("Geist", size: 15, relativeTo: .body))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Text("Optional")
                    .font(.custom("Geist", size: 14, relativeTo: .body))
                    .foregroundColor(primaryNavy.opacity(0.8))
            }

            VStack(spacing: 6) {
                ForEach(selectableCategories, id: \.self) { category in
                    categoryRow(for: category)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 420, alignment: .top)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func categoryRow(for category: UsageCategory) -> some View {
        let isSelected = viewModel.selectedCategories.contains(category)

        return Button(action: {
            if isSelected {
                viewModel.selectedCategories.remove(category)
            } else {
                viewModel.selectedCategories.insert(category)
            }
        }) {
            HStack(spacing: 12) {
                iconTile(systemName: categoryIcon(for: category))

                Text(category.displayName)
                    .font(.custom("Geist", size: 17, relativeTo: .body).weight(.medium))
                    .foregroundColor(primaryNavy)

                Spacer()

                ZStack {
                    Circle()
                        .stroke(isSelected ? iconBlue : .gray.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 18, height: 18)

                    if isSelected {
                        Circle()
                            .fill(iconBlue)
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private func iconTile(systemName: String) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(iconBackground)
            .frame(width: 28, height: 28)
            .overlay {
                Image(systemName: systemName)
                    .font(.custom("Geist", size: 14, relativeTo: .body).weight(.semibold))
                    .foregroundColor(iconBlue)
            }
    }

    private func categoryIcon(for category: UsageCategory) -> String {
        switch category {
        case .social:
            return "person.2"
        case .entertainment:
            return "tv"
        case .games:
            return "gamecontroller"
        default:
            return category.sfSymbolIcon
        }
    }
}
