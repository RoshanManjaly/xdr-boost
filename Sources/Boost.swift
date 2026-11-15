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
    /// Default top: (1130 / 500) ^ (1 / 2.32) = x1.42. Keeps large bright areas near the ~1,100-nit
    /// full-screen ceiling, so colors stay clean. The slider still goes to 1,600.
    static let defaultNits = 1130.0
    /// The tick loop ramps toward a new value within ~0.1 s per 0.02 of factor.
    var topNits: Double = defaultNits

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
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
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

    /// Largest factor change per 0.1 s tick: x1.0 -> x1.42 takes about 2 s. The slow ramp keeps colors
    /// from washing out while the panel's headroom catches up.
    static let rampStep: Float = 0.02

    private func tick() {
        guard isOn, let screen else { return }
        let target = targetFactor()
        let step = max(-Self.rampStep, min(Self.rampStep, target - appliedFactor))
        let current = readTable(Self.displayID(of: screen)).r.max() ?? 1
        // Ramp toward the target (it moves with headroom), and re-apply if something reset the gamma.
        if abs(step) > 0.001 {
            applyGamma(appliedFactor + step)
        } else if abs(current - appliedFactor * (baseTable?.r.max() ?? 1)) > 0.05 {
            applyGamma(appliedFactor)
        }
    }

    /// The gamma table holds encoded values: light gain = factor ^ 2.32. Measured 2026-11-15 with an
    /// ambient light sensor facing the panel: x1.30 -> 1.84x, x1.59 -> 2.92x, x2.00 -> 4.98x light.
    /// A 25% white patch at x1.65 with the slider at 100% measured 3.20x, about 1600 nits.
    static let panelGamma = 2.32

    /// Light ratio (topNits / 500), capped by the headroom macOS grants right now, so no channel clips.
    /// Scaling the table by the headroom itself (x3.2 = ~15x light) clipped and washed out color.
    var linearFactor: Double {
        let ratio = max(topNits, Self.sdrMaxNits) / Self.sdrMaxNits
        return min(ratio, max(Double(headroom), 1))
    }

    private func targetFactor() -> Float { Float(pow(linearFactor, 1 / Self.panelGamma)) }

    private func applyGamma(_ f: Float) {
        guard let screen, let base = baseTable else { return }
        let n = UInt32(base.r.count)
        let err = CGSetDisplayTransferByTable(Self.displayID(of: screen), n,
                                              base.r.map { $0 * f }, base.g.map { $0 * f }, base.b.map { $0 * f })
        if err == .success { appliedFactor = f }
        print("applied gamma x\(String(format: "%.2f", f)) (top \(Int(topNits)) nits, headroom \(headroom)) err=\(err.rawValue)")
        fflush(stdout)
    }

    /// 256 entries: writes built from a 1024-entry read were silently ignored in testing.
    private func readTable(_ id: CGDirectDisplayID) -> (r: [CGGammaValue], g: [CGGammaValue], b: [CGGammaValue]) {
        let cap: UInt32 = 256
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
