import SwiftUI

/// Sets up a plan, or adds to one, after onboarding, using the onboarding
/// plan steps. A draft left by declining Pro picks up where it stopped.
struct PlanSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var blocking: BlockingService
    @State private var draft: PlanDraftModel
    @State private var step = 0

    init(existing: [PlannedApp]) {
        _draft = State(initialValue: PlanDraftModel(existing: existing))
    }

    var body: some View {
        Group {
            switch step {
            case 0: PlanAppsView(draft: draft, chrome: chrome)
            case 1: PlanBaselinesView(draft: draft, chrome: chrome)
            default:
                PlanPreviewView(draft: draft, chrome: chrome) {
                    draft.start(with: blocking)
                    dismiss()
                }
            }
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        .background(Color.white.ignoresSafeArea())
        .screenSpanLightSurface()
    }

    private var chrome: PlanStepChrome {
        PlanStepChrome(
            progress: Double(step) / 2,
            back: { withAnimation(.easeInOut(duration: 0.25)) { if step > 0 { step -= 1 } else { dismiss() } } },
            next: { withAnimation(.easeInOut(duration: 0.3)) { step += 1 } }
        )
    }
}
