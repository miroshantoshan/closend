import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func savePNG(size: NSSize, url: URL, draw: () -> Void) throws {
    let image = NSImage(size: size)
    image.lockFocus()
    draw()
    image.unlockFocus()
    guard let data = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: data),
          let png = bitmap.representation(using: .png, properties: [:]) else { return }
    try png.write(to: url)
}

try savePNG(size: NSSize(width: 1024, height: 1024), url: output.appendingPathComponent("icon-1024.png")) {
    let outer = NSBezierPath(roundedRect: NSRect(x: 82, y: 82, width: 860, height: 860), xRadius: 210, yRadius: 210)
    NSGradient(colors: [NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.34, alpha: 1),
                        NSColor(calibratedRed: 0.055, green: 0.075, blue: 0.15, alpha: 1)])!.draw(in: outer, angle: -55)

    let window = NSBezierPath(roundedRect: NSRect(x: 220, y: 274, width: 584, height: 476), xRadius: 76, yRadius: 76)
    window.lineWidth = 42
    NSColor.white.withAlphaComponent(0.96).setStroke()
    window.stroke()

    let titleBar = NSBezierPath()
    titleBar.lineWidth = 34
    titleBar.lineCapStyle = .round
    titleBar.move(to: NSPoint(x: 248, y: 626))
    titleBar.line(to: NSPoint(x: 776, y: 626))
    titleBar.stroke()

    NSColor(calibratedRed: 1.0, green: 0.34, blue: 0.28, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 278, y: 664, width: 54, height: 54), xRadius: 14, yRadius: 14).fill()

    let arrow = NSBezierPath()
    arrow.lineWidth = 54
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.move(to: NSPoint(x: 362, y: 446))
    arrow.line(to: NSPoint(x: 632, y: 446))
    arrow.move(to: NSPoint(x: 548, y: 532))
    arrow.line(to: NSPoint(x: 642, y: 446))
    arrow.line(to: NSPoint(x: 548, y: 360))
    NSColor(calibratedRed: 0.32, green: 0.86, blue: 0.82, alpha: 1).setStroke()
    arrow.stroke()

    let speedLine = NSBezierPath()
    speedLine.lineWidth = 32
    speedLine.lineCapStyle = .round
    speedLine.move(to: NSPoint(x: 310, y: 532))
    speedLine.line(to: NSPoint(x: 438, y: 532))
    speedLine.move(to: NSPoint(x: 310, y: 360))
    speedLine.line(to: NSPoint(x: 438, y: 360))
    NSColor.white.withAlphaComponent(0.55).setStroke()
    speedLine.stroke()
}
