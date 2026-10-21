import SwiftUI
import UIKit

struct AgeInputView: View {
    var viewModel: OnboardingViewModel

    @State private var selectedDateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now

    private var minimumDate: Date {
        Calendar.current.date(byAdding: .year, value: -100, to: .now) ?? .distantPast
    }

    private var maximumDate: Date {
        Calendar.current.date(byAdding: .year, value: -13, to: .now) ?? .now
    }

    private var calculatedAge: Int {
        max(Calendar.current.dateComponents([.year], from: selectedDateOfBirth, to: .now).year ?? viewModel.selectedAge, 0)
    }

    private var yearsLeft: Int {
        max(SharedConstants.DefaultValues.targetAge - calculatedAge, 0)
    }

    var body: some View {
        OnboardingScaffold(
            viewModel: viewModel,
            title: "When were you born?",
            subtitle: "Your projection counts the years between now and age 80."
        ) {
            VStack(spacing: 18) {
                Spacer(minLength: 8)
                BirthDateWheelPicker(
                    selectedDate: $selectedDateOfBirth,
                    minimumDate: minimumDate,
                    maximumDate: maximumDate
                )
                .frame(height: 216)

                HStack(spacing: 0) {
                    ageFact(value: "\(calculatedAge)", label: "years old")
                    Divider().frame(height: 36)
                    ageFact(value: "\(yearsLeft)", label: "years until 80")
                    Divider().frame(height: 36)
                    ageFact(value: (yearsLeft * 12).formatted(), label: "months ahead")
                }
                .padding(.vertical, 16)
                .background(OnboardingStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 24)

                Text("80 is a planning age, not a prediction. You can change it in Settings.")
                    .font(.geist(size: 12))
                    .foregroundStyle(OnboardingStyle.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer(minLength: 8)
            }
        } footer: {
            OnboardingPrimaryButton(title: "Continue") {
                viewModel.saveAge(calculatedAge)
                viewModel.advance()
            }
        }
        .onAppear {
            if let dateFromAge = Calendar.current.date(byAdding: .year, value: -viewModel.selectedAge, to: .now) {
                selectedDateOfBirth = dateFromAge
            }
        }
    }

    private func ageFact(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.geist(size: 20, weight: .bold))
                .foregroundStyle(OnboardingStyle.navy)
                .monospacedDigit()
            Text(label)
                .font(.geist(size: 12))
                .foregroundStyle(OnboardingStyle.muted)
        }
        .frame(maxWidth: .infinity)
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
