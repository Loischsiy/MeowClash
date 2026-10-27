import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'adaptive_app_bar.dart';
import 'adaptive_list.dart';
import 'glass_accessibility.dart';
import 'glass_tokens.dart';

bool get _mac => defaultTargetPlatform == TargetPlatform.macOS;

/// An Apple grouped list whose rows can be put in a new order: one inset
/// section (the card of [GlassListSection]: rounded, hairline edge, inset
/// hairlines between the rows) around a lazily built `SliverReorderableList`,
/// so long lists stay cheap.
///
/// A long press lifts a row out of the card with [GlassTokens.floatingShadow]
/// and grows it to [GlassTokens.listRowDragScale] (no growth with Reduce
/// Motion), like the profile sort sheet; dropping it calls [onReorderItem]
/// with the old index and the index of the row once it is removed there (as
/// `SliverReorderableList.onReorderItem`).
///
/// Rows are usually [GlassListRow]s, each with a key unique in the list.
/// Scrolls, so never blurred; opaque with Reduce Transparency or the blur
/// kill switch. Darwin only.
class GlassReorderableSection extends StatelessWidget {
  const GlassReorderableSection({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.onReorderItem,
    this.hasLeading = false,
    this.bottomInset = 0,
  });

  final int itemCount;

  /// Builds the row at an index; the row must have a key.
  final IndexedWidgetBuilder itemBuilder;
  final ReorderCallback onReorderItem;

  /// The rows have a leading symbol: the hairlines start at the row text.
  final bool hasLeading;

  /// Extra space below the section, e.g. to scroll clear of a floating
  /// button.
  final double bottomInset;

  static double get _radius =>
      _mac ? GlassTokens.listSectionRadiusMac : GlassTokens.listSectionRadiusIos;

  static double get _dividerInset {
    final padding = GlassListSection.rowPadding;
    if (!_mac) {
      return padding +
          GlassTokens.listRowLeadingSizeIos +
          GlassTokens.listRowLeadingGapIos;
    }
    return padding +
        GlassTokens.listRowLeadingSizeMac +
        GlassTokens.listRowLeadingGapMac;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    final dark = brightness == Brightness.dark;
    final accessibility = GlassAccessibility.of(context);
    final reduceMotion = accessibility.reduceMotion;
    final base =
        dark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest;
    final fill = accessibility.opaque
        ? base
        : base.withValues(alpha: GlassTokens.cardFillOpacity(brightness));
    final edge = (dark ? Colors.white : Colors.black)
        .withValues(alpha: GlassTokens.cardHairlineOpacity(brightness));
    final separatorColor = scheme.onSurface
        .withValues(alpha: GlassTokens.hairlineOpacity(brightness));
    final shadow = GlassTokens.floatingShadow(brightness);
    final radius = BorderRadius.circular(_radius);
    final dividerInset =
        hasLeading ? _dividerInset : GlassListSection.rowPadding;
    final padding = GlassListSection.listPadding;

    // The lifted row is opaque: it floats over the other rows.
    Widget proxyDecorator(
      Widget child,
      int index,
      Animation<double> animation,
    ) =>
        AnimatedBuilder(
          animation: animation,
          builder: (_, child) {
            final t = Curves.easeInOut.transform(animation.value);
            final scale = reduceMotion
                ? 1.0
                : lerpDouble(1, GlassTokens.listRowDragScale, t)!;
            return Transform.scale(scale: scale, child: child);
          },
          child: _GlassLiftScope(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: base,
                shape: RoundedSuperellipseBorder(borderRadius: radius),
                shadows: shadow,
              ),
              child: ClipRSuperellipse(
                borderRadius: radius,
                child: Material(
                  type: MaterialType.transparency,
                  child: child,
                ),
              ),
            ),
          ),
        );

    return GlassListScope(
      inSection: true,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: padding.copyWith(
              top: padding.top + AdaptiveAppBar.topInset(context),
              bottom: padding.bottom + bottomInset,
            ),
            // One card behind all rows (built lazily): the decorations span
            // the whole sliver, so its corners scroll with the content.
            sliver: DecoratedSliver(
              position: DecorationPosition.foreground,
              decoration: ShapeDecoration(
                shape: RoundedSuperellipseBorder(
                  borderRadius: radius,
                  side: BorderSide(
                    color: edge,
                    width: GlassTokens.hairlineWidth,
                  ),
                ),
              ),
              sliver: DecoratedSliver(
                decoration: ShapeDecoration(
                  color: fill,
                  shape: RoundedSuperellipseBorder(borderRadius: radius),
                ),
                sliver: SliverReorderableList(
                  itemCount: itemCount,
                  onReorderItem: onReorderItem,
                  proxyDecorator: proxyDecorator,
                  itemBuilder: (context, index) {
                    final row = itemBuilder(context, index);
                    final key = row.key;
                    assert(key != null, 'Every row needs a key.');
                    return _GlassReorderableSlot(
                      key: ValueKey<Key?>(key),
                      index: index,
                      count: itemCount,
                      radius: _radius,
                      dividerInset: dividerInset,
                      separatorColor: separatorColor,
                      child: row,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Marks the copy of a row that follows the pointer while it is dragged.
class _GlassLiftScope extends InheritedWidget {
  const _GlassLiftScope({required super.child});

  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_GlassLiftScope>() != null;

  @override
  bool updateShouldNotify(_GlassLiftScope oldWidget) => false;
}

/// One row of a [GlassReorderableSection]: the hairline above it (none on
/// the first row), the card corners clipped on the first and last rows and
/// the long-press drag start.
class _GlassReorderableSlot extends StatelessWidget {
  const _GlassReorderableSlot({
    super.key,
    required this.index,
    required this.count,
    required this.radius,
    required this.dividerInset,
    required this.separatorColor,
    required this.child,
  });

  final int index;
  final int count;
  final double radius;
  final double dividerInset;
  final Color separatorColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget row = ReorderableDelayedDragStartListener(
      index: index,
      child: child,
    );
    // The lifted copy is drawn as a card of its own by the proxy.
    if (_GlassLiftScope.of(context)) return row;
    final first = index == 0;
    final last = index == count - 1;
    if (first || last) {
      final corner = Radius.circular(radius);
      row = ClipRSuperellipse(
        borderRadius: BorderRadius.vertical(
          top: first ? corner : Radius.zero,
          bottom: last ? corner : Radius.zero,
        ),
        child: row,
      );
    }
    if (first) return row;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(start: dividerInset),
          child: SizedBox(
            height: GlassTokens.hairlineWidth,
            child: ColoredBox(color: separatorColor),
          ),
        ),
        row,
      ],
    );
  }
}
