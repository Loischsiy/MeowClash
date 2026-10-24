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

## Inner screens (phase 2)

- One screen per PR. Each screen gets Material goldens taken **before** the glass work
  (`test/material_<screen>_golden_test.dart`) and a glass test that counts `BackdropFilter`s on a
  100+ item list (`test/adaptive_<screen>_glass_test.dart`).
- Content primitives: `AdaptiveCard` (translucent, no blur; selection = accent fill + outline,
  `checked` = check badge), `AdaptiveDelayBadge` (pill, `CupertinoActivityIndicator`, bolt),
  `AdaptiveGroupHeader` (collapsible group row; blurred only while `pinned`),
  `AdaptiveGroupSelector` (floating glass group bar over a `TabController`),
  `AdaptiveFloatingButton` (glass circle, `busy` spinner), `AdaptiveEmptyState`,
  `AdaptiveActivityIndicator`, `GlassIconButton` (Darwin-only symbol button).
- Blur budget of a scrolling screen is constant: only a pinned header / floating bar / floating
  button may be a `GlassSurface`. A pinned list header is a `SliverPersistentHeader` that swaps to its
  glass variant only when `shrinkOffset > 0`, so at rest the list has zero blur.
- A floating bar over content: the host stacks it over the pages and pads the scroll view by the
  primitive's `contentInset` (0 off Darwin, so the Material padding is unchanged).
- Proxies screen: in the list mode the expanded group header pins; in the tab mode the grid scrolls
  under `AdaptiveGroupSelector`. The Darwin check badge replaces `_ProxyComputedMark`. Proxy-screen
  sheets (settings, providers, group picker, icons) are still Material-in-glass-sheet — next PR.
- `proxy_list_performance_test.dart` looks for `IconButton` inside `ProxyGroupCard` and for
  `FloatingActionButton`: keep them in the Material branches.

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
  Transparency for this layer itself. Compare with the pre-26 material only:
  `defaults write com.meowclash.app MeowClashGlassBackdrop legacy` (delete the key to restore).
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

## Refraction shader (iOS tab bar only)

- `shaders/glass_refraction.frag` (declared under `flutter: shaders:` in `pubspec.yaml`) bends the
  blurred backdrop along the capsule rim and, more weakly, along the selected-tab capsule. Wired via
  `GlassSurface(refraction: GlassRefraction(...))`; only `_GlassTabBar` passes it, and only when
  `AdaptivePlatform.isIOSGlass`. macOS uses native AppKit glass and never gets the shader.
- Still **one** `BackdropFilterLayer` per surface (`RenderGlassRefraction`):
  `ImageFilter.compose(outer: shader, inner: blur)`. The selected-tab lens is computed inside the same
  shader — never stack a second shader `BackdropFilter` (stale content on iOS devices, flutter#187820).
- Falls back to the plain `BackdropFilter.grouped` blur when `ImageFilter.isShaderFilterSupported` is false
  (no Impeller), while the program is loading or after it failed, with `opaque` (Reduce Transparency /
  Increase Contrast) and with the kill switch `--dart-define=MEOWCLASH_GLASS_REFRACTION=false`.
- Uniform layout is fixed: Dart writes `GlassRefractionShader.uniformCount` floats after the
  engine-owned `uSize`; change `glassRefractionUniforms` and the `.frag` together
  (`test/adaptive_refraction_test.dart` checks the count against the compiled program). The backdrop
  texture is full screen in physical px, so rects are `localToGlobal × devicePixelRatio`.
- The position is read at paint time; during a route transition the rim/lens may lag a frame behind a
  moving bar. Strength numbers are `GlassTokens.tabBarRefraction*` / `tabBarLens*`.
- Compile check without a build: `impellerc` from
  `<flutter>/bin/cache/artifacts/engine/darwin-x64/` with `--runtime-stage-metal --sksl
  --include=<that dir>/shader_lib`.

## Checking without a device

- `flutter test` covers both branches (glass on/off, Reduce Motion / Transparency, channel fallbacks).
  Refraction tests check the uniforms and the layer tree only (support is forced with
  `GlassRefractionShader.debugSupportedOverride`); the look of the shader is checked on the simulator or
  a device.
- Swift has no unit tests here; type-check edited Runner files with `xcrun swiftc -typecheck` against the
  FlutterMacOS framework, stubbing plugin imports.
- The iOS simulator only runs the Debug UI build (see `.agents/build.md`); performance numbers
  must come from real hardware. `flutter build ios --simulator --debug` + `xcrun simctl install /
  launch / io screenshot` works without Xcode open. **Do not run a CLI iOS build while the project is
  open in Xcode**: Flutter regenerates the plugin package and Xcode 27.1 crashes
  (`IDEContainer _retainedContainerAtFilePath`).
