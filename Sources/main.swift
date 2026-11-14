// XDR Boost: menu-bar toggle for the built-in XDR panel's extra brightness.
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let boost = Boost()
    private var item: NSStatusItem!
    private let toggleItem = NSMenuItem(title: "Boost brightness", action: #selector(toggle), keyEquivalent: "b")
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    func applicationDidFinishLaunching(_ note: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.menu = buildMenu()
        observeSystem()
        if CommandLine.arguments.contains("--on") { setOn(true) }
        updateUI()
    }

    func applicationWillTerminate(_ note: Notification) { boost.disable() }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(statusLine)
        menu.addItem(.separator())
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
        updateUI()
    }

    @objc private func toggle() { setOn(!boost.isOn) }

    private func updateUI() {
        let symbol = boost.isOn ? "sun.max.fill" : "sun.max"
        item.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "XDR Boost")
        toggleItem.state = boost.isOn ? .on : .off
        toggleItem.isEnabled = boost.screen != nil
        statusLine.title = statusText()
    }

    private func statusText() -> String {
        if boost.screen == nil { return "No built-in XDR display" }
        if boost.isOn { return "On (gamma x\(String(format: "%.2f", boost.appliedFactor)))" }
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
