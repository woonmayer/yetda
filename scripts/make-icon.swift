// Renders the Yetda app icon: a screenshot-region frame around a
// terminal prompt. Run via scripts/make-icon.sh, which builds the .icns.
//
//   swift scripts/make-icon.swift <output-dir>
import AppKit

let outDir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "assets")

func render(size: Int) -> Data {
    let s = CGFloat(size) / 1024
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: s, y: s)

    // Body: Apple's macOS icon grid puts an 824pt rounded square in a 1024 canvas.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28,
                  color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(bodyPath)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(srgbRed: 0.16, green: 0.17, blue: 0.22, alpha: 1).cgColor,
            NSColor(srgbRed: 0.07, green: 0.07, blue: 0.10, alpha: 1).cgColor,
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    // Region-capture corner brackets.
    let frame = body.insetBy(dx: 150, dy: 150)
    let arm: CGFloat = 120
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(46)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    for (x, y, dx, dy) in [
        (frame.minX, frame.maxY, 1.0, -1.0), (frame.maxX, frame.maxY, -1.0, -1.0),
        (frame.minX, frame.minY, 1.0, 1.0), (frame.maxX, frame.minY, -1.0, 1.0),
    ] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
        ctx.move(to: CGPoint(x: x, y: y + dy * arm))
        ctx.addLine(to: CGPoint(x: x, y: y))
        ctx.addLine(to: CGPoint(x: x + dx * arm, y: y))
    }
    ctx.strokePath()

    // Terminal prompt "›_" in the accent color.
    let accent = NSColor(srgbRed: 1.0, green: 0.62, blue: 0.27, alpha: 1).cgColor
    ctx.setStrokeColor(accent)
    ctx.setLineWidth(52)
    ctx.move(to: CGPoint(x: 380, y: 610))
    ctx.addLine(to: CGPoint(x: 490, y: 512))
    ctx.addLine(to: CGPoint(x: 380, y: 414))
    ctx.strokePath()
    ctx.move(to: CGPoint(x: 545, y: 414))
    ctx.addLine(to: CGPoint(x: 660, y: 414))
    ctx.strokePath()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = outDir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try render(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try render(size: 512).write(to: outDir.appendingPathComponent("icon.png"))
