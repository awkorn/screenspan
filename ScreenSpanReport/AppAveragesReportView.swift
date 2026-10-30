import DeviceActivity
import SwiftUI

/// Up to three apps with their daily average over the last seven days. With
/// the host's unfiltered query these are the user's top apps; filtered to the
/// apps the user picked, they're the numbers to start the plan from. The user
/// reads them here and enters their own starting point in the host.
struct AppAveragesReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .appAverages
    let content: (ScreenTimeReportPayload) -> AppAveragesReportView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ScreenTimeReportPayload {
        await extractDailyAverage(from: data)
    }
}

struct AppAveragesReportView: View {
    let payload: ScreenTimeReportPayload

    var body: some View {
        VStack(spacing: 0) {
            if payload.topApps.isEmpty {
                Text("No app activity in the last 7 days.")
                    .font(.geist(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "#595959"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(Array(payload.topApps.prefix(3).enumerated()), id: \.element.id) { index, app in
                    if index > 0 { Divider().padding(.leading, 16) }
                    HStack(spacing: 12) {
                        AppNameLabel(app: app)
                            .font(.geist(size: 15, weight: .medium))
                            .foregroundStyle(Color(hex: "#051425"))
                            .lineLimit(1)
                            .frame(maxHeight: 28)
                        Spacer(minLength: 8)
                        Text("\(Self.format(hours: app.dailyHours)) a day")
                            .font(.geist(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: "#C82020"))
                            .monospacedDigit()
                            .fixedSize()
                    }
                    .padding(.horizontal, 16)
                    .frame(height: AppAveragesReportView.rowHeight)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(hex: "#F6F7FA"))
        .screenSpanLightSurface()
    }

    static let rowHeight: CGFloat = 52

    private static func format(hours: Double) -> String {
        let minutes = max(Int((hours * 60).rounded()), 0)
        if minutes < 60 { return "\(minutes)m" }
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }
}
