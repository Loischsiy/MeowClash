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
- Specular rim (`_GlassRimPainter`): light = 1 pt white 0.72 → 0.10 (unchanged, liked on device); dark
  = 0.5 pt (one Retina pixel) white 0.12 → 0.03 (`GlassTokens.rimWidth/rimTopOpacity/rimBottomOpacity`).
  A full 1 pt rim at 0.26 read as a gray frame around dark side sheets and dialogs.
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
  `GlassBackdrop.native` via `GlassSurface.isOverBlur` — never blur over blur. Its fill is then
  `GlassTokens.toolbarItemTintOverGlass` (light 0.18 = the native wash, dark 0.56) so in dark it reads as
  a filled disc, not a bare rim (`GlassSurface.tintOpacity` now applies to both backdrops).
- Close glyph: `GlassCloseIcon` (SF `xmark`, round caps, `closeGlyphSpan/Stroke` of the icon size).
  `GlassTheme.apply` installs it via `ActionIconThemeData.closeButtonIconBuilder`, so every Material
  `CloseButton` / `CloseButtonIcon` on Darwin draws it; Material keeps `Icons.close`. Use
  `CloseButtonIcon()` (or `GlassCloseIcon` in glass-only code) for new Darwin close buttons.
- Scrolling under the bar is **opt-in per page**: `CommonScaffold(scrollUnderToolbar: true)` →
  `extendBodyBehindAppBar`, `SafeArea(top: false)` and the bar's scroll-edge fade (a gradient in the
  window color, `toolbarFade*`, no blur, `IgnorePointer`). The page must pad its scroll view with
  `AdaptiveAppBar.topInset(context)` (0 on Material and on pages that do not opt in). Keyword chips stay
  below the bar and remove the top padding for the page under them. Home opts in per page via
  `scrollUnderToolbarPages` in `lib/common/navigation.dart` (Tools, Proxies, Profiles, Requests,
  Connections, Logs); other pages keep their own top padding, which would hide content under the bar if
  enabled globally. On iPhone, Requests / Connections / Logs are pushed from the Tools "More" section:
  `tools.dart` sets `OpenDelegate.scrollUnderToolbar` from the same set and `_showGlassPage`
  (`lib/widgets/list.dart`) then pushes `CommonScaffold.open(scrollUnderToolbar: true)` inside
  `SafeArea(top: false)` — a new pushed page needs the same flag, not only the Home set.
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
  under `AdaptiveGroupSelector`. The Darwin check badge replaces `_ProxyComputedMark`. The settings and
  providers sheets are glass (see Settings below); the group picker and icons sheets are still
  Material-in-glass-sheet.
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
  glass checks live in `test/adaptive_profile_editors_glass_test.dart`.
- Settings (app-wide `ListItem`, `lib/widgets/list.dart`): `ListItem`, `ListHeader`, `generateSection(V2)`
  and `generateListView` render `GlassListRow` / `GlassListSection` only inside a `GlassListScope`
  (`GlassListView` provides it); outside it they stay Material verbatim, so the dashboard mode radios are
  untouched (connections and logs have their own flat rows, see below). `_groupGlassSections` turns a flat header + items list into
  sections. Row kinds: `options` → `GlassPopUpButton` with the value at the trailing edge (macOS
  `NSMenu`, iOS glass menu); `input` → value + chevron; `open` / `next` → chevron (phone: `GlassPageRoute` push,
  desktop: `showExtend` side sheet on the spring); `switch` → `AdaptiveSwitch`; `radio` / `checkbox` →
  checkmark; Material buttons in `trailing` become capsules via `GlassTheme.row`; `destructive` paints
  the row red. Section hairlines start at the row text: `_GlassSectionSlot` + `GlassLeadingHint`
  report the leading width. A top-level item list whose items branch on the platform while it is built
  (`networkItems` calls `generateSection`) must be a **getter** — a `final` is built once and keeps the
  first branch (tests flip the platform); `generalItems` stays `final` because Darwin builds its own
  sections in `GeneralListView`. Pages with their
  own glass branch (Material moved verbatim): tools, application, general / network, backup, hotkeys
  (`GlassKeyCaps`), about, developer, theme (`AdaptiveSlider`, swatches), proxies setting and providers
  sheets, resources, media unlock. Material: `test/material_settings_golden_test.dart`; glass:
  `test/adaptive_settings_glass_test.dart` (rows, fallbacks, long list without blur),
  `test/adaptive_settings_pages_glass_test.dart`, `test/adaptive_settings_motion_test.dart`; shared host
  `test/settings_test_support.dart`.
