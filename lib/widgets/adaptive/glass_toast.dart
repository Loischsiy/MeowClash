import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'glass_accessibility.dart';
import 'glass_surface.dart';
import 'glass_text_styles.dart';
import 'glass_tokens.dart';

/// The glass toast banner of the Darwin app notifier (`MessageManager`).
///
/// One [GlassSurface] (a single `BackdropFilter`) with the message and an
/// optional trailing text action, like a macOS Notification Center banner or
/// the iOS system HUD banners. It floats over the app, never inside
/// scrolling content. Reduce Transparency and the blur kill switch make it
/// opaque through [GlassSurface].
///
/// Animate it with [GlassToastSwitcher], which feeds the appearance progress
/// in as [GlassSurface.presence] (no `Opacity` above the blur).
class GlassToast extends StatelessWidget {
  const GlassToast({
    super.key,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final String text;

  /// Trailing action ("Logs"); shown only together with [onAction].
  final String? actionLabel;
  final VoidCallback? onAction;

  static bool get _mac => defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final presence = _GlassToastPresence.of(context);
    final label = actionLabel;
    final action = onAction;
    final textStyle = GlassTextStyles.toast(theme.textTheme)
        .copyWith(color: theme.colorScheme.onSurface);

    Widget content = Text(
      text,
      style: textStyle,
      maxLines: GlassTokens.toastMaxLines,
      overflow: TextOverflow.ellipsis,
    );
    if (label != null && action != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: content),
          const SizedBox(width: GlassTokens.toastActionGap),
          _GlassToastAction(label: label, onPressed: action),
        ],
      );
    }

    return Semantics(
      container: true,
      liveRegion: true,
      child: GlassSurface(
        sigma: GlassTokens.menuSigma,
        borderRadius: BorderRadius.circular(
          _mac ? GlassTokens.toastRadiusMac : GlassTokens.toastRadiusIos,
        ),
        shadow: true,
        tintOpacity: GlassTokens.dialogTintOpacity(brightness),
        opaqueColor: theme.colorScheme.surfaceContainerHigh,
        presence: presence,
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: GlassTokens.toastPaddingHorizontal,
              vertical: GlassTokens.toastPaddingVertical,
            ),
            // The content fades inside the surface; the surface itself
            // scales its blur with [presence] instead of an `Opacity`.
            child: presence == 1
                ? content
                : Opacity(opacity: presence, child: content),
          ),
        ),
      ),
    );
  }
}

class _GlassToastAction extends StatelessWidget {
  const _GlassToastAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Text(
            label,
            style: GlassTextStyles.toastAction(theme.textTheme)
                .copyWith(color: theme.colorScheme.primary),
          ),
        ),
      ),
    );
  }
}

/// Swaps toasts: the new one drops in from above on a spring while the old
/// one fades away. Pass a [GlassToast] with a unique key, or
/// `SizedBox.shrink()` when there is nothing to show.
///
/// Reduce Motion: the toast appears and disappears at once, with no slide.
class GlassToastSwitcher extends StatelessWidget {
  const GlassToastSwitcher({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;

  /// Where toasts sit while two of them overlap during the swap.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = GlassAccessibility.of(context).reduceMotion;
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : GlassTokens.toastEnterDuration,
      reverseDuration:
          reduceMotion ? Duration.zero : GlassTokens.toastExitDuration,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) => _GlassToastTransition(
        animation: animation,
        slide: !reduceMotion,
        child: child,
      ),
      child: child,
    );
  }
}

class _GlassToastTransition extends StatefulWidget {
  const _GlassToastTransition({
    required this.animation,
    required this.slide,
    required this.child,
  });

  final Animation<double> animation;
  final bool slide;
  final Widget child;

  @override
  State<_GlassToastTransition> createState() => _GlassToastTransitionState();
}

class _GlassToastTransitionState extends State<_GlassToastTransition> {
  late CurvedAnimation _curve = _curved(widget.animation);

  static CurvedAnimation _curved(Animation<double> parent) => CurvedAnimation(
        parent: parent,
        curve: GlassTokens.toastEnterCurve,
        // The exit runs 1 → 0, so the flipped ease leaves quickly first.
        reverseCurve: GlassTokens.toastExitCurve.flipped,
      );

  @override
  void didUpdateWidget(_GlassToastTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _curve.dispose();
      _curve = _curved(widget.animation);
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _curve,
        builder: (context, child) {
          // The spring overshoots a little: the slide keeps it, presence
          // (blur, fill and fade) stays within 0..1.
          final value = _curve.value;
          final presence = value.clamp(0.0, 1.0);
          Widget result = _GlassToastPresence(presence: presence, child: child!);
          if (widget.slide && value != 1) {
            result = Transform.translate(
              offset: Offset(0, -GlassTokens.toastEnterOffset * (1 - value)),
              child: result,
            );
          }
          // A leaving toast no longer takes taps.
          return IgnorePointer(
            ignoring: widget.animation.status == AnimationStatus.reverse,
            child: result,
          );
        },
        child: widget.child,
      );
}

class _GlassToastPresence extends InheritedWidget {
  const _GlassToastPresence({required this.presence, required super.child});

  final double presence;

  /// 1 outside a [GlassToastSwitcher] (a toast shown on its own).
  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_GlassToastPresence>()
          ?.presence ??
      1;

  @override
  bool updateShouldNotify(_GlassToastPresence oldWidget) =>
      oldWidget.presence != presence;
}
