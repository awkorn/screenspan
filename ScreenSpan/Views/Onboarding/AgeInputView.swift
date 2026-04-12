import SwiftUI

struct AgeInputView: View {
    var viewModel: OnboardingViewModel

    @State private var selectedDateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now

    private let backgroundColor = Color.white
    private let titleColor = Color(hex: "051425")
    private let subtitleColor = Color(hex: "595959")
    private let buttonColor = Color(hex: "051425")
    private let secondaryColor = Color.screenSpanCardBackground

    private var minimumDate: Date {
        Calendar.current.date(byAdding: .year, value: -100, to: .now) ?? .distantPast
    }

    private var maximumDate: Date {
        Calendar.current.date(byAdding: .year, value: -13, to: .now) ?? .now
    }

    private var calculatedAge: Int {
        let age = Calendar.current.dateComponents([.year], from: selectedDateOfBirth, to: .now).year ?? viewModel.selectedAge
        return max(age, 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.goBack()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(titleColor)
                        .frame(width: 28, height: 28)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 6) {
                Text("Enter your date of birth")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(titleColor)
                    .minimumScaleFactor(0.75)
                    .lineLimit(2)

                Text("This will be used in your calculation")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(subtitleColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 28)

            Spacer().frame(height: 28)

            DatePicker(
                "Date picker",
                selection: $selectedDateOfBirth,
                in: minimumDate...maximumDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)

            Spacer()

            VStack(spacing: 8) {
                Text("Default life expectancy")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(titleColor)

                Text("80 years")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(titleColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(secondaryColor)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 24)

            Spacer()

            Button {
                viewModel.selectedAge = calculatedAge
                AppGroupManager.shared.currentAge = calculatedAge
                viewModel.calculateProjection()
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.advance()
                }
            } label: {
                Text("Next")
                    .onboardingPrimaryButtonStyle()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
        }
        .background(backgroundColor.ignoresSafeArea())
        .onAppear {
            if viewModel.selectedAge > 0,
               let dateFromAge = Calendar.current.date(byAdding: .year, value: -viewModel.selectedAge, to: .now) {
                selectedDateOfBirth = dateFromAge
            }
        }
    }
}
