import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: generate-app-icon.swift <iconset-directory>\n", stderr)
    exit(2)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let fileManager = FileManager.default

try? fileManager.removeItem(at: outputDirectory)
try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

struct IconVariant {
    let name: String
    let pixels: CGFloat
}

let variants = [
    IconVariant(name: "icon_16x16.png", pixels: 16),
    IconVariant(name: "icon_16x16@2x.png", pixels: 32),
    IconVariant(name: "icon_32x32.png", pixels: 32),
    IconVariant(name: "icon_32x32@2x.png", pixels: 64),
    IconVariant(name: "icon_128x128.png", pixels: 128),
    IconVariant(name: "icon_128x128@2x.png", pixels: 256),
    IconVariant(name: "icon_256x256.png", pixels: 256),
    IconVariant(name: "icon_256x256@2x.png", pixels: 512),
    IconVariant(name: "icon_512x512.png", pixels: 512),
    IconVariant(name: "icon_512x512@2x.png", pixels: 1024)
]

func roundedRect(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func circle(center: CGPoint, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
}

func drawArrow(from start: CGPoint, to end: CGPoint, color: NSColor, width: CGFloat, headSize: CGFloat) {
    color.setStroke()
    color.setFill()

    let line = NSBezierPath()
    line.lineWidth = width
    line.lineCapStyle = .round
    line.move(to: start)
    line.line(to: end)
    line.stroke()

    let direction = atan2(end.y - start.y, end.x - start.x)
    let leftAngle = direction + CGFloat.pi * 0.78
    let rightAngle = direction - CGFloat.pi * 0.78

    let left = CGPoint(x: end.x + cos(leftAngle) * headSize, y: end.y + sin(leftAngle) * headSize)
    let right = CGPoint(x: end.x + cos(rightAngle) * headSize, y: end.y + sin(rightAngle) * headSize)

    let head = NSBezierPath()
    head.move(to: end)
    head.line(to: left)
    head.line(to: right)
    head.close()
    head.fill()
}

func drawIcon(pixels: CGFloat) -> NSImage {
    let size = NSSize(width: pixels, height: pixels)
    let image = NSImage(size: size)
    image.lockFocus()

    let bounds = CGRect(origin: .zero, size: size)
    NSColor.clear.setFill()
    bounds.fill()

    let inset = pixels * 0.06
    let iconRect = bounds.insetBy(dx: inset, dy: inset)
    let cornerRadius = pixels * 0.21
    let basePath = roundedRect(iconRect, radius: cornerRadius)

    NSGraphicsContext.current?.saveGraphicsState()
    NSShadow().apply {
        $0.shadowOffset = NSSize(width: 0, height: -pixels * 0.018)
        $0.shadowBlurRadius = pixels * 0.06
        $0.shadowColor = NSColor.black.withAlphaComponent(0.28)
    }
    NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.12, alpha: 1).setFill()
    basePath.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.14, green: 0.17, blue: 0.20, alpha: 1),
        NSColor(calibratedRed: 0.04, green: 0.05, blue: 0.07, alpha: 1)
    ])!
    gradient.draw(in: basePath, angle: -35)

    let glowPath = circle(center: CGPoint(x: pixels * 0.32, y: pixels * 0.70), radius: pixels * 0.28)
    NSColor(calibratedRed: 0.08, green: 0.42, blue: 1.0, alpha: 0.16).setFill()
    glowPath.fill()

    let stroke = roundedRect(iconRect.insetBy(dx: pixels * 0.018, dy: pixels * 0.018), radius: cornerRadius * 0.92)
    NSColor.white.withAlphaComponent(0.14).setStroke()
    stroke.lineWidth = max(1, pixels * 0.012)
    stroke.stroke()

    let blue = NSColor(calibratedRed: 0.10, green: 0.57, blue: 1.0, alpha: 1)
    let green = NSColor(calibratedRed: 0.18, green: 0.86, blue: 0.46, alpha: 1)
    let white = NSColor.white.withAlphaComponent(0.92)

    drawArrow(
        from: CGPoint(x: pixels * 0.28, y: pixels * 0.61),
        to: CGPoint(x: pixels * 0.68, y: pixels * 0.61),
        color: blue,
        width: pixels * 0.055,
        headSize: pixels * 0.085
    )
    drawArrow(
        from: CGPoint(x: pixels * 0.72, y: pixels * 0.40),
        to: CGPoint(x: pixels * 0.32, y: pixels * 0.40),
        color: green,
        width: pixels * 0.055,
        headSize: pixels * 0.085
    )

    circle(center: CGPoint(x: pixels * 0.28, y: pixels * 0.61), radius: pixels * 0.055).fill(with: white)
    circle(center: CGPoint(x: pixels * 0.72, y: pixels * 0.40), radius: pixels * 0.055).fill(with: white)

    image.unlockFocus()
    return image
}

extension NSShadow {
    func apply(_ configure: (NSShadow) -> Void) {
        configure(self)
        set()
    }
}

extension NSBezierPath {
    func fill(with color: NSColor) {
        color.setFill()
        fill()
    }
}

for variant in variants {
    let image = drawIcon(pixels: variant.pixels)
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        fputs("failed to render \(variant.name)\n", stderr)
        exit(1)
    }

    try pngData.write(to: outputDirectory.appendingPathComponent(variant.name), options: [.atomic])
}
