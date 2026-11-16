// Draws the XDR Boost app icon to a PNG. assets/make-icon.sh runs it at every size the .icns needs.
// usage: icon <out.png> <size in pixels>
import AppKit

let out = CommandLine.arguments[1]
let px = CGFloat(Double(CommandLine.arguments[2]) ?? 1024)
let s = px / 1024

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(px), pixelsHigh: Int(px), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// macOS icon grid: 824 pt rounded square centered in 1024, soft drop shadow.
let body = CGRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
let shape = NSBezierPath(roundedRect: body, xRadius: 185 * s, yRadius: 185 * s)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10 * s), blur: 28 * s, color: NSColor.black.withAlphaComponent(0.35).cgColor)
NSColor.black.setFill()
shape.fill()
ctx.restoreGState()

// Background: a dark display panel, slightly lighter toward the top.
ctx.saveGState()
shape.addClip()
let bg = NSGradient(colors: [NSColor(srgbRed: 0.10, green: 0.11, blue: 0.16, alpha: 1),
                             NSColor(srgbRed: 0.02, green: 0.02, blue: 0.04, alpha: 1)])!
bg.draw(in: body, angle: -90)

let center = CGPoint(x: 512 * s, y: 512 * s)
// Glow: the "extra" brightness spilling past the sun.
let glow = NSGradient(colors: [NSColor(srgbRed: 1.0, green: 0.86, blue: 0.45, alpha: 0.55),
                               NSColor(srgbRed: 1.0, green: 0.62, blue: 0.20, alpha: 0.18),
                               NSColor(srgbRed: 1.0, green: 0.50, blue: 0.10, alpha: 0.0)],
                      atLocations: [0, 0.45, 1], colorSpace: .sRGB)!
glow.draw(fromCenter: center, radius: 0, toCenter: center, radius: 400 * s, options: [])

// Rays: 12, alternating long and short.
for i in 0..<12 {
    let a = CGFloat(i) * .pi / 6
    let inner: CGFloat = 228 * s, outer: CGFloat = (i % 2 == 0 ? 340 : 300) * s
    let ray = NSBezierPath()
    ray.lineWidth = 34 * s
    ray.lineCapStyle = .round
    ray.move(to: CGPoint(x: center.x + cos(a) * inner, y: center.y + sin(a) * inner))
    ray.line(to: CGPoint(x: center.x + cos(a) * outer, y: center.y + sin(a) * outer))
    NSColor(srgbRed: 1.0, green: 0.84, blue: 0.40, alpha: 1).setStroke()
    ray.stroke()
}

// Core: white-hot center fading to warm yellow.
let coreRect = CGRect(x: center.x - 170 * s, y: center.y - 170 * s, width: 340 * s, height: 340 * s)
let core = NSGradient(colors: [NSColor.white, NSColor(srgbRed: 1.0, green: 0.93, blue: 0.62, alpha: 1),
                               NSColor(srgbRed: 1.0, green: 0.78, blue: 0.30, alpha: 1)],
                      atLocations: [0, 0.55, 1], colorSpace: .sRGB)!
core.draw(in: NSBezierPath(ovalIn: coreRect), relativeCenterPosition: NSPoint(x: -0.15, y: 0.2))
ctx.restoreGState()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
