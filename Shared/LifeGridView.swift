import SwiftUI

/// One drawing surface instead of ~960 individual SwiftUI subviews.
/// Draw exactly one cell per month, including a partial final row. Each row is
/// three years, so the age labels on the left line up with real ages.
struct LifeGridView: View {
    let goalGridData: LifeGridData
    private let columns = 36
    private let gap: CGFloat = 2
    private let gutter: CGFloat = 22
    private let labelEveryRows = 5
    private var rows: Int { max((goalGridData.totalMonths + columns - 1) / columns, 1) }

    static let livedColor = Color(hex: "#0063D6")
    static let phoneColor = Color(hex: "#F63232")
    static let regainedColor = Color(hex: "#2BB673")
    static let remainingColor = Color(hex: "#D9D9D9")

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("1 square = 1 month · 1 row = 3 years")
                .font(.geist(size: 11))
                .foregroundStyle(ScreenSpanAppearance.secondaryText)
            Canvas { context, size in
                let cell = max((size.width - gutter - CGFloat(columns - 1) * gap) / CGFloat(columns), 0)
                let lived = goalGridData.monthsLived
                let phone = lived + goalGridData.phoneMonths
                let regained = phone + goalGridData.regainedMonths
                for month in 0..<max(goalGridData.totalMonths, 0) {
                    let rect = CGRect(x: gutter + CGFloat(month % columns) * (cell + gap),
                                      y: CGFloat(month / columns) * (cell + gap),
                                      width: cell, height: cell)
                    let color = month < lived ? Self.livedColor
                        : month < phone ? Self.phoneColor
                        : month < regained ? Self.regainedColor
                        : Self.remainingColor
                    context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color))
                }
                for row in stride(from: 0, to: rows, by: labelEveryRows) {
                    let label = Text("\(row * columns / 12)")
                        .font(.geist(size: 9, weight: .medium))
                        .foregroundColor(ScreenSpanAppearance.secondaryText)
                    context.draw(label, at: CGPoint(x: 0, y: CGFloat(row) * (cell + gap) + cell / 2), anchor: .leading)
                }
            }
            .aspectRatio(gridAspectRatio, contentMode: .fit)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)
        }
    }

    /// Width over height. The fixed gutter and gaps make the true ratio vary
    /// with width; using the widest iPhone never clips the last row on
    /// narrower ones, at the cost of a few points of bottom space.
    private var gridAspectRatio: CGFloat {
        let referenceWidth: CGFloat = 440
        let cell = (referenceWidth - gutter - CGFloat(columns - 1) * gap) / CGFloat(columns)
        return referenceWidth / (CGFloat(rows) * (cell + gap) - gap)
    }

    private var accessibilitySummary: String {
        var parts = ["Life chart: \(goalGridData.monthsLived) months lived",
                     "\(goalGridData.phoneMonths) months projected on your phone"]
        if goalGridData.regainedMonths > 0 { parts.append("\(goalGridData.regainedMonths) months won back") }
        parts.append("\(goalGridData.freeMonths) months remaining")
        return parts.joined(separator: ", ") + "."
    }
}

extension LifeGridData {
    static func mockData(months: Int = 96) -> LifeGridData {
        let lived = months * 3 / 5
        let phone = months / 4
        return LifeGridData(totalMonths: months, monthsLived: lived, phoneMonths: phone, freeMonths: months - lived - phone)
    }
}
