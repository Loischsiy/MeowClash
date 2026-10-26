import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/open_container.dart';
import 'package:flutter/material.dart';

import 'adaptive/adaptive.dart';
import 'card.dart';
import 'input.dart';
import 'scaffold.dart';
import 'sheet.dart';

class Delegate {
  const Delegate();
}

class RadioDelegate<T> extends Delegate {

  const RadioDelegate({
    required this.value,
    required this.groupValue,
    this.onChanged,
  });
  final T value;
  final T groupValue;
  final void Function(T?)? onChanged;
}

class SwitchDelegate<T> extends Delegate {

  const SwitchDelegate({
    required this.value,
    this.onChanged,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
}

class CheckboxDelegate<T> extends Delegate {

  const CheckboxDelegate({
    this.value = false,
    this.onChanged,
  });
  final bool value;
  final ValueChanged<bool?>? onChanged;
}

class OpenDelegate extends Delegate {

  const OpenDelegate({
    required this.title,
    required this.widget,
    this.maxWidth,
    this.action,
    this.blur = true,
    this.scrollUnderToolbar = false,
  });
  final Widget widget;
  final String title;
  final double? maxWidth;
  final Widget? action;
  final bool blur;

  /// Darwin glass only: when pushed full screen (iPhone), [widget] scrolls
  /// under the glass toolbar; it must add `AdaptiveAppBar.topInset` itself
  /// (see `scrollUnderToolbarPages`). No effect on Material or in sheets.
  final bool scrollUnderToolbar;
}

class NextDelegate extends Delegate {

  const NextDelegate({
    required this.title,
    required this.widget,
    this.maxWidth,
    this.action,
    this.blur = true,
  });
  final Widget widget;
  final String title;
  final double? maxWidth;
  final Widget? action;
  final bool blur;
}

class OptionsDelegate<T> extends Delegate {

  const OptionsDelegate({
    required this.title,
    required this.options,
    required this.textBuilder,
    required this.value,
    required this.onChanged,
  });
  final List<T> options;
  final String title;
  final T value;
  final String Function(T value) textBuilder;
  final Function(T? value) onChanged;
}

class InputDelegate extends Delegate {

  const InputDelegate({
    required this.title,
    required this.value,
    this.suffixText,
    required this.onChanged,
    this.resetValue,
    this.validator,
  });
  final String title;
  final String value;
  final String? suffixText;
  final Function(String? value) onChanged;
  final FormFieldValidator<String>? validator;

  final String? resetValue;
}

/// A settings row.
///
/// * Darwin, inside a [GlassListScope] (`generateListView`,
///   `generateSection`, a [GlassListSection]): a [GlassListRow] — open /
///   next / input get a chevron, options a menu over the value, switches an
///   `AdaptiveSwitch`, checkbox / radio a checkmark.
/// * Everywhere else: the Material `ListTile`, unchanged.
class ListItem<T> extends StatelessWidget implements GlassLeadingHint {

  const ListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.trailing,
    this.horizontalTitleGap,
    this.dense,
    this.onTap,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : delegate = const Delegate();

  const ListItem.open({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.trailing,
    required OpenDelegate this.delegate,
    this.horizontalTitleGap,
    this.dense,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : onTap = null;

  const ListItem.next({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.trailing,
    required NextDelegate this.delegate,
    this.horizontalTitleGap,
    this.dense,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : onTap = null;

  const ListItem.options({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.trailing,
    required OptionsDelegate<T> this.delegate,
    this.horizontalTitleGap,
    this.dense,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : onTap = null;

  const ListItem.input({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.trailing,
    required InputDelegate this.delegate,
    this.horizontalTitleGap,
    this.dense,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : onTap = null;

  const ListItem.checkbox({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.only(left: 16, right: 8),
    required CheckboxDelegate<T> this.delegate,
    this.horizontalTitleGap,
    this.dense,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  })  : trailing = null,
        onTap = null;

  const ListItem.switchItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.only(left: 16, right: 8),
    required SwitchDelegate<T> this.delegate,
    this.horizontalTitleGap,
    this.dense,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  })  : trailing = null,
        onTap = null;

  const ListItem.radio({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.only(left: 12, right: 16),
    required RadioDelegate<T> this.delegate,
    this.horizontalTitleGap = 8,
    this.dense,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  })  : leading = null,
        onTap = null;
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final EdgeInsets padding;
  final ListTileTitleAlignment tileTitleAlignment;
  final bool? dense;
  final Widget? trailing;
  final Delegate delegate;
  final double? horizontalTitleGap;
  final TextStyle? titleTextStyle;
  final TextStyle? subtitleTextStyle;
  final void Function()? onTap;

  @override
  bool get hasGlassLeading => leading != null;

  ListTile _buildListTile({
    void Function()? onTap,
    Widget? trailing,
    Widget? leading,
  }) => ListTile(
      key: key,
      dense: dense,
      titleTextStyle: titleTextStyle,
      subtitleTextStyle: subtitleTextStyle,
      leading: leading ?? this.leading,
      horizontalTitleGap: horizontalTitleGap,
      title: title,
      minVerticalPadding: 12,
      subtitle: subtitle,
      titleAlignment: tileTitleAlignment,
      onTap: onTap,
      trailing: trailing ?? this.trailing,
      contentPadding: padding,
    );

  Widget _buildGlassRow(
    BuildContext context, {
    VoidCallback? onTap,
    Widget? value,
    Widget? trailing,
    GlassRowAccessory accessory = GlassRowAccessory.none,
    bool selected = false,
    bool enabled = true,
    bool showSubtitle = true,
  }) {
    final rowTrailing = trailing ?? this.trailing;
    return GlassListRow(
      title: title,
      subtitle: showSubtitle ? subtitle : null,
      leading: leading,
      value: value,
      trailing: rowTrailing == null
          ? null
          : Theme(
              data: GlassTheme.row(Theme.of(context)),
              child: rowTrailing,
            ),
      accessory: accessory,
      onTap: enabled ? onTap : null,
      selected: selected,
      enabled: enabled,
    );
  }

  void _showGlassPage(
    BuildContext context, {
    required String title,
    required Widget body,
    required Widget? action,
    required double? maxWidth,
    required bool blur,
    bool scrollUnderToolbar = false,
  }) {
    final child = SafeArea(child: body);
    final actions = [if (action != null) action];
    if (globalState.appState.viewMode != ViewMode.mobile) {
      showExtend(
        context,
        props: ExtendProps(blur: blur, maxWidth: maxWidth),
        builder: (_, type) => AdaptiveSheetScaffold(
          actions: actions,
          type: type,
          body: child,
          title: title,
        ),
      );
      return;
    }
    final navigator = Navigator.of(context);
    BaseNavigator.push(
      context,
      CommonScaffold.open(
        key: Key(title),
        onBack: navigator.pop,
        title: title,
        // Scrolling under the toolbar: the page adds the top inset itself.
        body: scrollUnderToolbar ? SafeArea(top: false, child: body) : child,
        disableBackground: true,
        actions: actions,
        scrollUnderToolbar: scrollUnderToolbar,
      ),
    );
  }

  Widget _buildGlass(BuildContext context) {
    final delegate = this.delegate;
    if (delegate is OpenDelegate) {
      return _buildGlassRow(
        context,
        accessory: GlassRowAccessory.chevron,
        onTap: () => _showGlassPage(
          context,
          title: delegate.title,
          body: delegate.widget,
          action: delegate.action,
          maxWidth: delegate.maxWidth,
          blur: delegate.blur,
          scrollUnderToolbar: delegate.scrollUnderToolbar,
        ),
      );
    }
    if (delegate is NextDelegate) {
      return _buildGlassRow(
        context,
        accessory: GlassRowAccessory.chevron,
        onTap: () => _showGlassPage(
          context,
          title: delegate.title,
          body: delegate.widget,
          action: delegate.action,
          maxWidth: delegate.maxWidth,
          blur: delegate.blur,
        ),
      );
    }
    if (delegate is OptionsDelegate) {
      return _GlassOptionsItem<T>(
        item: this,
        delegate: delegate as OptionsDelegate<T>,
      );
    }
    if (delegate is InputDelegate) {
      final suffix = delegate.suffixText;
      return _buildGlassRow(
        context,
        // Input rows show their current value as the subtitle on Material.
        value: subtitle ??
            Text(suffix == null ? delegate.value : '${delegate.value} $suffix'),
        showSubtitle: false,
        accessory: GlassRowAccessory.chevron,
        onTap: () async {
          final value = await globalState.showCommonDialog<String>(
            child: InputDialog(
              title: delegate.title,
              value: delegate.value,
              suffixText: delegate.suffixText,
              resetValue: delegate.resetValue,
              validator: delegate.validator,
            ),
          );
          delegate.onChanged(value);
        },
      );
    }
    if (delegate is CheckboxDelegate) {
      final onChanged = delegate.onChanged;
      return _buildGlassRow(
        context,
        accessory: delegate.value
            ? GlassRowAccessory.checkmark
            : GlassRowAccessory.none,
        selected: delegate.value,
        enabled: onChanged != null,
        onTap: () => onChanged?.call(!delegate.value),
      );
    }
    if (delegate is SwitchDelegate) {
      final onChanged = delegate.onChanged;
      return _buildGlassRow(
        context,
        trailing: AdaptiveSwitch(
          value: delegate.value,
          onChanged: onChanged,
        ),
        enabled: onChanged != null,
        onTap: () => onChanged?.call(!delegate.value),
      );
    }
    if (delegate is RadioDelegate) {
      final radioDelegate = delegate as RadioDelegate<T>;
      final onChanged = radioDelegate.onChanged;
      final checked = radioDelegate.value == radioDelegate.groupValue;
      return _buildGlassRow(
        context,
        accessory:
            checked ? GlassRowAccessory.checkmark : GlassRowAccessory.none,
        selected: checked,
        enabled: onChanged != null,
        onTap: () => onChanged?.call(radioDelegate.value),
      );
    }
    return _buildGlassRow(context, onTap: onTap);
  }

  @override
  Widget build(BuildContext context) {
    if (AdaptivePlatform.useGlass) {
      final scope = GlassListScope.maybeOf(context);
      if (scope != null) {
        final row = _buildGlass(context);
        // A row placed straight into a glass list is a section of its own.
        return scope.inSection ? row : GlassListSection(children: [row]);
      }
    }
    if (delegate is OpenDelegate) {
      final openDelegate = delegate as OpenDelegate;
      final child = SafeArea(
        child: openDelegate.widget,
      );
      return OpenContainer(
        closedBuilder: (_, action) {
          void openAction() {
            final isMobile = globalState.appState.viewMode == ViewMode.mobile;
            if (!isMobile) {
              showExtend(
                context,
                props: ExtendProps(
                  blur: openDelegate.blur,
                  maxWidth: openDelegate.maxWidth,
                ),
                builder: (_, type) => AdaptiveSheetScaffold(
                    actions: [
                      if (openDelegate.action != null) openDelegate.action!,
                    ],
                    type: type,
                    body: child,
                    title: openDelegate.title,
                  ),
              );
              return;
            }
            action();
          }

          return _buildListTile(
            onTap: openAction,
          );
        },
        openBuilder: (_, action) => CommonScaffold.open(
            key: Key(openDelegate.title),
            onBack: action,
            title: openDelegate.title,
            body: child,
            disableBackground: true,
            actions: [
              if (openDelegate.action != null) openDelegate.action!,
            ],
          ),
      );
    }
    if (delegate is NextDelegate) {
      final nextDelegate = delegate as NextDelegate;
      final child = SafeArea(
        child: nextDelegate.widget,
      );

      return _buildListTile(
        onTap: () {
          showExtend(
            context,
            props: ExtendProps(
              blur: nextDelegate.blur,
              maxWidth: nextDelegate.maxWidth,
            ),
            builder: (_, type) => AdaptiveSheetScaffold(
                actions: [
                  if (nextDelegate.action != null) nextDelegate.action!,
                ],
                type: type,
                body: child,
                title: nextDelegate.title,
              ),
          );
        },
      );
    }
    if (delegate is OptionsDelegate) {
      final optionsDelegate = delegate as OptionsDelegate<T>;
      return _buildListTile(
        onTap: () async {
          final value = await globalState.showCommonDialog<T>(
            child: OptionsDialog<T>(
              title: optionsDelegate.title,
              options: optionsDelegate.options,
              textBuilder: optionsDelegate.textBuilder,
              value: optionsDelegate.value,
            ),
          );
          optionsDelegate.onChanged(value);
        },
      );
    }
    if (delegate is InputDelegate) {
      final inputDelegate = delegate as InputDelegate;
      return _buildListTile(
        onTap: () async {
          final value = await globalState.showCommonDialog<String>(
            child: InputDialog(
              title: inputDelegate.title,
              value: inputDelegate.value,
              suffixText: inputDelegate.suffixText,
              resetValue: inputDelegate.resetValue,
              validator: inputDelegate.validator,
            ),
          );
          inputDelegate.onChanged(value);
        },
      );
    }
    if (delegate is CheckboxDelegate) {
      final checkboxDelegate = delegate as CheckboxDelegate;
      return _buildListTile(
        onTap: () {
          if (checkboxDelegate.onChanged != null) {
            checkboxDelegate.onChanged!(!checkboxDelegate.value);
          }
        },
        trailing: CommonCheckBox(
          value: checkboxDelegate.value,
          onChanged: checkboxDelegate.onChanged,
        ),
      );
    }
    if (delegate is SwitchDelegate) {
      final switchDelegate = delegate as SwitchDelegate;
      return _buildListTile(
        onTap: () {
          if (switchDelegate.onChanged != null) {
            switchDelegate.onChanged!(!switchDelegate.value);
          }
        },
        trailing: Switch(
          value: switchDelegate.value,
          onChanged: switchDelegate.onChanged,
        ),
      );
    }
    if (delegate is RadioDelegate) {
      final radioDelegate = delegate as RadioDelegate<T>;
      return _buildListTile(
        onTap: () {
          if (radioDelegate.onChanged != null) {
            radioDelegate.onChanged!(radioDelegate.value);
          }
        },
        leading: Radio<T>(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          value: radioDelegate.value,
          groupValue: radioDelegate.groupValue,
          onChanged: radioDelegate.onChanged,
          toggleable: true,
        ),
        trailing: trailing,
      );
    }

    return _buildListTile(
      onTap: onTap,
    );
  }
}

/// Darwin options row: the current value at the trailing edge and a menu of
/// the choices over it (macOS native `NSMenu`, iOS glass menu).
class _GlassOptionsItem<T> extends StatefulWidget {
  const _GlassOptionsItem({required this.item, required this.delegate});

  final ListItem<T> item;
  final OptionsDelegate<T> delegate;

  @override
  State<_GlassOptionsItem<T>> createState() => _GlassOptionsItemState<T>();
}

class _GlassOptionsItemState<T> extends State<_GlassOptionsItem<T>> {
  final _valueKey = GlobalKey();

  Future<void> _open() async {
    final delegate = widget.delegate;
    final box = (_valueKey.currentContext ?? context).findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    final entries = [
      for (final option in delegate.options)
        AdaptiveMenuEntry(
          label: delegate.textBuilder(option),
          checked: option == delegate.value,
          onPressed: () => delegate.onChanged(option),
        ),
    ];
    final shown = await AdaptiveContextMenu.showNative(
      anchor: anchor,
      entries: entries,
      popUp: true,
    );
    if (shown || !mounted) return;
    await AdaptiveContextMenu.showGlass(
      context: context,
      anchor: anchor,
      entries: entries,
    );
  }

  @override
  Widget build(BuildContext context) {
    final delegate = widget.delegate;
    return widget.item._buildGlassRow(
      context,
      // Options rows show their current value as the subtitle on Material.
      value: Text(delegate.textBuilder(delegate.value), key: _valueKey),
      showSubtitle: false,
      accessory: GlassRowAccessory.popUp,
      enabled: delegate.options.isNotEmpty,
      onTap: _open,
    );
  }
}

Widget? _glassHeaderActions(List<Widget>? actions, {double? space}) {
  if (actions == null || actions.isEmpty) return null;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: genActions(actions, space: space),
  );
}

class ListHeader extends StatelessWidget {

  const ListHeader({
    super.key,
    required this.title,
    this.subTitle,
    this.padding,
    List<Widget>? actions,
    this.space,
  }) : actions = actions ?? const [];
  final String title;
  final String? subTitle;
  final List<Widget> actions;
  final EdgeInsets? padding;
  final double? space;

  @override
  Widget build(BuildContext context) {
    if (AdaptivePlatform.useGlass && GlassListScope.maybeOf(context) != null) {
      return GlassSectionHeader(
        title: title,
        subtitle: subTitle,
        trailing: _glassHeaderActions(actions, space: space),
      );
    }
    return _buildMaterial(context);
  }

  Widget _buildMaterial(BuildContext context) => Container(
      alignment: Alignment.centerLeft,
      padding: padding ??
          const EdgeInsets.only(
            left: 16,
            right: 8,
            top: 24,
            bottom: 8,
          ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .opacity80,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (subTitle != null)
                  Text(
                    subTitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ...genActions(
                actions,
                space: space,
              ),
            ],
          ),
        ],
      ),
    );
}

List<Widget> generateSection({
  String? title,
  required Iterable<Widget> items,
  List<Widget>? actions,
  bool separated = true,
}) {
  if (AdaptivePlatform.useGlass) {
    // One rounded group; it draws its own hairlines.
    final children = items.where((item) => item is! Divider).toList();
    if (children.isEmpty) return const [];
    return [
      GlassListSection(
        header: title,
        headerTrailing: _glassHeaderActions(actions),
        children: children,
      ),
    ];
  }
  final genItems = separated
      ? items.separated(
          const Divider(
            height: 0,
          ),
        )
      : items;
  return [
    if (items.isNotEmpty && title != null)
      ListHeader(
        title: title,
        actions: actions,
      ),
    ...genItems,
  ];
}

Widget generateSectionV2({
  String? title,
  required Iterable<Widget> items,
  List<Widget>? actions,
  bool separated = true,
}) {
  if (AdaptivePlatform.useGlass) {
    return GlassListSection(
      header: items.isNotEmpty ? title : null,
      headerTrailing: _glassHeaderActions(actions),
      children: items.where((item) => item is! Divider).toList(),
    );
  }
  return Column(
    children: [
      if (items.isNotEmpty && title != null)
        ListHeader(
          title: title,
          actions: actions,
        ),
      CommonCard(
        radius: 18,
        type: CommonCardType.filled,
        child: Column(
          children: [
            ...items,
          ],
        ),
      )
    ],
  );
}

List<Widget> generateInfoSection({
  required Info info,
  required Iterable<Widget> items,
  List<Widget>? actions,
  bool separated = true,
}) {
  final genItems = separated
      ? items.separated(
          const Divider(
            height: 0,
          ),
        )
      : items;
  return [
    if (items.isNotEmpty)
      InfoHeader(
        info: info,
        actions: actions,
      ),
    ...genItems,
  ];
}

Widget generateListView(List<Widget> items) {
  if (AdaptivePlatform.useGlass) {
    return GlassListView(children: _groupGlassSections(items));
  }
  return ListView.builder(
    itemCount: items.length,
    itemBuilder: (_, index) => items[index],
    padding: const EdgeInsets.only(
      bottom: 16,
    ),
  );
}

/// Darwin: a [ListHeader] and the bare [ListItem]s after it become one
/// [GlassListSection]; dividers are dropped (sections draw hairlines); any
/// other child (a section from `generateSection`, a custom block) stays.
List<Widget> _groupGlassSections(List<Widget> items) {
  final result = <Widget>[];
  ListHeader? header;
  final rows = <Widget>[];
  void flush() {
    final currentHeader = header;
    if (rows.isNotEmpty) {
      result.add(
        GlassListSection(
          header: currentHeader?.title,
          headerSubtitle: currentHeader?.subTitle,
          headerTrailing: currentHeader == null
              ? null
              : _glassHeaderActions(
                  currentHeader.actions,
                  space: currentHeader.space,
                ),
          children: List.of(rows),
        ),
      );
    } else if (currentHeader != null) {
      result.add(
        GlassSectionHeader(
          title: currentHeader.title,
          subtitle: currentHeader.subTitle,
          trailing: _glassHeaderActions(
            currentHeader.actions,
            space: currentHeader.space,
          ),
        ),
      );
    }
    header = null;
    rows.clear();
  }

  for (final item in items) {
    if (item is Divider) continue;
    if (item is ListHeader) {
      flush();
      header = item;
    } else if (item is ListItem) {
      rows.add(item);
    } else {
      flush();
      result.add(item);
    }
  }
  flush();
  return result;
}
