import SwiftUI

/// Reusable grid component displaying months of life
/// Colors: blue (lived), red (screen time), gray (remaining)
struct LifeGridView: View {
    let goalGridData: LifeGridData

    private let columnCount = 26
    private let cellSpacing: CGFloat = 4
    private let livedColor = Color(hex: "#0063D6")
    private let screenTimeColor = Color(hex: "#F63232")
    private let remainingColor = Color(hex: "#D9D9D9")

    private var rowCount: Int {
        Int(ceil(Double(goalGridData.totalMonths) / Double(columnCount)))
    }

    private var gridCells: [GridMonth.Status] {
        let totalCellCount = rowCount * columnCount
        return scaledCells(for: goalGridData, cellCount: totalCellCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("1 square = 1 month")
                .font(.geist(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "#595959"))

            gridContent
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(livedColor.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var gridContent: some View {
        GeometryReader { proxy in
            let cellSize = max((proxy.size.width - (CGFloat(columnCount - 1) * cellSpacing)) / CGFloat(columnCount), 6)
            let columns = Array(
                repeating: GridItem(.fixed(cellSize), spacing: cellSpacing, alignment: .top),
                count: columnCount
            )

            LazyVGrid(columns: columns, spacing: cellSpacing) {
                ForEach(Array(gridCells.enumerated()), id: \.offset) { _, status in
                    RoundedRectangle(cornerRadius: 3.2, style: .continuous)
                        .fill(color(for: status))
                        .frame(width: cellSize, height: cellSize)
                }
            }
        }
        .frame(height: gridHeight)
    }

    private var gridHeight: CGFloat {
        let screenWidth = UIScreen.main.bounds.width - 48
        let cellSize = max((screenWidth - (CGFloat(columnCount - 1) * cellSpacing)) / CGFloat(columnCount), 6)
        return (CGFloat(rowCount) * cellSize) + (CGFloat(max(rowCount - 1, 0)) * cellSpacing)
    }

    private func scaledCells(for gridData: LifeGridData, cellCount: Int) -> [GridMonth.Status] {
        let totalMonths = max(gridData.totalMonths, 1)
        var livedCount = Int((Double(gridData.monthsLived) / Double(totalMonths) * Double(cellCount)).rounded())
        var screenTimeCount = Int((Double(gridData.phoneMonths) / Double(totalMonths) * Double(cellCount)).rounded())
        let remainingCount = max(cellCount - livedCount - screenTimeCount, 0)

        let overflow = livedCount + screenTimeCount + remainingCount - cellCount
        if overflow > 0 {
            screenTimeCount = max(screenTimeCount - overflow, 0)
        }

        livedCount = min(livedCount, cellCount)
        screenTimeCount = min(screenTimeCount, max(cellCount - livedCount, 0))

        let finalRemainingCount = max(cellCount - livedCount - screenTimeCount, 0)

        return Array(repeating: .lived, count: livedCount)
            + Array(repeating: .phoneConsumed, count: screenTimeCount)
            + Array(repeating: .free, count: finalRemainingCount)
    }

    private func color(for status: GridMonth.Status) -> Color {
        switch status {
        case .lived:
            return livedColor
        case .phoneConsumed:
            return screenTimeColor
        case .free:
            return remainingColor
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
