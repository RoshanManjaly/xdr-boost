// Photometer test: full-screen black/white steps with gamma factors, EDR trigger on throughout.
// usage: lumtest <hold_s> <spec>...   spec = "b" (black) or "w:<factor>" (white x factor)
// Prints "epoch_ms step spec factor edr" at each step start.
import AppKit
import QuartzCore

func log(_ s: String) { print(s); fflush(stdout) }
func nowMs() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
let screen = NSScreen.screens.first {
    CGDisplayIsBuiltin($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID) != 0
}!
let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
let hold = Double(CommandLine.arguments[1]) ?? 5
let specs = Array(CommandLine.arguments.dropFirst(2))

typealias GetB = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
let ds = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
func sdrBrightness() -> Float {
    guard let p = dlsym(ds, "DisplayServicesGetBrightness") else { return -1 }
    var b: Float = -1
    _ = unsafeBitCast(p, to: GetB.self)(displayID, &b)
    return b
}
typealias SetB = @convention(c) (CGDirectDisplayID, Float) -> Int32
func setSdr(_ v: Float) {
    guard let p = dlsym(ds, "DisplayServicesSetBrightness") else { return }
    _ = unsafeBitCast(p, to: SetB.self)(displayID, v)
}
let originalSdr = sdrBrightness()
let patch = NSView(frame: NSRect(x: screen.frame.width / 4, y: screen.frame.height / 4,
                                 width: screen.frame.width / 2, height: screen.frame.height / 2))

func table() -> ([CGGammaValue], [CGGammaValue], [CGGammaValue]) {
    var r = [CGGammaValue](repeating: 0, count: 256), g = r, b = r
    var n: UInt32 = 0
    CGGetDisplayTransferByTable(displayID, 256, &r, &g, &b, &n)
    return (Array(r[0..<Int(n)]), Array(g[0..<Int(n)]), Array(b[0..<Int(n)]))
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
CGDisplayRestoreColorSyncSettings()
let base = table()

let win = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false, screen: screen)
win.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 2)
win.backgroundColor = .black
win.ignoresMouseEvents = true
win.collectionBehavior = [.canJoinAllSpaces, .stationary]
patch.wantsLayer = true
patch.layer?.backgroundColor = NSColor.white.cgColor
patch.isHidden = true
win.contentView?.addSubview(patch)
// Native HDR patch: an EDR Metal layer filled with an over-white value, as an HDR video would draw.
let hdrView = NSView(frame: .zero)
let hdrLayer = CAMetalLayer()
hdrLayer.wantsExtendedDynamicRangeContent = true
hdrLayer.pixelFormat = .rgba16Float
hdrLayer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
hdrView.wantsLayer = true
hdrView.layer = hdrLayer
hdrView.isHidden = true
win.contentView?.addSubview(hdrView)
func centered(_ area: Double) -> NSRect {
    let s = sqrt(area), W = screen.frame.width, H = screen.frame.height
    return NSRect(x: W * (1 - s) / 2, y: H * (1 - s) / 2, width: W * s, height: H * s)
}
win.orderFrontRegardless()

let h = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
let trig = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 2, height: 2), styleMask: .borderless,
                    backing: .buffered, defer: false, screen: screen)
trig.level = .screenSaver
trig.backgroundColor = .clear
trig.isOpaque = false
trig.ignoresMouseEvents = true
let space = CGColorSpace(name: CGColorSpace.extendedLinearITUR_2020)!
let layer = CAMetalLayer()
layer.wantsExtendedDynamicRangeContent = true
layer.pixelFormat = .rgba16Float
layer.colorspace = space
layer.edrMetadata = CAEDRMetadata.hdr10(minLuminance: 0.5, maxLuminance: Float(h * 100), opticalOutputScale: 100)
layer.backgroundColor = CGColor(colorSpace: space, components: [h, h, h, 1])
layer.opacity = 0.1
trig.contentView?.wantsLayer = true
trig.contentView?.layer = layer
trig.orderFrontRegardless()

let noGamma = ProcessInfo.processInfo.environment["NOGAMMA"] != nil
func apply(_ f: Float) {
    if noGamma { return }
    if f == 1 { CGDisplayRestoreColorSyncSettings(); return }
    CGSetDisplayTransferByTable(displayID, UInt32(base.0.count), base.0.map { $0 * f }, base.1.map { $0 * f }, base.2.map { $0 * f })
}

let start = 3.0
// Each step schedules the next one: deadlines far ahead get coalesced by GCD and fire in pairs.
func runStep(_ i: Int) {
    guard i < specs.count else { finish(); return }
    let spec = specs[i]
    DispatchQueue.main.asyncAfter(deadline: .now() + hold) { runStep(i + 1) }
    do {
        if spec.hasPrefix("s:") {
            setSdr(Float(spec.dropFirst(2)) ?? originalSdr)
            log("\(nowMs()) \(i) s 1 set sdr \(sdrBrightness())")
        } else if spec.hasPrefix("h:") {
            // h:<area>  native HDR white at the current headroom, gamma untouched
            let area = Double(spec.dropFirst(2)) ?? 0.25
            let v = screen.maximumExtendedDynamicRangeColorComponentValue
            win.backgroundColor = .black
            patch.isHidden = true
            apply(1)
            hdrView.frame = centered(area)
            hdrLayer.backgroundColor = CGColor(colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!, components: [v, v, v, 1])
            hdrView.isHidden = false
            log("\(nowMs()) \(i) h \(area) edr \(v)")
        } else if spec.hasPrefix("q:") {
            // q:<factor>:<area>  SDR white patch of the given area, gamma x factor
            let parts = spec.split(separator: ":")
            let f = Float(parts[1]) ?? 1, area = Double(parts[2]) ?? 0.25
            win.backgroundColor = .black
            hdrView.isHidden = true
            patch.frame = centered(area)
            patch.isHidden = false
            apply(f)
            log("\(nowMs()) \(i) q \(f) area \(area) edr \(screen.maximumExtendedDynamicRangeColorComponentValue) readback \(table().0.max() ?? 0)")
        } else if spec == "b" {
            win.backgroundColor = .black
            patch.isHidden = true
            hdrView.isHidden = true
            apply(1)
            log("\(nowMs()) \(i) b 1 \(screen.maximumExtendedDynamicRangeColorComponentValue) sdr \(sdrBrightness())")
        } else {
            let f = Float(spec.split(separator: ":").last ?? "1") ?? 1
            let isPatch = spec.hasPrefix("p:")
            win.backgroundColor = isPatch ? .black : .white
            patch.isHidden = !isPatch
            apply(f)
            log("\(nowMs()) \(i) \(isPatch ? "p" : "w") \(f) \(screen.maximumExtendedDynamicRangeColorComponentValue) readback \(table().0.max() ?? 0)")
        }
    }
}
func finish() {
    if !noGamma { CGDisplayRestoreColorSyncSettings() }
    setSdr(originalSdr)
    win.orderOut(nil); trig.orderOut(nil)
    log("\(nowMs()) end restored sdr \(sdrBrightness())")
    exit(0)
}
signal(SIGINT) { _ in CGDisplayRestoreColorSyncSettings(); exit(130) }
signal(SIGTERM) { _ in CGDisplayRestoreColorSyncSettings(); exit(143) }
log("\(nowMs()) start edr-potential \(h) sdr \(sdrBrightness())")
DispatchQueue.main.asyncAfter(deadline: .now() + start) { runStep(0) }
app.run()
