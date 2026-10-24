import 'dart:async';
import 'dart:io';

import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/providers/config.dart';
import 'package:meowclash/providers/app.dart';
import 'package:meowclash/services/ui_lifecycle.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_ext/window_ext.dart';
import 'package:window_manager/window_manager.dart';

class WindowManager extends ConsumerStatefulWidget {
  const WindowManager({
    super.key,
    required this.child,
  });
  final Widget child;

  @override
  ConsumerState<WindowManager> createState() => _WindowContainerState();
}

class _WindowContainerState extends ConsumerState<WindowManager>
    with WindowListener, WindowExtListener {
  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      appSettingProvider.select((state) => state.autoLaunch),
      (prev, next) {
        if (prev != next) {
          debouncer.call(
            FunctionTag.autoLaunch,
            () {
              autoLaunch?.updateStatus(next);
            },
          );
        }
      },
    );
    windowExtManager.addListener(this);
    windowManager.addListener(this);
    unawaited(_syncInitialVisibility());
  }

  Future<void> _syncInitialVisibility() async {
    try {
      await uiLifecycle.synchronizeWindowVisibility(() async {
        final visible = await windowManager.isVisible();
        final minimized = await windowManager.isMinimized();
        return visible && !minimized;
      });
    } catch (error) {
      commonPrint.log('Window visibility unavailable: $error');
    }
  }

  @override
  void onWindowClose() async {
    await globalState.appController.handleBackOrExit();
    super.onWindowClose();
  }

  @override
  void onWindowFocus() {
    super.onWindowFocus();
    commonPrint.log("focus");
    uiLifecycle.updateWindowVisibility(visible: true);
    render?.resume();
  }

  @override
  Future<void> onShouldTerminate() async {
    await globalState.appController.handleExit();
    super.onShouldTerminate();
  }

  @override
  Future<void> onWindowMoved() async {
    super.onWindowMoved();
    final offset = await windowManager.getPosition();
    ref.read(windowSettingProvider.notifier).updateState(
          (state) => state.copyWith(
            top: offset.dy,
            left: offset.dx,
          ),
        );
  }

  @override
  Future<void> onWindowResized() async {
    super.onWindowResized();
    final size = await windowManager.getSize();
    ref.read(windowSettingProvider.notifier).updateState(
          (state) => state.copyWith(
            width: size.width,
            height: size.height,
          ),
        );
  }

  @override
  void onWindowMinimize() async {
    globalState.appController.savePreferencesDebounce();
    commonPrint.log("minimize");
    uiLifecycle.updateWindowVisibility(visible: false);
    render?.pause();
    super.onWindowMinimize();
  }

  @override
  void onWindowRestore() {
    commonPrint.log("restore");
    uiLifecycle.updateWindowVisibility(visible: true);
    render?.resume();
    super.onWindowRestore();
  }

  @override
  Future<void> dispose() async {
    windowExtManager.removeListener(this);
    windowManager.removeListener(this);
    super.dispose();
  }
}

class WindowHeaderContainer extends StatelessWidget {
  const WindowHeaderContainer({
    super.key,
    required this.child,
  });
  final Widget child;

  // On macOS the strip is the transparent title bar: it holds the native
  // traffic lights and is a drag area (see WindowHeader).
  //
  // macOS glass: full-size content view. The app is laid out under the title
  // bar, which becomes a top `MediaQuery` inset: the sidebar runs up behind
  // the traffic lights and each page's AppBar grows into a unified toolbar
  // (AdaptiveSidebar / AdaptiveAppBar). The strip stays on top only as an
  // invisible drag area.
  @override
  Widget build(BuildContext context) {
    if (AdaptivePlatform.isMacOSGlass) {
      final mediaQuery = MediaQuery.of(context);
      return Stack(
        children: [
          MediaQuery(
            data: mediaQuery.copyWith(
              padding: mediaQuery.padding.copyWith(
                top: mediaQuery.padding.top + kHeaderHeight,
              ),
              viewPadding: mediaQuery.viewPadding.copyWith(
                top: mediaQuery.viewPadding.top + kHeaderHeight,
              ),
            ),
            child: child,
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: WindowHeader(),
          ),
        ],
      );
    }
    return _buildMaterial();
  }

  Widget _buildMaterial() => Consumer(
        builder: (_, ref, child) => Stack(
          children: [
            Column(
              children: [
                SizedBox(
                  height: kHeaderHeight,
                ),
                Expanded(
                  flex: 1,
                  child: child!,
                ),
              ],
            ),
            const WindowHeader(),
          ],
        ),
        child: child,
      );
}

class WindowHeader extends StatefulWidget {
  const WindowHeader({super.key});

  @override
  State<WindowHeader> createState() => _WindowHeaderState();
}

