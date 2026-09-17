import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'keep_scope.dart';

class NavigationPageView extends StatefulWidget {
  const NavigationPageView({
    super.key,
    required this.selectedIndex,
    required this.itemCount,
    required this.itemBuilder,
    required this.itemKey,
    required this.keepAlive,
    this.animate = true,
  });

  final int selectedIndex;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final LocalKey Function(int index) itemKey;
  final bool Function(int index) keepAlive;
  final bool animate;

  @override
  State<NavigationPageView> createState() => _NavigationPageViewState();
}

class _NavigationPageViewState extends State<NavigationPageView>
    with SingleTickerProviderStateMixin {
  // Pages more than one step apart are reached with jumpToPage, so the
  // destination fades in instead of appearing as a hard cut.
  static const _fadeDuration = Duration(milliseconds: 220);

  late final PageController _controller;
  late final AnimationController _fadeController;
  late final Animation<double> _fade;
  int _navigationGeneration = 0;

  int get _index => max(0, min(widget.selectedIndex, widget.itemCount - 1));

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: _index);
    _fadeController = AnimationController(
      vsync: this,
      duration: _fadeDuration,
      value: 1,
    );
    _fade = _fadeController.drive(CurveTween(curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant NavigationPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.itemCount != widget.itemCount) {
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
    final current = _controller.page ?? _controller.initialPage.toDouble();
    final target = _index;
    if (current == target) return;
    final generation = _navigationGeneration;
    final animate = widget.animate && !MediaQuery.disableAnimationsOf(context);
    if (animate && (current - target).abs() <= 1) {
      await _controller.animateToPage(
        target,
        duration: kTabScrollDuration,
        curve: Curves.easeOut,
      );
    } else {
      // Scrolling across skipped pages would build every page in between,
      // so keep the jump and fade the destination in.
      _controller.jumpToPage(target);
      if (animate) {
        unawaited(_fadeController.forward(from: 0));
      } else {
        _fadeController.value = 1;
      }
    }
    if (mounted && generation == _navigationGeneration) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  void dispose() {
    _navigationGeneration++;
    _fadeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return const SizedBox.shrink();
    final pageView = PageView.builder(
      controller: _controller,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.itemCount,
      findChildIndexCallback: (key) {
        for (var i = 0; i < widget.itemCount; i++) {
          if (widget.itemKey(i) == key) return i;
        }
        return null;
      },
      itemBuilder: (context, index) {
        final active = index == _index;
        return KeepScope(
          key: widget.itemKey(index),
          keep: widget.keepAlive(index),
          child: TickerMode(
            enabled: active,
            child: ExcludeFocus(
              excluding: !active,
              child: ExcludeSemantics(
                excluding: !active,
                child:
                    RepaintBoundary(child: widget.itemBuilder(context, index)),
              ),
            ),
          ),
        );
      },
    );
    return FadeTransition(opacity: _fade, child: pageView);
  }
}
