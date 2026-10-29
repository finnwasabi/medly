// Draws the 1024x1024 app icon in the app's neubrutalist style: a cream background, a hard ink shadow and a tilted
// capsule with a pink and a yellow half, outlined in ink.
// Usage: swift scripts/make-icon.swift <out.png>
import AppKit

let args = CommandLine.arguments
let out = args.count > 1 ? args[1] : "icon.png"
let size: CGFloat = 1024

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

let ink = color(0x161616)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Background: flat mint; iOS rounds the corners.
color(0x7CE3B8).setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

// The capsule, tilted 45 degrees the other way so the shadow falls along its side.
ctx.translateBy(x: size / 2, y: size / 2)
ctx.rotate(by: -.pi / 4)
let w: CGFloat = 320, h: CGFloat = 660, line: CGFloat = 30, depth: CGFloat = 44
let rect = NSRect(x: -w / 2, y: -h / 2, width: w, height: h)
let capsule = NSBezierPath(roundedRect: rect, xRadius: w / 2, yRadius: w / 2)

// The hard shadow: the same capsule in ink, offset down and right on the screen (rotated back into capsule space).
NSGraphicsContext.saveGraphicsState()
let offset = CGPoint(x: depth, y: -depth).applying(CGAffineTransform(rotationAngle: .pi / 4))
ctx.translateBy(x: offset.x, y: offset.y)
ink.setFill()
capsule.fill()
NSGraphicsContext.restoreGraphicsState()

// Pink upper half, yellow lower half.
NSGraphicsContext.saveGraphicsState()
capsule.addClip()
color(0xFF8FC0).setFill()
rect.fill()
color(0xFFD84D).setFill()
NSRect(x: -w / 2, y: -h / 2, width: w, height: h / 2).fill()
// The seam.
ink.setFill()
NSRect(x: -w / 2, y: -line / 2, width: w, height: line).fill()
NSGraphicsContext.restoreGraphicsState()

// Outline.
capsule.lineWidth = line
ink.setStroke()
capsule.stroke()

// A white highlight on the pink half.
let shine = NSBezierPath(roundedRect: NSRect(x: -w / 2 + 70, y: 70, width: 50, height: 170), xRadius: 25, yRadius: 25)
NSColor.white.setFill()
shine.fill()

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print(out)