class _WindowHeaderState extends State<WindowHeader> {
  final isMaximizedNotifier = ValueNotifier<bool>(false);
  final isPinNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _initNotifier();
  }

  Future<void> _initNotifier() async {
    isMaximizedNotifier.value = await windowManager.isMaximized();
    isPinNotifier.value = await windowManager.isAlwaysOnTop();
  }

  @override
  void dispose() {
    isMaximizedNotifier.dispose();
    isPinNotifier.dispose();
    super.dispose();
  }

  Future<void> _updateMaximized() async {
    final isMaximized = await windowManager.isMaximized();
    switch (isMaximized) {
      case true:
        await windowManager.unmaximize();
        break;
      case false:
        await windowManager.maximize();
        break;
    }
    isMaximizedNotifier.value = await windowManager.isMaximized();
  }

  Future<void> _updatePin() async {
    final isAlwaysOnTop = await windowManager.isAlwaysOnTop();
    await windowManager.setAlwaysOnTop(!isAlwaysOnTop);
    isPinNotifier.value = await windowManager.isAlwaysOnTop();
  }

  // Windows 11 style window control button
  Widget _buildWindowButton({
    required Widget icon,
    required VoidCallback onPressed,
    Color? hoverColor,
    Color? hoverIconColor,
  }) {
    return _WindowControlButton(
      icon: icon,
      onPressed: onPressed,
      hoverColor: hoverColor,
      hoverIconColor: hoverIconColor,
    );
  }

  Widget _buildActions(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pin button
        _buildWindowButton(
          icon: ValueListenableBuilder(
            valueListenable: isPinNotifier,
            builder: (_, value, ___) => Icon(
              value ? Icons.push_pin : Icons.push_pin_outlined,
              size: 16,
              color: colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          onPressed: _updatePin,
        ),
        // Minimize button
        _buildWindowButton(
          icon: Icon(
            Icons.remove,
            size: 18,
            color: colorScheme.onSurface.withValues(alpha: 0.8),
          ),
          onPressed: windowManager.minimize,
        ),
        // Maximize/Restore button
        _buildWindowButton(
          icon: ValueListenableBuilder(
            valueListenable: isMaximizedNotifier,
            builder: (_, value, ___) => Icon(
              value ? Icons.filter_none : Icons.crop_square,
              size: value ? 14 : 16,
              color: colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          onPressed: _updateMaximized,
        ),
        // Close button - red hover
        _buildWindowButton(
          icon: Icon(
            Icons.close,
            size: 18,
            color: colorScheme.onSurface.withValues(alpha: 0.8),
          ),
          onPressed: () => globalState.appController.handleBackOrExit(),
          hoverColor: const Color.fromARGB(255, 238, 44, 60),
          hoverIconColor: Colors.white,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    if (AdaptivePlatform.isMacOSGlass) {
      // Invisible: the native title bar is transparent and the content below
      // paints the chrome. Only window drag and zoom live here.
      return SizedBox(
        height: kHeaderHeight,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (_) => windowManager.startDragging(),
          onDoubleTap: _updateMaximized,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        height: kHeaderHeight,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
        child: Stack(
          children: [
            // Draggable area
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (_) => windowManager.startDragging(),
                onDoubleTap: _updateMaximized,
              ),
            ),
            // Content
            if (Platform.isMacOS)
              const Center(child: Text(appName))
            else
              Row(
                children: [
                  const SizedBox(width: 12),
                  // Connection status indicator
                  const _ConnectionStatusIndicator(),
                  const Spacer(),
                  // Window controls
                  _buildActions(context),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// Windows 11 style control button with hover effect
class _WindowControlButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback onPressed;
  final Color? hoverColor;
  final Color? hoverIconColor;

  const _WindowControlButton({
    required this.icon,
    required this.onPressed,
    this.hoverColor,
    this.hoverIconColor,
  });

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final defaultHoverColor = colorScheme.onSurface.withValues(alpha: 0.08);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 46,
          height: kHeaderHeight,
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.hoverColor ?? defaultHoverColor)
                : Colors.transparent,
          ),
          child: Center(
            child: _isHovered && widget.hoverIconColor != null
                ? IconTheme(
                    data: IconThemeData(color: widget.hoverIconColor),
                    child: widget.icon,
                  )
                : widget.icon,
          ),
        ),
      ),
    );
  }
}

// Connection status indicator for title bar
class _ConnectionStatusIndicator extends ConsumerWidget {
  const _ConnectionStatusIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;

    // Watch VPN/TUN status via runTimeProvider
    final isStart = ref.watch(runTimeProvider.select((state) => state != null));

    final statusColor = isStart
        ? const Color(0xFF4CAF50) // Green when connected
        : colorScheme.onSurface
            .withValues(alpha: 0.3); // Gray when disconnected

    final statusText =
        isStart ? appLocalizations.running : appLocalizations.stopped;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
            boxShadow: isStart
                ? [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          statusText,
          style: context.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class AppIcon extends StatelessWidget {
  const AppIcon({super.key});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 8),
        child: const Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircleAvatar(
                foregroundImage: AssetImage("assets/images/icon.png"),
                backgroundColor: Colors.transparent,
              ),
            ),
            SizedBox(
              width: 8,
            ),
            Text(
              appName,
            ),
          ],
        ),
      );
}
