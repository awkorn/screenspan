import SwiftUI

/// Move between two panels of the same opaque report view. Navigation belongs
/// to the host; activity and both rendered panels stay inside the extension.
/// Changing the visible panel does not change the report's identity or filter.
struct OnboardingReportViewport<Content: View>: View {
    let showsLifeChart: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            content()
                .frame(width: proxy.size.width, height: proxy.size.height * 2)
                .offset(y: showsLifeChart ? -proxy.size.height : 0)
        }
        .clipped()
    }
}
