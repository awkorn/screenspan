import SwiftUI

/// Reusable grid component displaying months of life
/// Each square represents one month, colored by activity type
/// Colors: blue (lived), red (phone-consumed), gray (free)
struct LifeGridView: View {
    let gridData: LifeGridData
    private let columnCount = 12

    private var months: [GridMonth] {
        var generatedMonths: [GridMonth] = []

        // Generate months: lived first, then phone-consumed, then free
        for i in 0..<gridData.monthsLived {
            generatedMonths.append(GridMonth(id: i, status: .lived))
        }

        for i in gridData.monthsLived..<(gridData.monthsLived + gridData.phoneMonths) {
            generatedMonths.append(GridMonth(id: i, status: .phoneConsumed))
        }

        for i in (gridData.monthsLived + gridData.phoneMonths)..<gridData.totalMonths {
            generatedMonths.append(GridMonth(id: i, status: .free))
        }

        return generatedMonths
    }

    var body: some View {
        VStack(spacing: 16) {
            // MARK: - Grid
            gridContent

            // MARK: - Legend
            legend
        }
    }

    private var gridContent: some View {
        VStack(spacing: 8) {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: columnCount)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<months.count, id: \.self) { index in
                    let month = months[index]

                    RoundedRectangle(cornerRadius: 6)
                        .fill(colorForMonth(month))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                }
            }
        }
    }

    private var legend: some View {
        VStack(spacing: 10) {
            Text("1 square = 1 month")
                .font(.caption2)
                .foregroundColor(Color(hex: "#A8DADC"))

            HStack(spacing: 16) {
                legendItem(color: Color(hex: "#457B9D"), label: "Lived")
                legendItem(color: Color(hex: "#E63946"), label: "Phone Time")
                legendItem(color: Color(hex: "#A8DADC"), label: "Free")
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(label)
                .font(.caption)
                .foregroundColor(Color(hex: "#1B2A4A"))
        }
    }

    private func colorForMonth(_ month: GridMonth) -> Color {
        switch month.status {
        case .lived:
            return Color(hex: "#457B9D")
        case .phoneConsumed:
            return Color(hex: "#E63946")
        case .free:
            return Color(hex: "#A8DADC")
        }
    }
}

// MARK: - Grid Month Model (local to this component)
struct GridMonth {
    enum Status {
        case lived
        case phoneConsumed
        case free
    }

    let id: Int
    let status: Status
}

// MARK: - Mock Data Generator for Previews
extension LifeGridData {
    static func mockData(months: Int = 96) -> LifeGridData {
        // For preview purposes, create a LifeGridData with mock counts
        return LifeGridData(
            totalMonths: months,
            monthsLived: Int(Double(months) * 0.6),
            phoneMonths: Int(Double(months) * 0.25),
            freeMonths: Int(Double(months) * 0.15)
        )
    }
}
