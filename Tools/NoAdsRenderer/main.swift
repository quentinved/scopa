import SwiftUI
import ImageIO
import UniformTypeIdentifiers

// Renders `NoAdsArtwork` to an opaque square PNG for the purchase's App Store promotional
// image. Run it with Tools/render-no-ads.sh.
MainActor.assumeIsolated {
    let arguments = CommandLine.arguments
    guard arguments.count == 3, let side = Double(arguments[1]) else {
        FileHandle.standardError.write(Data("usage: render-no-ads <size> <output.png>\n".utf8))
        exit(2)
    }
    let output = URL(fileURLWithPath: arguments[2])
    let renderer = ImageRenderer(content: NoAdsArtwork(size: side))
    renderer.scale = 1
    guard let drawing = renderer.cgImage else {
        FileHandle.standardError.write(Data("the renderer produced no image\n".utf8))
        exit(1)
    }
    // Flattened onto an opaque canvas: App Store Connect refuses an image with an alpha
    // channel, and says so as IMAGE_INCORRECT_DIMENSIONS.
    let pixels = Int(side.rounded())
    guard let canvas = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                                 space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                 bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { exit(1) }
    canvas.draw(drawing, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    guard let image = canvas.makeImage(),
          let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        FileHandle.standardError.write(Data("could not write \(output.path)\n".utf8))
        exit(1)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { exit(1) }
    print("\(pixels)×\(pixels) → \(output.path)")
}
