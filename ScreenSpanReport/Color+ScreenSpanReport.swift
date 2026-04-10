import SwiftUI

/// ScreenSpan color palette for the DeviceActivityReport extension target.
/// These mirror the colors defined in the main app target's Color+ScreenSpan.swift
/// since the report extension does not have access to the main app's source files.
extension Color {
    /// Navy blue - Primary dark color (#1B2A4A)
    static let screenSpanNavy = Color(red: 0.106, green: 0.165, blue: 0.290)

    /// Red - Accent/warning color (#E63946)
    static let screenSpanRed = Color(red: 0.902, green: 0.224, blue: 0.275)

    /// Blue - Primary action color (#457B9D)
    static let screenSpanBlue = Color(red: 0.271, green: 0.482, blue: 0.616)

    /// Off-white - Background color (#F8F9FA)
    static let screenSpanOffWhite = Color(red: 0.973, green: 0.976, blue: 0.980)

    /// Gray - Muted text color (#A8DADC)
    static let screenSpanGray = Color(red: 0.659, green: 0.855, blue: 0.859)

    /// Light gray - Subtle backgrounds (#E5E5E5)
    static let screenSpanLightGray = Color(red: 0.898, green: 0.898, blue: 0.898)
}
