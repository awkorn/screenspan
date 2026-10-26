import UIKit

/// The block screen's look, shared with the design preview: white like the
/// app, navy text and button, and the icon's life grid as the mark. The shield
/// mixes its background into a system blur, so a dark color comes out muddy
/// grey and the button label washes out; a light screen survives that.
enum BlockScreenStyle {
    static let background = UIColor.white
    static let navy = UIColor(red: 10 / 255, green: 31 / 255, blue: 56 / 255, alpha: 1)
    static let slate = UIColor(red: 75 / 255, green: 85 / 255, blue: 99 / 255, alpha: 1)
    /// Kept light whatever the device's appearance, so the white isn't
    /// blended toward dark grey in Dark Mode.
    static let blur = UIBlurEffect.Style.extraLight

    /// The life grid without its tile, so it sits directly on the white.
    /// Lived months navy, phone months red, the rest faint. A bitmap, since
    /// vector icons have failed to show on some devices' shields.
    static func mark(side: CGFloat = 56) -> UIImage {
        let columns = 6, lived = 14, phone = 7
        let gap = side * 0.07
        let cell = (side - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let red = UIColor(red: 230 / 255, green: 57 / 255, blue: 70 / 255, alpha: 1)
        let faint = navy.withAlphaComponent(0.12)
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
            for index in 0..<(columns * columns) {
                let column = CGFloat(index % columns), row = CGFloat(index / columns)
                let rect = CGRect(x: column * (cell + gap), y: row * (cell + gap), width: cell, height: cell)
                (index < lived ? navy : index < lived + phone ? red : faint).setFill()
                UIBezierPath(roundedRect: rect, cornerRadius: cell * 0.18).fill()
            }
        }
        .withRenderingMode(.alwaysOriginal)
    }
}
