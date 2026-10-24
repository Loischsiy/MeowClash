# Adaptive UI: Liquid Glass chrome on macOS and iOS

Router: `AGENTS.md`. Darwin gets glass *chrome*; every other platform keeps the Material widgets
pixel-for-pixel. Code: `lib/widgets/adaptive/` (import `adaptive.dart`).

## Platform switch

- `AdaptivePlatform.useGlass` — true on macOS/iOS only (`defaultTargetPlatform`, so tests can flip it
  with `debugDefaultTargetPlatformOverride` or `AdaptivePlatform.debugUseGlassOverride`).
  `isMacOSGlass` / `isIOSGlass` narrow it. Never branch on `Platform.isX` for chrome looks.
- Every adaptive widget has a Material branch that is the **old code moved verbatim**. Android, Linux and
  Windows must stay identical: `test/adaptive_chrome_golden_test.dart` and
  `test/material_chrome_golden_test.dart` (baselines generated before the glass work). Regenerate them only
  for an intended Material change (`--update-goldens`), never to make a glass change pass.

## Where glass is allowed

- Only chrome: macOS sidebar + title bar, iOS tab bar, app bar, sheets / side sheets, context menus.
- Never on scrolling content or list items, never nested (one `BackdropFilter` per surface, no blur
  inside a blurred surface), never an `Opacity` above a blur (animate scale / color instead).
- `GlassSurface` is the single primitive. `GlassBackdrop.blur` = one `BackdropFilter` (iOS bars, sheets,
  menus); `GlassBackdrop.native` = faint tint only, the AppKit glass behind the transparent Flutter view
  shows through (macOS sidebar and title bar, zero `BackdropFilter`).
- Sheets: on Darwin `showSheet` / `showExtend` skip the old full-screen `BackdropFilter` and
  `AdaptiveSheetScaffold` blurs only its own surface.
- All numbers (sigmas, radii, opacities, sizes, durations) live in `glass_tokens.dart`.

## Accessibility and fallbacks

- `GlassAccessibility.of(context)`: Reduce Transparency, Reduce Motion, Increase Contrast and the
  system accent, fed by the `meowclash/glass_accessibility` channel in both `AppDelegate.swift` files
  (missing channel = defaults, no crash).
- `opaque` (Reduce Transparency, Increase Contrast or `GlassFlags.backdropBlurEnabled == false`) →
  surfaces paint an opaque fill and skip the filter. Kill switch for old Macs:
  `--dart-define=MEOWCLASH_GLASS_BLUR=false`.
- Reduce Motion → glass transitions run with zero duration (`GlassTokens.motion`).
- Accent: macOS `NSColor.controlAccentColor` (Multicolor → MeowClash brand color); iOS has no system
  accent for third-party apps → `CupertinoColors.systemBlue`.

## macOS specifics

- The app is a regular window (not a menu-bar popover). The status item keeps a template SF Symbol;
  left click toggles the window, right click opens a native `NSMenu`.
- Window backdrop (`macos/Runner/MainFlutterWindow.swift`, `GlassContainerViewController`): transparent
  `FlutterViewController` over `NSVisualEffectView(.sidebar, .behindWindow)`; on macOS 26+ an
  `NSGlassEffectView` on top (`#if compiler(>=6.2)` + `#available(macOS 26, *)`). AppKit handles Reduce
  Transparency for this layer itself.
- Context menus: `AdaptiveContextMenu.showNative` → `meowclash/context_menu` channel →
  `ContextMenuPresenter` in `macos/Runner/AppDelegate.swift` (`NSMenu.popUp`). Mark destructive entries
  with `PopupMenuItemData.type = PopupMenuItemType.danger` (system red, own group at the end). Map new
  Material icons to SF Symbols in `AdaptiveContextMenu.sfSymbolFor`. macOS 27 hides symbol images in
  menus by default (`NSMenuItem.preferredImageVisibility = .automatic`); this is kept on purpose to match
  the system. Falls back to the Flutter menu when the channel is missing.
- New Swift code goes into existing files (a new file needs a `project.pbxproj` entry).

## iOS specifics

- Tab bar (`AdaptiveTabBar`): floating capsule above the home indicator; the hosting `CommonScaffold`
  uses `extendBody` but its `SafeArea` keeps page content **above** the capsule (nothing may hide under
  it, e.g. the dashboard start button). A screen that wants to scroll under the bar must disable that and
  pad its scroll view with `AdaptiveTabBar.bottomInset(context)` itself.
- Context menus: one glass `GlassSurface`, scale-only open, instant close, symbol on the trailing edge.

## Checking without a device

- `flutter test` covers both branches (glass on/off, Reduce Motion / Transparency, channel fallbacks).
- Swift has no unit tests here; type-check edited Runner files with `xcrun swiftc -typecheck` against the
  FlutterMacOS framework, stubbing plugin imports.
- The iOS simulator only runs the Debug UI build (see `.agents/build.md`); performance numbers
  must come from real hardware.
