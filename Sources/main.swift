// XDR Boost: menu-bar toggle for the built-in XDR panel's extra brightness.
import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let boost = Boost()
    private let power = PowerWatch()
    private var item: NSStatusItem!
    private let toggleItem = NSMenuItem(title: "Boost brightness", action: #selector(toggle), keyEquivalent: "b")
    private let sliderLabel = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let slider = NSSlider(value: Boost.peakNits, minValue: Boost.sdrMaxNits, maxValue: Boost.peakNits,
                                  target: nil, action: nil)
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Open at login", action: #selector(toggleLogin), keyEquivalent: "")
    private var autoOffReason: String?

    func applicationDidFinishLaunching(_ note: Notification) {
        let saved = UserDefaults.standard.double(forKey: "topNits")
        let top = saved >= Boost.sdrMaxNits ? saved : Boost.defaultNits
        slider.doubleValue = top
        boost.topNits = top
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.menu = buildMenu()
        observeSystem()
        power.onEnterLow = { [weak self] in self?.autoOff() }
        power.start()
        applyLoginDefault()
        if CommandLine.arguments.contains("--on") { setOn(true) }
        updateUI()
    }

    func applicationWillTerminate(_ note: Notification) { boost.disable() }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(sliderLabel)
        slider.target = self
        slider.action = #selector(sliderChanged)
        slider.isContinuous = true
        slider.numberOfTickMarks = 12
        slider.allowsTickMarkValuesOnly = false
        slider.frame = NSRect(x: 18, y: 4, width: 200, height: 22)
        let holder = NSView(frame: NSRect(x: 0, y: 0, width: 236, height: 30))
        holder.addSubview(slider)
        let sliderItem = NSMenuItem()
        sliderItem.view = holder
        menu.addItem(sliderItem)
        menu.addItem(statusLine)
        menu.addItem(.separator())
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem(title: "Quit XDR Boost", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    private func observeSystem() {
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil,
                                                          queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self?.boost.refresh() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.boost.refresh()
            self?.updateUI()
        }
    }

    private func setOn(_ on: Bool) {
        on ? boost.enable() : boost.disable()
        if on { autoOffReason = nil }
        updateUI()
    }

    private func autoOff() {
        guard boost.isOn else { return }
        autoOffReason = power.reason
        boost.disable()
        updateUI()
    }

    @objc private func toggle() { setOn(!boost.isOn) }

    /// Open at login is on by default: register once on first launch, then respect the menu toggle.
    private func applyLoginDefault() {
        let key = "loginDefaultApplied"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        try? SMAppService.mainApp.register()
    }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            NSLog("XDR Boost: login item change failed: \(error.localizedDescription)")
        }
        if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        updateUI()
    }

    @objc private func sliderChanged() {
        slider.doubleValue = (slider.doubleValue / 10).rounded() * 10
        boost.topNits = slider.doubleValue
        UserDefaults.standard.set(slider.doubleValue, forKey: "topNits")
        updateUI()
    }

    private func updateUI() {
        let symbol = boost.isOn ? "sun.max.fill" : "sun.max"
        item.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "XDR Boost")
        toggleItem.state = boost.isOn ? .on : .off
        toggleItem.isEnabled = boost.screen != nil
        sliderLabel.title = "Max brightness: \(Int(slider.doubleValue)) nits"
        statusLine.title = statusText()
        let login = SMAppService.mainApp.status
        loginItem.state = login == .enabled ? .on : .off
        loginItem.title = login == .requiresApproval ? "Open at login (approve in System Settings)" : "Open at login"
    }

    private func statusText() -> String {
        if boost.screen == nil { return "No built-in XDR display" }
        if boost.isOn {
            let light = pow(Double(boost.appliedFactor), Boost.panelGamma)
            return "On, 0 to \(Int(slider.doubleValue)) nits (light x\(String(format: "%.1f", light)))"
        }
        if let r = autoOffReason { return "Turned off automatically (\(r))" }
        return "Off"
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) { updateUI() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
signal(SIGTERM) { _ in CGDisplayRestoreColorSyncSettings(); exit(0) }
signal(SIGINT) { _ in CGDisplayRestoreColorSyncSettings(); exit(0) }
app.run()
