import SwiftUI

/// A window onto part of one tall report. Navigation belongs to the host; it
/// only chooses which region shows. Activity and every rendered region stay
/// inside the extension, and moving the window does not change the report's
/// identity or filter.
///
/// The content sits in a scroll view, not just a clipped frame, because a
/// clipped frame still receives touches outside its bounds; a scroll view
/// does not, so the report can't swallow taps on the controls around it.
struct OnboardingReportWindow<Content: View>: View {
    let contentHeight: CGFloat
    let offset: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            content()
                .frame(height: contentHeight)
                .offset(y: -offset)
                .animation(.easeInOut(duration: 0.35), value: offset)
        }
        .scrollDisabled(true)
    }
}
