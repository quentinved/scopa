import SwiftUI
import ImageIO
import UniformTypeIdentifiers

// Renders `IconArtwork` straight to PNG, so the icon in the asset catalogue is always the
// same drawing the app ships. Run it with Tools/render-icon.sh after changing the artwork.
MainActor.assumeIsolated {
    let arguments = CommandLine.arguments
    guard (3...4).contains(arguments.count), let side = Double(arguments[1]) else {
        FileHandle.standardError.write(
            Data("usage: render-icon <size> <output.png> [light|dark|tinted]\n".utf8))
        exit(2)
    }
    let output = URL(fileURLWithPath: arguments[2])

    let appearance: IconArtwork.Appearance
    switch arguments.count == 4 ? arguments[3] : "light" {
    case "light": appearance = .light
    case "dark": appearance = .dark
    case "tinted": appearance = .tinted
    case let other:
        FileHandle.standardError.write(Data("unknown appearance: \(other)\n".utf8))
        exit(2)
    }

    let renderer = ImageRenderer(content: IconArtwork(size: side, appearance: appearance))
    renderer.scale = 1
    guard let drawing = renderer.cgImage else {
        FileHandle.standardError.write(Data("the renderer produced no image\n".utf8))
        exit(1)
    }

    // Flatten onto an opaque canvas. ImageRenderer always hands back a bitmap with an alpha
    // channel, and App Store Connect rejects an icon that carries one (ITMS-90717) even when
    // every pixel is fully opaque, so the channel has to be dropped rather than just filled.
    let pixels = Int(side.rounded())
    guard let canvas = CGContext(
        data: nil, width: pixels, height: pixels,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        FileHandle.standardError.write(Data("could not open an opaque canvas\n".utf8))
        exit(1)
    }
    canvas.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    canvas.fill(CGRect(x: 0, y: 0, width: pixels, height: pixels))
    canvas.draw(drawing, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    guard let image = canvas.makeImage() else {
        FileHandle.standardError.write(Data("could not flatten the drawing\n".utf8))
        exit(1)
    }
    guard let destination = CGImageDestinationCreateWithURL(
        output as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        FileHandle.standardError.write(Data("could not open \(output.path)\n".utf8))
        exit(1)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        FileHandle.standardError.write(Data("could not write \(output.path)\n".utf8))
        exit(1)
    }
    print("\(Int(side))×\(Int(side)) → \(output.path)")
}
