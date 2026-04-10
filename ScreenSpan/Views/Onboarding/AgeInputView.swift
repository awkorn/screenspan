import SwiftUI

struct AgeInputView: View {
    var viewModel: OnboardingViewModel
    @State private var selectedAge: Int = 25
    @State private var isAnimating = false

    private var isAgeSelected: Bool {
        viewModel.userAge != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("How old are you?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.screenSpanNavy)

                Text("This helps us calculate your remaining life")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 40)

            Spacer()

            // Age Picker
            VStack(spacing: 16) {
                // Large display of selected age
                HStack(spacing: 4) {
                    Text("\(selectedAge)")
                        .font(.system(size: 64, weight: .bold, design: .default))
                        .foregroundColor(.screenSpanRed)
                        .monospacedDigit()

                    Text("years")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                // Subtitle about life expectancy
                VStack(spacing: 8) {
                    Text("Default life expectancy")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.screenSpanNavy)

                    Text("80 years")
                        .font(.system(size: 17))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.screenSpanNavy.opacity(0.06))
                .cornerRadius(12)
                .padding(.top, 24)
            }
            .padding(.horizontal, 24)

            Spacer()

            // Wheel Picker
            VStack(spacing: 24) {
                Picker("Age", selection: $selectedAge) {
                    ForEach(18...80, id: \.self) { age in
                        Text("\(age)").tag(age)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 180)
                .clipped()

                // Continue Button
                Button(action: {
                    viewModel.userAge = selectedAge
                    viewModel.calculateProjection()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.advance()
                    }
                }) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.screenSpanRed)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.screenSpanOffWhite.ignoresSafeArea())
        .onAppear {
            if let age = viewModel.userAge {
                selectedAge = age
            }
        }
    }
}
