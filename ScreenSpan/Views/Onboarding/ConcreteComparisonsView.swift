import SwiftUI

struct ConcreteComparisonsView: View {
    var viewModel: OnboardingViewModel
    @State private var isAnimating = false

    private var yearsFormatted: String {
        String(format: "%.1f", viewModel.projectedYearsOnPhone)
    }

    private var comparisons: [ComparisonItem] {
        let years = viewModel.projectedYearsOnPhone

        // Scale comparisons based on projection magnitude
        if years > 10 {
            return [
                ComparisonItem(
                    icon: "🎓",
                    title: "Multiple degrees",
                    subtitle: "Master's degrees in any field"
                ),
                ComparisonItem(
                    icon: "🌍",
                    title: "Around the world",
                    subtitle: "Extended travel to 50+ countries"
                ),
                ComparisonItem(
                    icon: "🏠",
                    title: "New skills & hobbies",
                    subtitle: "Mastery in music, art, or sports"
                ),
            ]
        } else if years > 5 {
            return [
                ComparisonItem(
                    icon: "📚",
                    title: "Learn something new",
                    subtitle: "Complete multiple certifications"
                ),
                ComparisonItem(
                    icon: "🌴",
                    title: "Travel",
                    subtitle: "Extended trips around the world"
                ),
                ComparisonItem(
                    icon: "💪",
                    title: "Build fitness",
                    subtitle: "Train for marathons or compete"
                ),
            ]
        } else {
            return [
                ComparisonItem(
                    icon: "📖",
                    title: "Read books",
                    subtitle: "Hundreds of books"
                ),
                ComparisonItem(
                    icon: "🎸",
                    title: "Learn an instrument",
                    subtitle: "Become proficient"
                ),
                ComparisonItem(
                    icon: "👥",
                    title: "Spend time with loved ones",
                    subtitle: "Thousands of meaningful hours"
                ),
            ]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with projection
                    VStack(spacing: 12) {
                        Text("In \(yearsFormatted) years, you could...")
                            .font(.custom("Geist", size: 28, relativeTo: .body).weight(.semibold))
                            .foregroundColor(.screenSpanNavy)
                            .lineSpacing(1)

                        Text("What could you accomplish with that time?")
                            .font(.custom("Geist", size: 15, relativeTo: .body))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 32)

                    // Comparison Cards
                    VStack(spacing: 12) {
                        ForEach(Array(comparisons.enumerated()), id: \.offset) { index, item in
                            ComparisonCard(item: item)
                                .opacity(isAnimating ? 1 : 0)
                                .offset(y: isAnimating ? 0 : 20)
                                .animation(
                                    .easeOut(duration: 0.4).delay(Double(index) * 0.1),
                                    value: isAnimating
                                )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }

            Spacer()

            // CTA
            VStack(spacing: 12) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.advance()
                    }
                }) {
                    Text("What if you could get some of it back?")
                        .font(.custom("Geist", size: 17, relativeTo: .body).weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.screenSpanRed)
                        .cornerRadius(12)
                }
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

// MARK: - Comparison Item Model
struct ComparisonItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
}

// MARK: - Comparison Card
struct ComparisonCard: View {
    let item: ComparisonItem

    var body: some View {
        HStack(spacing: 16) {
            Text(item.icon)
                .font(.custom("Geist", size: 40, relativeTo: .body))
                .frame(width: 56, height: 56)
                .background(Color.screenSpanRed.opacity(0.1))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.custom("Geist", size: 16, relativeTo: .body).weight(.semibold))
                    .foregroundColor(.screenSpanNavy)

                Text(item.subtitle)
                    .font(.custom("Geist", size: 14, relativeTo: .body))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.custom("Geist", size: 14, relativeTo: .body).weight(.semibold))
                .foregroundColor(.screenSpanBlue)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.screenSpanNavy.opacity(0.1), lineWidth: 1)
        )
    }
}
