import 'dart:ui';

import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'scaffold.dart';
import 'side_sheet.dart';

@immutable
class SheetProps {
  const SheetProps({
    this.maxWidth,
    this.maxHeight,
    this.useSafeArea = true,
    this.isScrollControlled = false,
    this.blur = true,
  });
  final double? maxWidth;
  final double? maxHeight;
  final bool isScrollControlled;
  final bool useSafeArea;
  final bool blur;
}

@immutable
class ExtendProps {
  const ExtendProps({
    this.maxWidth,
    this.useSafeArea = true,
    this.blur = true,
  });
  final double? maxWidth;
  final bool useSafeArea;
  final bool blur;
}

enum SheetType {
  page,
  bottomSheet,
  sideSheet,
}

typedef SheetBuilder = Widget Function(BuildContext context, SheetType type);

Future<T?> showSheet<T>({
  required BuildContext context,
  required SheetBuilder builder,
  SheetProps props = const SheetProps(),
}) {
  final isMobile = globalState.appState.viewMode == ViewMode.mobile;
  return switch (isMobile) {
    true => showModalBottomSheet<T>(
        context: context,
        isScrollControlled: props.isScrollControlled,
        backgroundColor: Colors.transparent,
        // Glass sheets blur only their own surface (AdaptiveSheetScaffold),
        // never the whole screen behind the barrier.
        builder: (_) => AdaptivePlatform.useGlass
            ? SafeArea(
                child: builder(context, SheetType.bottomSheet),
              )
            : BackdropFilter(
                filter: props.blur ? commonFilter : ImageFilter.blur(),
                child: SafeArea(
                  child: builder(context, SheetType.bottomSheet),
                ),
              ),
        showDragHandle: false,
        useSafeArea: props.useSafeArea,
      ),
    false => showModalSideSheet<T>(
        useSafeArea: props.useSafeArea,
        isScrollControlled: props.isScrollControlled,
        context: context,
        constraints: BoxConstraints(
          maxWidth: props.maxWidth ?? 360,
        ),
        filter: props.blur && !AdaptivePlatform.useGlass ? commonFilter : null,
        backgroundColor: AdaptivePlatform.useGlass ? Colors.transparent : null,
        motion: _glassSideSheetMotion(context),
        builder: (_) => builder(context, SheetType.sideSheet),
      ),
  };
}

Future<T?> showExtend<T>(
  BuildContext context, {
  required SheetBuilder builder,
  ExtendProps props = const ExtendProps(),
}) {
  final isMobile = globalState.appState.viewMode == ViewMode.mobile;
  return switch (isMobile) {
    true => BaseNavigator.push(
        context,
        builder(context, SheetType.page),
      ),
    false => showModalSideSheet<T>(
        useSafeArea: props.useSafeArea,
        context: context,
        constraints: BoxConstraints(
          maxWidth: props.maxWidth ?? 360,
        ),
        filter: props.blur && !AdaptivePlatform.useGlass ? commonFilter : null,
        backgroundColor: AdaptivePlatform.useGlass ? Colors.transparent : null,
        motion: _glassSideSheetMotion(context),
        builder: (context) => builder(context, SheetType.sideSheet),
      ),
  };
}

/// Darwin: the glass panel slides in on a spring, instantly with Reduce
/// Motion. Material keeps the side sheet's stock timing (`null`).
SideSheetMotion? _glassSideSheetMotion(BuildContext context) {
  if (!AdaptivePlatform.useGlass) return null;
  final reduceMotion = GlassAccessibility.of(context).reduceMotion;
  return SideSheetMotion(
    enterDuration: GlassTokens.motion(
      GlassTokens.sideSheetEnterDuration,
      reduceMotion: reduceMotion,
    ),
    exitDuration: GlassTokens.motion(
      GlassTokens.sideSheetExitDuration,
      reduceMotion: reduceMotion,
    ),
    curve: GlassTokens.sideSheetEnterCurve,
    reverseCurve: GlassTokens.sideSheetExitCurve,
  );
}

