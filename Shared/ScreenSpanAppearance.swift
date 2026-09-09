import SwiftUI

/// Fixed foreground colors for ScreenSpan's white and pale-gray surfaces.
/// The report extension has its own environment, separate from the host app.
enum ScreenSpanAppearance {
    static let text = Color(red: 10 / 255.0, green: 31 / 255.0, blue: 56 / 255.0)
    static let secondaryText = Color(red: 75 / 255.0, green: 85 / 255.0, blue: 99 / 255.0)
}

extension View {
    func screenSpanLightSurface() -> some View {
        foregroundStyle(ScreenSpanAppearance.text)
            .environment(\.colorScheme, .light)
    }
}