- Connections & Logs (`lib/views/connection/{requests,connections,item}.dart`, `lib/views/logs.dart`):
  long live lists, so rows are flat `GlassStreamRow`s (`glass_stream_row.dart`: transparent, hairline
  from the text, hover / press tint, `onContextMenu(globalPosition)` = right click / long press,
  `swipeAction` iOS only) — never a card, section or blur per row. Tags are `GlassTag`s
  (`glass_tag.dart`: small capsule without blur, neutral / accent / colored; `large` + ✕ = the keyword
  filter that `CommonScaffold` draws below the bar on Darwin). A connection row: host
  (`listRowTitle`), "process · time", ↑/↓ traffic (`streamMetric`, live Connections only:
  `showTraffic`), the chain as tags (tap = keyword filter). One menu for both (`AdaptiveMenuEntry`:
  Copy Host, Filter by Process, Close Connection `destructive`): macOS — ✕ at the trailing edge + the
  native right-click `NSMenu`; iOS — long swipe to close + the long-press glass menu.
  The dead Chinese `CommonPopupBox` stays in the Material branch only. A log row: `SelectableText`
  payload in `GlassTextStyles.logPayload` (`.AppleSystemUIFontMonospaced`, fallback Menlo / Courier),
  then the level tag (debug / silent gray, info blue, warning orange, error red, app accent; tap =
  filter) and the time. Row heights are precomputed and cached in `globalState.cacheHeightMap[tag]`:
  on Darwin they come from the same styles via `ConnectionItem.glassExtent` / `_GlassLogItem.extentOf`
  (`GlassStreamRow.extentOf`, `contentWidth − selectableCaretReserve` for the payload) — change the row
  and its extent together, and clear the tag's cache in tests that flip the platform. Empty →
  `AdaptiveEmptyState`, loading → `AdaptiveActivityIndicator` (never `NullStatus` /
  `CircularProgressIndicator` on Darwin), scrollbar → `AdaptiveScrollbar` (Material = `CommonScrollBar`
  verbatim, iOS Cupertino, macOS thin auto-hiding overlay). `ScrollToEndBox` jumps instead of animating
  with Reduce Motion. The reversed lists pad with `AdaptiveAppBar.topInset` through
  `CacheItemExtentListView(padding:)` (null on Material). Material: `test/material_connections_logs_golden_test.dart`;
  glass: `test/adaptive_connections_logs_glass_test.dart` (extents incl. 1.5× text, 1000 logs without
  blur, filters, closing, fallbacks, scrolling under the bar); frame times of 1000 logs glass vs
  Material: `test/connections_logs_performance_test.dart` (printed, not asserted); shared host
  `test/connections_logs_test_support.dart`. In tests the list is the `Scrollable` with
  `axisDirection == AxisDirection.up` — every `SelectableText` has its own `Scrollable`.
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
- App theme → window appearance: `GlassWindowAppearance` (wraps `MaterialApp` in `application.dart` on
  Darwin) sends `setAppearance {mode: system|light|dark}` over `meowclash/glass_accessibility` and
  `AppDelegate.swift` sets `NSApp.appearance` (nil / `.aqua` / `.darkAqua`). Without it the native
  sidebar material and `NSMenu`s follow the *system* theme: dark system + light app = gray sidebar.
  iOS never calls it; an older runner without the method is ignored. Swift changes need an app rebuild.
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
