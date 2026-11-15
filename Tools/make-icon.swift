import AppKit
let directory = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
    let outer = NSBezierPath(roundedRect: NSRect(x: 54, y: 54, width: 916, height: 916), xRadius: 208, yRadius: 208)
    NSGradient(starting: NSColor(calibratedRed: 0.12, green: 0.23, blue: 0.34, alpha: 1), ending: NSColor(calibratedRed: 0.025, green: 0.07, blue: 0.13, alpha: 1))!.draw(in: outer, angle: -90)
    NSColor.white.withAlphaComponent(0.12).setStroke(); outer.lineWidth = 3; outer.stroke()
    // An ordered piano-roll melody above a small piano keyboard.
    let bars: [(CGFloat, CGFloat, CGFloat)] = [(206, 604, 152), (334, 676, 170), (482, 604, 130), (588, 748, 160), (732, 676, 92)]
    for (x,y,w) in bars {
        let path = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: 48), xRadius: 14, yRadius: 14)
        NSColor(calibratedRed: 0.30, green: 0.87, blue: 0.80, alpha: 1).setFill(); path.fill()
    }
    for i in 0..<7 {
        let rect = NSRect(x: 192 + CGFloat(i) * 92, y: 218, width: 84, height: 252)
        NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 13, yRadius: 13).fill()
    }
    for i in [0,1,3,4,5] {
        NSColor(calibratedRed: 0.055, green: 0.11, blue: 0.17, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 250 + CGFloat(i) * 92, y: 325, width: 60, height: 148), xRadius: 9, yRadius: 9).fill()
    }
    NSColor(calibratedRed: 1, green: 0.47, blue: 0.36, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 560, y: 540, width: 9, height: 300), xRadius: 4, yRadius: 4).fill()
    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    let names: [String]
    switch size {
    case 16: names = ["icon_16x16.png"]
    case 32: names = ["icon_16x16@2x.png", "icon_32x32.png"]
    case 64: names = ["icon_32x32@2x.png"]
    case 128: names = ["icon_128x128.png"]
    case 256: names = ["icon_128x128@2x.png", "icon_256x256.png"]
    case 512: names = ["icon_256x256@2x.png", "icon_512x512.png"]
    default: names = ["icon_512x512@2x.png"]
    }
    for name in names { try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name)) }
}
