import SwiftUI
import DeviceActivity

/// Life grid rendered in the DeviceActivityReport extension
/// Displays a full grid with blue/red/gray squares representing life span
struct ChartReportView: View {
    let dailyAverageHours: Double

    // Shared UserDefaults
    @AppStorage(SharedConstants.UserDefaultsKey.currentAge.rawValue, store: .appGroup)
    private var currentAge: Int = 30

    @AppStorage(SharedConstants.UserDefaultsKey.targetAge.rawValue, store: .appGroup)
    private var targetAge: Int = SharedConstants.DefaultValues.targetAge

    @AppStorage(SharedConstants.UserDefaultsKey.screenTimeGoalMinutes.rawValue, store: .appGroup)
    private var screenTimeGoalMinutes: Int = 120

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Title
                VStack(spacing: 8) {
                    Text("Your Life Grid")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Each square represents one week. Blue shows weeks you've reclaimed.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Life Grid
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 52),
                    spacing: 2
                ) {
                    ForEach(0..<(52 * weeksUntilTarget), id: \.self) { index in
                        GridSquare(
                            isReclaimed: isWeekReclaimed(index),
                            isPassed: isWeekPassed(index)
                        )
                    }
                }
                .padding()
                .background(Color.screenSpanOffWhite)
                .cornerRadius(12)

                // Legend
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.screenSpanBlue)
                                .frame(width: 12, height: 12)
                            Text("Reclaimed")
                                .font(.caption)
                        }

                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.screenSpanRed)
                                .frame(width: 12, height: 12)
                            Text("Lived")
                                .font(.caption)
                        }

                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.screenSpanLightGray)
                                .frame(width: 12, height: 12)
                            Text("Future")
                                .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color.screenSpanOffWhite)
                .cornerRadius(8)

                // Stats Summary
                VStack(spacing: 12) {
                    InfoRow(
                        label: "Current Age",
                        value: "\(currentAge)"
                    )
                    InfoRow(
                        label: "Target Age",
                        value: "\(targetAge)"
                    )
                    InfoRow(
                        label: "Weeks Until Target",
                        value: "\(weeksUntilTarget)"
                    )
                }
            }
            .padding()
        }
    }

    private func isWeekReclaimed(_ index: Int) -> Bool {
        // Calculate if this week has been reclaimed based on usage
        return index < (weeksUntilTarget / 3)
    }

    private func isWeekPassed(_ index: Int) -> Bool {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: Date())
        let currentYearWeek = (ageComponents.year ?? 0) * 52
        return index < currentYearWeek
    }

    private var weeksUntilTarget: Int {
        (targetAge - currentAge) * 52
    }
}

struct GridSquare: View {
    let isReclaimed: Bool
    let isPassed: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .aspectRatio(1, contentMode: .fit)
    }

    private var color: Color {
        if isReclaimed {
            return .screenSpanBlue
        } else if isPassed {
            return .screenSpanRed
        } else {
            return .screenSpanLightGray
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color.screenSpanOffWhite)
        .cornerRadius(8)
    }
}
