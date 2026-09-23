import SwiftUI
import ImageIO
import UniformTypeIdentifiers

// Renders every `AchievementArtwork.Badge` to a PNG named after its App Store Connect id,
// so the badge you upload is always the drawing this repo holds. Run it with
// Tools/render-achievements.sh after changing the artwork.
MainActor.assumeIsolated {
    let arguments = CommandLine.arguments
    guard arguments.count == 3, let side = Double(arguments[1]) else {
        FileHandle.standardError.write(Data("usage: render-achievements <size> <directory>\n".utf8))
        exit(2)
    }
    let directory = URL(fileURLWithPath: arguments[2], isDirectory: true)
    do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    } catch {
        FileHandle.standardError.write(Data("could not open \(directory.path): \(error)\n".utf8))
        exit(1)
    }

    func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
        exit(1)
    }

    let pixels = Int(side.rounded())
    for badge in AchievementArtwork.Badge.allCases {
        let output = directory.appendingPathComponent("\(badge.rawValue).png")

        let renderer = ImageRenderer(content: AchievementArtwork(badge: badge, size: side))
        renderer.scale = 1
        guard let drawing = renderer.cgImage else { fail("\(badge.rawValue): the renderer produced no image") }

        // Flatten onto an opaque canvas. ImageRenderer always hands back a bitmap with an
        // alpha channel and App Store Connect rejects artwork that carries one even when
        // every pixel is opaque, so the channel has to be dropped rather than just filled.
        // The fill is the tile's own deep green, so any edge pixel blends into the drawing.
        guard let canvas = CGContext(
            data: nil, width: pixels, height: pixels,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            fail("\(badge.rawValue): could not open an opaque canvas")
        }
        canvas.setFillColor(CGColor(red: 0.055, green: 0.180, blue: 0.114, alpha: 1))
        canvas.fill(CGRect(x: 0, y: 0, width: pixels, height: pixels))
        canvas.draw(drawing, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
        guard let image = canvas.makeImage() else { fail("\(badge.rawValue): could not flatten the drawing") }

        guard let destination = CGImageDestinationCreateWithURL(
            output as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            fail("could not open \(output.path)")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { fail("could not write \(output.path)") }
        print("\(pixels)×\(pixels) → \(output.path)")
    }
}
