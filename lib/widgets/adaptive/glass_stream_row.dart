import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'glass_accessibility.dart';
import 'glass_tokens.dart';

/// The trailing swipe action of an iOS stream row ("Close"), as in Mail.
@immutable
class GlassSwipeAction {
  const GlassSwipeAction({
    required this.label,
    required this.onPressed,
    this.destructive = true,
  });

  final String label;
  final VoidCallback onPressed;

  /// System red (the default) instead of the accent.
  final bool destructive;
}

/// A flat row of a long live list (requests, connections, logs), in the
/// style of Console.app and Mail: on the window background, no card, a
/// hairline at the bottom from the row text to the trailing edge, a faint
/// wash on hover / press. Never blurred, so a list of thousands of rows has no
/// `BackdropFilter` at all.
///
/// The row fills the extent its list gives it; [extentOf] turns the height of
/// the content into that extent, so callers compute item extents from the
/// same tokens the row is painted with.
///
/// * [onContextMenu]: macOS right click / iOS long press, with the pointer
///   position (global) to anchor a menu at.
/// * [swipeAction]: iOS only, revealed by a swipe to the leading edge; a long
///   swipe runs it at once.
///
/// Darwin only; Material screens keep their `ListItem` rows.
class GlassStreamRow extends StatefulWidget {
  const GlassStreamRow({
    super.key,
    required this.child,
    this.onTap,
    this.onContextMenu,
    this.swipeAction,
    this.hairline = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onContextMenu;
  final GlassSwipeAction? swipeAction;

  /// Draws the bottom hairline.
  final bool hairline;

  static bool get _mac => defaultTargetPlatform == TargetPlatform.macOS;

  static double get horizontalPadding =>
      _mac ? GlassTokens.streamRowPaddingMac : GlassTokens.streamRowPaddingIos;

  static double get verticalPadding => _mac
      ? GlassTokens.streamRowVerticalPaddingMac
      : GlassTokens.streamRowVerticalPaddingIos;

  /// Gap between the text lines and the tag line below them.
  static double get tagGap =>
      _mac ? GlassTokens.streamRowTagGapMac : GlassTokens.streamRowTagGapIos;

  /// Width left for the content in a list [width] wide.
  static double contentWidth(double width) => width - 2 * horizontalPadding;

  /// Item extent of a row whose content is [contentHeight] tall. The hairline
  /// lies inside the bottom padding, so it adds nothing.
  static double extentOf(double contentHeight) =>
      contentHeight + 2 * verticalPadding;

  @override
  State<GlassStreamRow> createState() => _GlassStreamRowState();
}

class _GlassStreamRowState extends State<GlassStreamRow>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;

  /// Swipe offset, 0 (closed) .. -row width; negative = to the leading edge.
  /// Created on first use (iOS rows with a swipe action only), never from
  /// [dispose].
  AnimationController? _swipeController;
  AnimationController get _swipe => _swipeController ??= AnimationController(
        vsync: this,
        lowerBound: -double.maxFinite,
        upperBound: 0,
        value: 0,
      );
  double _width = 0;

  bool get _interactive => widget.onTap != null || widget.onContextMenu != null;

  GlassSwipeAction? get _swipeAction =>
      defaultTargetPlatform == TargetPlatform.iOS ? widget.swipeAction : null;

  @override
  void dispose() {
    _swipeController?.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  void _settle(double target) {
    final reduceMotion = GlassAccessibility.of(context).reduceMotion;
    if (reduceMotion) {
      _swipe.value = target;
      return;
    }
    _swipe.animateTo(
      target,
      duration: GlassTokens.swipeSettleDuration,
      curve: GlassTokens.morphCurve,
    );
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    _swipe.value = (_swipe.value + delta).clamp(-_width, 0);
  }

  void _onDragEnd(DragEndDetails details) {
    final action = _swipeAction;
    if (action == null) return;
    final offset = -_swipe.value;
    if (_width > 0 && offset >= _width * GlassTokens.swipeActionFullFraction) {
      _runSwipeAction(action);
      return;
    }
    final velocity = details.primaryVelocity ?? 0;
    final open = velocity < 0 ||
        (velocity == 0 && offset >= GlassTokens.swipeActionWidth / 2);
    _settle(open ? -GlassTokens.swipeActionWidth : 0);
  }

  void _runSwipeAction(GlassSwipeAction action) {
    _settle(0);
    action.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    final accessibility = GlassAccessibility.of(context);
    final washOpacity = !_interactive
        ? 0.0
        : _pressed
            ? GlassTokens.menuPressedOpacity(brightness)
            : _hovered
                ? GlassTokens.hoverOpacity(brightness)
                : 0.0;
    final hairlineColor = scheme.onSurface
        .withValues(alpha: GlassTokens.hairlineOpacity(brightness));

    Widget row = AnimatedContainer(
      duration: GlassTokens.motion(
        GlassTokens.hoverDuration,
        reduceMotion: accessibility.reduceMotion,
      ),
      color: scheme.onSurface.withValues(alpha: washOpacity),
      padding: EdgeInsets.symmetric(
        horizontal: GlassStreamRow.horizontalPadding,
        vertical: GlassStreamRow.verticalPadding,
      ),
      alignment: AlignmentDirectional.topStart,
      child: widget.child,
    );
    if (widget.hairline) {
      row = Stack(
        fit: StackFit.passthrough,
        children: [
          row,
          PositionedDirectional(
            start: GlassStreamRow.horizontalPadding,
            end: 0,
            bottom: 0,
            height: GlassTokens.hairlineWidth,
            child: ColoredBox(color: hairlineColor),
          ),
        ],
      );
    }
    if (_interactive) {
      final onContextMenu = widget.onContextMenu;
      row = MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: widget.onTap != null ? (_) => _setPressed(true) : null,
          onTapUp: widget.onTap != null ? (_) => _setPressed(false) : null,
          onTapCancel: widget.onTap != null ? () => _setPressed(false) : null,
          onSecondaryTapUp: onContextMenu == null
              ? null
              : (details) => onContextMenu(details.globalPosition),
          onLongPressStart: onContextMenu == null
              ? null
              : (details) => onContextMenu(details.globalPosition),
          child: row,
        ),
      );
    }
    final action = _swipeAction;
    if (action == null) return ClipRect(child: row);
    final actionColor =
        action.destructive ? GlassTokens.systemRed(brightness) : scheme.primary;
    return LayoutBuilder(
      builder: (_, constraints) {
        _width = constraints.maxWidth;
        return ClipRect(
          child: GestureDetector(
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            child: AnimatedBuilder(
              animation: _swipe,
              builder: (_, child) {
                final offset = _swipe.value;
                return Stack(
                  fit: StackFit.passthrough,
                  children: [
                    if (offset < 0)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        right: 0,
                        width: -offset,
                        child: GestureDetector(
                          onTap: () => _runSwipeAction(action),
                          child: ColoredBox(
                            color: actionColor,
                            child: Center(
                              child: Text(
                                action.label,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Transform.translate(
                      offset: Offset(offset, 0),
                      child: child,
                    ),
                  ],
                );
              },
              child: row,
            ),
          ),
        );
      },
    );
  }
}
