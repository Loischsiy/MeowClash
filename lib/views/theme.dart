// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/config.dart' show TextScale;
import 'package:meowclash/models/selector.dart';
import 'package:meowclash/providers/config.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/widgets.dart';

class ThemeModeItem {
  const ThemeModeItem({
    required this.themeMode,
    required this.iconData,
    required this.label,
  });
  final ThemeMode themeMode;
  final IconData iconData;
  final String label;
}

class FontFamilyItem {
  const FontFamilyItem({
    required this.fontFamily,
    required this.label,
  });
  final FontFamily fontFamily;
  final String label;
}

class ThemeView extends StatelessWidget {
  const ThemeView({super.key});

  @override
  Widget build(BuildContext context) {
    if (AdaptivePlatform.useGlass) {
      // Darwin: an Apple grouped list, as System Settings > Appearance.
      return GlassListView(
        children: [
          GlassListSection(
            header: appLocalizations.themeMode,
            children: const [_ThemeModeItem()],
          ),
          const _PrimaryColorItem(),
          const GlassListSection(children: [_PrueBlackItem()]),
          const _TextScaleFactorItem(),
        ],
      );
    }
    return const SingleChildScrollView(
      child: Column(
        spacing: 24,
        children: [
          _ThemeModeItem(),
          _PrimaryColorItem(),
          _PrueBlackItem(),
          _TextScaleFactorItem(),
          SizedBox(
            height: 64,
          ),
        ],
      ),
    );
  }
}

class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.info,
    required this.child,
    this.actions = const [],
  });
  final Widget child;
  final Info info;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Wrap(
        runSpacing: 16,
        children: [
          InfoHeader(
            info: info,
            actions: actions,
          ),
          child,
        ],
      );
}

