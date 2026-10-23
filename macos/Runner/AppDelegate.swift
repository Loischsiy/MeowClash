import Cocoa
import FlutterMacOS
import window_ext
import LaunchAtLogin

@main
class AppDelegate: FlutterAppDelegate {
    var statusBarController: StatusBarController?
    private var statusBarChannel: FlutterMethodChannel?
    private var glassAccessibilityChannel: FlutterMethodChannel?
    
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
