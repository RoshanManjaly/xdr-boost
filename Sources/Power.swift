// Watches Low Power Mode and battery level. Fires `onEnterLow` once per transition into the low
// state, so a manual re-enable from the menu is not undone until power recovers and drops again.
import Foundation
import IOKit.ps

final class PowerWatch {
    static let batteryThreshold = 20

    var onEnterLow: (() -> Void)?
    private(set) var isLow = false
    private var timer: Timer?

    func start() {
        NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil,
                                               queue: .main) { [weak self] _ in self?.check() }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.check() }
        check()
    }

    var reason: String? {
        if ProcessInfo.processInfo.isLowPowerModeEnabled { return "Low Power Mode" }
        if let b = Self.battery(), b.onBattery, b.percent <= Self.batteryThreshold { return "battery \(b.percent)%" }
        return nil
    }

    private func check() {
        let low = reason != nil
        if low && !isLow { onEnterLow?() }
        isLow = low
    }

    static func battery() -> (percent: Int, onBattery: Bool)? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for src in list {
            guard let d = IOPSGetPowerSourceDescription(info, src)?.takeUnretainedValue() as? [String: Any],
                  d[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let cur = d[kIOPSCurrentCapacityKey] as? Int, let max = d[kIOPSMaxCapacityKey] as? Int, max > 0
            else { continue }
            let onBattery = d[kIOPSPowerSourceStateKey] as? String == kIOPSBatteryPowerValue
            return (cur * 100 / max, onBattery)
        }
        return nil
    }
}
