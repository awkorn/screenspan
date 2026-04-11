import SwiftUI

// MARK: - Goal Setting View
struct GoalSettingView: View {
    var viewModel: OnboardingViewModel
    @State private var selectedCategories: Set<String> = []
    @State private var isAnimating = false

    private var dailyLimitFormatted: String {
        String(format: "%.1f", viewModel.selectedDailyLimit)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Text("Ready to make it happen?")
                            .font(.custom("Geist", size: 28, relativeTo: .body).weight(.semibold))
                            .foregroundColor(.screenSpanNavy)

                        Text("Your daily limit")
                            .font(.custom("Geist", size: 15, relativeTo: .body))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 32)

                    // Daily Limit Display
                    HStack(spacing: 12) {
                        Image(systemName: "target")
                            .font(.custom("Geist", size: 20, relativeTo: .body).weight(.semibold))
                            .foregroundColor(.screenSpanRed)
                            .frame(width: 40, height: 40)
                            .background(Color.screenSpanRed.opacity(0.1))
                            .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Daily screen time goal")
                                .font(.custom("Geist", size: 13, relativeTo: .body).weight(.semibold))
                                .foregroundColor(.secondary)

                            HStack(spacing: 4) {
                                Text(dailyLimitFormatted)
                                    .font(.custom("Geist", size: 24, relativeTo: .body).weight(.bold))
                                    .foregroundColor(.screenSpanRed)
                                    .monospacedDigit()

                                Text("hours/day")
                                    .font(.custom("Geist", size: 14, relativeTo: .body))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 24)

                    // Category Selection
                    VStack(spacing: 16) {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Which categories to limit?")
                                    .font(.custom("Geist", size: 16, relativeTo: .body).weight(.semibold))
                                    .foregroundColor(.screenSpanNavy)

                                Spacer()

                                Text("Optional")
                                    .font(.custom("Geist", size: 12, relativeTo: .body).weight(.semibold))
                                    .foregroundColor(.secondary)
                            }

                            Text("We'll help manage these categories within your daily goal")
                                .font(.custom("Geist", size: 13, relativeTo: .body))
                                .foregroundColor(.secondary)
                        }

                        VStack(spacing: 10) {
                            ForEach(Array(UsageCategory.allCases.enumerated()), id: \.offset) { index, category in
                                CategoryToggleRow(
                                    category: category,
                                    isSelected: selectedCategories.contains(category.rawValue),
                                    action: {
                                        if selectedCategories.contains(category.rawValue) {
                                            selectedCategories.remove(category.rawValue)
                                        } else {
                                            selectedCategories.insert(category.rawValue)
                                        }
                                    }
                                )
                                .opacity(isAnimating ? 1 : 0)
                                .offset(y: isAnimating ? 0 : 20)
                                .animation(
                                    .easeOut(duration: 0.3).delay(Double(index) * 0.05),
                                    value: isAnimating
                                )
                            }
                        }

                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }

            Spacer()

            // CTA Button
            Button(action: {
                // Convert selected categories to UsageCategory
                let categories = selectedCategories.compactMap { categoryName in
                    UsageCategory(rawValue: categoryName)
                }
                viewModel.selectedCategories = Set(categories)

                // TODO: Integrate FamilyActivityPicker when available
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.advance()
                }
            }) {
                Text("Activate My Plan")
                    .font(.custom("Geist", size: 17, relativeTo: .body).weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.screenSpanRed)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.screenSpanOffWhite.ignoresSafeArea())
        .onAppear {
            withAnimation {
                isAnimating = true
            }
        }
    }
}

// MARK: - Category Toggle Row
struct CategoryToggleRow: View {
    let category: UsageCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: category.sfSymbolIcon)
                    .font(.custom("Geist", size: 16, relativeTo: .body).weight(.semibold))
                    .foregroundColor(isSelected ? .white : Color.screenSpanBlue)
                    .frame(width: 32, height: 32)
                    .background(isSelected ? Color.screenSpanBlue : Color.screenSpanBlue.opacity(0.1))
                    .cornerRadius(8)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)

                Text(category.displayName)
                    .font(.custom("Geist", size: 15, relativeTo: .body).weight(.semibold))
                    .foregroundColor(Color.screenSpanNavy)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.custom("Geist", size: 20, relativeTo: .body).weight(.semibold))
                    .foregroundColor(isSelected ? Color.screenSpanRed : Color.screenSpanNavy.opacity(0.3))
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.screenSpanRed.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
    }
}
