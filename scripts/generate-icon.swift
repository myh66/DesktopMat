import AppKit

// An original vector-drawn app icon; this asset is never used as the desktop rug.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let variants = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
for (points, scale) in variants {
    let pixels = points * scale
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    let tile = NSBezierPath(roundedRect: NSRect(x: 54, y: 54, width: 916, height: 916), xRadius: 205, yRadius: 205)
    NSGradient(starting: NSColor(calibratedRed: 0.91, green: 0.88, blue: 0.8, alpha: 1),
        ending: NSColor(calibratedRed: 0.73, green: 0.75, blue: 0.7, alpha: 1))!.draw(in: tile, angle: 110)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
    shadow.shadowBlurRadius = 30
    shadow.shadowOffset = NSSize(width: 0, height: -20)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    let rug = NSBezierPath(roundedRect: NSRect(x: 230, y: 240, width: 564, height: 515), xRadius: 26, yRadius: 26)
    NSColor(calibratedRed: 0.93, green: 0.9, blue: 0.81, alpha: 1).setFill()
    rug.fill()
    NSGraphicsContext.restoreGraphicsState()
    let indigo = NSColor(calibratedRed: 0.16, green: 0.24, blue: 0.31, alpha: 1)
    indigo.setStroke()
    let border = NSBezierPath(roundedRect: NSRect(x: 263, y: 272, width: 498, height: 446), xRadius: 6, yRadius: 6)
    border.lineWidth = 23
    border.stroke()
    let inner = NSBezierPath(rect: NSRect(x: 289, y: 298, width: 446, height: 394))
    inner.lineWidth = 4
    inner.stroke()
    let cloud = NSBezierPath()
    cloud.move(to: NSPoint(x: 408, y: 456))
    cloud.curve(to: NSPoint(x: 430, y: 546), controlPoint1: NSPoint(x: 340, y: 495), controlPoint2: NSPoint(x: 375, y: 566))
    cloud.curve(to: NSPoint(x: 534, y: 579), controlPoint1: NSPoint(x: 423, y: 614), controlPoint2: NSPoint(x: 509, y: 629))
    cloud.curve(to: NSPoint(x: 623, y: 520), controlPoint1: NSPoint(x: 598, y: 615), controlPoint2: NSPoint(x: 663, y: 560))
    cloud.curve(to: NSPoint(x: 578, y: 457), controlPoint1: NSPoint(x: 677, y: 479), controlPoint2: NSPoint(x: 641, y: 435))
    cloud.curve(to: NSPoint(x: 466, y: 484), controlPoint1: NSPoint(x: 525, y: 446), controlPoint2: NSPoint(x: 472, y: 423))
    cloud.curve(to: NSPoint(x: 514, y: 511), controlPoint1: NSPoint(x: 454, y: 525), controlPoint2: NSPoint(x: 493, y: 539))
    cloud.lineWidth = 18
    cloud.lineCapStyle = .round
    cloud.stroke()
    for x in stride(from: 272, through: 754, by: 26) {
        let strand = NSBezierPath()
        strand.move(to: NSPoint(x: x, y: 238))
        strand.line(to: NSPoint(x: x - 4, y: 201))
        strand.lineWidth = 10
        strand.lineCapStyle = .round
        NSColor(calibratedRed: 0.9, green: 0.87, blue: 0.77, alpha: 1).setStroke()
        strand.stroke()
    }
    let roll = NSBezierPath(roundedRect: NSRect(x: 230, y: 681, width: 564, height: 90), xRadius: 43, yRadius: 43)
    NSColor(calibratedRed: 0.8, green: 0.77, blue: 0.66, alpha: 1).setFill()
    roll.fill()
    indigo.setStroke()
    roll.lineWidth = 9
    roll.stroke()
    let curl = NSBezierPath(ovalIn: NSRect(x: 719, y: 701, width: 45, height: 45))
    curl.lineWidth = 8
    curl.stroke()
    NSGraphicsContext.restoreGraphicsState()
    let suffix = scale == 2 ? "@2x" : ""
    let name = "icon_\(points)x\(points)\(suffix).png"
    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
}

// Encode the standard PNG-backed ICNS container directly. This avoids relying
// on iconutil's image conversion service when building in a restricted workspace.
if CommandLine.arguments.count > 2 {
    var chunks = Data()
    let types = ["icp4", "ic11", "icp5", "ic12", "ic07", "ic13", "ic08", "ic14", "ic09", "ic10"]
    func bigEndianLength(_ value: Int) -> Data {
        var number = UInt32(value).bigEndian
        return withUnsafeBytes(of: &number) { Data($0) }
    }
    for (index, variant) in variants.enumerated() {
        let suffix = variant.1 == 2 ? "@2x" : ""
        let png = try Data(contentsOf: output.appendingPathComponent("icon_\(variant.0)x\(variant.0)\(suffix).png"))
        chunks.append(Data(types[index].utf8))
        chunks.append(bigEndianLength(png.count + 8))
        chunks.append(png)
    }
    var icon = Data("icns".utf8)
    icon.append(bigEndianLength(chunks.count + 8))
    icon.append(chunks)
    try icon.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
}
