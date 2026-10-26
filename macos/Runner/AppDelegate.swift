import Cocoa
import FlutterMacOS
import window_ext
import LaunchAtLogin

@main
class AppDelegate: FlutterAppDelegate {
    var statusBarController: StatusBarController?
    private var statusBarChannel: FlutterMethodChannel?
    private var glassAccessibilityChannel: FlutterMethodChannel?
    private var contextMenuChannel: FlutterMethodChannel?
    private let contextMenuPresenter = ContextMenuPresenter()
    
    // MeowClash is a regular window app (Dock icon + app menu) with an extra
    // menu bar icon. The window starts hidden (`hiddenWindowAtLaunch`) and Dart
    // shows it unless silent launch is enabled (lib/controller.dart).
    override func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSLog("AppDelegate: applicationDidFinishLaunching called")
        
        setupCoreInApplicationSupport()
        
        guard let mainController = (mainFlutterWindow as? MainFlutterWindow)?.flutterViewController else {
            NSLog("ERROR: Could not get FlutterViewController from mainFlutterWindow")
            return
        }
        
        setupStatusBarChannel(flutterViewController: mainController)
        setupGlassAccessibilityChannel(flutterViewController: mainController)
        setupContextMenuChannel(flutterViewController: mainController)
        setupAppVisibilityObservers()
        
