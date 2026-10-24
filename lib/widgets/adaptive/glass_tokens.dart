import 'package:flutter/widgets.dart';

/// The one place for every number of the Darwin glass chrome.
///
/// Widgets read blur strength, tint opacity, specular rim, radii, shadows and
/// motion from here; no glass value is written inline anywhere else. Values
/// that differ by appearance are resolved through [Brightness].
abstract final class GlassTokens {
  // Blur sigmas (logical px). Chrome only: never applied to scrolling content.
  static const double sidebarSigma = 30;
  static const double barSigma = 24;
  static const double sheetSigma = 32;
  static const double menuSigma = 20;

  // Tint laid over the blurred backdrop, as alpha of the surface color.
  static const double _tintOpacityLight = 0.64;
  static const double _tintOpacityDark = 0.52;

  // Tint used where the macOS window already sits on native AppKit glass, so
  // the Flutter layer only needs a faint wash to keep text legible.
  static const double _nativeBackdropTintLight = 0.18;
  static const double _nativeBackdropTintDark = 0.14;

  // Specular rim: a 1px edge, brighter at the top, as light catches glass.
  static const double rimWidth = 1;
  static const double _rimTopOpacityLight = 0.72;
  static const double _rimTopOpacityDark = 0.26;
  static const double _rimBottomOpacityLight = 0.10;
  static const double _rimBottomOpacityDark = 0.05;

  // Hairline separating chrome from content (title bar, tab bar, sidebar).
  static const double hairlineWidth = 0.5;
  static const double _hairlineOpacityLight = 0.10;
  static const double _hairlineOpacityDark = 0.16;

  // Selection capsule (tab bar item, sidebar row), as alpha of the accent.
  static const double _selectionOpacityLight = 0.16;
  static const double _selectionOpacityDark = 0.24;
  // With Reduce Transparency the capsule must read on an opaque fill.
  static const double selectionOpacityOpaque = 0.30;
  // Hover wash on sidebar rows (macOS pointer).
  static const double _hoverOpacityLight = 0.06;
  static const double _hoverOpacityDark = 0.08;

  // Corner radii.
  static const double tabBarRadius = 30;
  static const double sheetRadius = 26;
  static const double menuRadius = 14;
  static const double selectionRadius = 10;
  static const double sidebarRowRadius = 8;

  // Geometry of the floating iOS tab bar.
  static const double tabBarHeight = 62;
  static const double tabBarHorizontalMargin = 16;
  static const double tabBarBottomGap = 8;
  static const double tabBarInnerPadding = 4;
  static const double tabBarIconSize = 24;
  static const double tabBarLabelGap = 2;

  // Edge refraction of the iOS tab bar (shaders/glass_refraction.frag), in
  // logical px: how far in from the rim the bevel reaches, how far its
  // outermost band reads from, and how far red and blue part there. The
  // selected tab gets a shallower lens of its own.
  static const double tabBarRefractionBevel = 14;
  static const double tabBarRefractionDepth = 10;
  static const double tabBarRefractionDispersion = 0.75;
  static const double tabBarLensBevel = 8;
  static const double tabBarLensDepth = 4;
  static const double tabBarLensDispersion = 0.5;

  // Geometry of the macOS chrome.
  static const double sidebarWidth = 84;
  static const double sidebarExtendedWidth = 200;
  static const double sidebarPadding = 10;
  static const double sidebarRowHeight = 32;
  static const double sidebarCompactRowHeight = 44;
  static const double sidebarRowGap = 2;
  static const double sidebarIconSize = 20;
  static const double sidebarCompactIconSize = 22;
  static const double sidebarLogoSize = 28;
  static const double titleBarHeight = 28;
  static const double trafficLightsInset = 78;

  // Geometry of the Flutter glass context menu (iOS, and macOS when the
  // native NSMenu channel is unavailable).
  static const double menuMinWidth = 200;
  static const double menuMaxWidth = 280;
  static const double menuVerticalPadding = 6;
  static const double menuRowHeight = 44;
  static const double menuRowInset = 6;
  static const double menuRowPadding = 12;
  static const double menuRowRadius = 8;
  static const double menuIconSize = 20;
  static const double menuIconGap = 16;
  static const double menuGroupGap = 6;
  // Distance between the menu and the control that opened it.
  static const double menuAnchorGap = 4;
  // The menu grows from this scale to 1 while opening.
  static const double menuOpenScale = 0.85;
  static const double _menuPressedOpacityLight = 0.10;
  static const double _menuPressedOpacityDark = 0.14;
  // Text and icons of disabled menu rows, as alpha of the foreground.
  static const double disabledOpacity = 0.30;

