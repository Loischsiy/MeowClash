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
- Font: Darwin uses the system San Francisco — `GlassTheme.fontFamily` / `fontFamilyFallback` return
  `null` there, so `ThemeData` keeps the Cupertino typography and the system fallback cascade (PingFang,
  Apple Color Emoji). Other platforms keep the bundled NotoSans + JetBrainsMono fallback
  (`test/adaptive_font_test.dart`). Never hardcode `fontFamily: 'NotoSans'` in a theme or widget.

## Where glass is allowed

- Only chrome: macOS sidebar + title bar, iOS tab bar, app bar, sheets / side sheets, dialogs, context
  menus.
- Never on scrolling content or list items, never nested (one `BackdropFilter` per surface, no blur
  inside a blurred surface), never an `Opacity` above a blur (animate scale / color instead).
- `GlassSurface` is the single primitive. `GlassBackdrop.blur` = one `BackdropFilter` (iOS bars, sheets,
  menus); `GlassBackdrop.native` = faint tint only, the AppKit glass behind the transparent Flutter view
  shows through (macOS sidebar and title bar, zero `BackdropFilter`).
- Sheets: on Darwin `showSheet` / `showExtend` skip the old full-screen `BackdropFilter` and
  `AdaptiveSheetScaffold` blurs only its own surface. A side sheet is a floating panel: inset
  `sideSheetInset` from the window edges, every corner rounded (`sideSheetRadiusMac/Ios`), the window
  insets inside reduced by the gap so its toolbar still clears the macOS title bar strip.
- `SheetType.page` (phones, `showExtend`) is an opaque full-screen route with nothing behind it to
  blur: `AdaptiveSheetScaffold` renders it without glass, on the theme's opaque page background.
  Glass there would only tint an empty backdrop flat grey.
- Navigation motion (`BaseNavigator.push`, `showSheet` / `showExtend`): on Darwin a phone push is
  `GlassPageRoute` (Cupertino slide + parallax + edge back swipe); a macOS / iPad full-window push is a
  `CupertinoPageTransition` slide without the swipe; the floating side sheet enters on a
  `GlassSpringCurve` (`sideSheetSpring*`) and leaves on an ease via `SideSheetMotion`. Never fade a
  glass page (`Opacity` over `BackdropFilter`). Material keeps `CommonRoute` / `CommonDesktopRoute` and
  the stock 300/200 ms side sheet (`motion: null`). Pinned by `test/adaptive_settings_motion_test.dart`.
- All numbers (sigmas, radii, opacities, sizes, durations) live in `glass_tokens.dart`.

## Toolbar (app bar)

- Every page's bar comes from `CommonScaffold`: on Darwin it builds
  `AdaptiveAppBar(child: GlassToolbar(...))` instead of the Material `AppBar`; the Material branch is the
  old code verbatim. Pages keep passing plain `IconButton`s as `actions` — never restyle them per page.
  A page with its own `appBar: AppBar(...)` (editor, side sheets) is converted the same way: its title,
  leading (or the implied back / close button) and actions; `genActions` spacers are dropped.
- macOS 26 / iOS 26 model: the bar itself has **no fill and no blur**; only its capsules are glass
  (`GlassToolbarGroup`, one `GlassSurface` each). Page actions share one capsule, search is its own
  round capsule, the leading button (back / close / edit-exit) another. While searching,
  `GlassToolbarSearchField` replaces the title and the actions hide. Budget: 1–3 blurs per bar.
- Sizes (`GlassTokens.toolbar*`): macOS 52 pt bar, compact 15 pt title at the leading edge; iOS 44 pt
  bar under the status bar, centered 17 pt title. macOS keeps window drag on the bar (`onWindowDrag`).
- iOS root pages (no back / close button, `CommonScaffold._isRootPage`) get the iOS 26 large title: the
  44 pt row keeps only the capsules and a second 52 pt row holds a 34 pt bold title at the leading edge
  (`toolbarLargeTitle*`). It stays while searching and scrolling, so the bar never changes height; pushed
  pages keep the centered 17 pt title, macOS keeps one row. Without a status bar (top inset 0) the bar
  still keeps `toolbarMinTopInsetIos` above the capsules. Bar height always comes from
  `AdaptiveAppBar.preferredHeight`; pages read it only through `AdaptiveAppBar.topInset` (MediaQuery).
