// Draws the app icon and writes AppIcon.iconset. Run once, then turn it into the .icns:
//   swiftc -parse-as-library make-icon.swift -o /tmp/make-icon && /tmp/make-icon AppIcon.iconset
//   iconutil -c icns AppIcon.iconset -o AppIcon.icns
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

@main
struct MakeIcon {
    /// Every size macOS wants: point size, scale.
    static let variants: [(points: Int, scale: Int)] = [
        (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
    ]

    static func main() throws {
        let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        for v in variants {
            let pixels = v.points * v.scale
            let name = "icon_\(v.points)x\(v.points)" + (v.scale == 2 ? "@2x" : "") + ".png"
            try write(render(pixels: pixels), to: out.appendingPathComponent(name))
        }
        print("wrote \(variants.count) sizes to \(out.path)")
    }

    static func color(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
        CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [r, g, b, a])!
    }

    static func gradient(_ top: CGColor, _ bottom: CGColor) -> CGGradient {
        CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [top, bottom] as CFArray, locations: [0, 1])!
    }

    static func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
        CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    /// Draws on a 1024 point canvas with the origin at the top left, scaled to `pixels`.
    static func render(pixels: Int) -> CGImage {
        let ctx = CGContext(
            data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let s = CGFloat(pixels) / 1024
        ctx.translateBy(x: 0, y: CGFloat(pixels))
        ctx.scaleBy(x: s, y: -s)

        // Dark rounded square in the standard macOS icon footprint, with a soft shadow.
        let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0, 0, 0, 0.45))
        ctx.addPath(roundedRect(tile, 185))
        ctx.setFillColor(color(0.12, 0.10, 0.12))
        ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(roundedRect(tile, 185))
        ctx.clip()
        ctx.drawLinearGradient(gradient(color(0.20, 0.17, 0.20), color(0.07, 0.06, 0.08)),
                               start: CGPoint(x: 0, y: tile.minY), end: CGPoint(x: 0, y: tile.maxY), options: [])
        ctx.restoreGState()

        drawAccordion(ctx)
        return ctx.makeImage()!
    }

    static func drawAccordion(_ ctx: CGContext) {
        let bodyW: CGFloat = 190, bellowsW: CGFloat = 270, h: CGFloat = 400
        let x0 = (1024 - (bodyW * 2 + bellowsW)) / 2
        let top = (1024 - h) / 2
        let bottom = top + h

        // Bellows: strips whose top and bottom edges alternate between the edge and an inset.
        let bellowsX = x0 + bodyW
        let folds = 10
        let inset: CGFloat = 34
        for i in 0..<folds {
            let xa = bellowsX + bellowsW * CGFloat(i) / CGFloat(folds)
            let xb = bellowsX + bellowsW * CGFloat(i + 1) / CGFloat(folds)
            let ia = i % 2 == 0 ? 0 : inset
            let ib = i % 2 == 0 ? inset : 0
            ctx.beginPath()
            ctx.move(to: CGPoint(x: xa, y: top + ia))
            ctx.addLine(to: CGPoint(x: xb, y: top + ib))
            ctx.addLine(to: CGPoint(x: xb, y: bottom - ib))
            ctx.addLine(to: CGPoint(x: xa, y: bottom - ia))
            ctx.closePath()
            ctx.setFillColor(color(i % 2 == 0 ? 0.10 : 0.21, i % 2 == 0 ? 0.10 : 0.21, i % 2 == 0 ? 0.10 : 0.21))
            ctx.setStrokeColor(color(0.60, 0.60, 0.60))
            ctx.setLineWidth(4)
            ctx.drawPath(using: .fillStroke)
        }

        let left = CGRect(x: x0, y: top, width: bodyW, height: h)
        let right = CGRect(x: bellowsX + bellowsW, y: top, width: bodyW, height: h)
        for rect in [left, right] {
            ctx.saveGState()
            ctx.addPath(roundedRect(rect, 40))
            ctx.clip()
            ctx.drawLinearGradient(gradient(color(0.80, 0.13, 0.16), color(0.44, 0.05, 0.09)),
                                   start: CGPoint(x: 0, y: rect.minY), end: CGPoint(x: 0, y: rect.maxY), options: [])
            ctx.restoreGState()
            ctx.addPath(roundedRect(rect, 40))
            ctx.setStrokeColor(color(0.90, 0.90, 0.90))
            ctx.setLineWidth(8)
            ctx.strokePath()
        }

        // Grill slits on the left body.
        ctx.setFillColor(color(0, 0, 0, 0.55))
        for row in 0..<6 {
            let slit = CGRect(x: left.minX + 38, y: top + 48 + CGFloat(row) * 56, width: bodyW - 76, height: 16)
            ctx.addPath(roundedRect(slit, 8))
            ctx.fillPath()
        }
        // Buttons on the right body.
        for row in 0..<5 {
            for col in 0..<3 {
                let dot = CGRect(x: right.minX + 32 + CGFloat(col) * 48, y: top + 44 + CGFloat(row) * 70, width: 34, height: 34)
                ctx.setFillColor(color(0.94, 0.94, 0.94))
                ctx.fillEllipse(in: dot)
                ctx.setStrokeColor(color(0, 0, 0, 0.45))
                ctx.setLineWidth(2)
                ctx.strokeEllipse(in: dot)
            }
        }
    }

    static func write(_ image: CGImage, to url: URL) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
    }
}
