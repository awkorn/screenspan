import SwiftUI

/// ScreenSpan color palette extensions
extension Color {
    /// Navy blue - Primary dark color (#1B2A4A)
    static let screenSpanNavy = Color(red: 0.106, green: 0.165, blue: 0.290)

    /// Red - Accent/warning color (#E63946)
    static let screenSpanRed = Color(red: 0.902, green: 0.224, blue: 0.275)

    /// Blue - Primary action color (#457B9D)
    static let screenSpanBlue = Color(red: 0.271, green: 0.482, blue: 0.616)

    /// Off-white - Background color (#F3F4F6)
    static let screenSpanOffWhite = Color(red: 0.953, green: 0.957, blue: 0.965)

    /// Off-white card color used in onboarding (#F6F7FA)
    static let screenSpanCardBackground = Color(red: 0.965, green: 0.969, blue: 0.980)

    /// Gray - Muted text color (#A8DADC)
    static let screenSpanGray = Color(red: 0.659, green: 0.855, blue: 0.859)

    /// Light gray - Subtle backgrounds (#E5E5E5)
    static let screenSpanLightGray = Color(red: 0.898, green: 0.898, blue: 0.898)

    /// Initialize color from hex string (e.g., "#1B2A4A")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0

        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue >> 16) & 0xFF) / 255.0
        let g = Double((rgbValue >> 8) & 0xFF) / 255.0
        let b = Double(rgbValue & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

/// UIColor variants for compatibility with UIKit
extension UIColor {
    /// Navy blue - Primary dark color (#1B2A4A)
    static let screenSpanNavy = UIColor(red: 0.106, green: 0.165, blue: 0.290, alpha: 1.0)

    /// Red - Accent/warning color (#E63946)
    static let screenSpanRed = UIColor(red: 0.902, green: 0.224, blue: 0.275, alpha: 1.0)

    /// Blue - Primary action color (#457B9D)
    static let screenSpanBlue = UIColor(red: 0.271, green: 0.482, blue: 0.616, alpha: 1.0)

    /// Off-white - Background color (#F3F4F6)
    static let screenSpanOffWhite = UIColor(red: 0.953, green: 0.957, blue: 0.965, alpha: 1.0)

    /// Off-white card color used in onboarding (#F6F7FA)
    static let screenSpanCardBackground = UIColor(red: 0.965, green: 0.969, blue: 0.980, alpha: 1.0)

    /// Gray - Muted text color (#A8DADC)
    static let screenSpanGray = UIColor(red: 0.659, green: 0.855, blue: 0.859, alpha: 1.0)

    /// Light gray - Subtle backgrounds (#E5E5E5)
    static let screenSpanLightGray = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1.0)
}

struct OnboardingPrimaryButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.geist(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color(hex: "#051425"))
            .clipShape(Capsule())
    }
}

extension View {
    func onboardingPrimaryButtonStyle() -> some View {
        modifier(OnboardingPrimaryButtonModifier())
    }
}
