// Regenerate the original vector-drawn Momentum icon with:
// swift scripts/generate-icon.swift [output-directory]
import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("MomentumIcon-\(UUID().uuidString)", isDirectory: true)
let iconset = temporary.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: temporary) }

func render(size: Int) throws -> Data {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                                  bytesPerRow: size * 4, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw NSError(domain: "MomentumIcon", code: 1)
    }
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    context.setAllowsAntialiasing(true)
    // macOS rounded-square canvas with transparent corners.
    let canvas = CGPath(roundedRect: CGRect(x: 56, y: 56, width: 912, height: 912), cornerWidth: 190, cornerHeight: 190, transform: nil)
    context.addPath(canvas)
    context.setFillColor(CGColor(srgbRed: 0.97, green: 0.966, blue: 0.95, alpha: 1))
    context.fillPath()
    context.addPath(canvas)
    context.setLineWidth(3)
    context.setStrokeColor(CGColor(gray: 0.82, alpha: 1))
    context.strokePath()
    // A slight offset sheet edge gives a recognizable silhouette at small sizes.
    context.setFillColor(CGColor(gray: 0.08, alpha: 1))
    context.addPath(CGPath(roundedRect: CGRect(x: 234, y: 214, width: 580, height: 580), cornerWidth: 16, cornerHeight: 16, transform: nil))
    context.fillPath()
    let page = CGPath(roundedRect: CGRect(x: 210, y: 238, width: 580, height: 580), cornerWidth: 12, cornerHeight: 12, transform: nil)
    context.addPath(page)
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.setStrokeColor(CGColor(gray: 0.08, alpha: 1))
    context.setLineWidth(22)
    context.drawPath(using: .fillStroke)
    // M is a geometric path, not a proprietary font or another product's mark.
    let normalized: [CGPoint] = [
        .init(x: 0, y: 1), .init(x: 0, y: 0), .init(x: 0.2, y: 0),
        .init(x: 0.5, y: 0.52), .init(x: 0.8, y: 0), .init(x: 1, y: 0),
        .init(x: 1, y: 1), .init(x: 0.79, y: 1), .init(x: 0.79, y: 0.4),
        .init(x: 0.5, y: 0.9), .init(x: 0.21, y: 0.4), .init(x: 0.21, y: 1)
    ]
    let points = normalized.map { CGPoint(x: 314 + $0.x * 372, y: 342 + (1 - $0.y) * 372) }
    context.beginPath()
    context.addLines(between: points)
    context.closePath()
    context.setFillColor(CGColor(gray: 0.08, alpha: 1))
    context.fillPath()
    guard let image = context.makeImage(), let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        throw NSError(domain: "MomentumIcon", code: 2)
    }
    return png
}
let representations: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]
for (name, size) in representations { try render(size: size).write(to: iconset.appendingPathComponent(name)) }
try render(size: 1024).write(to: output.appendingPathComponent("AppIcon.png"))
let utility = Process()
utility.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
utility.arguments = ["-c", "icns", "-o", output.appendingPathComponent("AppIcon.icns").path, iconset.path]
try utility.run()
utility.waitUntilExit()
guard utility.terminationStatus == 0 else { throw NSError(domain: "MomentumIcon", code: Int(utility.terminationStatus)) }
print("Generated AppIcon.icns and AppIcon.png in \(output.path)")
