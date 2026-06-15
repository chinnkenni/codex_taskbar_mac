import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("Usage: generate-icon <output-png>\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: arguments[1])
let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()

let rect = CGRect(origin: .zero, size: size)
NSColor(red: 0.06, green: 0.08, blue: 0.11, alpha: 1).setFill()
rect.fill()

let base = NSBezierPath(roundedRect: rect.insetBy(dx: 96, dy: 96), xRadius: 210, yRadius: 210)
NSColor(red: 0.09, green: 0.11, blue: 0.14, alpha: 1).setFill()
base.fill()

let ringRect = CGRect(x: 246, y: 246, width: 532, height: 532)
let ring = NSBezierPath(ovalIn: ringRect)
ring.lineWidth = 44
NSColor(red: 0.20, green: 0.25, blue: 0.31, alpha: 1).setStroke()
ring.stroke()

let arc = NSBezierPath()
arc.appendArc(
    withCenter: CGPoint(x: ringRect.midX, y: ringRect.midY),
    radius: 266,
    startAngle: 125,
    endAngle: 398,
    clockwise: false
)
arc.lineWidth = 52
arc.lineCapStyle = .round
NSColor(red: 0.16, green: 0.57, blue: 0.96, alpha: 1).setStroke()
arc.stroke()

let dot = NSBezierPath(ovalIn: CGRect(x: 704, y: 650, width: 82, height: 82))
NSColor(red: 0.22, green: 0.86, blue: 0.62, alpha: 1).setFill()
dot.fill()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 278, weight: .semibold),
    .foregroundColor: NSColor(red: 0.92, green: 0.96, blue: 1.0, alpha: 1),
    .paragraphStyle: paragraph
]
let letterRect = CGRect(x: 0, y: 330, width: 1024, height: 340)
"C".draw(in: letterRect, withAttributes: attributes)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Could not render icon PNG\n", stderr)
    exit(1)
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: outputURL)
