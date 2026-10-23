import Cocoa
import FlutterMacOS
import window_manager
import LaunchAtLogin

/// Hosts Flutter above a native sidebar material so the Liquid Glass sidebar
/// (lib/widgets/adaptive/adaptive_sidebar.dart) shows the desktop through the
/// window, like Finder. Flutter paints opaque everywhere else, so the material
/// is visible only where Dart leaves pixels transparent.
final class GlassContainerViewController: NSViewController {
    let flutterViewController: FlutterViewController

    init(flutterViewController: FlutterViewController) {
        self.flutterViewController = flutterViewController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let material = NSVisualEffectView()
        material.material = .sidebar
        material.blendingMode = .behindWindow
        material.state = .followsWindowActiveState
        view = material

        addChild(flutterViewController)
        let flutterView = flutterViewController.view
        flutterView.frame = material.bounds
        flutterView.autoresizingMask = [.width, .height]
        material.addSubview(flutterView)
    }
}

class MainFlutterWindow: NSWindow {
    private(set) var flutterViewController: FlutterViewController?

    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        // Transparent Flutter layer over the native material (see above).
        flutterViewController.backgroundColor = .clear
        self.flutterViewController = flutterViewController
        let windowFrame = self.frame
        self.contentViewController = GlassContainerViewController(
            flutterViewController: flutterViewController
        )
        self.setFrame(windowFrame, display: true)
        
        // Regular macOS window: Flutter draws under a transparent title bar and
        // the traffic lights sit in the kHeaderHeight strip
        // (lib/manager/window_manager.dart). Dart applies the same style through
        // window_manager; setting it here avoids a flash of the default title
        // bar. Keep minSize in sync with Window.init (lib/common/window.dart).
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.styleMask.insert(.fullSizeContentView)
        self.minSize = NSSize(width: 380, height: 400)
        
        FlutterMethodChannel(
            name: "launch_at_startup", binaryMessenger: flutterViewController.engine.binaryMessenger
        )
        .setMethodCallHandler { (_ call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "launchAtStartupIsEnabled":
                result(LaunchAtLogin.isEnabled)
            case "launchAtStartupSetEnabled":
                if let arguments = call.arguments as? [String: Any] {
                    LaunchAtLogin.isEnabled = arguments["setEnabledValue"] as! Bool
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        RegisterGeneratedPlugins(registry: flutterViewController)
        super.awakeFromNib()
    }
    override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
        super.order(place, relativeTo: otherWin)
        hiddenWindowAtLaunch()
    }
}
