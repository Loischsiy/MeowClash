import 'package:flutter/material.dart';

import 'glass_accessibility.dart';
import 'glass_tokens.dart';

/// Darwin resizable bottom sheet (iPhone), after the medium/large detents of
/// `UISheetPresentationController`.
///
/// Wraps the content of a scroll-controlled modal bottom sheet
/// (`SheetProps.expandable`) in a [DraggableScrollableSheet]: it opens at the
/// medium detent and grows to the whole safe area. Scrolling the content up
/// first expands the sheet (its scrollable inherits the sheet's
/// [PrimaryScrollController]); the sheet header ([GlassSheetDragArea]) drags
/// and settles it, and its grabber switches between the detents. Dragging below [GlassTokens.sheetDismissDetent]
/// closes the sheet. Reduce Motion makes the header and grabber settles
/// instant; a release of the content keeps the stock snap, which continues
/// the user's own drag.
///
/// Glass only: `showSheet` never builds it for Material.
class GlassSheetDetents extends StatefulWidget {
  const GlassSheetDetents({super.key, required this.child});

  final Widget child;

  /// The detents of the enclosing expandable sheet, or `null` outside one.
  static GlassSheetDetentsState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DetentsScope>()?.state;

  @override
  State<GlassSheetDetents> createState() => GlassSheetDetentsState();
}

class GlassSheetDetentsState extends State<GlassSheetDetents> {
  final _controller = DraggableScrollableController();
  bool _dismissing = false;

  static const double _medium = GlassTokens.sheetMediumDetent;
  static const double _large = GlassTokens.sheetLargeDetent;
  // Tolerance when comparing fractional sizes.
  static const double _epsilon = 0.01;

  /// Current height as a fraction of the available height.
  double get size => _controller.isAttached ? _controller.size : _medium;

  /// Whether the sheet stands at the large detent.
  bool get isExpanded => size >= _large - _epsilon;

  /// Notifies on every size change.
  Listenable get sizeListenable => _controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleSize);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleSize)
      ..dispose();
    super.dispose();
  }

  // Content dragged all the way down (the sheet bottoms out at its minimum
  // size): close it, like a swipe down on an iOS sheet.
  void _handleSize() {
    if (_controller.size <= GlassTokens.sheetMinDetent + _epsilon / 10) {
      _dismiss();
    }
  }

  void _dismiss() {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    Navigator.maybePop(context);
  }

  /// Moves the sheet by a vertical drag of [delta] logical pixels (positive
  /// is downwards).
  void dragBy(double delta) {
    if (!_controller.isAttached || _dismissing) return;
    final next = (_controller.size - _controller.pixelsToSize(delta))
        .clamp(GlassTokens.sheetMinDetent, _large);
    _controller.jumpTo(next);
  }

  /// Ends a header drag released at [velocity] (logical px/s, positive is
  /// downwards): settles on a detent or closes the sheet.
  void settle(double velocity) {
    if (!_controller.isAttached || _dismissing) return;
    final size = _controller.size;
    final flingDown = velocity >= GlassTokens.sheetFlingVelocity;
    final flingUp = velocity <= -GlassTokens.sheetFlingVelocity;
    if (size < GlassTokens.sheetDismissDetent ||
        (flingDown && size <= _medium + _epsilon)) {
      _dismiss();
      return;
    }
    final double target;
    if (flingUp) {
      target = _large;
    } else if (flingDown) {
      target = _medium;
    } else {
      target = (size - _medium).abs() <= (_large - size).abs()
          ? _medium
          : _large;
    }
    _moveTo(target);
  }

  /// The grabber tap: medium ↔ large.
  void toggle() => _moveTo(isExpanded ? _medium : _large);

  void _moveTo(double target) {
    if (!_controller.isAttached || _dismissing) return;
    final duration = GlassTokens.motion(
      GlassTokens.sheetDetentDuration,
      reduceMotion: GlassAccessibility.of(context).reduceMotion,
    );
    if (duration == Duration.zero) {
      _controller.jumpTo(target);
      return;
    }
    _controller.animateTo(
      target,
      duration: duration,
      curve: GlassTokens.sheetDetentCurve,
    );
  }

  @override
  Widget build(BuildContext context) => _DetentsScope(
        state: this,
        child: DraggableScrollableSheet(
          controller: _controller,
          expand: false,
          initialChildSize: _medium,
          minChildSize: GlassTokens.sheetMinDetent,
          maxChildSize: _large,
          snap: true,
          snapSizes: const [_medium],
          snapAnimationDuration: GlassTokens.sheetDetentDuration,
          builder: (context, scrollController) => PrimaryScrollController(
            controller: scrollController,
            // Inherit on macOS too (a narrow window uses the mobile layout).
            automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
            child: widget.child,
          ),
        ),
      );
}

class _DetentsScope extends InheritedWidget {
  const _DetentsScope({required this.state, required super.child});

  final GlassSheetDetentsState state;

  @override
  bool updateShouldNotify(_DetentsScope oldWidget) => state != oldWidget.state;
}

/// The header of an expandable glass sheet (grabber + title bar): dragging it
/// resizes the sheet, tapping the [grabber] switches between the detents.
/// Outside a [GlassSheetDetents] it returns its children unchanged.
class GlassSheetDragArea extends StatelessWidget {
  const GlassSheetDragArea({
    super.key,
    required this.grabber,
    required this.child,
  });

  final Widget grabber;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final detents = GlassSheetDetents.maybeOf(context);
    if (detents == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [grabber, child],
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) => detents.dragBy(details.primaryDelta!),
      onVerticalDragEnd: (details) =>
          detents.settle(details.primaryVelocity ?? 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListenableBuilder(
            listenable: detents.sizeListenable,
            builder: (_, child) => Semantics(
              button: true,
              expanded: detents.isExpanded,
              child: child,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: detents.toggle,
              // A full-width tap target; the grabber keeps its own size.
              child: SizedBox(
                width: double.infinity,
                child: Center(child: grabber),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
