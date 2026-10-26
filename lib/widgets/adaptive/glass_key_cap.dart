import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_text_styles.dart';
import 'glass_tokens.dart';

bool get _mac => defaultTargetPlatform == TargetPlatform.macOS;

/// A keyboard shortcut as Apple draws it: one small rounded cap per key
/// (modifier symbols first, in the macOS order ⌃⌥⇧⌘), no "+" between
/// them. A flat fill with a hairline edge; content, so never blurred.
///
/// [large] is the recorder dialog size. Darwin only; the Material screens
/// keep their own key boxes.
class GlassKeyCaps extends StatelessWidget {
  const GlassKeyCaps({
    super.key,
    required this.keys,
    this.large = false,
    this.alignment = WrapAlignment.end,
  });

  /// Cap labels in display order: modifier symbols ([command] & co.), then
  /// the key ([labelOf]).
  final List<String> keys;
  final bool large;
  final WrapAlignment alignment;

  /// Apple symbols of the modifier keys.
  static const String control = '⌃';
  static const String option = '⌥';
  static const String shift = '⇧';
  static const String command = '⌘';
  static const String capsLock = '⇪';
  static const String function = 'fn';

  static final Map<LogicalKeyboardKey, String> _symbols = {
    LogicalKeyboardKey.arrowUp: '↑',
    LogicalKeyboardKey.arrowDown: '↓',
    LogicalKeyboardKey.arrowLeft: '←',
    LogicalKeyboardKey.arrowRight: '→',
    LogicalKeyboardKey.enter: '↩',
    LogicalKeyboardKey.numpadEnter: '⌤',
    LogicalKeyboardKey.escape: '⎋',
    LogicalKeyboardKey.backspace: '⌫',
    LogicalKeyboardKey.delete: '⌦',
    LogicalKeyboardKey.tab: '⇥',
    LogicalKeyboardKey.pageUp: '⇞',
    LogicalKeyboardKey.pageDown: '⇟',
    LogicalKeyboardKey.home: '↖',
    LogicalKeyboardKey.end: '↘',
    LogicalKeyboardKey.space: 'Space',
    LogicalKeyboardKey.controlLeft: control,
    LogicalKeyboardKey.controlRight: control,
    LogicalKeyboardKey.altLeft: option,
    LogicalKeyboardKey.altRight: option,
    LogicalKeyboardKey.shiftLeft: shift,
    LogicalKeyboardKey.shiftRight: shift,
    LogicalKeyboardKey.metaLeft: command,
    LogicalKeyboardKey.metaRight: command,
    LogicalKeyboardKey.capsLock: capsLock,
    LogicalKeyboardKey.fn: function,
  };

  /// Cap label of a (main) key: an Apple symbol where macOS menus show one,
  /// else the key label, else its debug name.
  static String labelOf(LogicalKeyboardKey key) {
    final symbol = _symbols[key];
    if (symbol != null) return symbol;
    if (key.keyLabel.isNotEmpty) return key.keyLabel.toUpperCase();
    return key.debugName ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    final height = large
        ? GlassTokens.keyCapLargeHeight
        : _mac
            ? GlassTokens.keyCapHeightMac
            : GlassTokens.keyCapHeightIos;
    final radius = large
        ? GlassTokens.keyCapLargeRadius
        : _mac
            ? GlassTokens.keyCapRadiusMac
            : GlassTokens.keyCapRadiusIos;
    final padding = large
        ? GlassTokens.keyCapLargePadding
        : _mac
            ? GlassTokens.keyCapPaddingMac
            : GlassTokens.keyCapPaddingIos;
    final gap = large ? GlassTokens.keyCapLargeGap : GlassTokens.keyCapGap;
    final style = GlassTextStyles.keyCap(theme.textTheme, large: large)
        .copyWith(color: scheme.onSurface);
    final decoration = BoxDecoration(
      color: scheme.onSurface
          .withValues(alpha: GlassTokens.keyCapFillOpacity(brightness)),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: scheme.onSurface
            .withValues(alpha: GlassTokens.keyCapEdgeOpacity(brightness)),
        width: GlassTokens.keyCapEdgeWidth,
      ),
    );
    return Semantics(
      label: keys.join(' '),
      excludeSemantics: true,
      child: Wrap(
        spacing: gap,
        runSpacing: gap,
        alignment: alignment,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final key in keys)
            Container(
              constraints: BoxConstraints(minWidth: height, minHeight: height),
              padding: EdgeInsets.symmetric(horizontal: padding),
              alignment: Alignment.center,
              decoration: decoration,
              child: Text(
                key,
                style: style,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
