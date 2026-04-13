import SwiftUI

struct LifeGridRevealView: View {
    var viewModel: OnboardingViewModel

    @State private var arrowPulse = false

    private let titleColor = Color(hex: "051425")
    private let livedColor = Color(hex: "0063D6")
    private let screenTimeColor = Color(hex: "F63232")
    private let remainingColor = Color(hex: "D9D9D9")
    private let columnCount = 26
    private let spacing: CGFloat = 3
    private let horizontalPadding: CGFloat = 24

    private var lifeGridData: LifeGridData {
        let projection = viewModel.projectionResult ?? ProjectionCalculator.calculateProjectionFromDaily(
            currentAge: viewModel.selectedAge,
            targetAge: SharedConstants.DefaultValues.targetAge,
            dailyHours: viewModel.currentDailyAvgHours
        )

        return ProjectionCalculator.calculateLifeGrid(
            currentAge: viewModel.selectedAge,
            targetAge: SharedConstants.DefaultValues.targetAge,
            monthsOnPhone: projection.monthsOnPhone
        )
    }

    private var monthStates: [MonthState] {
        var states: [MonthState] = []
        states.reserveCapacity(lifeGridData.totalMonths)

        for _ in 0..<lifeGridData.monthsLived {
            states.append(.lived)
        }

        for _ in 0..<lifeGridData.phoneMonths {
            states.append(.screenTime)
        }

        for _ in 0..<lifeGridData.freeMonths {
            states.append(.remaining)
        }

        if states.count < lifeGridData.totalMonths {
            states.append(contentsOf: Array(repeating: .remaining, count: lifeGridData.totalMonths - states.count))
        }

        return Array(states.prefix(lifeGridData.totalMonths))
    }

    private var gridWidth: CGFloat {
        UIScreen.main.bounds.width - (horizontalPadding * 2)
    }

    private var cellSize: CGFloat {
        max((gridWidth - (CGFloat(columnCount - 1) * spacing)) / CGFloat(columnCount), 4)
    }

    private var rowCount: Int {
        Int(ceil(Double(monthStates.count) / Double(columnCount)))
    }

    private var gridHeight: CGFloat {
        (CGFloat(rowCount) * cellSize) + (CGFloat(max(rowCount - 1, 0)) * spacing)
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(cellSize), spacing: spacing, alignment: .top),
            count: columnCount
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your projected life chart")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(titleColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 24)
            .padding(.horizontal, horizontalPadding)

            Text("1 square = 1 month")
                .font(.system(size: 11))
                .foregroundStyle(titleColor.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
                .padding(.horizontal, horizontalPadding)

            chartGrid
                .padding(.top, 14)
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 18)

            legend
                .padding(.horizontal, horizontalPadding)

            Spacer(minLength: 20)

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.advance()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Reclaim your life")
                        .font(.system(size: 15, weight: .semibold))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .semibold))
                        .scaleEffect(arrowPulse ? 1.15 : 0.95)
                        .opacity(arrowPulse ? 1 : 0.7)
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: arrowPulse
                        )
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .onboardingPrimaryButtonStyle()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 26)
        }
        .background(Color.white.ignoresSafeArea())
        .onAppear {
            viewModel.calculateProjection()
            arrowPulse = true
        }
    }

    private var chartGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: spacing) {
            ForEach(Array(monthStates.enumerated()), id: \.offset) { _, state in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color(for: state))
                    .frame(width: cellSize, height: cellSize)
            }
        }
        .frame(width: gridWidth, height: gridHeight, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: livedColor, label: "Lived")
            legendItem(color: screenTimeColor, label: "Screen time")
            legendItem(color: remainingColor, label: "Remaining time")
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(titleColor)
        }
    }

    private func color(for state: MonthState) -> Color {
        switch state {
        case .lived:
            return livedColor
        case .screenTime:
            return screenTimeColor
        case .remaining:
            return remainingColor
        }
    }
}

private enum MonthState {
    case lived
    case screenTime
    case remaining
}