class _ThemeModeItem extends ConsumerWidget {
  const _ThemeModeItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode =
        ref.watch(themeSettingProvider.select((state) => state.themeMode));
    final themeModeItems = <ThemeModeItem>[
      ThemeModeItem(
        iconData: Icons.auto_mode,
        label: appLocalizations.auto,
        themeMode: ThemeMode.system,
      ),
      ThemeModeItem(
        iconData: Icons.light_mode,
        label: appLocalizations.light,
        themeMode: ThemeMode.light,
      ),
      ThemeModeItem(
        iconData: Icons.dark_mode,
        label: appLocalizations.dark,
        themeMode: ThemeMode.dark,
      ),
    ];
    if (AdaptivePlatform.useGlass) {
      return _GlassAppearancePicker(
        items: themeModeItems,
        value: themeMode,
        onChanged: (mode) {
          ref.read(themeSettingProvider.notifier).updateState(
                (state) => state.copyWith(themeMode: mode),
              );
        },
      );
    }
    return ItemCard(
      info: Info(
        label: appLocalizations.themeMode,
        iconData: Icons.brightness_high,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: themeModeItems.length,
          itemBuilder: (_, index) {
            final themeModeItem = themeModeItems[index];
            return CommonCard(
              isSelected: themeModeItem.themeMode == themeMode,
              onPressed: () {
                ref.read(themeSettingProvider.notifier).updateState(
                      (state) => state.copyWith(
                        themeMode: themeModeItem.themeMode,
                      ),
                    );
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Icon(
                        themeModeItem.iconData,
                        size: 18,
                      ),
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    Flexible(
                      child: Text(
                        themeModeItem.label,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(
            width: 12,
          ),
        ),
      ),
    );
  }
}

class _PrimaryColorItem extends ConsumerStatefulWidget {
  const _PrimaryColorItem();

  @override
  ConsumerState<_PrimaryColorItem> createState() => _PrimaryColorItemState();
}

class _PrimaryColorItemState extends ConsumerState<_PrimaryColorItem> {
  int? _removablePrimaryColor;

  int _calcColumns(double maxWidth) => max((maxWidth / 96).ceil(), 3);

  Future<void> _handleReset() async {
    final res = await globalState.showMessage(
      message: TextSpan(
        text: appLocalizations.resetTip,
      ),
    );
    if (res != true) {
      return;
    }
    ref.read(themeSettingProvider.notifier).updateState(
          (state) => state.copyWith(
            primaryColors: defaultPrimaryColors,
            primaryColor: defaultPrimaryColor,
            schemeVariant: DynamicSchemeVariant.tonalSpot,
          ),
        );
  }

  Future<void> _handleDel() async {
    if (_removablePrimaryColor == null) {
      return;
    }
    final res = await globalState.showMessage(
      message: TextSpan(
        text: appLocalizations.deleteTip(
          appLocalizations.colorSchemes,
        ),
      ),
    );
    if (res != true) {
      return;
    }
    ref.read(themeSettingProvider.notifier).updateState(
      (state) {
        final newPrimaryColors = List<int>.from(state.primaryColors)
          ..remove(_removablePrimaryColor);
        var newPrimaryColor = state.primaryColor;
        if (state.primaryColor == _removablePrimaryColor) {
          if (newPrimaryColors.contains(defaultPrimaryColor)) {
            newPrimaryColor = defaultPrimaryColor;
          } else {
            newPrimaryColor = null;
          }
        }
        return state.copyWith(
          primaryColors: newPrimaryColors,
          primaryColor: newPrimaryColor,
        );
      },
    );
    setState(() {
      _removablePrimaryColor = null;
    });
  }

  Future<void> _handleAdd() async {
    final res = await globalState.showCommonDialog<int>(
      child: const _PaletteDialog(),
    );
    if (res == null) {
      return;
    }
    final isExists = ref.read(
      themeSettingProvider.select((state) => state.primaryColors.contains(res)),
    );
    if (isExists && mounted) {
      context.showNotifier(
        appLocalizations.existsTip(
          appLocalizations.colorSchemes,
        ),
      );
      return;
    }
    ref.read(themeSettingProvider.notifier).updateState(
          (state) => state.copyWith(
            primaryColors: List.from(
              state.primaryColors,
            )..add(res),
          ),
        );
  }

  Future<void> _handleChangeSchemeVariant() async {
    final schemeVariant = ref.read(
      themeSettingProvider.select(
        (state) => state.schemeVariant,
      ),
    );
    final value = await globalState.showCommonDialog<DynamicSchemeVariant>(
      child: OptionsDialog<DynamicSchemeVariant>(
        title: appLocalizations.colorSchemes,
        options: DynamicSchemeVariant.values,
        textBuilder: (item) => Intl.message("${item.name}Scheme"),
        value: schemeVariant,
      ),
    );
    if (value == null) {
      return;
    }
    ref.read(themeSettingProvider.notifier).updateState(
          (state) => state.copyWith(
            schemeVariant: value,
          ),
        );
  }

  /// Darwin: a long press (or a secondary click) asks to delete the color
  /// right away instead of entering the Material delete mode.
  Future<void> _handleGlassDelete(int color) async {
    setState(() {
      _removablePrimaryColor = color;
    });
    await _handleDel();
    if (mounted && _removablePrimaryColor != null) {
      setState(() {
        _removablePrimaryColor = null;
      });
    }
  }

  /// Darwin: the colors as round swatches (the macOS accent color row), the
  /// scheme variant as a pop-up row and a red reset row while the colors
  /// differ from the defaults.
  Widget _buildGlass({
    required int? primaryColor,
    required List<int?> primaryColors,
    required DynamicSchemeVariant schemeVariant,
    required bool isEquals,
  }) {
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    final gap =
        mac ? GlassTokens.themeSwatchGapMac : GlassTokens.themeSwatchGapIos;
    return GlassListSection(
      header: appLocalizations.themeColor,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: GlassListSection.rowPadding,
            vertical: mac
                ? GlassTokens.themeSwatchRowPaddingMac
                : GlassTokens.themeSwatchRowPaddingIos,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final color in primaryColors)
                  _GlassColorSwatch(
                    color: color,
                    selected: color == primaryColor,
                    onTap: () {
                      ref.read(themeSettingProvider.notifier).updateState(
                            (state) => state.copyWith(primaryColor: color),
                          );
                    },
                    onDelete:
                        color == null ? null : () => _handleGlassDelete(color),
                  ),
                _GlassAddSwatch(onTap: _handleAdd),
              ],
            ),
          ),
        ),
        ListItem<DynamicSchemeVariant>.options(
          title: Text(appLocalizations.colorSchemes),
          delegate: OptionsDelegate<DynamicSchemeVariant>(
            title: appLocalizations.colorSchemes,
            options: DynamicSchemeVariant.values,
            textBuilder: (item) => Intl.message("${item.name}Scheme"),
            value: schemeVariant,
            onChanged: (value) {
              if (value == null) {
                return;
              }
              ref.read(themeSettingProvider.notifier).updateState(
                    (state) => state.copyWith(schemeVariant: value),
                  );
            },
          ),
        ),
        if (!isEquals)
          GlassListRow(
            title: Text(appLocalizations.reset),
            destructive: true,
            onTap: _handleReset,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm4 = ref.watch(
      themeSettingProvider.select(
        (state) => VM4(
          a: state.primaryColor,
          b: state.primaryColors,
          c: state.schemeVariant,
          d: state.primaryColor == defaultPrimaryColor &&
              intListEquality.equals(state.primaryColors, defaultPrimaryColors),
        ),
      ),
    );
    final primaryColor = vm4.a;
    final primaryColors = [null, ...vm4.b];
    final schemeVariant = vm4.c;
    final isEquals = vm4.d;

    if (AdaptivePlatform.useGlass) {
      return _buildGlass(
        primaryColor: primaryColor,
        primaryColors: primaryColors,
        schemeVariant: schemeVariant,
        isEquals: isEquals,
      );
    }
    return CommonPopScope(
      onPop: () {
        if (_removablePrimaryColor != null) {
          setState(() {
            _removablePrimaryColor = null;
          });
          return false;
        }
        return true;
      },
      child: ItemCard(
        info: Info(
          label: appLocalizations.themeColor,
          iconData: Icons.palette,
        ),
        actions: genActions(
          [
            if (_removablePrimaryColor == null)
              FilledButton(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _handleChangeSchemeVariant,
                child: Text(Intl.message("${schemeVariant.name}Scheme")),
              ),
            if (_removablePrimaryColor != null)
              FilledButton(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  setState(() {
                    _removablePrimaryColor = null;
                  });
                },
                child: Text(appLocalizations.cancel),
              ),
            if (_removablePrimaryColor == null && !isEquals)
              IconButton.filledTonal(
                iconSize: 20,
                padding: const EdgeInsets.all(4),
                visualDensity: VisualDensity.compact,
                onPressed: _handleReset,
                icon: const Icon(Icons.replay),
              )
          ],
          space: 8,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          child: LayoutBuilder(
            builder: (_, constraints) {
              final columns = _calcColumns(constraints.maxWidth);
              final itemWidth =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final color in primaryColors)
                    Container(
                      clipBehavior: Clip.none,
                      width: itemWidth,
                      height: itemWidth,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          EffectGestureDetector(
                            child: ColorSchemeBox(
                              isSelected: color == primaryColor,
                              primaryColor:
                                  color != null ? ui.Color(color) : null,
                              onPressed: () {
                                setState(() {
                                  _removablePrimaryColor = null;
                                });
                                ref
                                    .read(themeSettingProvider.notifier)
                                    .updateState(
                                      (state) => state.copyWith(
                                        primaryColor: color,
                                      ),
                                    );
                              },
                            ),
                            onLongPress: () {
                              setState(() {
                                _removablePrimaryColor = color;
                              });
                            },
                          ),
                          if (_removablePrimaryColor != null &&
                              _removablePrimaryColor == color)
                            Container(
                              color: Colors.white.opacity0,
                              padding: const EdgeInsets.all(8),
                              child: IconButton.filledTonal(
                                onPressed: _handleDel,
                                padding: const EdgeInsets.all(12),
                                iconSize: 30,
                                icon: Icon(
                                  color: context.colorScheme.primary,
                                  Icons.delete,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (_removablePrimaryColor == null)
                    Container(
                      width: itemWidth,
                      height: itemWidth,
                      padding: const EdgeInsets.all(
                        4,
                      ),
                      child: IconButton.filledTonal(
                        onPressed: _handleAdd,
                        iconSize: 32,
                        icon: Icon(
                          color: context.colorScheme.primary,
                          Icons.add,
                        ),
                      ),
                    )
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PrueBlackItem extends ConsumerWidget {
  const _PrueBlackItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prueBlack = ref.watch(
      themeSettingProvider.select(
        (state) => state.pureBlack,
      ),
    );
    if (AdaptivePlatform.useGlass) {
      return ListItem.switchItem(
        leading: const Icon(Icons.contrast),
        title: Text(appLocalizations.pureBlackMode),
        delegate: SwitchDelegate(
          value: prueBlack,
          onChanged: (value) {
            ref.read(themeSettingProvider.notifier).updateState(
                  (state) => state.copyWith(pureBlack: value),
                );
          },
        ),
      );
    }
    return ListItem.switchItem(
      leading: const Icon(
        Icons.contrast,
      ),
      horizontalTitleGap: 12,
      title: Text(
        appLocalizations.pureBlackMode,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
      ),
      delegate: SwitchDelegate(
        value: prueBlack,
        onChanged: (value) {
          ref.read(themeSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  pureBlack: value,
                ),
              );
        },
      ),
    );
  }
}

class _TextScaleFactorItem extends ConsumerWidget {
  const _TextScaleFactorItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textScale = ref.watch(
      themeSettingProvider.select(
        (state) => state.textScale,
      ),
    );
    final process = "${((textScale.scale * 100) as double).round()}%";
    if (AdaptivePlatform.useGlass) {
      return _buildGlass(context, ref, textScale, process);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ListItem.switchItem(
            leading: const Icon(
              Icons.text_fields,
            ),
            horizontalTitleGap: 12,
            title: Text(
              appLocalizations.textScale,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
            ),
            delegate: SwitchDelegate(
              value: textScale.enable,
              onChanged: (value) {
                ref.read(themeSettingProvider.notifier).updateState(
                      (state) => state.copyWith.textScale(
                        enable: value,
                      ),
                    );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            spacing: 32,
            children: [
              Expanded(
                child: DisabledMask(
                  status: !textScale.enable,
                  child: ActivateBox(
                    active: textScale.enable,
                    child: SliderTheme(
                      data: _SliderDefaultsM3(context),
                      child: Slider(
                        padding: EdgeInsets.zero,
                        min: minTextScale,
                        max: maxTextScale,
                        value: textScale.scale,
                        onChanged: (value) {
                          ref.read(themeSettingProvider.notifier).updateState(
                                (state) => state.copyWith.textScale(
                                  scale: value,
                                ),
                              );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  process,
                  style: context.textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

extension on _TextScaleFactorItem {
  /// Darwin: the switch row with the current size as its value, then the
  /// slider between a small and a large "A", as iOS Text Size.
  Widget _buildGlass(
    BuildContext context,
    WidgetRef ref,
    TextScale textScale,
    String process,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final glyphColor = textScale.enable
        ? scheme.onSurfaceVariant
        : scheme.onSurface.withValues(alpha: GlassTokens.disabledOpacity);
    void setEnabled({required bool enable}) {
      ref.read(themeSettingProvider.notifier).updateState(
            (state) => state.copyWith.textScale(enable: enable),
          );
    }

    return GlassListSection(
      children: [
        GlassListRow(
          leading: const Icon(Icons.text_fields),
          title: Text(appLocalizations.textScale),
          value: Text(process),
          trailing: AdaptiveSwitch(
            value: textScale.enable,
            onChanged: (value) => setEnabled(enable: value),
          ),
          onTap: () => setEnabled(enable: !textScale.enable),
        ),
        GlassListField(
          child: Row(
            children: [
              ExcludeSemantics(
                child: Text(
                  'A',
                  style: GlassTextStyles.scaleGlyph(
                    theme.textTheme,
                    large: false,
                  ).copyWith(color: glyphColor),
                ),
              ),
              const SizedBox(width: GlassTokens.scaleGlyphGap),
              Expanded(
                child: AdaptiveSlider(
                  min: minTextScale,
                  max: maxTextScale,
                  value: textScale.scale,
                  onChanged: textScale.enable
                      ? (value) {
                          ref.read(themeSettingProvider.notifier).updateState(
                                (state) => state.copyWith.textScale(
                                  scale: value,
                                ),
                              );
                        }
                      : null,
                ),
              ),
              const SizedBox(width: GlassTokens.scaleGlyphGap),
              ExcludeSemantics(
                child: Text(
                  'A',
                  style: GlassTextStyles.scaleGlyph(
                    theme.textTheme,
                    large: true,
                  ).copyWith(color: glyphColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Darwin: the theme modes as window previews with a selection ring, as
/// macOS Appearance (Auto is split light / dark).
class _GlassAppearancePicker extends StatelessWidget {
  const _GlassAppearancePicker({
    required this.items,
    required this.value,
    required this.onChanged,
  });

  final List<ThemeModeItem> items;
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: GlassListSection.rowPadding,
        vertical: mac
            ? GlassTokens.themePickerPaddingMac
            : GlassTokens.themePickerPaddingIos,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final item in items)
            _GlassAppearanceOption(
              item: item,
              selected: item.themeMode == value,
              onTap: () => onChanged(item.themeMode),
            ),
        ],
      ),
    );
  }
}

class _GlassAppearanceOption extends StatelessWidget {
  const _GlassAppearanceOption({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ThemeModeItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    final reduceMotion = GlassAccessibility.of(context).reduceMotion;
    final width = mac
        ? GlassTokens.themePreviewWidthMac
        : GlassTokens.themePreviewWidthIos;
    final height = mac
        ? GlassTokens.themePreviewHeightMac
        : GlassTokens.themePreviewHeightIos;
    final radius = mac
        ? GlassTokens.themePreviewRadiusMac
        : GlassTokens.themePreviewRadiusIos;
    const ringInset =
        GlassTokens.themePreviewRingGap + GlassTokens.themePreviewRingWidth;
    final accent = scheme.primary;
    Widget pane({required bool dark}) => _AppearancePane(
          dark: dark,
          accent: accent,
          width: width,
          height: height,
        );
    final preview = switch (item.themeMode) {
      ThemeMode.light => pane(dark: false),
      ThemeMode.dark => pane(dark: true),
      ThemeMode.system => Stack(
          children: [
            pane(dark: false),
            PositionedDirectional(
              top: 0,
              bottom: 0,
              end: 0,
              child: ClipRect(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  widthFactor: 0.5,
                  child: pane(dark: true),
                ),
              ),
            ),
          ],
        ),
    };
    final labelStyle =
        GlassTextStyles.listRowSubtitle(theme.textTheme).copyWith(
      color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: GlassTokens.motion(
                GlassTokens.hoverDuration,
                reduceMotion: reduceMotion,
              ),
              padding: const EdgeInsets.all(ringInset),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius + ringInset),
                border: Border.all(
                  color: accent.withValues(alpha: selected ? 1 : 0),
                  width: GlassTokens.themePreviewRingWidth,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: scheme.onSurface.withValues(
                        alpha: GlassTokens.hairlineOpacity(theme.brightness),
                      ),
                      width: GlassTokens.themeSwatchEdgeWidth,
                    ),
                  ),
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: preview,
                  ),
                ),
              ),
            ),
            const SizedBox(height: GlassTokens.themePreviewLabelGap),
            Text(item.label, style: labelStyle),
          ],
        ),
      ),
    );
  }
}

/// A miniature window in the light or [dark] system colors: title bar, an
/// accent pill and a text line.
class _AppearancePane extends StatelessWidget {
  const _AppearancePane({
    required this.dark,
    required this.accent,
    required this.width,
    required this.height,
  });

  final bool dark;
  final Color accent;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    BorderRadius pill(double size) => BorderRadius.circular(size / 2);
    return SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: dark
            ? GlassTokens.themePreviewDarkFill
            : GlassTokens.themePreviewLightFill,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: height * GlassTokens.themePreviewBarFraction,
              color: dark
                  ? GlassTokens.themePreviewDarkBar
                  : GlassTokens.themePreviewLightBar,
            ),
            Padding(
              padding: const EdgeInsets.all(GlassTokens.themePreviewInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: width * GlassTokens.themePreviewPillWidthFraction,
                    height: GlassTokens.themePreviewPillHeight,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: pill(GlassTokens.themePreviewPillHeight),
                    ),
                  ),
                  const SizedBox(height: GlassTokens.themePreviewLineGap),
                  Container(
                    width: width * GlassTokens.themePreviewLineWidthFraction,
                    height: GlassTokens.themePreviewLineHeight,
                    decoration: BoxDecoration(
                      color: dark
                          ? GlassTokens.themePreviewDarkLine
                          : GlassTokens.themePreviewLightLine,
                      borderRadius: pill(GlassTokens.themePreviewLineHeight),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double get _swatchSize => defaultTargetPlatform == TargetPlatform.macOS
    ? GlassTokens.themeSwatchSizeMac
    : GlassTokens.themeSwatchSizeIos;

const _swatchRingInset =
    GlassTokens.themeSwatchRingGap + GlassTokens.themeSwatchRingWidth;

/// Darwin: one theme color as a round swatch of the picked color itself (as
/// the macOS accent row, not a scheme tone); the selected one gets a ring
/// and a white checkmark. `null` follows the system accent and is drawn
/// multicolor, as on macOS.
class _GlassColorSwatch extends StatelessWidget {
  const _GlassColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
    this.onDelete,
  });

  final int? color;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final value = color;
    final theme = Theme.of(context);
    final fill = value != null ? ui.Color(value) : theme.colorScheme.primary;
    final size = _swatchSize;
    final reduceMotion = GlassAccessibility.of(context).reduceMotion;
    return Semantics(
      button: true,
      selected: selected,
      label: value == null ? appLocalizations.system : fill.hex,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onDelete,
        onSecondaryTap: onDelete,
        child: AnimatedContainer(
          duration: GlassTokens.motion(
            GlassTokens.hoverDuration,
            reduceMotion: reduceMotion,
          ),
          padding: const EdgeInsets.all(_swatchRingInset),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: fill.withValues(alpha: selected ? 1 : 0),
              width: GlassTokens.themeSwatchRingWidth,
            ),
          ),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value == null ? null : fill,
              gradient: value == null
                  ? const SweepGradient(
                      colors: GlassTokens.themeSwatchMulticolor,
                    )
                  : null,
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(
                  alpha: GlassTokens.hairlineOpacity(theme.brightness),
                ),
                width: GlassTokens.themeSwatchEdgeWidth,
              ),
            ),
            child: selected
                ? Icon(
                    Icons.check_rounded,
                    size: size * GlassTokens.themeSwatchCheckFraction,
                    color: Colors.white,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Darwin: the "add color" swatch at the end of the swatch row.
class _GlassAddSwatch extends StatelessWidget {
  const _GlassAddSwatch({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final size = _swatchSize;
    return Semantics(
      button: true,
      label: appLocalizations.add,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(_swatchRingInset),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.onSurface.withValues(
                alpha: GlassTokens.inputFillOpacity(theme.brightness),
              ),
              border: Border.all(
                color: scheme.onSurface.withValues(
                  alpha: GlassTokens.hairlineOpacity(theme.brightness),
                ),
                width: GlassTokens.themeSwatchEdgeWidth,
              ),
            ),
            child: Icon(
              Icons.add_rounded,
              size: size * GlassTokens.themeSwatchCheckFraction,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _PaletteDialog extends StatefulWidget {
  const _PaletteDialog();

  @override
  State<_PaletteDialog> createState() => _PaletteDialogState();
}

class _PaletteDialogState extends State<_PaletteDialog> {
  final _controller = ValueNotifier<ui.Color>(Colors.transparent);

  @override
  Widget build(BuildContext context) => CommonDialog(
        title: appLocalizations.palette,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(appLocalizations.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(_controller.value.toARGB32());
            },
            child: Text(appLocalizations.confirm),
          ),
        ],
        child: Column(
          children: [
            const SizedBox(
              height: 8,
            ),
            SizedBox(
              width: 250,
              height: 250,
              child: Palette(
                controller: _controller,
              ),
            ),
            const SizedBox(
              height: 24,
            ),
            ValueListenableBuilder(
              valueListenable: _controller,
              builder: (_, color, __) => PrimaryColorBox(
                primaryColor: color,
                child: FilledButton(
                  onPressed: () {},
                  child: Text(
                    _controller.value.hex,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _SliderDefaultsM3 extends SliderThemeData {
  _SliderDefaultsM3(this.context) : super(trackHeight: 16.0);

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;

  @override
  Color? get activeTrackColor => _colors.primary;

  @override
  Color? get inactiveTrackColor => _colors.secondaryContainer;

  @override
  Color? get secondaryActiveTrackColor => _colors.primary.withOpacity(0.54);

  @override
  Color? get disabledActiveTrackColor => _colors.onSurface.withOpacity(0.38);

  @override
  Color? get disabledInactiveTrackColor => _colors.onSurface.withOpacity(0.12);

  @override
  Color? get disabledSecondaryActiveTrackColor =>
      _colors.onSurface.withOpacity(0.38);

  @override
  Color? get activeTickMarkColor => _colors.onPrimary.withOpacity(1.0);

  @override
  Color? get inactiveTickMarkColor =>
      _colors.onSecondaryContainer.withOpacity(1.0);

  @override
  Color? get disabledActiveTickMarkColor => _colors.onInverseSurface;

  @override
  Color? get disabledInactiveTickMarkColor => _colors.onSurface;

  @override
  Color? get thumbColor => _colors.primary;

  @override
  Color? get disabledThumbColor => _colors.onSurface.withOpacity(0.38);

  @override
  Color? get overlayColor => WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.dragged)) {
          return _colors.primary.withOpacity(0.1);
        }
        if (states.contains(WidgetState.hovered)) {
          return _colors.primary.withOpacity(0.08);
        }
        if (states.contains(WidgetState.focused)) {
          return _colors.primary.withOpacity(0.1);
        }

        return Colors.transparent;
      });

  @override
  TextStyle? get valueIndicatorTextStyle =>
      Theme.of(context).textTheme.labelLarge!.copyWith(
            color: _colors.onInverseSurface,
          );

  @override
  Color? get valueIndicatorColor => _colors.inverseSurface;

  @override
  SliderComponentShape? get valueIndicatorShape =>
      const RoundedRectSliderValueIndicatorShape();

  @override
  SliderComponentShape? get thumbShape => const HandleThumbShape();

  @override
  SliderTrackShape? get trackShape => const GappedSliderTrackShape();

  @override
  SliderComponentShape? get overlayShape => const RoundSliderOverlayShape();

  @override
  SliderTickMarkShape? get tickMarkShape =>
      const RoundSliderTickMarkShape(tickMarkRadius: 4.0 / 2);

  @override
  WidgetStateProperty<Size?>? get thumbSize =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return const Size(4.0, 44.0);
        }
        if (states.contains(WidgetState.hovered)) {
          return const Size(4.0, 44.0);
        }
        if (states.contains(WidgetState.focused)) {
          return const Size(2.0, 44.0);
        }
        if (states.contains(WidgetState.pressed)) {
          return const Size(2.0, 44.0);
        }
        return const Size(4.0, 44.0);
      });

  @override
  double? get trackGap => 6.0;
}
