import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';

import 'keep_scope.dart';

/// How [NavigationPageView] moves between destinations.
enum NavigationPageTransition {
  /// Phone tab bar: the pages scroll sideways, through every page in between.
  slide,

  /// Material sidebar layout (Windows, Linux, Android tablets): Material 3
  /// fade through. The old page fades out, then the new one fades in while
  /// growing from 92 %.
  fadeThrough,

  /// Darwin glass sidebar layout (macOS, iPad): the old and the new page slide
  /// vertically along the sidebar. Transforms only: an `Opacity` over a glass
  /// page would flatten its blur.
  verticalSlide,
}

class NavigationPageView extends StatefulWidget {
  const NavigationPageView({
    super.key,
    required this.selectedIndex,
    required this.itemCount,
    required this.itemBuilder,
    required this.itemKey,
    required this.keepAlive,
    this.animate = true,
    this.transition = NavigationPageTransition.slide,
  });

  final int selectedIndex;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final LocalKey Function(int index) itemKey;
  final bool Function(int index) keepAlive;
  final bool animate;
  final NavigationPageTransition transition;

  @override
  State<NavigationPageView> createState() => _NavigationPageViewState();
}

class _NavigationPageViewState extends State<NavigationPageView> {
  // Material 3 fade through: the old page is gone after the first 35 %, the
  // new one fades in over the rest while it grows from 92 %.
  static const Duration _fadeThroughDuration = Durations.medium2;
  static const Curve _fadeOut = Interval(0.65, 1);
  static const Curve _fadeIn = Interval(0.35, 1, curve: Curves.easeOut);
  static const Curve _growIn = Curves.easeOutCubic;
  static const double _fadeThroughScale = 0.92;

  late final PageController _controller;
  int _navigationGeneration = 0;
  bool _reduceMotion = false;

  // Sidebar transitions move exactly two pages however far apart they are:
  // the page being left is swapped into the slot next to the target for the
  // duration (as TabBarView does), so the pages in between are never built.
  // `null` = every page sits in its own slot. A swap is its own inverse, so
  // [_swapped] maps an item to its slot and a slot to its item alike.
  ({int item, int slot})? _warp;

  int get _index => max(0, min(widget.selectedIndex, widget.itemCount - 1));

  bool get _sidebar => widget.transition != NavigationPageTransition.slide;

