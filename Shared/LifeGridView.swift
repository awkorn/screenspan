import SwiftUI

/// One drawing surface instead of ~960 individual SwiftUI subviews.
/// Draw exactly one cell per month, including a partial final row.
struct LifeGridView: View {
    let goalGridData: LifeGridData
    private let columns = 26
    private let gap: CGFloat = 3
    private var rows: Int { max((goalGridData.totalMonths + columns - 1) / columns, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("1 square = 1 month")
                .font(.geist(size: 11))
                .foregroundStyle(ScreenSpanAppearance.secondaryText)
            Canvas { context, size in
                let cell = max((size.width - CGFloat(columns - 1) * gap) / CGFloat(columns), 0)
                for month in 0..<max(goalGridData.totalMonths, 0) {
                    let rect = CGRect(x: CGFloat(month % columns) * (cell + gap),
                                      y: CGFloat(month / columns) * (cell + gap),
                                      width: cell, height: cell)
                    let color: Color = month < goalGridData.monthsLived ? Color(hex: "#0063D6")
                        : month < goalGridData.monthsLived + goalGridData.phoneMonths ? Color(hex: "#F63232")
                        : Color(hex: "#D9D9D9")
                    context.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(color))
                }
            }
            .aspectRatio(CGFloat(columns) / CGFloat(rows), contentMode: .fit)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Life chart: \(goalGridData.monthsLived) months lived, \(goalGridData.phoneMonths) months projected on your phone, \(goalGridData.freeMonths) months remaining.")
        }
    }
}

extension LifeGridData {
    static func mockData(months: Int = 96) -> LifeGridData {
        let lived = months * 3 / 5
        let phone = months / 4
        return LifeGridData(totalMonths: months, monthsLived: lived, phoneMonths: phone, freeMonths: months - lived - phone)
    }
}