- A capsule inside an already blurring surface (e.g. `CommonScaffold` in a glass sheet) switches to
  `GlassBackdrop.native` via `GlassSurface.isOverBlur` — never blur over blur.
- Scrolling under the bar is **opt-in per page**: `CommonScaffold(scrollUnderToolbar: true)` →
  `extendBodyBehindAppBar`, `SafeArea(top: false)` and the bar's scroll-edge fade (a gradient in the
  window color, `toolbarFade*`, no blur, `IgnorePointer`). The page must pad its scroll view with
  `AdaptiveAppBar.topInset(context)` (0 on Material and on pages that do not opt in). Keyword chips stay
  below the bar and remove the top padding for the page under them. Home opts in per tab via
  `_scrollUnderToolbarPages` in `lib/pages/home.dart` (currently Tools, Proxies and Profiles); other pages keep their own
  top padding, which would hide content under the bar if enabled globally.
- Fallbacks: `opaque` → solid window-colored bar + hairline, no fade, opaque capsules. Nothing in the bar
  animates (no `Opacity` above the capsules), and with Reduce Motion the search hint does not fade.
- Tests: `test/adaptive_toolbar_test.dart` (layout, blur count, search, back, drag, scroll-under,
  fallbacks); Material: `test/material_chrome_golden_test.dart`.

## Inner screens (phase 2)

- One screen per PR. Each screen gets Material goldens taken **before** the glass work
  (`test/material_<screen>_golden_test.dart`) and a glass test that counts `BackdropFilter`s on a
  100+ item list (`test/adaptive_<screen>_glass_test.dart`).
- Content primitives: `AdaptiveCard` (translucent, no blur; selection = light accent tint + faint
  accent hairline, never a thick outline; `checked` = check badge; the 1.5 px accent ring is keyboard
  focus only), `AdaptiveDelayBadge` (pill, `CupertinoActivityIndicator`, bolt),
  `AdaptiveGroupHeader` (collapsible group row; blurred only while `pinned`),
  `AdaptiveGroupSelector` (floating glass group bar over a `TabController`),
  `AdaptiveFloatingButton` (glass circle, `busy` spinner), `AdaptiveEmptyState`,
  `AdaptiveActivityIndicator`, `AdaptiveProgressBar` (static capsule, no animation; the Material
  branch is the old `LinearProgressIndicator`), `GlassIconButton` (Darwin-only symbol button,
  `busy` spinner).
- Blur budget of a scrolling screen is constant: only a pinned header / floating bar / floating
  button may be a `GlassSurface`. A pinned list header is a `SliverPersistentHeader` that swaps to its
  glass variant only when `shrinkOffset > 0`, so at rest the list has zero blur.
- Glass content text uses the Apple type scale from `GlassTextStyles` (sizes/line heights are
  `GlassTokens.card*` / `delayBadge*` / `group*`, per macOS and iOS), not the Material `TextTheme`
  sizes. Fixed-height rows must measure the same style: `Measure.heightOf(style)` (see
  `proxyCardLineHeights` in `lib/views/proxies/common.dart`); the Material branch keeps
  `measure.bodyMediumHeight` & co. so its goldens do not move.
- A floating bar over content: the host stacks it over the pages and pads the scroll view by the
  primitive's `contentInset` (0 off Darwin, so the Material padding is unchanged).
- A scroll view with its own pinned headers that scrolls under the toolbar starts with
  `SliverToolbarInset` (only when `topInset > 0`): an empty pinned spacer as tall as the bar, so the
  headers stick right below the bar via `constraints.overlap` while the content keeps going under it.
  Plain top padding would pin them under the bar — glass under glass. Floating overlays (the proxies
  group bar) are positioned at `top: topInset` and the content below them adds the inset too.
- Proxies screen: in the list mode the expanded group header pins; in the tab mode the grid scrolls
  under `AdaptiveGroupSelector`. The Darwin check badge replaces `_ProxyComputedMark`. Proxy-screen
  sheets (settings, providers, group picker, icons) are still Material-in-glass-sheet — next PR.
- Profiles screen: cards are `AdaptiveCard(checked: false)` — selection is the tint + hairline only, no
  check badge; the name uses `GlassTextStyles.groupTitle`, the details `cardSubtitle`. The traffic bar
  is an `AdaptiveProgressBar` colored by `GlassTokens.trafficColor` (Apple green, orange above
  `trafficWarningThreshold`, red above `trafficCriticalThreshold`). The trailing `GlassIconButton`
  opens the same `CommonPopupBox` menu and turns into the spinner while the profile updates. The sort
  sheet rows are flat `AdaptiveCard`s `listRowHeight` tall (the card hairline counts in), the dragged
  row lifts with `floatingShadow` and `listRowDragScale` (no scale with Reduce Motion).
