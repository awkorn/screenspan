import DeviceActivity
import FamilyControls
import SwiftUI

/// Pick the apps the plan will cut back on. The report lists the user's top
/// apps so they know which to choose; the host only learns what they pick.
struct PlanAppsView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var selection = FamilyActivitySelection()
    @State private var showsPicker = false
    @State private var pickedTooMany = false

    var body: some View {
        OnboardingScaffold(
            viewModel: viewModel,
            title: "Start with your top apps",
            subtitle: "A little less time on the two or three apps that take the most is the change most likely to stick."
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    PlanSectionLabel("YOUR TOP APPS · LAST 7 DAYS")
                    PlanAppAveragesReport(filter: .screenSpanProjectionAverage)
                    if !viewModel.planItems.isEmpty {
                        PlanSectionLabel("IN YOUR PLAN")
                            .padding(.top, 12)
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.planItems.enumerated()), id: \.element.id) { index, item in
                                if index > 0 { Divider().padding(.leading, 16) }
                                PlanItemLabel(selection: item.selection)
                                    .padding(.horizontal, 16)
                                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                            }
                        }
                        .background(OnboardingStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    if pickedTooMany {
                        Text("Pick up to \(ReductionPlan.maximumApps). Fewer changes at once are easier to keep.")
                            .font(.geist(size: 13, weight: .medium))
                            .foregroundStyle(OnboardingStyle.red)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
        } footer: {
            if viewModel.planItems.isEmpty {
                OnboardingPrimaryButton(title: "Choose apps") { showsPicker = true }
            } else {
                OnboardingPrimaryButton(title: "Continue") { viewModel.advance() }
                OnboardingSecondaryButton(title: "Change apps") { showsPicker = true }
            }
        }
        .familyActivityPicker(headerText: "Choose up to \(ReductionPlan.maximumApps) of your top apps.",
                              isPresented: $showsPicker, selection: $selection)
        .onAppear { selection = viewModel.planItems.combinedSelection }
        .onChange(of: showsPicker) { _, isShowing in
            guard !isShowing else { return }
            pickedTooMany = selection.tokenCount > ReductionPlan.maximumApps
            if pickedTooMany {
                selection = viewModel.planItems.combinedSelection
            } else {
                withAnimation { viewModel.setPlanSelection(selection) }
            }
        }
    }
}

/// The app averages report in a card sized for three rows. A spinner sits
/// behind it until the extension paints over it.
struct PlanAppAveragesReport: View {
    let filter: DeviceActivityFilter

    var body: some View {
        ZStack {
            ProgressView().tint(OnboardingStyle.red)
            DeviceActivityReport(.appAverages, filter: filter)
        }
        .frame(height: 3 * 52)
        .frame(maxWidth: .infinity)
        .background(OnboardingStyle.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// The name and icon of a planned app, drawn by iOS from its token.
struct PlanItemLabel: View {
    let selection: FamilyActivitySelection

    var body: some View {
        Group {
            if let token = selection.applicationTokens.first {
                Label(token)
            } else if let token = selection.categoryTokens.first {
                Label(token)
            } else if let token = selection.webDomainTokens.first {
                Label(token)
            }
        }
        .labelStyle(.titleAndIcon)
        .font(.geist(size: 15, weight: .semibold))
        .foregroundStyle(OnboardingStyle.navy)
        .lineLimit(1)
    }
}

struct PlanSectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.geist(size: 12, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(OnboardingStyle.muted)
    }
}

extension [PlanDraftItem] {
    var combinedSelection: FamilyActivitySelection {
        var combined = FamilyActivitySelection()
        for item in self {
            combined.applicationTokens.formUnion(item.selection.applicationTokens)
            combined.categoryTokens.formUnion(item.selection.categoryTokens)
            combined.webDomainTokens.formUnion(item.selection.webDomainTokens)
        }
        return combined
    }
}