class AdaptiveSheetScaffold extends StatefulWidget {
  const AdaptiveSheetScaffold({
    super.key,
    required this.type,
    required this.body,
    required this.title,
    this.actions = const [],
    this.disableBackground = true,
  });
  final SheetType type;
  final Widget body;
  final String title;
  final List<Widget> actions;
  final bool disableBackground;

  @override
  State<AdaptiveSheetScaffold> createState() => _AdaptiveSheetScaffoldState();
}

class _AdaptiveSheetScaffoldState extends State<AdaptiveSheetScaffold> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final bottomSheet = widget.type == SheetType.bottomSheet;
    final sideSheet = widget.type == SheetType.sideSheet;
    // A full-screen page (mobile `showExtend`) is an opaque route: nothing is
    // painted behind it, so glass would only tint an empty backdrop grey.
    // Darwin pages use the theme's opaque page background instead.
    final darwinPage =
        AdaptivePlatform.useGlass && widget.type == SheetType.page;
    final useGlass = AdaptivePlatform.useGlass && !darwinPage;
    final backgroundColor = useGlass
        ? Colors.transparent
        : darwinPage
            ? null
            : sideSheet
                ? colorScheme.surface.withValues(alpha: 0.92)
                : colorScheme.surface.withValues(alpha: 0.92);
    final appBar = AppBar(
      forceMaterialTransparency: bottomSheet ? true : false,
      automaticallyImplyLeading: bottomSheet
          ? false
          : widget.actions.isEmpty && sideSheet
              ? false
              : true,
      centerTitle: bottomSheet,
      backgroundColor: backgroundColor,
      title: Text(
        widget.title,
      ),
      actions: genActions([
        if (widget.actions.isEmpty && sideSheet) const CloseButton(),
        ...widget.actions,
      ]),
    );
    if (bottomSheet) {
      const handleSize = Size(32, 4);
      final sheet = Container(
        clipBehavior: Clip.hardEdge,
        decoration: ShapeDecoration(
          color: backgroundColor,
          shape: const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                alignment: Alignment.center,
                height: handleSize.height,
                width: handleSize.width,
                decoration: ShapeDecoration(
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(handleSize.height / 2),
                  ),
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            appBar,
            Flexible(
              flex: 1,
              child: widget.body,
            )
          ],
        ),
      );
      if (!useGlass) return sheet;
      return GlassSurface(
        sigma: GlassTokens.sheetSigma,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(GlassTokens.sheetRadius),
        ),
        shadow: true,
        child: sheet,
      );
    }
    final scaffold = CommonScaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      body: widget.body,
      disableBackground: widget.disableBackground,
    );
    if (!useGlass) return scaffold;
    return _GlassSideSheetPanel(child: scaffold);
  }
}

/// Darwin side sheet: a floating glass panel inset from the window edges with
/// all four corners rounded. The window insets (macOS title bar strip, iPad
/// status bar) are reduced by the gap, so the toolbar inside still clears
/// them without an extra step.
class _GlassSideSheetPanel extends StatelessWidget {
  const _GlassSideSheetPanel({required this.child});

  final Widget child;

  static double _less(double value) =>
      (value - GlassTokens.sideSheetInset).clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final padding = mediaQuery.padding;
    final radius = defaultTargetPlatform == TargetPlatform.macOS
        ? GlassTokens.sideSheetRadiusMac
        : GlassTokens.sideSheetRadiusIos;
    return Padding(
      padding: const EdgeInsets.all(GlassTokens.sideSheetInset),
      child: MediaQuery(
        data: mediaQuery.copyWith(
          padding: EdgeInsets.fromLTRB(
            0,
            _less(padding.top),
            _less(padding.right),
            _less(padding.bottom),
          ),
        ),
        child: GlassSurface(
          sigma: GlassTokens.sheetSigma,
          borderRadius: BorderRadius.circular(radius),
          shadow: true,
          child: child,
        ),
      ),
    );
  }
}
