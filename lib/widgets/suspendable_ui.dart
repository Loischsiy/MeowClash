import 'package:flutter/widgets.dart';
import 'package:meowclash/services/image_memory.dart';
import 'package:meowclash/services/ui_lifecycle.dart';

/// Keeps the app shell, navigator and platform/core managers alive, but stops
/// all visual tickers (including retained editor/dialog routes) while hidden.
class UiActivityScope extends StatefulWidget {
  const UiActivityScope({
    super.key,
    required this.controller,
    required this.child,
  });

  final UiLifecycleController controller;
  final Widget child;

  @override
  State<UiActivityScope> createState() => _UiActivityScopeState();
}

class _UiActivityScopeState extends State<UiActivityScope> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onActivityChanged);
  }

  @override
  void didUpdateWidget(covariant UiActivityScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onActivityChanged);
      widget.controller.addListener(_onActivityChanged);
    }
  }

  void _onActivityChanged() {
    setState(() {});
    // Hidden/paused engines do not schedule normal frames. One warm-up frame
    // is necessary to actually dispose the old Elements/RenderObjects instead
    // of retaining them until the user returns. Also restores a native popover
    // whose original Flutter window may still report itself as hidden.
    WidgetsBinding.instance.scheduleWarmUpFrame();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onActivityChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TickerMode(
        enabled: widget.controller.isVisible,
        child: ExcludeFocus(
          excluding: !widget.controller.isVisible,
          child: widget.child,
        ),
      );
}

/// Unmounts the expensive home/navigation tree, not Application or its engine.
/// Use a builder so a retained child cannot accidentally keep widget resources.
class SuspendableUi extends StatefulWidget {
  const SuspendableUi({
    super.key,
    required this.controller,
    required this.builder,
    this.onUnload,
    this.canUnload = true,
  });

  final UiLifecycleController controller;
  final WidgetBuilder builder;
  final VoidCallback? onUnload;
  final bool canUnload;

  @override
  State<SuspendableUi> createState() => _SuspendableUiState();
}

class _SuspendableUiState extends State<SuspendableUi> {
  bool _unloaded = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          // A pushed editor, dialog or sheet may hold unsaved input or await a
          // result in the home tree. Preserve both sides of that interaction.
          final canUnload = widget.canUnload &&
              !widget.controller.hasKeepAlive &&
              (ModalRoute.of(context)?.isCurrent ?? true);
          final shouldUnload = !widget.controller.isVisible &&
              (_unloaded || (widget.controller.isSuspended && canUnload));
          if (shouldUnload && !_unloaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || !_unloaded || widget.controller.isVisible) return;
              // Clear reusable images only AFTER the removed widgets have
              // dropped their live references. Never evict still-live images.
              releaseUnusedUiImages(PaintingBinding.instance.imageCache);
              widget.onUnload?.call();
            });
          }
          _unloaded = shouldUnload;
          return _unloaded ? const SizedBox.shrink() : widget.builder(context);
        },
      );
}
