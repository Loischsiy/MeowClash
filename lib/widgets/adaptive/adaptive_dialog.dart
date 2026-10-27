import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'glass_accessibility.dart';
import 'glass_surface.dart';
import 'glass_text_styles.dart';
import 'glass_theme.dart';
import 'glass_tokens.dart';

bool get _mac => defaultTargetPlatform == TargetPlatform.macOS;

/// Shows [builder] as a Darwin dialog: the app behind is only dimmed (no
/// full-screen blur), the panel itself is the one glass layer.
///
/// Darwin only; Material keeps `showModal` + `FadeScaleTransition`.
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  final brightness = Theme.of(context).brightness;
  return Navigator.of(context).push<T>(
    GlassDialogRoute<T>(
      builder: builder,
      barrierDismissible: dismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: GlassTokens.dialogBarrierColor(brightness, mac: _mac),
    ),
  );
}

/// Popup route of the Darwin dialogs.
///
/// A glass panel must not fade through an `Opacity` above its
/// `BackdropFilter` (the blur would only appear when the fade ends), so
/// [GlassDialog] and [GlassModalPanel] animate themselves from
/// [presenceOf]. Any other child (a raw `AlertDialog`) gets a plain fade.
class GlassDialogRoute<T> extends PopupRoute<T> {
  GlassDialogRoute({
    required this.builder,
    required Color barrierColor,
    required String barrierLabel,
    bool barrierDismissible = true,
    super.settings,
  })  : _barrierColor = barrierColor,
        _barrierLabel = barrierLabel,
        _barrierDismissible = barrierDismissible;

  final WidgetBuilder builder;
  final Color _barrierColor;
  final String _barrierLabel;
  final bool _barrierDismissible;

  bool _presentsItself = false;

  /// The appearance animation of the enclosing [GlassDialogRoute], or `null`
  /// outside one (then the caller renders fully shown). Calling it tells the
  /// route that the caller animates itself, so it skips its fallback fade.
  static Animation<double>? presenceOf(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route is! GlassDialogRoute) return null;
    route._presentsItself = true;
    return route.animation;
  }

  @override
  Color get barrierColor => _barrierColor;

  @override
  bool get barrierDismissible => _barrierDismissible;

  @override
  String get barrierLabel => _barrierLabel;

  @override
  Curve get barrierCurve => GlassTokens.dialogCurve;

  @override
  Duration get transitionDuration => GlassTokens.dialogEnterDuration;

  @override
  Duration get reverseTransitionDuration => GlassTokens.dialogExitDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) =>
      Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: DisplayFeatureSubScreen(child: Builder(builder: builder)),
      );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      AnimatedBuilder(
        animation: animation,
        // Opacity 1 adds no layer, so a self-animating glass child keeps its
        // blur; the tree shape never changes, so no state is lost.
        builder: (context, child) => Opacity(
          opacity: _presentsItself
              ? 1
              : GlassTokens.dialogCurve.transform(animation.value),
          child: child,
        ),
        child: child,
      );
}

/// Drives the appearance of a glass panel: `presence` for the surface and
/// the content fade, `scale` for the system-alert shrink (1 with Reduce
/// Motion and while closing, which only fades).
class _GlassPresence extends StatelessWidget {
  const _GlassPresence({required this.builder});

  final Widget Function(BuildContext context, double presence, double scale)
      builder;

  @override
  Widget build(BuildContext context) {
    final animation = GlassDialogRoute.presenceOf(context);
    if (animation == null) return builder(context, 1, 1);
    final reduceMotion = GlassAccessibility.of(context).reduceMotion;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = GlassTokens.dialogCurve.transform(animation.value);
        final closing = animation.status == AnimationStatus.reverse;
        final scale = reduceMotion || closing
            ? 1.0
            : GlassTokens.dialogEnterScale +
                (1 - GlassTokens.dialogEnterScale) * t;
        return builder(context, t, scale);
      },
    );
  }
}

/// The Darwin dialog panel (the glass branch of `CommonDialog`).
///
/// One [GlassSurface] (the only blur of the dialog), Apple type scale, and
/// the actions laid out by [GlassDialogActions]. Content keeps working
/// unchanged: it sits on a transparent `Material` with the [GlassTheme.form]
/// theme, so its text fields turn into Apple fields by themselves.
class GlassDialog extends StatelessWidget {
  const GlassDialog({
    super.key,
    this.title,
    required this.content,
    this.actions = const [],
    this.contentPadding,
    this.color,
    this.titleAccessory,
  });

  final String? title;
  final Widget content;
  final List<Widget> actions;

  /// A secondary control beside the title (usually a `GlassIconButton` of
  /// [GlassTokens.dialogTitleAccessorySize]), at the trailing edge of the
  /// title row instead of among the push buttons. Needs a [title].
  final Widget? titleAccessory;

  /// Replaces the default content padding (the dialog edge inset).
  final EdgeInsetsGeometry? contentPadding;

  /// Base color of the glass tint; the theme surface by default.
  final Color? color;