        super.applicationDidFinishLaunching(aNotification)
    }
    
    func setupStatusBarChannel(flutterViewController: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: "status_bar_icon",
            binaryMessenger: flutterViewController.engine.binaryMessenger
        )
        
        statusBarChannel = channel
        statusBarController = StatusBarController(window: mainFlutterWindow, channel: channel)
        channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "isVisible":
                result(self?.statusBarController?.isWindowVisible ?? false)
            case "updateIcon":
                if let args = call.arguments as? [String: Any],
                   let isConnected = args["isConnected"] as? Bool {
                    self?.statusBarController?.updateIcon(isVpnConnected: isConnected)
                    result(true)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        NSLog("StatusBar channel set up successfully")
    }
    
    // Mirrors Reduce Transparency / Reduce Motion / Increase Contrast and the
    // system accent color to the Flutter glass chrome
    // (lib/widgets/adaptive/glass_accessibility.dart).
    func setupGlassAccessibilityChannel(flutterViewController: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: "meowclash/glass_accessibility",
            binaryMessenger: flutterViewController.engine.binaryMessenger
        )
        glassAccessibilityChannel = channel
        channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "snapshot":
                result(self?.glassAccessibilitySnapshot())
            case "setAppearance":
                // The app's own light / dark choice. The sidebar material
                // and NSMenus are AppKit and would otherwise follow the
                // system appearance (lib/widgets/adaptive/glass_window_appearance.dart).
                let mode = (call.arguments as? [String: Any])?["mode"] as? String
                NSApp.appearance = Self.appearance(forMode: mode)
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(glassAccessibilityDidChange),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(glassAccessibilityDidChange),
            name: NSColor.systemColorsDidChangeNotification,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(glassAccessibilityDidChange),
            name: NSNotification.Name("AppleColorPreferencesChangedNotification"),
            object: nil
        )
    }

    // Native context menus for the Flutter chrome
    // (lib/widgets/adaptive/adaptive_context_menu.dart). `show` pops an NSMenu
    // up at a point in Flutter logical coordinates (points, origin top-left)
    // and replies with the chosen item index, or -1 when it was dismissed.
    func setupContextMenuChannel(flutterViewController: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: "meowclash/context_menu",
            binaryMessenger: flutterViewController.engine.binaryMessenger
        )
        contextMenuChannel = channel
        channel.setMethodCallHandler { [weak self, weak flutterViewController] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            guard call.method == "show" else {
                result(FlutterMethodNotImplemented)
                return
            }
            guard let self = self,
                  let view = flutterViewController?.view,
                  view.window != nil,
                  let args = call.arguments as? [String: Any],
                  let items = args["items"] as? [[String: Any]],
                  let x = (args["x"] as? NSNumber)?.doubleValue,
                  let y = (args["y"] as? NSNumber)?.doubleValue else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            // A pop-up button passes the index of its current value: that
            // item is placed over the button, as NSPopUpButton does.
            let positioning = (args["positioning"] as? NSNumber)?.intValue
            self.contextMenuPresenter.present(
                items: items,
                at: NSPoint(x: x, y: y),
                positioning: positioning,
                in: view
            ) { index in
                result(index)
            }
        }
    }

    /// `nil` follows the system appearance.
    static func appearance(forMode mode: String?) -> NSAppearance? {
        switch mode {
        case "light":
            return NSAppearance(named: .aqua)
        case "dark":
            return NSAppearance(named: .darkAqua)
        default:
            return nil
        }
    }

    @objc func glassAccessibilityDidChange(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.glassAccessibilityChannel?.invokeMethod("changed", arguments: self.glassAccessibilitySnapshot())
        }
    }

    func glassAccessibilitySnapshot() -> [String: Any] {
        let workspace = NSWorkspace.shared
        var snapshot: [String: Any] = [
            "reduceTransparency": workspace.accessibilityDisplayShouldReduceTransparency,
            "reduceMotion": workspace.accessibilityDisplayShouldReduceMotion,
            "increaseContrast": workspace.accessibilityDisplayShouldIncreaseContrast,
        ]
        if let accent = systemAccentARGB() {
            snapshot["accentColor"] = accent
        }
        return snapshot
    }

    // `AppleAccentColor` is absent from the global domain when the user picks
    // "Multicolor": macOS then defers to the app, so MeowClash keeps its own
    // brand color and no accent is sent.
    func systemAccentARGB() -> Int? {
        guard UserDefaults.standard.object(forKey: "AppleAccentColor") != nil,
              let color = NSColor.controlAccentColor.usingColorSpace(.sRGB) else {
            return nil
        }
        let a = Int((color.alphaComponent * 255).rounded())
        let r = Int((color.redComponent * 255).rounded())
        let g = Int((color.greenComponent * 255).rounded())
        let b = Int((color.blueComponent * 255).rounded())
        return (a << 24) | (r << 16) | (g << 8) | b
    }

    // Cmd+H hides the whole app without any window event reaching
    // window_manager, so report it to the UI lifecycle directly. The window
    // delegate belongs to window_manager; never replace it here.
    func setupAppVisibilityObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationVisibilityDidChange),
            name: NSApplication.didHideNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationVisibilityDidChange),
            name: NSApplication.didUnhideNotification,
            object: nil
        )
    }

    @objc func applicationVisibilityDidChange(_ notification: Notification) {
        let visible = notification.name == NSApplication.didUnhideNotification
            && (statusBarController?.isWindowVisible ?? false)
        statusBarChannel?.invokeMethod("visibilityChanged", arguments: visible)
    }

    func setupCoreInApplicationSupport() {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("ERROR: Could not get Application Support directory")
            return
        }
        
        let bundleURL = Bundle.main.bundleURL
        let bundleCorePath = bundleURL.appendingPathComponent("Contents/MacOS/MeowClashCore")
        let appSupportCorePath = appSupportURL.appendingPathComponent("com.meowclash.app/cores/MeowClashCore")
        let appSupportDir = appSupportCorePath.deletingLastPathComponent()
        
        do {
            try FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
            print("Directory created: \(appSupportDir.path)")
            
            let coreExists = FileManager.default.fileExists(atPath: appSupportCorePath.path)
            let needsUpdate = !coreExists || shouldUpdateCore(bundlePath: bundleCorePath.path, appSupportPath: appSupportCorePath.path)
            
            if needsUpdate {
                try? FileManager.default.removeItem(at: appSupportCorePath)
                
                try FileManager.default.copyItem(at: bundleCorePath, to: appSupportCorePath)
                
                if setCorePermissions(corePath: appSupportCorePath.path) {
                    print("MeowClashCore updated to: \(appSupportCorePath.path)")
                }
            } else {
                let attrs = try? FileManager.default.attributesOfItem(atPath: appSupportCorePath.path)
                if let posixPerms = attrs?[.posixPermissions] as? NSNumber {
                    // Check if setuid bit is set (04000 in octal)
                    if (posixPerms.uint16Value & 0o4000) == 0 {
                        print("Permissions not set, setting them now...")
                        let _ = setCorePermissions(corePath: appSupportCorePath.path)
                    } else {
                        print("MeowClashCore already up-to-date with correct permissions")
                    }
                }
            }
        } catch {
            print("Failed to setup core: \(error)")
        }
    }
    
    func setCorePermissions(corePath: String) -> Bool {
        let script = """
        do shell script "chown root:admin '\(corePath)' && chmod +sx '\(corePath)'" with administrator privileges
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                if let errorCode = error["NSAppleScriptErrorNumber"] as? Int, errorCode == -128 {
                    print("User cancelled password prompt")
                    showPermissionRequiredAlert()
                    NSApplication.shared.terminate(nil)
                    return false
                }
                print("Failed to set permissions: \(error)")
                return false
            } else {
                print("Permissions set successfully for: \(corePath)")
                return true
            }
        }
        return false
    }
    
    func showPermissionRequiredAlert() {
        let alert = NSAlert()
        alert.messageText = "Administrator Access Required"
        alert.informativeText = "MeowClash requires administrator privileges to set up the network core. The application cannot run without these permissions.\n\nPlease restart the application and grant administrator access when prompted."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Quit")
        alert.runModal()
    }
    
    func shouldUpdateCore(bundlePath: String, appSupportPath: String) -> Bool {
        guard let bundleAttrs = try? FileManager.default.attributesOfItem(atPath: bundlePath),
              let appSupportAttrs = try? FileManager.default.attributesOfItem(atPath: appSupportPath),
              let bundleDate = bundleAttrs[.modificationDate] as? Date,
              let appSupportDate = appSupportAttrs[.modificationDate] as? Date else {
            return true
        }
        return bundleDate > appSupportDate
    }
    
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        WindowExtPlugin.instance?.handleShouldTerminate()
        return .terminateCancel
    }

    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
      return true
    }
    
    // Dock click or a second launch from Finder while the window is hidden or
    // minimized: show it the same way the menu bar icon does.
    override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag, let controller = statusBarController {
            controller.showWindow()
            return false
        }
        return true
    }
}

/// Builds and shows the NSMenu behind `meowclash/context_menu`. Lives here, not
/// in its own file, so the Xcode project needs no new source entry.
final class ContextMenuPresenter: NSObject, NSMenuDelegate {
    private struct DestructiveItem {
        let title: String
        let image: NSImage?
    }

    private var selectedIndex = -1
    private var destructiveItems: [NSMenuItem: DestructiveItem] = [:]

    /// `popUp` runs its own tracking loop and returns once the menu closes.
    /// The reply is sent on the next run-loop turn, after AppKit has delivered
    /// the item action.
    func present(
        items: [[String: Any]],
        at point: NSPoint,
        positioning: Int? = nil,
        in view: NSView,
        completion: @escaping (Int) -> Void
    ) {
        selectedIndex = -1
        destructiveItems.removeAll()
        var positioningItem: NSMenuItem?
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        for (index, item) in items.enumerated() {
            let title = item["title"] as? String ?? ""
            let enabled = item["enabled"] as? Bool ?? true
            let destructive = item["destructive"] as? Bool ?? false
            // HIG: destructive actions form their own group at the end.
            if destructive, let last = menu.items.last, !last.isSeparatorItem {
                menu.addItem(.separator())
            }
            let menuItem = NSMenuItem(title: title, action: #selector(itemSelected(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.tag = index
            menuItem.isEnabled = enabled
            // Current value of a pop-up button / choice in a list.
            if item["checked"] as? Bool == true {
                menuItem.state = .on
            }
            if index == positioning {
                positioningItem = menuItem
            }
            var image: NSImage?
            if let symbol = item["symbol"] as? String {
                image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            }
            menuItem.image = image
            if destructive && enabled {
                let info = DestructiveItem(title: title, image: image)
                destructiveItems[menuItem] = info
                style(menuItem, info, highlighted: false)
            }
            menu.addItem(menuItem)
        }
        let location = NSPoint(x: point.x, y: view.isFlipped ? point.y : view.bounds.height - point.y)
        menu.popUp(positioning: positioningItem, at: location, in: view)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                completion(-1)
                return
            }
            self.destructiveItems.removeAll()
            completion(self.selectedIndex)
        }
    }

    @objc private func itemSelected(_ sender: NSMenuItem) {
        selectedIndex = sender.tag
    }

    // Red text would be unreadable on the accent-colored highlight, so the
    // highlighted destructive item switches to the standard selected color.
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        for (menuItem, info) in destructiveItems {
            style(menuItem, info, highlighted: menuItem === item)
        }
    }

    private func style(_ item: NSMenuItem, _ info: DestructiveItem, highlighted: Bool) {
        let color: NSColor = highlighted ? .selectedMenuItemTextColor : .systemRed
        item.attributedTitle = NSAttributedString(
            string: info.title,
            attributes: [.foregroundColor: color, .font: NSFont.menuFont(ofSize: 0)]
        )
        if let image = info.image {
            item.image = image.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [color])) ?? image
        }
    }
}
