import UIKit

/// The block screen's look, shared with the design preview: the app icon's
/// navy, soft grey-blue text, and the icon's life grid as the mark.
enum BlockScreenStyle {
    static let navy = UIColor(red: 10 / 255, green: 31 / 255, blue: 56 / 255, alpha: 1)
    static let mist = UIColor(red: 154 / 255, green: 166 / 255, blue: 181 / 255, alpha: 1)
    /// Near-black navy for the button label. The shield draws its label
    /// lighter than the color given, so this goes darker than the navy.
    static let ink = UIColor(red: 2 / 255, green: 8 / 255, blue: 16 / 255, alpha: 1)

    /// The life grid without its tile, so it sits directly on the navy.
    /// Lived months white, phone months red, the rest faint. A bitmap, since
    /// vector icons have failed to show on some devices' shields.
    static func mark(side: CGFloat = 56) -> UIImage {
        let columns = 6, lived = 14, phone = 7
        let gap = side * 0.07
        let cell = (side - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let red = UIColor(red: 246 / 255, green: 50 / 255, blue: 50 / 255, alpha: 1)
        let faint = UIColor.white.withAlphaComponent(0.16)
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
            for index in 0..<(columns * columns) {
                let column = CGFloat(index % columns), row = CGFloat(index / columns)
                let rect = CGRect(x: column * (cell + gap), y: row * (cell + gap), width: cell, height: cell)
                (index < lived ? UIColor.white : index < lived + phone ? red : faint).setFill()
                UIBezierPath(roundedRect: rect, cornerRadius: cell * 0.18).fill()
            }
        }
        .withRenderingMode(.alwaysOriginal)
    }
}