  static double radius() =>
      _mac ? GlassTokens.dialogRadiusMac : GlassTokens.dialogRadiusIos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const padding = GlassTokens.dialogPadding;
    final title = this.title;
    final accessory = titleAccessory;
    Widget? titleRow;
    if (title != null) {
      final text = Text(
        title,
        textAlign: _mac ? TextAlign.start : TextAlign.center,
        style: GlassTextStyles.dialogTitle(theme.textTheme)
            .copyWith(color: scheme.onSurface),
      );
      titleRow = accessory == null
          ? text
          : Row(
              children: [
                if (!_mac)
                  const SizedBox(
                    width: GlassTokens.dialogTitleAccessorySize +
                        GlassTokens.dialogTitleAccessoryGap,
                  ),
                Expanded(child: text),
                const SizedBox(width: GlassTokens.dialogTitleAccessoryGap),
                accessory,
              ],
            );
    }
    final body = Material(
      type: MaterialType.transparency,
      child: Theme(
        data: GlassTheme.form(theme),
        child: DefaultTextStyle(
          style: GlassTextStyles.dialogMessage(theme.textTheme)
              .copyWith(color: scheme.onSurface),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (titleRow != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    padding,
                    padding,
                    padding,
                    0,
                  ),
                  child: titleRow,
                ),
              Flexible(
                child: Padding(
                  padding: contentPadding ??
                      EdgeInsets.fromLTRB(
                        padding,
                        title != null ? GlassTokens.dialogTitleGap : padding,
                        padding,
                        0,
                      ),
                  child: content,
                ),
              ),
              if (actions.isNotEmpty)
                GlassDialogActions(actions: actions)
              else
                const SizedBox(height: padding),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      namesRoute: true,
      scopesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: _GlassDialogFrame(
        child: _GlassPresence(
          builder: (context, presence, scale) => Transform.scale(
            scale: scale,
            child: GlassSurface(
              sigma: GlassTokens.dialogSigma,
              tintOpacity: GlassTokens.dialogTintOpacity(theme.brightness),
              borderRadius: BorderRadius.circular(radius()),
              color: color ??
                  GlassTokens.dialogTint(
                    theme.colorScheme.surface,
                    theme.brightness,
                  ),
              shadow: true,
              presence: presence,
              // The fade lives below the blur, never above it.
              child: Opacity(opacity: presence, child: body),
            ),
          ),
        ),
      ),
    );
  }
}

/// Centers a dialog panel, keeps it clear of the window edges and lifts it
/// above the keyboard.
class _GlassDialogFrame extends StatelessWidget {
  const _GlassDialogFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: MediaQuery.viewInsetsOf(context) +
            const EdgeInsets.all(GlassTokens.dialogInset),
        child: MediaQuery.removeViewInsets(
          context: context,
          removeLeft: true,
          removeTop: true,
          removeRight: true,
          removeBottom: true,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: GlassTokens.dialogWidth,
              ),
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
        ),
      );
}

/// Buttons of a Darwin dialog. Call sites keep passing `TextButton` /
/// `FilledButton`; only their style changes, through a button theme per
/// position (a style set on the button itself still wins). Empty spacers
/// between the buttons are dropped.
///
/// * macOS: push-button capsules at the trailing edge; the last (confirming)
///   one is filled with the accent.
/// * iOS: full-width buttons under a hairline, the last one semibold; two
///   side by side, three or more stacked.
class GlassDialogActions extends StatelessWidget {
  const GlassDialogActions({super.key, required this.actions});

  final List<Widget> actions;

  static bool _isSpacer(Widget widget) =>
      widget is Spacer || (widget is SizedBox && widget.child == null);

