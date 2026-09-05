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

class _NavigationPageViewState extends State<NavigationPageView> {
  late final PageController _controller;
  int _navigationGeneration = 0;

  int get _index => max(0, min(widget.selectedIndex, widget.itemCount - 1));

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: _index);
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
    if (widget.animate &&
        !MediaQuery.disableAnimationsOf(context) &&
        (current - target).abs() <= 1) {
      await _controller.animateToPage(
        target,
        duration: kTabScrollDuration,
        curve: Curves.easeOut,
      );
    } else {
      _controller.jumpToPage(target);
    }
    if (mounted && generation == _navigationGeneration) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  void dispose() {
    _navigationGeneration++;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return const SizedBox.shrink();
    return PageView.builder(
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
  }
}
