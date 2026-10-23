import AppKit
import Cocoa
import FlutterMacOS

/// Menu bar icon of the regular MeowClash window.
///
/// Left click shows or hides the window, right click opens a small menu.
/// Showing and hiding go through Dart (`status_bar_icon` channel,
/// `lib/common/statusbar.dart`) so render suspension, the Dock icon and the UI
/// lifecycle follow the same path as the tray on Windows/Linux. When Dart does
/// not answer (an older Dart bundle during development) the window is toggled
/// natively instead.
class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private weak var window: NSWindow?
    private let channel: FlutterMethodChannel
    private let contextMenu = NSMenu()

    init(window: NSWindow?, channel: FlutterMethodChannel) {
        self.window = window
        self.channel = channel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = StatusBarController.icon(isVpnConnected: false)
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        } else {
            NSLog("StatusBarController: ERROR - Could not get status bar button!")
        }

        setupContextMenu()
    }

    private func setupContextMenu() {
        let showItem = NSMenuItem(
            title: "Show MeowClash",
            action: #selector(showWindowFromMenu),
            keyEquivalent: ""
        )
        showItem.target = self
        contextMenu.addItem(showItem)
        contextMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit MeowClash",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        contextMenu.addItem(quitItem)
    }

    @objc func statusItemClicked(_ sender: AnyObject?) {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showContextMenu()
            return
        }
        toggleWindow()
    }

    /// Frontmost means the user is looking at the window right now: visible,
    /// not in the Dock and the app is active. A window hidden behind other
    /// apps is brought forward instead of being hidden.
    var isWindowFrontmost: Bool {
        guard let window = window else { return false }
        return window.isVisible && !window.isMiniaturized && NSApp.isActive
    }

    var isWindowVisible: Bool {
        guard let window = window else { return false }
        return window.isVisible && !window.isMiniaturized
    }

    func toggleWindow() {
        if isWindowFrontmost {
            hideWindow()
        } else {
            showWindow()
        }
    }

    func showWindow() {
        request("showWindow") { [weak self] in self?.showWindowNatively() }
    }

    func hideWindow() {
        request("hideWindow") { [weak self] in self?.hideWindowNatively() }
    }

    private func request(_ method: String, fallback: @escaping () -> Void) {
        channel.invokeMethod(method, arguments: nil) { result in
            let unanswered = (result as AnyObject?) === FlutterMethodNotImplemented
            if unanswered || result is FlutterError {
                fallback()
            }
        }
    }

    private func showWindowNatively() {
        guard let window = window else { return }
        NSApp.setActivationPolicy(.regular)
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        channel.invokeMethod("visibilityChanged", arguments: true)
    }

    private func hideWindowNatively() {
        window?.orderOut(nil)
        channel.invokeMethod("visibilityChanged", arguments: false)
    }

    private func showContextMenu() {
        guard let button = statusItem.button else { return }
        statusItem.menu = contextMenu
        button.performClick(nil)
        // Keep left click as a toggle: the menu is attached only for this click.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.statusItem.menu = nil
        }
    }

    @objc func showWindowFromMenu() {
        showWindow()
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func updateIcon(isVpnConnected: Bool) {
        statusItem.button?.image = StatusBarController.icon(isVpnConnected: isVpnConnected)
    }

    private static func icon(isVpnConnected: Bool) -> NSImage? {
        let name = isVpnConnected ? "checkmark.rectangle.fill" : "xmark.rectangle"
        guard let icon = NSImage(systemSymbolName: name, accessibilityDescription: "MeowClash") else {
            return nil
        }
        let image = icon.withSymbolConfiguration(NSImage.SymbolConfiguration(scale: .large))
        image?.isTemplate = true
        return image
    }
}
