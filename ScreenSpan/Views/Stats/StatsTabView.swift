import SwiftUI

/// Statistics tab displaying user's screen time metrics
/// In production, this view renders within the DeviceActivityReport extension.
/// During development, it shows a mock layout for UI testing.
struct StatsTabView: View {
    @State private var viewModel = StatsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Hero Years Number
                    heroYearsSection

                    // MARK: - Donut Chart
                    donutChartSection

                    // MARK: - Stat Cards
                    statCardsSection

                    // MARK: - Reclaim Preview
                    reclaimSection

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(hex: "#F8F9FA"))
        }
    }

    // MARK: - Hero Years Number Section
    private var heroYearsSection: some View {
        VStack(spacing: 8) {
            Text("Years of Life")
                .textCase(.uppercase)
                .font(.caption)
                .foregroundColor(Color(hex: "#A8DADC"))

            Text("42.3")
                .font(.system(size: 56, weight: .bold, design: .default))
                .foregroundColor(Color(hex: "#1B2A4A"))

            Text("years until target lifespan")
                .font(.subheadline)
                .foregroundColor(Color(hex: "#A8DADC"))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }

    // MARK: - Donut Chart Section
    private var donutChartSection: some View {
        VStack(spacing: 12) {
            Text("Daily Activity")
                .font(.headline)
                .foregroundColor(Color(hex: "#1B2A4A"))
                .frame(maxWidth: .infinity, alignment: .leading)

            DonutChartView(
                phoneTime: 4.5,
                totalWakingHours: 16
            )
            .frame(height: 240)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }

    // MARK: - Stat Cards Section
    private var statCardsSection: some View {
        VStack(spacing: 12) {
            statCard(
                icon: "timer",
                label: "Today",
                value: "4h 32m",
                color: Color(hex: "#E63946")
            )

            statCard(
                icon: "calendar",
                label: "This Week",
                value: "31h 15m",
                color: Color(hex: "#457B9D")
            )

            statCard(
                icon: "chart.line.uptrend.xyaxis",
                label: "Average",
                value: "4h 28m",
                color: Color(hex: "#A8DADC")
            )
        }
    }

    // MARK: - Reclaim Section
    private var reclaimSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time Reclaimed")
                        .font(.headline)
                        .foregroundColor(Color(hex: "#1B2A4A"))

                    Text("This month")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#A8DADC"))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("12h 45m")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "#457B9D"))

                    Text("vs last month")
                        .font(.caption2)
                        .foregroundColor(Color(hex: "#A8DADC"))
                }
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#457B9D").opacity(0.1),
                        Color(hex: "#E63946").opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
        }
    }

    // MARK: - Helper: Stat Card
    private func statCard(
        icon: String,
        label: String,
        value: String,
        color: Color
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .textCase(.uppercase)
                    .font(.caption)
                    .foregroundColor(Color(hex: "#A8DADC"))

                Text(value)
                    .font(.headline)
                    .foregroundColor(Color(hex: "#1B2A4A"))
            }

            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}
