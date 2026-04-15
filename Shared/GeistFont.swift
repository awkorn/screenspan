import SwiftUI
import UIKit

extension Font {
    static func geist(size: CGFloat, weight: Weight = .regular) -> Font {
        .custom("Geist", size: size).weight(weight)
    }

    static func geist(_ textStyle: TextStyle, weight: Weight = .regular) -> Font {
        .custom(
            "Geist",
            size: UIFont.preferredFont(forTextStyle: textStyle.uiKitTextStyle).pointSize,
            relativeTo: textStyle
        )
        .weight(weight)
    }
}

private extension Font.TextStyle {
    var uiKitTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle:
            return .largeTitle
        case .title:
            return .title1
        case .title2:
            return .title2
        case .title3:
            return .title3
        case .headline:
            return .headline
        case .subheadline:
            return .subheadline
        case .body:
            return .body
        case .callout:
            return .callout
        case .caption:
            return .caption1
        case .caption2:
            return .caption2
        case .footnote:
            return .footnote
        @unknown default:
            return .body
        }
    }
}
