import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("usage: generate-app-icon.swift <source-image> <iconset-directory>\n", stderr)
    exit(2)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let fileManager = FileManager.default

try? fileManager.removeItem(at: outputDirectory)
try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fputs("failed to load source image at \(sourceURL.path)\n", stderr)
    exit(1)
}

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

func drawIcon(sourceImage: NSImage, pixels: CGFloat) -> NSImage {
    let size = NSSize(width: pixels, height: pixels)
    let image = NSImage(size: size)
    image.lockFocus()

    let bounds = CGRect(origin: .zero, size: size)
    NSGraphicsContext.current?.imageInterpolation = .high
    sourceImage.draw(
        in: bounds,
        from: CGRect(origin: .zero, size: sourceImage.size),
        operation: .copy,
        fraction: 1
    )

    image.unlockFocus()
    return image
}

for variant in variants {
    let image = drawIcon(sourceImage: sourceImage, pixels: variant.pixels)
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
