import SwiftUI
import UIKit

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
                        .font(.geist(size: 18))
                        .foregroundColor(titleColor)
                        .frame(width: 28, height: 28)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 6) {
                Text("Enter your date of birth")
                    .font(.geist(size: 28, weight: .bold))
                    .foregroundColor(titleColor)
                    .minimumScaleFactor(0.75)
                    .lineLimit(2)

                Text("This will be used in your calculation")
                    .font(.geist(size: 18))
                    .foregroundColor(subtitleColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 28)

            Spacer().frame(height: 28)

            VStack(spacing: 12) {
                Text(selectedDateOfBirth.formatted(date: .complete, time: .omitted))
                    .font(.geist(size: 18, weight: .medium))
                    .foregroundColor(titleColor)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                BirthDateWheelPicker(
                    selectedDate: $selectedDateOfBirth,
                    minimumDate: minimumDate,
                    maximumDate: maximumDate
                )
                .frame(height: 216)
            }
            .padding(.horizontal, 12)

            Spacer()

            VStack(spacing: 8) {
                Text("Default life expectancy")
                    .font(.geist(size: 16, weight: .medium))
                    .foregroundColor(titleColor)

                Text("80 years")
                    .font(.geist(size: 16, weight: .semibold))
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

private struct BirthDateWheelPicker: UIViewRepresentable {
    @Binding var selectedDate: Date
    let minimumDate: Date
    let maximumDate: Date

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.locale = .current
        picker.minimumDate = minimumDate
        picker.maximumDate = maximumDate
        picker.date = selectedDate
        picker.overrideUserInterfaceStyle = .light
        picker.addTarget(
            context.coordinator,
            action: #selector(Coordinator.dateChanged(_:)),
            for: .valueChanged
        )
        return picker
    }

    func updateUIView(_ uiView: UIDatePicker, context: Context) {
        uiView.minimumDate = minimumDate
        uiView.maximumDate = maximumDate
        uiView.overrideUserInterfaceStyle = .light

        if uiView.date != selectedDate {
            uiView.date = selectedDate
        }
    }

    final class Coordinator: NSObject {
        private var parent: BirthDateWheelPicker

        init(_ parent: BirthDateWheelPicker) {
            self.parent = parent
        }

        @objc func dateChanged(_ sender: UIDatePicker) {
            parent.selectedDate = sender.date
        }
    }
}
