import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/providers/config.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ProxiesSetting extends StatelessWidget {
  const ProxiesSetting({super.key});

  IconData _getIconWithProxiesType(ProxiesType type) => switch (type) {
      ProxiesType.tab => Icons.view_carousel,
      ProxiesType.list => Icons.view_list,
    };

  IconData _getIconWithProxiesSortType(ProxiesSortType type) => switch (type) {
      ProxiesSortType.none => Icons.sort,
      ProxiesSortType.delay => Icons.network_ping,
      ProxiesSortType.name => Icons.sort_by_alpha,
    };

  String _getStringProxiesSortType(ProxiesSortType type) => switch (type) {
      ProxiesSortType.none => appLocalizations.defaultText,
      ProxiesSortType.delay => appLocalizations.delay,
      ProxiesSortType.name => appLocalizations.name,
    };

  String getTextForProxiesLayout(ProxiesLayout proxiesLayout) => switch (proxiesLayout) {
      ProxiesLayout.tight => appLocalizations.tight,
      ProxiesLayout.standard => appLocalizations.standard,
      ProxiesLayout.loose => appLocalizations.loose,
    };

  String _getTextWithProxiesIconStyle(ProxiesIconStyle style) => switch (style) {
      ProxiesIconStyle.none => appLocalizations.noIcon,
      ProxiesIconStyle.icon => appLocalizations.onlyIcon,
    };

  List<Widget> _buildStyleSetting() => generateSection(
      title: appLocalizations.style,
      items: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          child: Consumer(
            builder: (_, ref, __) {
              final proxiesType = ref.watch(proxiesStyleSettingProvider.select(
                (state) => state.type,
              ));
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in ProxiesType.values) ...[
                    SettingInfoCard(
                      Info(
                        label: Intl.message(item.name),
                        iconData: _getIconWithProxiesType(item),
                      ),
                      isSelected: proxiesType == item,
                      onPressed: () {
                        ref
                            .read(proxiesStyleSettingProvider.notifier)
                            .updateState((state) => state.copyWith(
                            type: item,
                          ));
                      },
                    ),
                    if (item != ProxiesType.values.last) const SizedBox(width: 16),
                  ]
                ],
              );
            },
          ),
        )
      ],
    );

  List<Widget> _buildSortSetting() => generateSection(
      title: appLocalizations.sort,
      items: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Consumer(
            builder: (_, ref, __) {
              final sortType = ref.watch(proxiesStyleSettingProvider.select(
                (state) => state.sortType,
              ));
              return Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  for (final item in ProxiesSortType.values)
                    SettingInfoCard(
                      Info(
                        label: _getStringProxiesSortType(item),
                        iconData: _getIconWithProxiesSortType(item),
                      ),
                      isSelected: sortType == item,
                      onPressed: () {
                        ref
                            .read(proxiesStyleSettingProvider.notifier)
                            .updateState((state) => state.copyWith(
                            sortType: item,
                          ));
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );

  List<Widget> _buildSizeSetting() => generateSection(
      title: appLocalizations.size,
      items: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Consumer(
            builder: (_, ref, __) {
              final cardType = ref.watch(proxiesStyleSettingProvider.select(
                (state) => state.cardType,
              ));
              return Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  for (final item in ProxyCardType.values)
                    SettingTextCard(
                      Intl.message(item.name),
                      isSelected: item == cardType,
                      onPressed: () {
                        ref
                            .read(proxiesStyleSettingProvider.notifier)
                            .updateState((state) => state.copyWith(
                            cardType: item,
                          ));
                      },
                    ),
                ],
              );
            },
          ),
        )
      ],
    );

  List<Widget> _buildLayoutSetting() => generateSection(
      title: appLocalizations.layout,
      items: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          scrollDirection: Axis.horizontal,
          child: Consumer(
            builder: (_, ref, __) {
              final layout = ref.watch(proxiesStyleSettingProvider.select(
                (state) => state.layout,
              ));
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in ProxiesLayout.values) ...[
                    SettingTextCard(
                      getTextForProxiesLayout(item),
                      isSelected: item == layout,
                      onPressed: () {
                        ref
                            .watch(proxiesStyleSettingProvider.notifier)
                            .updateState((state) => state.copyWith(
                            layout: item,
                          ));
                      },
                    ),
                    if (item != ProxiesLayout.values.last) const SizedBox(width: 16),
                  ]
                ],
              );
            },
          ),
        ),
      ],
    );

  List<Widget> _buildGroupStyleSetting() => generateSection(
      title: appLocalizations.iconStyle,
      items: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          child: Consumer(
            builder: (_, ref, __) {
              final iconStyle = ref.watch(proxiesStyleSettingProvider.select(
                (state) => state.iconStyle,
              ));
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in ProxiesIconStyle.values) ...[
                    SettingTextCard(
                      _getTextWithProxiesIconStyle(item),
                      isSelected: iconStyle == item,
                      onPressed: () {
                        ref
                            .read(proxiesStyleSettingProvider.notifier)
                            .updateState((state) => state.copyWith(
                            iconStyle: item,
                          ));
                      },
                    ),
                    if (item != ProxiesIconStyle.values.last) const SizedBox(width: 16),
                  ]
                ],
              );
            },
          ),
        ),
      ],
    );

  /// Darwin: one grouped section of pop-up rows (value at the end, a menu on
  /// tap) instead of the Material chip cards. A plain scroll view, not a
  /// `GlassListView`: the sheet sizes itself to the content.
  Widget _buildGlass(BuildContext context) {
    final padding = GlassListSection.listPadding;
    return SingleChildScrollView(
      padding: padding.copyWith(
        top: padding.top + AdaptiveAppBar.topInset(context),
      ),
      child: Consumer(
        builder: (_, ref, __) {
          final setting = ref.watch(proxiesStyleSettingProvider);
          final notifier = ref.read(proxiesStyleSettingProvider.notifier);
          return GlassListSection(
            children: [
              ListItem<ProxiesType>.options(
                title: Text(appLocalizations.style),
                delegate: OptionsDelegate<ProxiesType>(
                  title: appLocalizations.style,
                  options: ProxiesType.values,
                  value: setting.type,
                  textBuilder: (item) => Intl.message(item.name),
                  onChanged: (item) {
                    if (item == null) return;
                    notifier.updateState(
                      (state) => state.copyWith(type: item),
                    );
                  },
                ),
              ),
              ListItem<ProxiesSortType>.options(
                title: Text(appLocalizations.sort),
                delegate: OptionsDelegate<ProxiesSortType>(
                  title: appLocalizations.sort,
                  options: ProxiesSortType.values,
                  value: setting.sortType,
                  textBuilder: _getStringProxiesSortType,
                  onChanged: (item) {
                    if (item == null) return;
                    notifier.updateState(
                      (state) => state.copyWith(sortType: item),
                    );
                  },
                ),
              ),
              ListItem<ProxiesLayout>.options(
                title: Text(appLocalizations.layout),
                delegate: OptionsDelegate<ProxiesLayout>(
                  title: appLocalizations.layout,
                  options: ProxiesLayout.values,
                  value: setting.layout,
                  textBuilder: getTextForProxiesLayout,
                  onChanged: (item) {
                    if (item == null) return;
                    notifier.updateState(
                      (state) => state.copyWith(layout: item),
                    );
                  },
                ),
              ),
              ListItem<ProxyCardType>.options(
                title: Text(appLocalizations.size),
                delegate: OptionsDelegate<ProxyCardType>(
                  title: appLocalizations.size,
                  options: ProxyCardType.values,
                  value: setting.cardType,
                  textBuilder: (item) => Intl.message(item.name),
                  onChanged: (item) {
                    if (item == null) return;
                    notifier.updateState(
                      (state) => state.copyWith(cardType: item),
                    );
                  },
                ),
              ),
              if (setting.type == ProxiesType.list)
                ListItem<ProxiesIconStyle>.options(
                  title: Text(appLocalizations.iconStyle),
                  delegate: OptionsDelegate<ProxiesIconStyle>(
                    title: appLocalizations.iconStyle,
                    options: ProxiesIconStyle.values,
                    value: setting.iconStyle,
                    textBuilder: _getTextWithProxiesIconStyle,
                    onChanged: (item) {
                      if (item == null) return;
                      notifier.updateState(
                        (state) => state.copyWith(iconStyle: item),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AdaptivePlatform.useGlass) return _buildGlass(context);
    return _buildMaterial();
  }

  Widget _buildMaterial() => SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._buildStyleSetting(),
          ..._buildSortSetting(),
          ..._buildLayoutSetting(),
          ..._buildSizeSetting(),
          Consumer(
            builder: (_, ref, child) {
              final isList = ref.watch(proxiesStyleSettingProvider
                  .select((state) => state.type == ProxiesType.list));
              if (isList) {
                return child!;
              }
              return Container();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._buildGroupStyleSetting(),
              ],
            ),
          ),
        ],
      ),
    );
}
