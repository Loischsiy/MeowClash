import 'dart:math';

import 'package:meowclash/providers/app.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CommonDialog extends ConsumerWidget {

  const CommonDialog({
    super.key,
    required this.title,
    this.actions,
    this.child,
    this.padding,
    this.overrideScroll = false,
    this.backgroundColor,
    this.titleAccessory,
  });
  final String title;
  final Widget? child;
  final List<Widget>? actions;
  final EdgeInsets? padding;
  final bool overrideScroll;
  final Color? backgroundColor;

  /// Glass only: a control beside the title (see `GlassDialog`). Material
  /// ignores it, so call sites keep their Material actions unchanged.
  final Widget? titleAccessory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.watch(viewSizeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (AdaptivePlatform.useGlass) {
      return GlassDialog(
        title: title,
        actions: actions ?? const [],
        contentPadding: padding,
        color: backgroundColor,
        titleAccessory: titleAccessory,
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: min(
              size.height - 40,
              GlassTokens.dialogContentMaxHeight,
            ),
          ),
          child: !overrideScroll
              ? SingleChildScrollView(
                  child: child,
                )
              : child ?? const SizedBox.shrink(),
        ),
      );
    }
    
    return AlertDialog(
      title: Text(title),
      actions: actions,
      contentPadding: padding,
      backgroundColor: backgroundColor ?? colorScheme.surface.withValues(alpha: 0.92),
      content: Container(
        constraints: BoxConstraints(
          maxHeight: min(
            size.height - 40,
            500,
          ),
          maxWidth: 300,
        ),
        width: size.width - 40,
        child: !overrideScroll
            ? SingleChildScrollView(
                child: child,
              )
            : child,
      ),
    );
  }
}

class CommonModal extends ConsumerWidget {

  const CommonModal({
    super.key,
    this.child,
  });
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.watch(viewSizeProvider);
    final colorScheme = Theme.of(context).colorScheme;
    if (AdaptivePlatform.useGlass) {
      return GlassModalPanel(
        width: size.width * 0.85,
        height: size.height * 0.85,
        child: child,
      );
    }
    return Center(
      child: Container(
        width: size.width * 0.85,
        height: size.height * 0.85,
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