  int _swapped(int value) {
    final warp = _warp;
    if (warp == null) return value;
    if (value == warp.item) return warp.slot;
    if (value == warp.slot) return warp.item;
    return value;
  }

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: _index);
  }

  @override
  void didUpdateWidget(covariant NavigationPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The swapped slots may no longer exist; the post-frame pass below
    // settles on the selected page again.
    if (oldWidget.itemCount != widget.itemCount) _warp = null;
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.itemCount != widget.itemCount ||
        oldWidget.transition != widget.transition) {
      final generation = ++_navigationGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && generation == _navigationGeneration) {
          unawaited(_showPage());
        }
      });
    }
  }

  Future<void> _showPage() async {
    if (!_controller.hasClients || widget.itemCount == 0) return;
    final generation = _navigationGeneration;
    final target = _index;
    final animate = widget.animate && !_reduceMotion;
    if (!animate || !_sidebar) _unwarp();
    final current = _controller.page ?? _controller.initialPage.toDouble();
    if (current == _swapped(target)) {
      if (_warp != null) {
        _unwarp();
      } else if (_sidebar) {
        // A shrunk item list makes layout clamp the scroll without notifying,
        // so pages built before that would keep a stale offset.
        setState(() {});
      }
      return;
    }
    if (!animate) {
      _controller.jumpToPage(target);
    } else if (_sidebar) {
      await _switchTo(target, current);
      if (!mounted || generation != _navigationGeneration) return;
      _unwarp();
    } else {
      final diff = (current - target).abs();
      // Cap long jumps at 700 ms so distant tabs don't feel slow.
      final duration = Duration(
        milliseconds:
            (kTabScrollDuration.inMilliseconds * diff).clamp(300, 700).round(),
      );
      await _controller.animateToPage(
        target,
        duration: duration,
        curve: diff > 1 ? Curves.easeInOutCubic : Curves.easeOut,
      );
    }
    if (mounted && generation == _navigationGeneration) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  /// Sidebar layouts: one page of scroll drives the transition, whatever the
  /// distance between the destinations.
  Future<void> _switchTo(int target, double current) async {
    var slot = _swapped(target);
    if ((slot - current).abs() > 1) {
      // Too far to scroll without building every page in between: move the
      // page on screen next to the target, then scroll a single page.
      final shown = _swapped(current.round());
      final next = target > shown ? target - 1 : target + 1;
      setState(() => _warp = next == shown ? null : (item: shown, slot: next));
      _controller.jumpToPage(next);
      slot = target;
    }
    final fadeThrough =
        widget.transition == NavigationPageTransition.fadeThrough;
    await _controller.animateToPage(
      slot,
      // Fade through shapes each page itself, so the scroll stays linear.
      duration: fadeThrough
          ? _fadeThroughDuration
          : GlassTokens.sidebarSwitchDuration,
      curve: fadeThrough ? Curves.linear : GlassTokens.sidebarSwitchCurve,
    );
  }

  /// Puts every page back in its own slot, keeping the page on screen.
  void _unwarp() {
    if (_warp == null) return;
    final page = _controller.page;
    final shown = page == null ? _index : _swapped(page.round());
    setState(() => _warp = null);
    _controller.jumpToPage(shown);
  }

  /// Signed distance of [slot] from the scroll position, in pages.
  double _delta(int slot) {
    final page = _controller.hasClients ? _controller.page : null;
    return slot - (page ?? _swapped(_index).toDouble());
  }

  /// Sidebar layouts keep both pages in place over the scroll that drives the
  /// transition and move them as the transition asks instead.
  Widget _sidebarMotion(int slot, bool active, Widget page) => IgnorePointer(
        ignoring: !active,
        child: AnimatedBuilder(
          animation: _controller,
          child: page,
          builder: (context, child) {
            final delta = _delta(slot).clamp(-1.0, 1.0);
            // Cancels the PageView's own sideways scroll.
            final stay =
                Directionality.of(context) == TextDirection.rtl ? delta : -delta;
            if (widget.transition == NavigationPageTransition.verticalSlide) {
              // Down the sidebar: the old page leaves upwards and the new one
              // rises from below; up the sidebar the other way round.
              return FractionalTranslation(
                translation: Offset(stay, delta),
                child: child,
              );
            }
            // 0 = off screen, 1 = settled.
            final shown = 1 - delta.abs();
            final scale = active
                ? _fadeThroughScale +
                    (1 - _fadeThroughScale) * _growIn.transform(shown)
                : 1.0;
            return FractionalTranslation(
              translation: Offset(stay, 0),
              child: Opacity(
                opacity: (active ? _fadeIn : _fadeOut).transform(shown),
                child: Transform.scale(scale: scale, child: child),
              ),
            );
          },
        ),
      );

  @override
  void dispose() {
    _navigationGeneration++;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = widget.transition == NavigationPageTransition.verticalSlide
        ? GlassAccessibility.of(context).reduceMotion
        : MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.itemCount == 0) return const SizedBox.shrink();
    final pageView = PageView.builder(
      controller: _controller,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.itemCount,
      findChildIndexCallback: (key) {
        for (var i = 0; i < widget.itemCount; i++) {
          if (widget.itemKey(i) == key) return _swapped(i);
        }
        return null;
      },
      itemBuilder: (context, slot) {
        final index = _swapped(slot);
        final active = index == _index;
        Widget page =
            RepaintBoundary(child: widget.itemBuilder(context, index));
        if (_sidebar) page = _sidebarMotion(slot, active, page);
        return KeepScope(
          key: widget.itemKey(index),
          keep: widget.keepAlive(index),
          child: TickerMode(
            enabled: active,
            child: ExcludeFocus(
              excluding: !active,
              child: ExcludeSemantics(
                excluding: !active,
                child: page,
              ),
            ),
          ),
        );
      },
    );
    return pageView;
  }
}
