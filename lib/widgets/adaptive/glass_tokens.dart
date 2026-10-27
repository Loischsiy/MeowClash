import 'package:flutter/widgets.dart';

import 'glass_motion.dart';

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

  // Specular rim: a thin edge, brighter at the top, as light catches glass.
  // Dark glass keeps it to a faint single device pixel on Retina: a full 1pt
  // white edge reads as a gray frame on a dark window.
  static const double _rimWidthLight = 1;
  static const double _rimWidthDark = 0.5;
  static const double _rimTopOpacityLight = 0.72;
  static const double _rimTopOpacityDark = 0.12;
  static const double _rimBottomOpacityLight = 0.10;
  static const double _rimBottomOpacityDark = 0.03;

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
  // Desktop side sheet (`showSheet` / `showExtend` on a wide window): a
  // floating panel, like the macOS 26 inspector — this gap to the window
  // edges and every corner rounded (the window's own corner never stands in
  // for the panel's).
  static const double sideSheetInset = 8;
  static const double sideSheetRadiusMac = 18;
  static const double sideSheetRadiusIos = 26;
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
  // Least distance between a menu and the safe-area edges.
  static const double menuScreenMargin = 8;
  // Choice menus: gap between the leading checkmark column and the label.
  static const double menuCheckGap = 8;
  // The menu grows from this scale to 1 while opening.
  static const double menuOpenScale = 0.85;
  static const double _menuPressedOpacityLight = 0.10;
  static const double _menuPressedOpacityDark = 0.14;
  // Text and icons of disabled menu rows, as alpha of the foreground.
  static const double disabledOpacity = 0.30;

  // Type scale of glass content, after the Apple HIG text styles: macOS
  // body 13 / caption 11 / title3 15, iOS subheadline 15 / footnote 13 /
  // caption 12 / headline 17. Sizes and line heights in logical px, resolved
  // per platform by `GlassTextStyles`.
  static const double cardTitleSizeMac = 13;
  static const double cardTitleLineMac = 16;
  static const double cardTitleSizeIos = 15;
  static const double cardTitleLineIos = 20;
  // Proxy description; one line, as tall as the delay badge beside it.
  static const double cardSubtitleSizeMac = 11;
  static const double cardSubtitleLineMac = 16;
  static const double cardSubtitleSizeIos = 13;
  static const double cardSubtitleLineIos = 18;
  // Delay badge label; the line height is the height of the capsule.
  static const double delayBadgeSizeMac = 11;
  static const double delayBadgeLineMac = 16;
  static const double delayBadgeSizeIos = 12;
  static const double delayBadgeLineIos = 18;
  static const double groupTitleSizeMac = 15;
  static const double groupTitleLineMac = 20;
  static const double groupTitleSizeIos = 17;
  static const double groupTitleLineIos = 22;
  static const double groupSubtitleSizeMac = 11;
  static const double groupSubtitleLineMac = 14;
  static const double groupSubtitleSizeIos = 13;
  static const double groupSubtitleLineIos = 18;

  // Content cards (proxy nodes). They scroll, so they never blur: a
  // translucent fill over the window background and a hairline edge, quieter
  // than the chrome's. The selected card is a light accent tint with a faint
  // accent edge — no thick outline; the check badge marks the choice.
  static const double cardRadius = 12;
  static const double _cardFillOpacityLight = 0.72;
  static const double _cardFillOpacityDark = 0.46;
  static const double _cardHairlineOpacityLight = 0.06;
  static const double _cardHairlineOpacityDark = 0.08;
  static const double _cardSelectedOpacityLight = 0.12;
  static const double _cardSelectedOpacityDark = 0.20;
  // Edge of the selected card, as alpha of the accent; hairline wide.
  static const double cardSelectedEdgeOpacity = 0.45;
  // Keyboard focus ring (macOS full keyboard access).
  static const double cardFocusBorderWidth = 1.5;
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

  // Page toolbar: the macOS window toolbar and the iOS navigation bar, after
  // macOS 26 / iOS 26. The bar itself is see-through (no blur of its own);
  // its buttons sit in glass capsules and the content under it fades out
  // (scroll edge). Heights exclude the top inset (title bar / status bar).
  static const double toolbarHeightMac = 52;
  static const double toolbarHeightIos = 44;
  // Title: macOS 15 semibold at the leading edge, iOS headline 17 semibold
  // in the middle.
  static const double toolbarTitleSizeMac = 15;
  static const double toolbarTitleLineMac = 20;
  static const double toolbarTitleSizeIos = 17;
  static const double toolbarTitleLineIos = 22;
  // iOS root pages (no back button): the buttons keep the 44 pt row and the
  // title gets a row of its own below it, large and at the leading edge, as
  // the iOS 26 large title (34 bold) of Mail / Settings. Its line sits
  // [toolbarLargeTitleBottomIos] above the row's bottom edge.
  static const double toolbarLargeTitleSizeIos = 34;
  static const double toolbarLargeTitleLineIos = 41;
  static const double toolbarLargeTitleHeightIos = 52;
  static const double toolbarLargeTitleBottomIos = 8;
  // Least space above the iOS bar where there is no status bar (iPhone in
  // landscape), so the capsules never touch the screen edge.
  static const double toolbarMinTopInsetIos = 8;
  // Distance of the outermost capsules from the bar edges, between capsules
  // and between the leading capsule and the title.
  static const double toolbarInsetMac = 12;
  static const double toolbarInsetIos = 16;
  static const double toolbarItemGap = 8;
  static const double toolbarTitleGap = 12;
  // Capsule height, which is also the width of each button in it.
  static const double toolbarItemSizeMac = 32;
  static const double toolbarItemSizeIos = 36;
  static const double toolbarIconSizeMac = 17;
  static const double toolbarIconSizeIos = 20;
  static const double toolbarItemSigma = 16;
  // Tint of a capsule painted inside a glass sheet, where it must not blur
  // again. Dark glass needs a denser fill to read as a filled disc (Apple's
  // sheet close button) rather than a bare rim; light stays at the native
  // wash, which already reads white.
  static const double _toolbarItemTintOverGlassLight = 0.18;
  static const double _toolbarItemTintOverGlassDark = 0.56;
  // SF Symbols `xmark` of close buttons, as fractions of the icon size: the
  // span of each stroke and its width.
  static const double closeGlyphSpan = 0.6;
  static const double closeGlyphStroke = 0.1;
  // Search field capsule (search mode): magnifier, text, clear button.
  static const double toolbarSearchSizeMac = 13;
  static const double toolbarSearchLineMac = 16;
  static const double toolbarSearchSizeIos = 17;
  static const double toolbarSearchLineIos = 22;
  static const double toolbarSearchIconSizeMac = 14;
  static const double toolbarSearchIconSizeIos = 17;
  static const double toolbarSearchPadding = 10;
  static const double toolbarSearchIconGap = 6;
  // Text action in a toolbar capsule ("Edit" / "Done"): body text on macOS
  // (13/16), the iOS bar button size (17/22); horizontal padding inside the
  // capsule.
  static const double toolbarActionSizeMac = 13;
  static const double toolbarActionLineMac = 16;
  static const double toolbarActionSizeIos = 17;
  static const double toolbarActionLineIos = 22;
  static const double toolbarActionPaddingMac = 10;
  static const double toolbarActionPaddingIos = 12;
  // Scroll edge: the window color behind the bar, solid down to
  // [toolbarFadeSolidStop] of the painted height, then fading out to nothing
  // [toolbarFadeExtent] below the bar's bottom edge. No blur, no hairline.
  static const double toolbarFadeExtent = 16;
  static const double toolbarFadeSolidStop = 0.6;
  static const double _toolbarFadeOpacityLight = 0.92;
  static const double _toolbarFadeOpacityDark = 0.88;
  // Capsules float a little above the bar: a soft drop and, in light mode,
  // a crisp contour (the white rim alone vanishes on a light window).
  static const List<BoxShadow> _toolbarItemShadowLight = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x12000000),
      blurRadius: 1,
    ),
  ];
  static const List<BoxShadow> _toolbarItemShadowDark = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  // Round floating action (delay test of the current group).
  static const double floatingButtonSize = 56;
  static const double floatingButtonIconSize = 24;
  static const double floatingButtonPressedScale = 0.92;
  // With a label the button becomes a capsule of the same height.
  static const double floatingButtonLabelPadding = 20;
  static const double floatingButtonLabelGap = 8;
  static const double floatingButtonLabelSize = 17;
  static const double floatingButtonLabelLine = 22;

  // Empty and loading states.
  static const double emptyStateIconSize = 44;
  static const double emptyStateGap = 12;
  static const double emptyStatePadding = 32;
  static const double activityIndicatorRadius = 10;

  // Profile cards: padding of the content and the gaps between its lines.
  static const double profileCardHorizontalPadding = 14;
  static const double profileCardVerticalPadding = 10;
  static const double profileCardLineGap = 4;
  static const double profileCardTrailingGap = 8;

  // Progress bar (subscription traffic): a thin capsule on a faint track,
  // no animation. The fill turns orange past [trafficWarningThreshold] and
  // red past [trafficCriticalThreshold] of the quota, in the Apple system
  // colors of the current appearance.
  static const double progressBarHeight = 4;
  static const double progressBarRadius = progressBarHeight / 2;
  static const double _progressTrackOpacityLight = 0.08;
  static const double _progressTrackOpacityDark = 0.14;
  static const double trafficWarningThreshold = 0.7;
  static const double trafficCriticalThreshold = 0.9;
  static const Color _systemGreenLight = Color(0xFF34C759);
  static const Color _systemGreenDark = Color(0xFF30D158);
  static const Color _systemOrangeLight = Color(0xFFFF9500);
  static const Color _systemOrangeDark = Color(0xFFFF9F0A);
  static const Color _systemRedLight = Color(0xFFFF3B30);
  static const Color _systemRedDark = Color(0xFFFF453A);

  // Rows of a plain list inside a glass sheet (profiles sort): flat
  // translucent cards, no blur, a trailing symbol.
  static const double listRowHeight = 44;
  static const double listRowHorizontalPadding = 12;
  static const double listRowIconSize = 20;
  // The dragged row grows to this scale (none with Reduce Motion).
  static const double listRowDragScale = 1.02;

  // Dialogs (alerts, prompts, pickers) and the large desktop modal: one glass
  // panel over an unblurred app (dimmed on iOS only). The panel is a bit
  // denser than the chrome so forms stay legible, yet the app still shows
  // through it.
  static const double dialogSigma = 30;
  static const double _dialogTintOpacityLight = 0.66;
  static const double _dialogTintOpacityDark = 0.55;
  // Dark mode: the panel is lifted above the window by a white wash over the
  // surface color, like the macOS / iOS alerts, instead of sinking into the
  // equally dark background.
  static const double _dialogLiftDark = 0.12;
  static const double dialogRadiusIos = 28;
  static const double dialogRadiusMac = 18;
  // Panel width (content is 300 wide inside the paddings, as before) and its
  // least distance to the window edges.
  static const double dialogWidth = 340;
  static const double dialogInset = 20;
  static const double dialogContentMaxHeight = 500;
  static const double dialogPadding = 20;
  static const double dialogTitleGap = 8;
  // Between the controls of a form inside a dialog (editors of override
  // rules and proxy chains).
  static const double dialogFieldGap = 12;
  // macOS: push buttons in a row at the trailing edge below the content.
  static const double dialogActionsGapMac = 16;
  static const double dialogButtonHeightMac = 28;
  static const double dialogButtonMinWidthMac = 72;
  static const double dialogButtonPaddingMac = 14;
  static const double dialogButtonGapMac = 8;
  static const double _dialogButtonFillOpacityLight = 0.07;
  static const double _dialogButtonFillOpacityDark = 0.14;
  // iOS: full-width buttons under a hairline; two side by side, three or
  // more stacked.
  static const double dialogContentBottomIos = 18;
  static const double dialogButtonHeightIos = 44;
  static const double dialogButtonPaddingIos = 8;
  static const int dialogSideBySideMaxIos = 2;
  static const double _dialogPressedOpacityLight = 0.08;
  static const double _dialogPressedOpacityDark = 0.12;
  // Type scale (Apple HIG): macOS title3 15 / body 13 / push button 13,
  // iOS headline 17 / subheadline 15 / alert button 17.
  static const double dialogTitleSizeMac = 15;
  static const double dialogTitleLineMac = 20;
  static const double dialogTitleSizeIos = 17;
  static const double dialogTitleLineIos = 22;
  static const double dialogMessageSizeMac = 13;
  static const double dialogMessageLineMac = 17;
  static const double dialogMessageSizeIos = 15;
  static const double dialogMessageLineIos = 20;
  static const double dialogButtonSizeMac = 13;
  static const double dialogButtonLineMac = 16;
  static const double dialogButtonSizeIos = 17;
  static const double dialogButtonLineIos = 22;
  // Dimming behind a dialog, as alpha of black. No blur behind it. macOS
  // does not dim the window under an alert: the shadow sets it apart and the
  // app keeps showing through the glass.
  static const double _dialogBarrierOpacityIosLight = 0.20;
  static const double _dialogBarrierOpacityIosDark = 0.30;
  // Appearance, as the system alerts: the panel fades in while shrinking
  // from [dialogEnterScale] to 1 (no scale with Reduce Motion) and only
  // fades out.
  static const double dialogEnterScale = 1.05;
  static const Duration dialogEnterDuration = Duration(milliseconds: 250);
  static const Duration dialogExitDuration = Duration(milliseconds: 160);
  static const Curve dialogCurve = Curves.easeOutCubic;

  // Text fields (dialogs, editors): a rounded filled field without an
  // outline. macOS draws the accent focus ring, iOS shows only the caret.
  static const double inputRadius = 10;
  static const double inputHorizontalPadding = 12;
  static const double inputVerticalPaddingMac = 8;
  static const double inputVerticalPaddingIos = 11;
  static const double inputFocusWidthMac = 2;
  static const double inputFocusOpacityMac = 0.55;
  static const double inputErrorWidth = 1;
  static const double _inputFillOpacityLight = 0.06;
  static const double _inputFillOpacityDark = 0.10;
  static const double inputTextSizeMac = 13;
  static const double inputTextLineMac = 17;
  static const double inputTextSizeIos = 17;
  static const double inputTextLineIos = 22;

  // Single-choice rows (pickers in dialogs): the checkmark marks the choice
  // instead of a radio button.
  static const double optionRowHeightMac = 32;
  static const double optionRowHeightIos = 44;
  static const double optionRowRadius = 8;
  static const double optionRowPadding = 12;
  static const double optionCheckSize = 18;

  // Grouped list sections (profile editors; later Settings): rows inside one
  // rounded inset card, as the grouped lists of iOS Settings and macOS
  // System Settings. They scroll, so they never blur: the card fill and
  // hairline edge of the content cards; rows are split by hairlines that
  // start at the row text.
  static const double listSectionRadiusMac = 10;
  static const double listSectionRadiusIos = 12;
  // Space between two sections, and between a section and its header or
  // footer text (which line up with the row text).
  static const double listSectionGapMac = 20;
  static const double listSectionGapIos = 28;
  static const double listSectionHeaderGap = 6;
  // Margin between the sections and the edges of the scroll view.
  static const double listInsetMac = 20;
  static const double listInsetIos = 16;
  static const double listInsetVerticalMac = 16;
  static const double listInsetVerticalIos = 20;
  static const double listSectionFooterGap = 6;
  // Rows: least height (one line), paddings, leading symbol.
  static const double listRowMinHeightMac = 36;
  static const double listRowMinHeightIos = 44;
  static const double listRowPaddingMac = 10;
  static const double listRowPaddingIos = 16;
  static const double listRowVerticalPaddingMac = 7;
  static const double listRowVerticalPaddingIos = 10;
  static const double listRowLeadingSizeMac = 18;
  static const double listRowLeadingSizeIos = 22;
  static const double listRowLeadingGapMac = 10;
  static const double listRowLeadingGapIos = 14;
  static const double listRowSubtitleGap = 2;
  static const double listRowTrailingGap = 8;
  static const double listRowChevronSizeMac = 14;
  static const double listRowChevronSizeIos = 18;
  // Chevron of rows that open something, as alpha of the secondary text.
  static const double listRowChevronOpacity = 0.6;

  /// Widest share of a row the current value (`GlassListRow.value`) may
  /// take before it is ellipsized, as in iOS Settings.
  static const double listRowValueMaxFraction = 0.5;
  // Action buttons under a row subtitle (provider upload / sync).
  static const double listRowActionsGap = 8;
  static const double listRowActionsSpacing = 8;
  // Filter capsules above a grouped list (media unlock categories).
  static const double filterCapsuleGap = 8;
  // Type scale: macOS body 13 / caption 11 / headline 13, iOS body 17 /
  // subheadline 15 / footnote 13.
  static const double listRowTitleSizeMac = 13;
  static const double listRowTitleLineMac = 16;
  static const double listRowTitleSizeIos = 17;
  static const double listRowTitleLineIos = 22;
  static const double listRowSubtitleSizeMac = 11;
  static const double listRowSubtitleLineMac = 14;
  static const double listRowSubtitleSizeIos = 15;
  static const double listRowSubtitleLineIos = 20;
  static const double listSectionHeaderSizeMac = 13;
  static const double listSectionHeaderLineMac = 16;
  static const double listSectionHeaderSizeIos = 13;
  static const double listSectionHeaderLineIos = 18;
  static const double listSectionFooterSizeMac = 11;
  static const double listSectionFooterLineMac = 14;
  static const double listSectionFooterSizeIos = 13;
  static const double listSectionFooterLineIos = 18;
  // Keyboard shortcuts as key caps (hotkeys page, shortcut recorder): the
  // modifiers in the macOS order ⌃⌥⇧⌘, then the key, each on a small
  // rounded cap with a hairline edge. Content, so never blurred.
  static const double keyCapHeightMac = 20;
  static const double keyCapHeightIos = 26;
  static const double keyCapLargeHeight = 44;
  static const double keyCapRadiusMac = 5;
  static const double keyCapRadiusIos = 6;
  static const double keyCapLargeRadius = 10;
  static const double keyCapPaddingMac = 6;
  static const double keyCapPaddingIos = 8;
  static const double keyCapLargePadding = 14;
  static const double keyCapGap = 4;
  static const double keyCapLargeGap = 8;
  static const double keyCapTextSizeMac = 12;
  static const double keyCapTextLineMac = 16;
  static const double keyCapTextSizeIos = 15;
  static const double keyCapTextLineIos = 20;
  static const double keyCapLargeTextSize = 20;
  static const double keyCapLargeTextLine = 24;
  static const double keyCapEdgeWidth = 0.5;
  static const double _keyCapFillOpacityLight = 0.06;
  static const double _keyCapFillOpacityDark = 0.12;
  static const double _keyCapEdgeOpacityLight = 0.14;
  static const double _keyCapEdgeOpacityDark = 0.2;
  // Reachability of a remote account (WebDAV backup): a dot in the system
  // green / red, a spinner of the same size while it is checked.
  static const double statusDotSize = 8;
  static const double statusSpinnerRadius = 6;
  static const double statusGap = 6;
  // About page header: app icon, name and versions centered above the
  // sections, as the macOS About window and iOS app info.
  static const double aboutIconSizeMac = 64;
  static const double aboutIconSizeIos = 80;
  static const double aboutIconRadiusMac = 14;
  static const double aboutIconRadiusIos = 18;
  static const double aboutHeaderGap = 8;
  static const double aboutTitleSizeMac = 20;
  static const double aboutTitleLineMac = 24;
  static const double aboutTitleSizeIos = 22;
  static const double aboutTitleLineIos = 28;
  static const double aboutAvatarSize = 48;
  static const double aboutAvatarGap = 16;
  // Theme page: appearance previews (Auto / Light / Dark) as in macOS
  // Appearance, accent swatches as the macOS accent color row, the text
  // size slider as in iOS Text Size. Content, so never blurred.
  static const double themePreviewWidthMac = 68;
  static const double themePreviewWidthIos = 84;
  static const double themePreviewHeightMac = 46;
  static const double themePreviewHeightIos = 56;
  static const double themePreviewRadiusMac = 7;
  static const double themePreviewRadiusIos = 10;
  static const double themePreviewInset = 6;
  static const double themePreviewBarFraction = 0.22;
  static const double themePreviewPillWidthFraction = 0.45;
  static const double themePreviewPillHeight = 6;
  static const double themePreviewLineWidthFraction = 0.7;
  static const double themePreviewLineHeight = 4;
  static const double themePreviewLineGap = 4;
  static const double themePreviewRingWidth = 2.5;
  static const double themePreviewRingGap = 2;
  static const double themePreviewLabelGap = 6;
  static const double themePickerPaddingMac = 12;
  static const double themePickerPaddingIos = 16;
  static const Color themePreviewLightFill = Color(0xFFF2F2F7);
  static const Color themePreviewLightBar = Color(0xFFFFFFFF);
  static const Color themePreviewLightLine = Color(0xFFD1D1D6);
  static const Color themePreviewDarkFill = Color(0xFF1C1C1E);
  static const Color themePreviewDarkBar = Color(0xFF2C2C2E);
  static const Color themePreviewDarkLine = Color(0xFF48484A);
  static const double themeSwatchSizeMac = 22;
  static const double themeSwatchSizeIos = 30;
  static const double themeSwatchGapMac = 10;
  static const double themeSwatchGapIos = 14;
  static const double themeSwatchRingWidth = 2;
  static const double themeSwatchRingGap = 2;
  static const double themeSwatchCheckFraction = 0.6;
  static const double themeSwatchEdgeWidth = 0.5;
  static const double themeSwatchRowPaddingMac = 10;
  static const double themeSwatchRowPaddingIos = 14;
  // Multicolor swatch (follow the system accent), the macOS accent order.
  static const List<Color> themeSwatchMulticolor = [
    Color(0xFFFF3B30),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF007AFF),
    Color(0xFFAF52DE),
    Color(0xFFFF2D55),
    Color(0xFFFF3B30),
  ];
  // macOS slider: thin AppKit track, small white knob (iOS uses the stock
  // CupertinoSlider).
  static const double sliderTrackHeightMac = 4;
  static const double sliderThumbRadiusMac = 9;
  static const double sliderThumbElevationMac = 1.5;
  static const double _sliderTrackOpacityLight = 0.12;
  static const double _sliderTrackOpacityDark = 0.24;
  // Small and large "A" at the ends of the text size slider.
  static const double scaleGlyphSmallSizeMac = 11;
  static const double scaleGlyphSmallLineMac = 14;
  static const double scaleGlyphLargeSizeMac = 17;
  static const double scaleGlyphLargeLineMac = 20;
  static const double scaleGlyphSmallSizeIos = 13;
  static const double scaleGlyphSmallLineIos = 16;
  static const double scaleGlyphLargeSizeIos = 22;
  static const double scaleGlyphLargeLineIos = 26;
  static const double scaleGlyphGap = 12;
  // Rules of a profile override: a long reorderable list, so one small
  // content card per rule instead of a grouped section; monospaced value and
  // a selection circle at the end, as in Mail's edit mode.
  static const double ruleRowGap = 6;
  static const double ruleRowVerticalPaddingMac = 8;
  static const double ruleRowVerticalPaddingIos = 12;
  static const double ruleCheckSizeMac = 18;
  static const double ruleCheckSizeIos = 22;
  static const double ruleTextSizeMac = 12;
  static const double ruleTextLineMac = 16;
  static const double ruleTextSizeIos = 15;
  static const double ruleTextLineIos = 20;

  // Switch: the Cupertino switch in the accent. Its track is 31 pt tall in a
  // 39 pt box (focus margin); macOS scales it down to the 22 pt track of the
  // AppKit switch.
  static const double switchTrackHeightIos = 31;
  static const double switchBoxHeightIos = 39;
  static const double switchTrackHeightMac = 22;

  // Push buttons inside content (editor actions): capsules, tinted with the
  // accent (or filled for the main action), never blurred.
  static const double buttonHeightMac = 28;
  static const double buttonHeightIos = 34;
  static const double buttonPaddingMac = 12;
  static const double buttonPaddingIos = 14;
  static const double buttonIconSizeMac = 14;
  static const double buttonIconSizeIos = 17;
  static const double buttonIconGap = 6;
  static const double buttonTextSizeMac = 13;
  static const double buttonTextLineMac = 16;
  static const double buttonTextSizeIos = 15;
  static const double buttonTextLineIos = 20;
  static const double _buttonTintOpacityLight = 0.12;
  static const double _buttonTintOpacityDark = 0.22;

  // Tags: small capsules inside long lists (proxy chain, log level) and the
  // keyword filters above them. Never blurred: a faint neutral, accent or
  // system-color wash only. `Large` is the removable filter capsule.
  static const double tagHeightMac = 18;
  static const double tagHeightIos = 22;
  static const double tagLargeHeightMac = 24;
  static const double tagLargeHeightIos = 30;
  static const double tagPaddingMac = 7;
  static const double tagPaddingIos = 8;
  static const double tagLargePaddingMac = 10;
  static const double tagLargePaddingIos = 12;
  static const double tagGap = 6;
  static const double tagTextSizeMac = 11;
  static const double tagTextLineMac = 14;
  static const double tagTextSizeIos = 13;
  static const double tagTextLineIos = 18;
  static const double tagLargeTextSizeMac = 12;
  static const double tagLargeTextLineMac = 16;
  static const double tagLargeTextSizeIos = 15;
  static const double tagLargeTextLineIos = 20;
  static const double tagRemoveIconSizeMac = 12;
  static const double tagRemoveIconSizeIos = 15;
  static const double tagRemoveGap = 4;
  static const double _tagFillOpacityLight = 0.06;
  static const double _tagFillOpacityDark = 0.12;
  static const double _tagTintOpacityLight = 0.14;
  static const double _tagTintOpacityDark = 0.24;
  // Keyword filter bar above a stream page.
  static const double filterBarPaddingMac = 12;
  static const double filterBarPaddingIos = 16;
  static const double filterBarVerticalPadding = 8;

  // Stream rows: flat rows of long live lists (requests, connections, logs),
  // like Console.app / Mail — on the window background, no card, a hairline
  // from the row text to the trailing edge. Fixed heights so the lists can
  // use item extents.
  static const double streamRowPaddingMac = 16;
  static const double streamRowPaddingIos = 16;
  static const double streamRowVerticalPaddingMac = 8;
  static const double streamRowVerticalPaddingIos = 10;
  static const double streamRowLineGap = 2;
  static const double streamRowTagGapMac = 6;
  static const double streamRowTagGapIos = 8;
  static const double streamRowTrailingGap = 8;
  static const double streamRowCloseSizeMac = 24;
  static const double streamRowCloseSizeIos = 30;
  static const double streamRowCloseIconSizeMac = 14;
  static const double streamRowCloseIconSizeIos = 17;
  // `SelectableText` lays its text out narrower than its box by the caret
  // (`RenderEditable`: 1 px gap + 2 px cursor). Measured heights subtract it.
  static const double selectableCaretReserve = 3;
  // iOS trailing swipe action ("Close"), as in Mail.
  static const double swipeActionWidth = 84;
  // A swipe past this share of the row width runs the action at once.
  static const double swipeActionFullFraction = 0.6;
  static const Duration swipeSettleDuration = Duration(milliseconds: 250);

  // Overlay scrollbar of long lists. macOS: the thin AppKit overlay scroller
  // that fades out when the list rests; iOS: `CupertinoScrollbar` (its own
  // metrics).
  static const double scrollbarThicknessMac = 6;
  static const double scrollbarMarginMac = 3;
  static const double _scrollbarOpacityLight = 0.38;
  static const double _scrollbarOpacityDark = 0.42;
  static const Duration scrollbarFadeDuration = Duration(milliseconds: 200);
  static const Duration scrollbarTimeToFade = Duration(milliseconds: 900);

  // Further system colors (log levels: debug gray, info blue).
  static const Color _systemBlueLight = Color(0xFF007AFF);
  static const Color _systemBlueDark = Color(0xFF0A84FF);
  static const Color _systemGrayLight = Color(0xFF8E8E93);
  static const Color _systemGrayDark = Color(0xFF98989D);

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

  // Opening a settings sub-page. All zeroed by [GlassAccessibility.reduceMotion].
  // iPhone: UINavigationController push (slide in from the right, parallax of
  // the page below, back swipe from the left edge).
  static const Duration pushDuration = Duration(milliseconds: 500);
  // macOS / iPad full-window page: a NavigationStack push (slide in from the
  // trailing edge, no back swipe for the mouse). Never a cross-fade: an
  // Opacity over a glass page would flatten its blur.
  static const Duration desktopPushDuration = Duration(milliseconds: 350);
  // Side sheet (macOS / iPad): the floating glass panel slides in from the
  // trailing edge on `.spring(response: 0.45, dampingFraction: 0.9)` and
  // leaves on a plain ease. The exit curve is applied to the falling route
  // value, so ease-out here means "starts slow, leaves fast".
  static const double sideSheetSpringResponse = 0.45;
  static const double sideSheetSpringDamping = 0.9;
  static const Duration sideSheetEnterDuration = Duration(milliseconds: 450);
  static const Duration sideSheetExitDuration = Duration(milliseconds: 250);
  static const Curve sideSheetEnterCurve = GlassSpringCurve(
    response: sideSheetSpringResponse,
    dampingFraction: sideSheetSpringDamping,
    duration: sideSheetEnterDuration,
  );
  static const Curve sideSheetExitCurve = Curves.easeOutCubic;

  // Dashboard widget tiles, after the macOS 26 / iOS 26 widgets: a larger
  // corner than the proxy cards, the symbol in the accent next to a small
  // secondary title, and large tabular figures. They live in a scrolling
  // grid, so they never blur (fill and edge are the content card's).
  static const double widgetTileRadiusMac = 16;
  static const double widgetTileRadiusIos = 20;
  static const double widgetTilePaddingMac = 12;
  static const double widgetTilePaddingIos = 14;
  static const double widgetTileSymbolSizeMac = 13;
  static const double widgetTileSymbolSizeIos = 15;
  static const double widgetTileSymbolGap = 5;
  static const double widgetTitleSizeMac = 11;
  static const double widgetTitleLineMac = 14;
  static const double widgetTitleSizeIos = 13;
  static const double widgetTitleLineIos = 16;
  static const double widgetValueSizeMac = 20;
  static const double widgetValueLineMac = 24;
  static const double widgetValueSizeIos = 24;
  static const double widgetValueLineIos = 29;
  static const double widgetCaptionSizeMac = 11;
  static const double widgetCaptionLineMac = 14;
  static const double widgetCaptionSizeIos = 12;
  static const double widgetCaptionLineIos = 16;
  // Gap between stacked lines inside a tile (value over caption, legend).
  static const double widgetLineGap = 2;
  static const double widgetRowGap = 8;
  // Spinner of a tile still loading its value.
  static const double widgetSpinnerRadius = 8;

  /// Spinner inside a widget row (media-unlock status slot).
  static const double widgetInlineSpinnerRadius = 5;
  // Small borderless button at the trailing edge of a tile header (ⓘ).
  static const double widgetHeaderButtonSizeMac = 22;
  static const double widgetHeaderButtonSizeIos = 28;
  static const double widgetHeaderButtonIconSizeMac = 14;
  static const double widgetHeaderButtonIconSizeIos = 16;

  /// Between two header buttons of a widget tile.
  static const double widgetHeaderButtonGap = 4;
  // Cross-fade when a tile swaps its content (loading → value → error).
  static const Duration widgetContentFadeDuration = Duration(milliseconds: 200);

  // Start/Stop button (the cat). The shape and the cat stay; the fill is a
  // system color: green when connected, a neutral gray fill (secondarySystem
  // Fill) when idle and an accent tint while connecting. A press dims the fill
  // instead of scaling the button.
  /// Minimum height: the button grows with larger text instead of clipping.
  static const double startButtonHeight = 96;
  static const double startButtonMargin = 16;
  static const double startButtonRadiusMac = 16;
  static const double startButtonRadiusIos = 22;
  static const double startButtonPaddingH = 16;
  static const double startButtonPaddingV = 8;
  static const double startButtonCatSize = 80;
  static const double startButtonCatGap = 12;
  static const double startButtonTitleGap = 4;
  static const double startButtonActionGap = 4;
  // Title: title2 on macOS (17/22), title3 on iOS (20/25), semibold.
  static const double startButtonTitleSizeMac = 17;
  static const double startButtonTitleLineMac = 22;
  static const double startButtonTitleSizeIos = 20;
  static const double startButtonTitleLineIos = 25;
  // Status line: body on macOS (13/16), subheadline on iOS (15/20).
  static const double startButtonStatusSizeMac = 13;
  static const double startButtonStatusLineMac = 16;
  static const double startButtonStatusSizeIos = 15;
  static const double startButtonStatusLineIos = 20;

  /// Opacity of the status line under the title.
  static const double startButtonStatusOpacity = 0.85;
  static const Color _startButtonIdleBase = Color(0xFF787880);
  static const double _startButtonIdleOpacityLight = 0.16;
  static const double _startButtonIdleOpacityDark = 0.32;
  static const double _startButtonConnectingOpacityLight = 0.16;
  static const double _startButtonConnectingOpacityDark = 0.28;

  /// Opacity of the whole button while pressed.
  static const double startButtonPressedOpacity = 0.8;

  /// The cat's eyes on the green fill.
  static const Color startButtonCatAccentConnected = Color(0xFFFFE082);
  static const Color startButtonForegroundConnected = Color(0xFFFFFFFF);

  /// Letter spacing of the "···" progress dots while connecting.
  static const double startButtonDotsSpacing = 4;
  static const Duration startButtonFillDuration = Duration(milliseconds: 350);

  // Dashboard editing: round badges at the top leading corner of a tile, as on
  // the iOS home screen and macOS widgets — a neutral "−" to remove, a green
  // "+" to add. They sit [editBadgeOffset] outside the tile corner.
  static const double editBadgeSizeMac = 20;
  static const double editBadgeSizeIos = 24;
  static const double editBadgeIconSizeMac = 14;
  static const double editBadgeIconSizeIos = 18;
  static const double editBadgeOffset = -8;
  static const Color _editBadgeRemoveFillLight = Color(0xFFE5E5EA);
  static const Color _editBadgeRemoveFillDark = Color(0xFF3A3A3C);
  static const Color editBadgeAddGlyph = Color(0xFFFFFFFF);

  // Segmented control (dashboard mode picker), as in System Settings: a
  // recessed capsule track and a neutral raised thumb — never the accent.
  static const double segmentedHeightMac = 24;
  static const double segmentedHeightIos = 32;
  static const double segmentedLargeHeightMac = 30;
  static const double segmentedLargeHeightIos = 36;
  static const double segmentedInset = 2;
  static const double segmentedTextSizeMac = 13;
  static const double segmentedTextLineMac = 16;
  static const double segmentedTextSizeIos = 13;
  static const double segmentedTextLineIos = 18;
  // Track: a gray fill (tertiarySystemFill), as alpha of [_segmentedTrackBase].
  static const Color _segmentedTrackBase = Color(0xFF767680);
  static const double _segmentedTrackOpacityLight = 0.12;
  static const double _segmentedTrackOpacityDark = 0.24;
  static const Color _segmentedThumbLight = Color(0xFFFFFFFF);
  static const Color _segmentedThumbDark = Color(0xFF636366);
  static const List<BoxShadow> _segmentedThumbShadowLight = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 3)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 1, offset: Offset(0, 3)),
  ];
  static const List<BoxShadow> _segmentedThumbShadowDark = [
    BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3)),
  ];
  static const Duration segmentedDuration = Duration(milliseconds: 220);
  static const Curve segmentedCurve = Curves.easeOutCubic;

  // Dashboard charts, colored as Activity Monitor's network graph:
  // received (down) blue, sent (up) orange. Thin line, faint fill.
  static const double chartLineWidth = 1.5;
  static const double chartFillTopOpacity = 0.22;
  static const double chartFillBottomOpacity = 0;
  static const double chartLegendDotSize = 8;
  static const double chartLegendGap = 6;
  static const double chartDonutStrokeFraction = 0.16;

  static bool _isDark(Brightness brightness) => brightness == Brightness.dark;

  static double tintOpacity(Brightness brightness) =>
      _isDark(brightness) ? _tintOpacityDark : _tintOpacityLight;

  static double nativeBackdropTint(Brightness brightness) =>
      _isDark(brightness) ? _nativeBackdropTintDark : _nativeBackdropTintLight;

  static double rimWidth(Brightness brightness) =>
      _isDark(brightness) ? _rimWidthDark : _rimWidthLight;

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

  static double cardHairlineOpacity(Brightness brightness) =>
      _isDark(brightness)
          ? _cardHairlineOpacityDark
          : _cardHairlineOpacityLight;

  static double cardSelectedOpacity(Brightness brightness) =>
      _isDark(brightness)
          ? _cardSelectedOpacityDark
          : _cardSelectedOpacityLight;

  static double delayPillOpacity(Brightness brightness) =>
      _isDark(brightness) ? _delayPillOpacityDark : _delayPillOpacityLight;

  static double progressTrackOpacity(Brightness brightness) =>
      _isDark(brightness)
          ? _progressTrackOpacityDark
          : _progressTrackOpacityLight;

  /// Fill of a traffic bar at [progress] (0..1 of the quota).
  static Color trafficColor(double progress, Brightness brightness) {
    final dark = _isDark(brightness);
    if (progress > trafficCriticalThreshold) {
      return dark ? _systemRedDark : _systemRedLight;
    }
    if (progress > trafficWarningThreshold) {
      return dark ? _systemOrangeDark : _systemOrangeLight;
    }
    return dark ? _systemGreenDark : _systemGreenLight;
  }

  /// Reachability dot: system green when [ok], else system red.
  static Color statusColor({required bool ok, required Brightness brightness}) {
    final dark = _isDark(brightness);
    if (ok) return dark ? _systemGreenDark : _systemGreenLight;
    return dark ? _systemRedDark : _systemRedLight;
  }

  /// System colors of a check result (media unlock): passed / partial /
  /// failed.
  static Color systemGreen(Brightness brightness) =>
      _isDark(brightness) ? _systemGreenDark : _systemGreenLight;

  static Color systemOrange(Brightness brightness) =>
      _isDark(brightness) ? _systemOrangeDark : _systemOrangeLight;

  static Color systemRed(Brightness brightness) =>
      _isDark(brightness) ? _systemRedDark : _systemRedLight;

  static Color systemBlue(Brightness brightness) =>
      _isDark(brightness) ? _systemBlueDark : _systemBlueLight;

  static Color systemGray(Brightness brightness) =>
      _isDark(brightness) ? _systemGrayDark : _systemGrayLight;

  static double tagFillOpacity(Brightness brightness) =>
      _isDark(brightness) ? _tagFillOpacityDark : _tagFillOpacityLight;

  static double tagTintOpacity(Brightness brightness) =>
      _isDark(brightness) ? _tagTintOpacityDark : _tagTintOpacityLight;

  static double scrollbarOpacity(Brightness brightness) =>
      _isDark(brightness) ? _scrollbarOpacityDark : _scrollbarOpacityLight;

  static double sliderTrackOpacity(Brightness brightness) =>
      _isDark(brightness) ? _sliderTrackOpacityDark : _sliderTrackOpacityLight;

  static double keyCapFillOpacity(Brightness brightness) =>
      _isDark(brightness) ? _keyCapFillOpacityDark : _keyCapFillOpacityLight;

  static double keyCapEdgeOpacity(Brightness brightness) =>
      _isDark(brightness) ? _keyCapEdgeOpacityDark : _keyCapEdgeOpacityLight;

  static double dialogTintOpacity(Brightness brightness) =>
      _isDark(brightness) ? _dialogTintOpacityDark : _dialogTintOpacityLight;

  static double dialogButtonFillOpacity(Brightness brightness) =>
      _isDark(brightness)
          ? _dialogButtonFillOpacityDark
          : _dialogButtonFillOpacityLight;

  static double dialogPressedOpacity(Brightness brightness) =>
      _isDark(brightness)
          ? _dialogPressedOpacityDark
          : _dialogPressedOpacityLight;

  static Color dialogBarrierColor(Brightness brightness, {required bool mac}) =>
      const Color(0xFF000000).withValues(
        alpha: mac
            ? 0
            : _isDark(brightness)
                ? _dialogBarrierOpacityIosDark
                : _dialogBarrierOpacityIosLight,
      );

  /// Tint color of a dialog panel made from the theme [surface].
  static Color dialogTint(Color surface, Brightness brightness) =>
      _isDark(brightness)
          ? Color.alphaBlend(
              const Color(0xFFFFFFFF).withValues(alpha: _dialogLiftDark),
              surface,
            )
          : surface;

  static double buttonTintOpacity(Brightness brightness) =>
      _isDark(brightness) ? _buttonTintOpacityDark : _buttonTintOpacityLight;

  static double inputFillOpacity(Brightness brightness) =>
      _isDark(brightness) ? _inputFillOpacityDark : _inputFillOpacityLight;

  static List<BoxShadow> floatingShadow(Brightness brightness) =>
      _isDark(brightness) ? _floatingShadowDark : _floatingShadowLight;

  static double toolbarFadeOpacity(Brightness brightness) =>
      _isDark(brightness) ? _toolbarFadeOpacityDark : _toolbarFadeOpacityLight;

  static double toolbarItemTintOverGlass(Brightness brightness) =>
      _isDark(brightness)
          ? _toolbarItemTintOverGlassDark
          : _toolbarItemTintOverGlassLight;

  static List<BoxShadow> toolbarItemShadow(Brightness brightness) =>
      _isDark(brightness) ? _toolbarItemShadowDark : _toolbarItemShadowLight;

  static double widgetTileRadius({required bool mac}) =>
      mac ? widgetTileRadiusMac : widgetTileRadiusIos;

  static double editBadgeSize({required bool mac}) =>
      mac ? editBadgeSizeMac : editBadgeSizeIos;

  static double editBadgeIconSize({required bool mac}) =>
      mac ? editBadgeIconSizeMac : editBadgeIconSizeIos;

  /// Fill of the "−" badge (systemGray5); the glyph is the label color.
  static Color editBadgeRemoveFill(Brightness brightness) => _isDark(brightness)
      ? _editBadgeRemoveFillDark
      : _editBadgeRemoveFillLight;

  static Color segmentedTrack(Brightness brightness) =>
      _segmentedTrackBase.withValues(
        alpha: _isDark(brightness)
            ? _segmentedTrackOpacityDark
            : _segmentedTrackOpacityLight,
      );

  static Color segmentedThumb(Brightness brightness) =>
      _isDark(brightness) ? _segmentedThumbDark : _segmentedThumbLight;

  static List<BoxShadow> segmentedThumbShadow(Brightness brightness) =>
      _isDark(brightness)
          ? _segmentedThumbShadowDark
          : _segmentedThumbShadowLight;

  /// Received traffic (↓) in dashboard charts.
  static Color chartDownload(Brightness brightness) => systemBlue(brightness);

  /// Sent traffic (↑) in dashboard charts.
  static Color chartUpload(Brightness brightness) =>
      _isDark(brightness) ? _systemOrangeDark : _systemOrangeLight;

  static double startButtonRadius({required bool mac}) =>
      mac ? startButtonRadiusMac : startButtonRadiusIos;

  /// Fill of the idle Start button: a neutral system fill, never the accent.
  static Color startButtonIdleFill(Brightness brightness) =>
      _startButtonIdleBase.withValues(
        alpha: _isDark(brightness)
            ? _startButtonIdleOpacityDark
            : _startButtonIdleOpacityLight,
      );

  /// Fill of the Start button while connecting / disconnecting.
  static Color startButtonConnectingFill(Color accent, Brightness brightness) =>
      accent.withValues(
        alpha: _isDark(brightness)
            ? _startButtonConnectingOpacityDark
            : _startButtonConnectingOpacityLight,
      );

  static Duration motion(Duration duration, {required bool reduceMotion}) =>
      reduceMotion ? Duration.zero : duration;
}
