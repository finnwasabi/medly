// Draws the 1024x1024 app icon: the app's rose background and a tilted white capsule with a light pink half.
// Usage: swift scripts/make-icon.swift <out.png>
import AppKit

let args = CommandLine.arguments
let out = args.count > 1 ? args[1] : "icon.png"
let size: CGFloat = 1024

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Background: a soft rose gradient; iOS rounds the corners.
let gradient = NSGradient(starting: color(0xD9566F), ending: color(0xB8384F))!
gradient.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -90)

// The capsule, tilted 45 degrees, centered.
ctx.translateBy(x: size / 2, y: size / 2)
ctx.rotate(by: .pi / 4)
let w: CGFloat = 300, h: CGFloat = 640
let capsule = NSBezierPath(roundedRect: NSRect(x: -w / 2, y: -h / 2, width: w, height: h), xRadius: w / 2, yRadius: w / 2)

// A soft shadow lifts the capsule off the background.
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
shadow.shadowBlurRadius = 40
shadow.shadowOffset = NSSize(width: 0, height: -18)
shadow.set()
color(0xFFFFFF).setFill()
capsule.fill()
NSGraphicsContext.restoreGraphicsState()

// The lower half in light pink, clipped to the capsule.
NSGraphicsContext.saveGraphicsState()
capsule.addClip()
color(0xFBE6EA).setFill()
NSRect(x: -w / 2, y: -h / 2, width: w, height: h / 2).fill()
// The seam between the halves.
color(0xEFC3CC).setFill()
NSRect(x: -w / 2, y: -6, width: w, height: 12).fill()
NSGraphicsContext.restoreGraphicsState()

// A highlight on the white half.
let shine = NSBezierPath(roundedRect: NSRect(x: -w / 2 + 62, y: 60, width: 46, height: 190), xRadius: 23, yRadius: 23)
color(0xFBE6EA).withAlphaComponent(0.9).setFill()
shine.fill()

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print(out)
