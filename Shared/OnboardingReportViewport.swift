import SwiftUI

/// Show one of several equal-height panels stacked in the same opaque report
/// view. Navigation belongs to the host; activity and every rendered panel
/// stay inside the extension. Changing the visible panel does not change the
/// report's identity or filter.
struct OnboardingReportViewport<Content: View>: View {
    let panel: Int
    let panelCount: Int
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            content()
                .frame(width: proxy.size.width, height: proxy.size.height * CGFloat(panelCount))
                .offset(y: -proxy.size.height * CGFloat(min(max(panel, 0), panelCount - 1)))
                .animation(.easeInOut(duration: 0.35), value: panel)
        }
        .clipped()
    }
}
