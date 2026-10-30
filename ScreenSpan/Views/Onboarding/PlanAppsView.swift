import DeviceActivity
import FamilyControls
import SwiftUI

/// Back, progress, and continue for a plan step, so the same screens work in
/// onboarding and in the setup sheet.
struct PlanStepChrome {
    /// Nil hides the progress bar.
    var progress: Double?
    var back: (() -> Void)?
    var next: () -> Void
}

/// Pick the apps the plan will cut back on. The report lists the user's top
/// apps so they know which to choose; the host only learns what they pick.
struct PlanAppsView: View {
    @Bindable var draft: PlanDraftModel
    let chrome: PlanStepChrome
    @State private var selection = FamilyActivitySelection()
    @State private var showsPicker = false
    @State private var pickedTooMany = false

    var body: some View {
        OnboardingScaffold(
            title: draft.isAdding ? "Add to your plan" : "Start with your top apps",
            subtitle: draft.isAdding
                ? "Pick an app that takes a lot of your time, like one that took over from the others."
                : "A little less time on the two or three apps that take the most is the change most likely to stick.",
            progress: chrome.progress,
            onBack: chrome.back
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    PlanSectionLabel("YOUR TOP APPS · LAST 7 DAYS")
                    PlanAppAveragesReport(filter: .screenSpanProjectionAverage)
                    if !draft.items.isEmpty {
                        PlanSectionLabel(draft.isAdding ? "ADDING" : "IN YOUR PLAN")
                            .padding(.top, 12)
                        VStack(spacing: 0) {
                            ForEach(Array(draft.items.enumerated()), id: \.element.id) { index, item in
                                if index > 0 { Divider().padding(.leading, 16) }
                                PlanItemLabel(selection: item.selection)
                                    .padding(.horizontal, 16)
                                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                            }
                        }
                        .background(OnboardingStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    if pickedTooMany {
                        Text(draft.isAdding
                             ? "Your plan has room for \(draft.room) more. Fewer changes at once are easier to keep."
                             : "Pick up to \(ReductionPlan.maximumApps). Fewer changes at once are easier to keep.")
                            .font(.geist(size: 13, weight: .medium))
                            .foregroundStyle(OnboardingStyle.red)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
        } footer: {
            if draft.items.isEmpty {
                OnboardingPrimaryButton(title: draft.room == 1 ? "Choose an app" : "Choose apps") { showsPicker = true }
            } else {
                OnboardingPrimaryButton(title: "Continue", action: chrome.next)
                OnboardingSecondaryButton(title: "Change apps") { showsPicker = true }
            }
        }
        .familyActivityPicker(headerText: draft.room == 1 ? "Choose one app." : "Choose up to \(draft.room) of your top apps.",
                              isPresented: $showsPicker, selection: $selection)
        .onAppear { selection = draft.items.combinedSelection }
        .onChange(of: showsPicker) { _, isShowing in
            guard !isShowing else { return }
            var accepted = false
            withAnimation { accepted = draft.setSelection(selection) }
            pickedTooMany = !accepted
            if !accepted { selection = draft.items.combinedSelection }
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
