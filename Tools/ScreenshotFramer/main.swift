import SwiftUI
import ImageIO
import UniformTypeIdentifiers

// Frames the raw shots from Tools/shoot-screenshots.sh for the App Store: a caption above,
// the shot in a device bezel below, on the cream the cards are printed on. Run it with
// Tools/frame-screenshots.sh.

/// One App Store display size: the canvas Apple wants, and how the frame sits on it.
struct Canvas {
    let directory: String
    let size: CGSize
    let headline: CGFloat
    let line: CGFloat
    /// Where the device starts; the caption is centred in the band above it.
    let deviceTop: CGFloat
    let bottom: CGFloat
    let bezel: CGFloat
    /// The screen's corner radius, as a fraction of its width.
    let corner: CGFloat
    /// The Dynamic Island, in the raw shot's pixels. The simulator draws it into some shots
    /// and not others, so it is drawn over all of them.
    let island: CGRect?
}

let canvases = [
    Canvas(directory: "iphone-6.9", size: CGSize(width: 1320, height: 2868),
           headline: 124, line: 50, deviceTop: 620, bottom: 90, bezel: 22, corner: 0.14,
           island: CGRect(x: 472, y: 42, width: 376, height: 110)),
    Canvas(directory: "ipad-13", size: CGSize(width: 2064, height: 2752),
           headline: 150, line: 62, deviceTop: 540, bottom: 90, bezel: 26, corner: 0.03,
           island: nil),
]

// Palette's, repeated here because Palette.swift needs the game package to compile.
enum Ink {
    static let cream = Color(red: 0.988, green: 0.973, blue: 0.933)
    static let linen = Color(red: 0.937, green: 0.906, blue: 0.827)
    static let tableDeep = Color(red: 0.055, green: 0.180, blue: 0.114)
    static let inkSoft = Color(red: 0.361, green: 0.333, blue: 0.298)
    static let bezel = Color(red: 0.118, green: 0.106, blue: 0.094)
    static let terracotta = Color(red: 0.808, green: 0.353, blue: 0.243)
    static let goldLight = Color(red: 0.941, green: 0.745, blue: 0.290)
}

struct FramedShot: View {
    let canvas: Canvas
    let caption: Caption
    let shot: CGImage

    var body: some View {
        ZStack(alignment: .top) {
            backdrop
            VStack(spacing: canvas.line * 0.55) {
                headline
                Text(caption.line)
                    .font(.system(size: canvas.line, weight: .medium))
                    .foregroundStyle(Ink.inkSoft)
            }
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .frame(width: canvas.size.width * 0.86, height: canvas.deviceTop * 0.92)
            device.padding(.top, canvas.deviceTop)
        }
        .frame(width: canvas.size.width, height: canvas.size.height)
    }

    /// The headline, with its `*starred*` words in terracotta.
    private var headline: some View {
        let parts = caption.headline.split(separator: "*", omittingEmptySubsequences: false)
        let text = parts.enumerated().reduce(Text(verbatim: "")) { text, part in
            text + Text(verbatim: String(part.element))
                .foregroundColor(part.offset.isMultiple(of: 2) ? Ink.tableDeep : Ink.terracotta)
        }
        return text.font(.system(size: canvas.headline, weight: .black).width(.condensed))
    }

