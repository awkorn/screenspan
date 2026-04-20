import SwiftUI

/// Donut chart visualization showing phone time vs rest of waking life.
/// Two-segment donut with center label and legend.
///
/// Lives in `Shared/` because it is rendered by the `ScreenSpanReport`
/// extension (inside `StatsReportView`) as well as available to any
/// host-app preview / settings surface. It takes only display numbers
/// as inputs and does no Screen Time API work itself — so being in
/// Shared/ is safe.
struct DonutChartView: View {
    let phoneTime: Double    // in hours
    let totalWakingHours: Double

    private var phonePercentage: Double {
        guard totalWakingHours > 0 else { return 0 }
        return min(max((phoneTime / totalWakingHours) * 100, 0), 100)
    }

    var body: some View {
        VStack(spacing: 24) {
            donutChart

            legend
        }
    }

    private var donutChart: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let ringWidth = size * 0.18

            ZStack {
                Circle()
                    .stroke(Color(hex: "#0063D6"), style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                    .shadow(color: Color.black.opacity(0.07), radius: 12, x: 0, y: 4)

                Circle()
                    .trim(from: 0, to: phonePercentage / 100)
                    .stroke(Color(hex: "#F63232"), style: StrokeStyle(lineWidth: ringWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))

                Circle()
                    .fill(.white)
                    .frame(width: size * 0.64, height: size * 0.64)

                VStack(spacing: 6) {
                    Text(formattedPercentage)
                        .font(.geist(size: size * 0.16, weight: .bold))
                        .foregroundStyle(Color(hex: "#0D141C"))
                        .monospacedDigit()

                    Text("of your waking life")
                        .font(.geist(size: size * 0.06, weight: .semibold))
                        .foregroundStyle(Color(hex: "#595959"))
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 260)
    }

    private var formattedPercentage: String {
        String(format: "%.1f%%", phonePercentage)
    }

    private var legend: some View {
        HStack(spacing: 24) {
            legendDot(
                color: Color(hex: "#0063D6"),
                label: "Rest of Life"
            )

            Spacer()

            legendDot(
                color: Color(hex: "#F63232"),
                label: "Phone Time"
            )
        }
        .padding(.horizontal, 18)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.geist(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: "#0D141C"))
        }
    }
}
