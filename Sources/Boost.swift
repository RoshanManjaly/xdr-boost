// XDR boost engine: lifts SDR content on the built-in XDR panel into EDR headroom.
// Public APIs only. Mechanism:
//   1. A 2x2 EDR Metal window makes macOS open HDR headroom on the panel.
//   2. The gamma table is scaled by up to that headroom so SDR pixels use it.
import AppKit
import QuartzCore

final class Boost {
    /// Stock SDR cap of the built-in XDR preset (PresetMaxSDRLuminance).
    static let sdrMaxNits = 500.0
    /// Panel HDR peak (PresetMaxHDRLuminance).
    static let peakNits = 1600.0

    private(set) var isOn = false
    /// Brightness that the top of the system slider maps to, 500...1600 nits.
    /// The boost is a fixed ratio, so auto-brightness keeps working across 0...topNits.
    var topNits: Double = peakNits { didSet { if isOn { applyGamma() } } }

    private var window: NSWindow?
    private var baseTable: (r: [CGGammaValue], g: [CGGammaValue], b: [CGGammaValue])?
    private(set) var appliedFactor: Float = 1
    private var timer: Timer?

    var screen: NSScreen? {
        NSScreen.screens.first { CGDisplayIsBuiltin(Self.displayID(of: $0)) != 0 }
    }

    var headroom: CGFloat { screen?.maximumExtendedDynamicRangeColorComponentValue ?? 1 }

    static func displayID(of screen: NSScreen) -> CGDirectDisplayID {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    }

    func enable() {
        guard !isOn, let screen else { return }
        isOn = true
        CGDisplayRestoreColorSyncSettings()
        baseTable = readTable(Self.displayID(of: screen))
        showTrigger(on: screen)
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
    }

    func disable() {
        guard isOn else { return }
        isOn = false
        timer?.invalidate()
        timer = nil
        CGDisplayRestoreColorSyncSettings()
        window?.orderOut(nil)
        window = nil
        appliedFactor = 1
    }

    /// Re-run after wake or a display change: the system may drop the window or reset gamma.
    func refresh() {
        guard isOn else { return }
        disable()
        enable()
    }

    private func tick() {
        guard isOn, let screen else { return }
        let target = targetFactor()
        let current = readTable(Self.displayID(of: screen)).r.max() ?? 1
        // Re-apply when headroom moved (ambient light) or something reset the gamma.
        if abs(target - appliedFactor) > 0.02 || abs(current - appliedFactor * (baseTable?.r.max() ?? 1)) > 0.05 {
            applyGamma()
        }
    }

    /// Ratio topNits / 500, capped by the headroom macOS grants right now.
    var linearFactor: Double {
        let ratio = max(topNits, Self.sdrMaxNits) / Self.sdrMaxNits
        return min(ratio, max(Double(headroom), 1))
    }

    private func targetFactor() -> Float { Float(linearFactor) }

    private func applyGamma() {
        guard let screen, let base = baseTable else { return }
        let f = targetFactor()
        let n = UInt32(base.r.count)
        let err = CGSetDisplayTransferByTable(Self.displayID(of: screen), n,
                                              base.r.map { $0 * f }, base.g.map { $0 * f }, base.b.map { $0 * f })
        if err == .success { appliedFactor = f }
        print("applied gamma x\(String(format: "%.2f", f)) (top \(Int(topNits)) nits, headroom \(headroom)) err=\(err.rawValue)")
        fflush(stdout)
    }

    private func readTable(_ id: CGDirectDisplayID) -> (r: [CGGammaValue], g: [CGGammaValue], b: [CGGammaValue]) {
        let cap: UInt32 = 1024
        var r = [CGGammaValue](repeating: 0, count: Int(cap)), g = r, b = r
        var count: UInt32 = 0
        CGGetDisplayTransferByTable(id, cap, &r, &g, &b, &count)
        let c = Int(count)
        return (Array(r[0..<c]), Array(g[0..<c]), Array(b[0..<c]))
    }

    private func showTrigger(on screen: NSScreen) {
        let potential = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
        let f = screen.frame
        let w = NSWindow(contentRect: NSRect(x: f.minX, y: f.minY, width: 2, height: 2),
                         styleMask: .borderless, backing: .buffered, defer: false, screen: screen)
        w.level = .statusBar
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        w.sharingType = .none
        w.ignoresMouseEvents = true
        w.backgroundColor = .clear
        w.isOpaque = false
        w.hasShadow = false
        w.isReleasedWhenClosed = false
        w.contentView?.wantsLayer = true
        w.contentView?.layer = Self.edrLayer(headroom: potential)
        w.orderFrontRegardless()
        window = w
    }

    private static func edrLayer(headroom: CGFloat) -> CALayer {
        let space = CGColorSpace(name: CGColorSpace.extendedLinearITUR_2020)!
        let layer = CAMetalLayer()
        layer.wantsExtendedDynamicRangeContent = true
        layer.pixelFormat = .rgba16Float
        layer.colorspace = space
        layer.edrMetadata = CAEDRMetadata.hdr10(minLuminance: 0.5, maxLuminance: Float(headroom * 100),
                                                opticalOutputScale: 100)
        layer.backgroundColor = CGColor(colorSpace: space, components: [headroom, headroom, headroom, 1])
        layer.opacity = 0.1
        return layer
    }
}
