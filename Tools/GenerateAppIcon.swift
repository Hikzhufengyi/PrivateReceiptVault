import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let appIconURL = root.appendingPathComponent("PrivateReceiptVault/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: appIconURL, withIntermediateDirectories: true)

struct IconSize {
    let idiom: String
    let size: String
    let scale: String
    let pixels: Int
}

let sizes: [IconSize] = [
    .init(idiom: "iphone", size: "20x20", scale: "2x", pixels: 40),
    .init(idiom: "iphone", size: "20x20", scale: "3x", pixels: 60),
    .init(idiom: "iphone", size: "29x29", scale: "2x", pixels: 58),
    .init(idiom: "iphone", size: "29x29", scale: "3x", pixels: 87),
    .init(idiom: "iphone", size: "40x40", scale: "2x", pixels: 80),
    .init(idiom: "iphone", size: "40x40", scale: "3x", pixels: 120),
    .init(idiom: "iphone", size: "60x60", scale: "2x", pixels: 120),
    .init(idiom: "iphone", size: "60x60", scale: "3x", pixels: 180),
    .init(idiom: "ipad", size: "20x20", scale: "1x", pixels: 20),
    .init(idiom: "ipad", size: "20x20", scale: "2x", pixels: 40),
    .init(idiom: "ipad", size: "29x29", scale: "1x", pixels: 29),
    .init(idiom: "ipad", size: "29x29", scale: "2x", pixels: 58),
    .init(idiom: "ipad", size: "40x40", scale: "1x", pixels: 40),
    .init(idiom: "ipad", size: "40x40", scale: "2x", pixels: 80),
    .init(idiom: "ipad", size: "76x76", scale: "1x", pixels: 76),
    .init(idiom: "ipad", size: "76x76", scale: "2x", pixels: 152),
    .init(idiom: "ipad", size: "83.5x83.5", scale: "2x", pixels: 167),
    .init(idiom: "ios-marketing", size: "1024x1024", scale: "1x", pixels: 1024)
]

func color(_ hex: UInt32) -> NSColor {
    NSColor(
        red: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: 1
    )
}

func drawIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let scale = CGFloat(size) / 1024
    func r(_ value: CGFloat) -> CGFloat { value * scale }
    let rect = NSRect(x: 0, y: 0, width: size, height: size)

    let gradient = NSGradient(colors: [
        color(0xF7FBFF),
        color(0xE9F3FA),
        color(0xDCECF5)
    ])!
    gradient.draw(in: rect, angle: 135)

    let outerSeal = NSBezierPath(ovalIn: NSRect(x: r(96), y: r(96), width: r(832), height: r(832)))
    color(0x17466B).withAlphaComponent(0.08).setFill()
    outerSeal.fill()
    color(0x17466B).withAlphaComponent(0.18).setStroke()
    outerSeal.lineWidth = r(12)
    outerSeal.stroke()

    let innerSeal = NSBezierPath(ovalIn: NSRect(x: r(160), y: r(160), width: r(704), height: r(704)))
    color(0xFFFFFF).withAlphaComponent(0.66).setFill()
    innerSeal.fill()

    let documentShadow = roundedRect(x: r(290), y: r(220), width: r(456), height: r(592), radius: r(44))
    color(0x17466B).withAlphaComponent(0.14).setFill()
    documentShadow.fill()

    let document = roundedRect(x: r(272), y: r(244), width: r(456), height: r(592), radius: r(44))
    color(0xFFFFFF).setFill()
    document.fill()
    color(0xB9CEDB).withAlphaComponent(0.85).setStroke()
    document.lineWidth = r(8)
    document.stroke()

    let folded = NSBezierPath()
    folded.move(to: NSPoint(x: r(646), y: r(820)))
    folded.line(to: NSPoint(x: r(730), y: r(736)))
    folded.line(to: NSPoint(x: r(646), y: r(736)))
    folded.close()
    color(0xE2EDF4).setFill()
    folded.fill()

    color(0x17466B).withAlphaComponent(0.25).setStroke()
    for y in [660, 596, 532] as [CGFloat] {
        let line = NSBezierPath()
        line.move(to: NSPoint(x: r(352), y: r(y)))
        line.line(to: NSPoint(x: r(654), y: r(y)))
        line.lineWidth = r(18)
        line.lineCapStyle = .round
        line.stroke()
    }

    let shield = NSBezierPath()
    shield.move(to: NSPoint(x: r(512), y: r(604)))
    shield.curve(to: NSPoint(x: r(684), y: r(538)), controlPoint1: NSPoint(x: r(584), y: r(594)), controlPoint2: NSPoint(x: r(646), y: r(570)))
    shield.curve(to: NSPoint(x: r(512), y: r(296)), controlPoint1: NSPoint(x: r(678), y: r(420)), controlPoint2: NSPoint(x: r(622), y: r(336)))
    shield.curve(to: NSPoint(x: r(340), y: r(538)), controlPoint1: NSPoint(x: r(402), y: r(336)), controlPoint2: NSPoint(x: r(346), y: r(420)))
    shield.curve(to: NSPoint(x: r(512), y: r(604)), controlPoint1: NSPoint(x: r(378), y: r(570)), controlPoint2: NSPoint(x: r(440), y: r(594)))
    shield.close()

    let shieldGradient = NSGradient(colors: [color(0x1E5B84), color(0x123E66)])!
    shieldGradient.draw(in: shield, angle: 90)
    color(0xFFFFFF).withAlphaComponent(0.72).setStroke()
    shield.lineWidth = r(12)
    shield.stroke()

    let shackle = NSBezierPath()
    shackle.appendArc(withCenter: NSPoint(x: r(512), y: r(478)), radius: r(72), startAngle: 0, endAngle: 180, clockwise: false)
    color(0xB9F6E6).setStroke()
    shackle.lineWidth = r(38)
    shackle.lineCapStyle = .round
    shackle.stroke()

    let lockBody = roundedRect(x: r(420), y: r(358), width: r(184), height: r(132), radius: r(28))
    color(0xB9F6E6).setFill()
    lockBody.fill()

    color(0x123E66).setFill()
    NSBezierPath(ovalIn: NSRect(x: r(493), y: r(408), width: r(38), height: r(38))).fill()
    let keySlot = roundedRect(x: r(502), y: r(378), width: r(20), height: r(48), radius: r(10))
    keySlot.fill()

    let star = NSBezierPath()
    star.move(to: NSPoint(x: r(512), y: r(716)))
    star.line(to: NSPoint(x: r(532), y: r(672)))
    star.line(to: NSPoint(x: r(580), y: r(666)))
    star.line(to: NSPoint(x: r(544), y: r(634)))
    star.line(to: NSPoint(x: r(554), y: r(586)))
    star.line(to: NSPoint(x: r(512), y: r(610)))
    star.line(to: NSPoint(x: r(470), y: r(586)))
    star.line(to: NSPoint(x: r(480), y: r(634)))
    star.line(to: NSPoint(x: r(444), y: r(666)))
    star.line(to: NSPoint(x: r(492), y: r(672)))
    star.close()
    color(0x0B7568).withAlphaComponent(0.95).setFill()
    star.fill()

    return image
}

func roundedRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: width, height: height), xRadius: radius, yRadius: radius)
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "Icon", code: 1)
    }
    try png.write(to: url)
}

var imagesJSON: [[String: String]] = []
for item in sizes {
    let fileName = "Icon-\(item.pixels).png"
    let url = appIconURL.appendingPathComponent(fileName)
    try writePNG(drawIcon(size: item.pixels), to: url)
    try resizePNG(at: url, pixels: item.pixels)
    imagesJSON.append([
        "idiom": item.idiom,
        "size": item.size,
        "scale": item.scale,
        "filename": fileName
    ])
}

let contents: [String: Any] = [
    "images": imagesJSON,
    "info": [
        "author": "xcode",
        "version": 1
    ]
]

let data = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try data.write(to: appIconURL.appendingPathComponent("Contents.json"))

let previewURL = root.appendingPathComponent("PrivateReceiptVault/AppIcon-Preview-1024.png")
try writePNG(drawIcon(size: 1024), to: previewURL)
try resizePNG(at: previewURL, pixels: 1024)
print(previewURL.path)

func resizePNG(at url: URL, pixels: Int) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    process.arguments = ["-z", "\(pixels)", "\(pixels)", url.path]
    process.standardOutput = Pipe()
    process.standardError = Pipe()
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw NSError(domain: "IconResize", code: Int(process.terminationStatus))
    }
}