  // Content cards (proxy nodes). They scroll, so they never blur: a
  // translucent fill over the window background, a hairline edge, and the
  // accent for the selected card.
  static const double cardRadius = 12;
  static const double _cardFillOpacityLight = 0.72;
  static const double _cardFillOpacityDark = 0.46;
  static const double _cardSelectedOpacityLight = 0.14;
  static const double _cardSelectedOpacityDark = 0.22;
  static const double cardSelectedBorderWidth = 1.5;
  // Check badge of the user's choice, in the top-end corner of the card.
  static const double cardCheckSize = 18;
  static const double cardCheckIconSize = 12;
  static const double cardCheckInset = 6;
  // Space the card content leaves free for the check badge.
  static const double cardCheckReserve = 16;

  // Delay badge: a capsule tinted with the delay color.
  static const double delayPillHorizontalPadding = 6;
  static const double _delayPillOpacityLight = 0.14;
  static const double _delayPillOpacityDark = 0.24;
  // Spinner radius as a fraction of the badge height.
  static const double delayIndicatorRadiusFactor = 0.4;
  // Bolt symbol of an untested proxy, as a fraction of the badge height.
  static const double delayBoltSizeFactor = 0.85;

  // Group header of the list mode; pinned (blurred) while its group scrolls
  // under it, a plain translucent card otherwise.
  static const double groupHeaderRadius = 14;
  static const double groupHeaderMargin = 4;
  static const double groupHeaderHorizontalPadding = 12;
  static const double groupHeaderVerticalPadding = 8;
  static const double groupHeaderIconSize = 32;
  static const double groupHeaderIconGap = 12;
  static const double groupHeaderTitleGap = 2;
  static const double groupHeaderButtonSize = 32;
  static const double groupHeaderButtonIconSize = 18;
  static const double groupHeaderButtonGap = 4;

  // Group selector bar of the tab mode, floating over the proxy grid.
  static const double groupBarHeight = 44;
  static const double groupBarHorizontalMargin = 16;
  static const double groupBarTopMargin = 8;
  static const double groupBarRadius = 22;
  static const double groupBarInnerPadding = 4;
  static const double groupBarItemPadding = 14;
  static const double groupBarButtonSize = 36;
  static const double groupBarIconSize = 18;

  // Round floating action (delay test of the current group).
  static const double floatingButtonSize = 56;
  static const double floatingButtonIconSize = 24;
  static const double floatingButtonPressedScale = 0.92;

  // Empty and loading states.
  static const double emptyStateIconSize = 44;
  static const double emptyStateGap = 12;
  static const double emptyStatePadding = 32;
  static const double activityIndicatorRadius = 10;

  // Shadows cast by floating glass (tab bar, menus, sheets).
  static const List<BoxShadow> _floatingShadowLight = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];
  static const List<BoxShadow> _floatingShadowDark = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 28,
      offset: Offset(0, 10),
    ),
  ];

  // Motion. Zeroed by [GlassAccessibility.reduceMotion].
  static const Duration morphDuration = Duration(milliseconds: 240);
  static const Curve morphCurve = Curves.easeOutCubic;
  static const Duration hoverDuration = Duration(milliseconds: 120);

  static bool _isDark(Brightness brightness) => brightness == Brightness.dark;

  static double tintOpacity(Brightness brightness) =>
      _isDark(brightness) ? _tintOpacityDark : _tintOpacityLight;

  static double nativeBackdropTint(Brightness brightness) =>
      _isDark(brightness) ? _nativeBackdropTintDark : _nativeBackdropTintLight;

  static double rimTopOpacity(Brightness brightness) =>
      _isDark(brightness) ? _rimTopOpacityDark : _rimTopOpacityLight;

  static double rimBottomOpacity(Brightness brightness) =>
      _isDark(brightness) ? _rimBottomOpacityDark : _rimBottomOpacityLight;

  static double hairlineOpacity(Brightness brightness) =>
      _isDark(brightness) ? _hairlineOpacityDark : _hairlineOpacityLight;

  static double selectionOpacity(Brightness brightness) =>
      _isDark(brightness) ? _selectionOpacityDark : _selectionOpacityLight;

  static double hoverOpacity(Brightness brightness) =>
      _isDark(brightness) ? _hoverOpacityDark : _hoverOpacityLight;

  static double menuPressedOpacity(Brightness brightness) =>
      _isDark(brightness) ? _menuPressedOpacityDark : _menuPressedOpacityLight;

  static double cardFillOpacity(Brightness brightness) =>
      _isDark(brightness) ? _cardFillOpacityDark : _cardFillOpacityLight;

  static double cardSelectedOpacity(Brightness brightness) =>
      _isDark(brightness)
          ? _cardSelectedOpacityDark
          : _cardSelectedOpacityLight;

  static double delayPillOpacity(Brightness brightness) =>
      _isDark(brightness) ? _delayPillOpacityDark : _delayPillOpacityLight;

  static List<BoxShadow> floatingShadow(Brightness brightness) =>
      _isDark(brightness) ? _floatingShadowDark : _floatingShadowLight;

  static Duration motion(Duration duration, {required bool reduceMotion}) =>
      reduceMotion ? Duration.zero : duration;
}