    private var device: some View {
        let height = canvas.size.height - canvas.deviceTop - canvas.bottom - 2 * canvas.bezel
        let width = height * CGFloat(shot.width) / CGFloat(shot.height)
        let radius = width * canvas.corner
        let scale = width / CGFloat(shot.width)
        return Image(decorative: shot, scale: 1)
            .resizable()
            .frame(width: width, height: height)
            .overlay(alignment: .topLeading) {
                if let island = canvas.island {
                    Capsule().fill(.black)
                        .frame(width: island.width * scale, height: island.height * scale)
                        .offset(x: island.minX * scale, y: island.minY * scale)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .padding(canvas.bezel)
            .background(RoundedRectangle(cornerRadius: radius + canvas.bezel, style: .continuous)
                .fill(Ink.bezel))
            .shadow(color: .black.opacity(0.25), radius: 60, y: 36)
    }

    /// Cream paper with a warm light behind the device, as if the table were lamplit.
    private var backdrop: some View {
        let side = max(canvas.size.width, canvas.size.height)
        return ZStack {
            LinearGradient(colors: [Ink.cream, Ink.linen], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Ink.goldLight.opacity(0.45), Ink.goldLight.opacity(0)],
                           center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: side * 0.45)
            RadialGradient(colors: [Ink.terracotta.opacity(0.14), Ink.terracotta.opacity(0)],
                           center: UnitPoint(x: 0.5, y: 1.05), startRadius: 0, endRadius: side * 0.4)
        }
    }
}

// MARK: Files

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

func load(_ url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

/// Writes the drawing flattened onto an opaque canvas: App Store Connect wants no alpha.
func write(_ drawing: CGImage, to url: URL) {
    guard let canvas = CGContext(
        data: nil, width: drawing.width, height: drawing.height,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fail("could not open a canvas") }
    let bounds = CGRect(x: 0, y: 0, width: drawing.width, height: drawing.height)
    canvas.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    canvas.fill(bounds)
    canvas.draw(drawing, in: bounds)
    guard let image = canvas.makeImage(),
          let destination = CGImageDestinationCreateWithURL(
              url as CFURL, UTType.png.identifier as CFString, 1, nil) else { fail("could not write \(url.path)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fail("could not write \(url.path)") }
}

/// The locales to frame for one display size: every one shot, plus those borrowing a shot set.
func locales(in directory: URL) -> [(store: String, shots: String)] {
    let shot = ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
        .filter { !$0.hasPrefix(".") }.sorted()
    let borrowed = borrowedShots.filter { shot.contains($0.value) }.map { ($0.key, $0.value) }
    return shot.map { ($0, $0) } + borrowed.sorted { $0.0 < $1.0 }
}

@MainActor
func frame(_ canvas: Canvas, locale: (store: String, shots: String), raw: URL, out: URL) {
    let source = raw.appendingPathComponent(canvas.directory).appendingPathComponent(locale.shots)
    let target = out.appendingPathComponent(canvas.directory).appendingPathComponent(locale.store)
    try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    // Emptied first: a frame renamed or dropped must not linger and be uploaded.
    for old in (try? FileManager.default.contentsOfDirectory(at: target, includingPropertiesForKeys: nil)) ?? []
    where old.pathExtension == "png" { try? FileManager.default.removeItem(at: old) }

    for frame in frames {
        guard let caption = frame.caption(for: locale.store) else { fail("\(frame.name): no \(locale.store) caption") }
        let named = [frame.shot] + (frame.fallback.map { [$0] } ?? [])
        guard let shot = named.lazy.compactMap({ load(source.appendingPathComponent("\($0).png")) }).first else {
            fail("missing \(source.path)/\(frame.shot).png")
        }
        let renderer = ImageRenderer(content: FramedShot(canvas: canvas, caption: caption, shot: shot))
        renderer.scale = 1
        guard let drawing = renderer.cgImage else { fail("\(frame.name): the renderer produced no image") }
        write(drawing, to: target.appendingPathComponent("\(frame.name).png"))
    }
    print("  \(canvas.directory)/\(locale.store): \(frames.count) framed")
}

MainActor.assumeIsolated {
    let arguments = CommandLine.arguments
    guard arguments.count == 3 else { fail("usage: frame-screenshots <raw shots> <framed output>") }
    let raw = URL(fileURLWithPath: arguments[1], isDirectory: true)
    let out = URL(fileURLWithPath: arguments[2], isDirectory: true)
    for canvas in canvases {
        for locale in locales(in: raw.appendingPathComponent(canvas.directory)) {
            frame(canvas, locale: locale, raw: raw, out: out)
        }
    }
    print(out.path)
}
