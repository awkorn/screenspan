import SwiftUI

/// Life grid chart tab
/// Displays a visual grid representing months of life and phone consumption
/// In production, this view renders within the extension.
/// The LifeGridView component shows the grid of months colored by activity.
struct ChartTabView: View {
    @State private var viewModel = ChartViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Grid Title
                    VStack(spacing: 8) {
                        Text("Life Grid")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "#1B2A4A"))

                        Text("Each square represents one month of your life")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#A8DADC"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // MARK: - Life Grid
                    VStack(spacing: 16) {
                        LifeGridView(gridData: viewModel.gridData)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }

                    // MARK: - Legend
                    legendSection

                    // MARK: - Summary
                    summarySection

                    Spacer()
                }
                .padding(.vertical)
            }
            .navigationTitle("Life Grid")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(hex: "#F8F9FA"))
        }
    }

    // MARK: - Legend Section
    private var legendSection: some View {
        VStack(spacing: 12) {
            Text("Legend")
                .font(.headline)
                .foregroundColor(Color(hex: "#1B2A4A"))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 20) {
                legendItem(
                    color: Color(hex: "#457B9D"),
                    label: "Lived"
                )

                legendItem(
                    color: Color(hex: "#E63946"),
                    label: "Phone Time"
                )

                legendItem(
                    color: Color(hex: "#A8DADC"),
                    label: "Free"
                )
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }

    // MARK: - Summary Section
    private var summarySection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Phone vs Life")
                        .font(.headline)
                        .foregroundColor(Color(hex: "#1B2A4A"))

                    Text("Last 30 days")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#A8DADC"))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("35%")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "#E63946"))

                    Text("of waking hours")
                        .font(.caption2)
                        .foregroundColor(Color(hex: "#A8DADC"))
                }
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#E63946").opacity(0.1),
                        Color(hex: "#457B9D").opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }

    // MARK: - Helper: Legend Item
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            Text(label)
                .font(.caption)
                .foregroundColor(Color(hex: "#1B2A4A"))
        }
    }
}
