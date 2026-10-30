import DeviceActivity
import SwiftUI

/// Where each app starts. The report shows the picked apps' last seven days;
/// the user dials in their own starting point beside it, since measured
/// numbers can't leave the report.
struct PlanBaselinesView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingScaffold(
            viewModel: viewModel,
            title: "Where are you starting?",
            subtitle: "Set each app to about what it takes now. Your plan steps down from here."
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    PlanSectionLabel("YOUR LAST 7 DAYS")
                    PlanAppAveragesReport(filter: .screenSpanAppAverages(viewModel.planItems.combinedSelection))
                    PlanSectionLabel("YOUR STARTING POINT")
                        .padding(.top, 12)
                    ForEach($viewModel.planItems) { $item in
                        BaselineCard(item: $item)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
        } footer: {
            OnboardingPrimaryButton(title: "See my plan", isEnabled: viewModel.planIsReady) {
                viewModel.savePlanDraft()
                viewModel.advance()
            }
        }
    }
}

private struct BaselineCard: View {
    @Binding var item: PlanDraftItem

    private var minutes: Int { item.baselineMinutes ?? 0 }
    private var isTooLow: Bool { item.baselineMinutes != nil && minutes < ReductionCourse.minimumBaselineMinutes }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                PlanItemLabel(selection: item.selection)
                Spacer(minLength: 8)
                Text(item.baselineMinutes == nil ? "Not set" : "\(PlanFormat.duration(minutes)) a day")
                    .font(.geist(size: 15, weight: .semibold))
                    .foregroundStyle(item.baselineMinutes == nil ? OnboardingStyle.muted : OnboardingStyle.navy)
                    .monospacedDigit()
            }
            HStack(spacing: 0) {
                Picker("Hours", selection: component(hours: true)) {
                    ForEach(0...12, id: \.self) { Text("\($0) h").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
                Picker("Minutes", selection: component(hours: false)) {
                    ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text("\($0) min").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .frame(height: 110)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Starting daily time")
            if isTooLow {
                Text("Under \(ReductionCourse.minimumBaselineMinutes) minutes a day is already low. Pick an app that takes more.")
                    .font(.geist(size: 12, weight: .medium))
                    .foregroundStyle(OnboardingStyle.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(OnboardingStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func component(hours: Bool) -> Binding<Int> {
        Binding {
            hours ? minutes / 60 : minutes % 60
        } set: { value in
            let total = hours ? value * 60 + minutes % 60 : (minutes / 60) * 60 + value
            item.baselineMinutes = total
            // A target picked for an older starting point may no longer fit.
            item.targetMinutes = nil
        }
    }
}

enum PlanFormat {
    static func duration(_ minutes: Int) -> String {
        let minutes = max(minutes, 0)
        if minutes < 60 { return "\(minutes)m" }
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }

    static func years(_ years: Double) -> String {
        if years >= 1 { return String(format: "%.1f years", years) }
        let months = years * 12
        if months >= 1 { return "\(Int(months.rounded())) months" }
        return "\(Int((years * 365).rounded())) days"
    }
}
