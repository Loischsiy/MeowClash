import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var iosService: IOSService?
    private var glassAccessibilityChannel: FlutterMethodChannel?

    override func application(_ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        if let controller = window?.rootViewController as? FlutterViewController {
            iosService = IOSService(messenger: controller.binaryMessenger)
            setupGlassAccessibilityChannel(messenger: controller.binaryMessenger)
        }
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Mirrors Reduce Transparency / Reduce Motion / Increase Contrast to the
    // Flutter glass chrome (lib/widgets/adaptive/glass_accessibility.dart).
    // iOS has no user accent color for third-party apps, so none is sent.
    private func setupGlassAccessibilityChannel(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "meowclash/glass_accessibility", binaryMessenger: messenger)
        glassAccessibilityChannel = channel
        channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "snapshot":
                result(self?.glassAccessibilitySnapshot())
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        let names: [Notification.Name] = [
            UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            UIAccessibility.reduceMotionStatusDidChangeNotification,
            UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
        ]
        for name in names {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(glassAccessibilityDidChange),
                name: name,
                object: nil
            )
        }
    }

    @objc private func glassAccessibilityDidChange(_ notification: Notification) {
        glassAccessibilityChannel?.invokeMethod("changed", arguments: glassAccessibilitySnapshot())
    }

    private func glassAccessibilitySnapshot() -> [String: Any] {
        return [
            "reduceTransparency": UIAccessibility.isReduceTransparencyEnabled,
            "reduceMotion": UIAccessibility.isReduceMotionEnabled,
            "increaseContrast": UIAccessibility.isDarkerSystemColorsEnabled,
        ]
    }
}