  @override
  Widget build(BuildContext context) {
    final buttons = actions.where((action) => !_isSpacer(action)).toList();
    if (buttons.isEmpty) {
      return const SizedBox(height: GlassTokens.dialogPadding);
    }
    final theme = Theme.of(context);
    Widget styled(int index) {
      final preferred = index == buttons.length - 1;
      final style = _mac
          ? _macStyle(theme, preferred: preferred)
          : _iosStyle(theme, preferred: preferred);
      return Theme(
        data: theme.copyWith(
          textButtonTheme: TextButtonThemeData(style: style),
          filledButtonTheme: FilledButtonThemeData(style: style),
          elevatedButtonTheme: ElevatedButtonThemeData(style: style),
          outlinedButtonTheme: OutlinedButtonThemeData(style: style),
        ),
        child: buttons[index],
      );
    }

    if (_mac) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          GlassTokens.dialogPadding,
          GlassTokens.dialogActionsGapMac,
          GlassTokens.dialogPadding,
          GlassTokens.dialogPadding,
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: GlassTokens.dialogButtonGapMac,
          runSpacing: GlassTokens.dialogButtonGapMac,
          children: [for (var i = 0; i < buttons.length; i++) styled(i)],
        ),
      );
    }

    final hairline = theme.colorScheme.onSurface.withValues(
      alpha: GlassTokens.hairlineOpacity(theme.brightness),
    );
    final horizontal = Container(
      height: GlassTokens.hairlineWidth,
      color: hairline,
    );
    final Widget buttonsArea;
    if (buttons.length <= GlassTokens.dialogSideBySideMaxIos) {
      buttonsArea = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0)
                Container(width: GlassTokens.hairlineWidth, color: hairline),
              Expanded(child: styled(i)),
            ],
          ],
        ),
      );
    } else {
      buttonsArea = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) horizontal,
            styled(i),
          ],
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: GlassTokens.dialogContentBottomIos),
        horizontal,
        buttonsArea,
      ],
    );
  }

  static WidgetStateProperty<Color?> _overlay(Color base, Brightness b) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return base.withValues(alpha: GlassTokens.dialogPressedOpacity(b));
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return base.withValues(alpha: GlassTokens.hoverOpacity(b));
        }
        return Colors.transparent;
      });

  static ButtonStyle _common(ThemeData theme, {required bool preferred}) =>
      ButtonStyle(
        textStyle: WidgetStatePropertyAll(
          GlassTextStyles.dialogButton(theme.textTheme, preferred: preferred),
        ),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        side: const WidgetStatePropertyAll(BorderSide.none),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        splashFactory: NoSplash.splashFactory,
      );

  static ButtonStyle _iosStyle(ThemeData theme, {required bool preferred}) {
    final scheme = theme.colorScheme;
    return _common(theme, preferred: preferred).copyWith(
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? scheme.onSurface.withValues(alpha: GlassTokens.disabledOpacity)
            : scheme.primary,
      ),
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: _overlay(scheme.onSurface, theme.brightness),
      shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
      minimumSize: const WidgetStatePropertyAll(
        Size(0, GlassTokens.dialogButtonHeightIos),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: GlassTokens.dialogButtonPaddingIos),
      ),
    );
  }

  static ButtonStyle _macStyle(ThemeData theme, {required bool preferred}) {
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    final foreground = preferred ? scheme.onPrimary : scheme.onSurface;
    final background = preferred
        ? scheme.primary
        : scheme.onSurface.withValues(
            alpha: GlassTokens.dialogButtonFillOpacity(brightness),
          );
    return _common(theme, preferred: preferred).copyWith(
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? scheme.onSurface.withValues(alpha: GlassTokens.disabledOpacity)
            : foreground,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? scheme.onSurface.withValues(
                alpha: GlassTokens.dialogButtonFillOpacity(brightness),
              )
            : background,
      ),
      overlayColor: _overlay(
        preferred ? scheme.onPrimary : scheme.onSurface,
        brightness,
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      minimumSize: const WidgetStatePropertyAll(
        Size(
          GlassTokens.dialogButtonMinWidthMac,
          GlassTokens.dialogButtonHeightMac,
        ),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: GlassTokens.dialogButtonPaddingMac),
      ),
    );
  }
}

/// A row of a single-choice list (Darwin pickers): the label and, on the
/// chosen row, a checkmark in the accent instead of a radio button.
class GlassOptionRow extends StatelessWidget {
  const GlassOptionRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Widget label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    final radius = BorderRadius.circular(GlassTokens.optionRowRadius);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        customBorder: RoundedRectangleBorder(borderRadius: radius),
        splashFactory: NoSplash.splashFactory,
        highlightColor: scheme.onSurface.withValues(
          alpha: GlassTokens.dialogPressedOpacity(brightness),
        ),
        hoverColor: scheme.onSurface.withValues(
          alpha: GlassTokens.hoverOpacity(brightness),
        ),
        child: SizedBox(
          height: _mac
              ? GlassTokens.optionRowHeightMac
              : GlassTokens.optionRowHeightIos,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: GlassTokens.optionRowPadding,
            ),
            child: Row(
              children: [
                Expanded(
                  child: DefaultTextStyle.merge(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GlassTextStyles.dialogMessage(theme.textTheme)
                        .copyWith(color: scheme.onSurface),
                    child: label,
                  ),
                ),
                SizedBox.square(
                  dimension: GlassTokens.optionCheckSize,
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: GlassTokens.optionCheckSize,
                          color: scheme.primary,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The large desktop modal (the glass branch of `CommonModal`): one glass
/// panel; the page inside paints no opaque scaffold of its own, so the
/// panel shows through, and its toolbar capsules stay unblurred
/// (`GlassSurface.isOverBlur`).
class GlassModalPanel extends StatelessWidget {
  const GlassModalPanel({
    super.key,
    required this.width,
    required this.height,
    this.child,
  });

  final double width;
  final double height;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Theme(
      data: theme.copyWith(scaffoldBackgroundColor: Colors.transparent),
      child: child ?? const SizedBox.shrink(),
    );
    return Center(
      child: SizedBox(
        width: width,
        height: height,
        child: _GlassPresence(
          builder: (context, presence, scale) => Transform.scale(
            scale: scale,
            child: GlassSurface(
              sigma: GlassTokens.dialogSigma,
              tintOpacity: GlassTokens.dialogTintOpacity(theme.brightness),
              borderRadius: BorderRadius.circular(GlassDialog.radius()),
              color: GlassTokens.dialogTint(
                theme.colorScheme.surface,
                theme.brightness,
              ),
              shadow: true,
              presence: presence,
              child: Opacity(opacity: presence, child: content),
            ),
          ),
        ),
      ),
    );
  }
}
