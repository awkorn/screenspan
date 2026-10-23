import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Concept A, "Phone months": a 6×6 life grid on navy. Lived months are
// white, phone months red, the rest dim. Opaque and square; iOS applies the mask.
let size = 1024.0
let columns = 6
let lived = 14, phone = 7

func rgb(_ r: Double, _ g: Double, _ b: Double) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
}
let navy = rgb(10, 31, 56)
let white = rgb(255, 255, 255)
let red = rgb(246, 50, 50)
let dim = rgb(49, 67, 88) // white at 16% over navy

let context = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(navy)
context.fill(CGRect(x: 0, y: 0, width: size, height: size))

let pad = size * 0.2
let inner = size - pad * 2
let gap = inner * 0.06
let cell = (inner - gap * Double(columns - 1)) / Double(columns)
let radius = cell * 0.18
for index in 0..<(columns * columns) {
    let column = Double(index % columns), row = Double(index / columns)
    // Core Graphics' origin is bottom-left; rows count down from the top.
    let rect = CGRect(x: pad + column * (cell + gap), y: size - pad - (row + 1) * cell - row * gap,
                      width: cell, height: cell)
    context.setFillColor(index < lived ? white : index < lived + phone ? red : dim)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.fillPath()
}

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination), "Couldn't write \(output.path)")
print("Wrote \(output.path)")
