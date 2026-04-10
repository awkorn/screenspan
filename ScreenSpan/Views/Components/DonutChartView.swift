import SwiftUI

/// Donut chart visualization showing phone time vs rest of waking life
/// Two-segment donut with center label and legend
/// Uses custom drawing for iOS 17+ compatibility
struct DonutChartView: View {
    let phoneTime: Double    // in hours
    let totalWakingHours: Double

    private var phonePercentage: Double {
        (phoneTime / totalWakingHours) * 100
    }

    private var restPercentage: Double {
        100 - phonePercentage
    }

    var body: some View {
        VStack(spacing: 24) {
            // MARK: - Donut Chart
            donutChart

            // MARK: - Legend
            legend
        }
    }

    private var donutChart: some View {
        ZStack {
            // MARK: - Donut Circle
            Circle()
                .trim(from: 0, to: phonePercentage / 100)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#E63946"),
                            Color(hex: "#E63946").opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 20
                )
                .rotationEffect(.degrees(-90))

            Circle()
                .trim(from: phonePercentage / 100, to: 1)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#457B9D"),
                            Color(hex: "#457B9D").opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 20
                )
                .rotationEffect(.degrees(-90))

            // MARK: - Center Label
            VStack(spacing: 6) {
                Text("\(Int(phonePercentage))%")
                    .font(.system(size: 36, weight: .bold, design: .default))
                    .foregroundColor(Color(hex: "#1B2A4A"))

                Text("of your waking life")
                    .font(.caption)
                    .foregroundColor(Color(hex: "#A8DADC"))
            }
        }
        .frame(height: 200)
    }

    private var legend: some View {
        HStack(spacing: 24) {
            legendDot(
                color: Color(hex: "#E63946"),
                label: "Phone Time",
                value: String(format: "%.1f", phoneTime) + "h"
            )

            Spacer()

            legendDot(
                color: Color(hex: "#457B9D"),
                label: "Rest of Life",
                value: String(format: "%.1f", totalWakingHours - phoneTime) + "h"
            )
        }
    }

    private func legendDot(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(Color(hex: "#A8DADC"))

                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "#1B2A4A"))
            }
        }
    }
}