- Profile editors (add / edit / scripts / override + its rule and chain dialogs): settings-style
  primitives from `lib/widgets/adaptive/adaptive_list.dart` — `GlassListSection` (rounded group of rows,
  inset hairlines, header / footer, never blurred; `listPadding` / `gap` for the page),
  `GlassSectionHeader` (title, optional subtitle and trailing `GlassButton`), `GlassListRow` (chevron /
  checkmark / custom trailing), `GlassListField` (a form field inside a section under `GlassTheme.form`),
  `AdaptiveSwitch` (Material keeps `Switch` verbatim; Darwin `CupertinoSwitch` in the accent, smaller on
  macOS) and `GlassButton` (tinted / filled / plain capsule, `busy`, `destructive`). Choices go through
  `GlassPopUpButton<T>` (`glass_pop_up_button.dart`): macOS opens the native `NSMenu` over the control with
  the current item checked (`AdaptiveMenuEntry.checked` → `state = .on`), iOS the glass menu scrolled to
  the current item; wrap it in a `FormField` with the Material validator and pass `field.errorText`. The
  override rule list stays one flat `AdaptiveCard` per rule (hundreds of rows, no blur) with a selection
  circle; its `itemExtentBuilder` is computed from the same tokens (`ruleRow*`, `ruleCheck*`,
  `GlassTextStyles.codeLine`) and the text width `maxWidth − RuleContent.glassTextReserve` — change both
  together. Branch with `AdaptivePlatform.useGlass` around the Material tree and share validators /
  handlers as methods; the Material editors are pinned by `test/material_profile_editors_golden_test.dart`,
  glass checks live in `test/adaptive_profile_editors_glass_test.dart`. App-wide `ListItem` (settings)
  is not migrated yet.
- Dialogs (`lib/widgets/adaptive/adaptive_dialog.dart`): on Darwin `showCommonDialog` goes through
  `showGlassDialog` / `GlassDialogRoute` and `CommonDialog` / `CommonModal` render `GlassDialog` /
  `GlassModalPanel` — one `GlassSurface` each, no blur behind. `dialogBarrierColor`: macOS does not dim
  the window at all (as AppKit alerts; a dark barrier kills the glass), iOS dims lightly. In dark mode
  the panel tint is `dialogTint` (surface lifted by a white wash), so it stands above the equally dark
  window instead of sinking into it; keep `dialogTintOpacity` low enough for the app to show through. Appearing
  is animated by the dialog itself via `GlassDialogRoute.presenceOf` → `GlassSurface.presence` (sigma,
  fill, rim and shadow scale with it) + scale 1.05→1 (no scale with Reduce Motion or on close); never an
  `Opacity` / `FadeTransition` above the blur. A raw `AlertDialog` pushed through the route falls back
  to a plain fade (it has no blur). `GlassDialogActions` drops `SizedBox` / `Spacer` between actions:
  macOS — 28 pt capsules at the trailing edge, the last one filled with the accent; iOS — full-width
  44 pt buttons over a hairline, two side by side, three or more stacked. Content inherits
  `GlassTheme.form` (fields get `GlassFieldBorder`: filled, no outline, accent ring on focus), so call
  sites keep their `TextField`s. Pickers (`OptionsDialog`) use `GlassOptionRow` with a checkmark.
  Material keeps `showModal` + `FadeScaleTransition` + `AlertDialog` verbatim
  (`test/material_dialogs_golden_test.dart`); glass checks live in
  `test/adaptive_dialogs_glass_test.dart`.
- `proxy_list_performance_test.dart` looks for `IconButton` inside `ProxyGroupCard` and for
  `FloatingActionButton`: keep them in the Material branches.
- Proxies goldens (`test/material_proxies_golden_test.dart`) need groups with `hidden: false`, otherwise
  the screen renders empty and the golden proves nothing.
- Do not use `CupertinoIcons`: `cupertino_icons` is not a dependency, so its font is not bundled and
  the glyphs render as empty boxes. Use rounded Material symbols (`Icons.*_rounded`) on Darwin too.

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
