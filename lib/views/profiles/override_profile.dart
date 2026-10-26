import 'package:meowclash/clash/clash.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OverrideProfileView extends StatefulWidget {

  const OverrideProfileView({
    super.key,
    required this.profileId,
  });
  final String profileId;

  @override
  State<OverrideProfileView> createState() => _OverrideProfileViewState();
}

class _OverrideProfileViewState extends State<OverrideProfileView> {
  final _controller = ScrollController();
  double _currentMaxWidth = 0;

  void _initState(WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () async {
        final rawConfig = await globalState.getProfileConfig(widget.profileId);
        final snippet = ClashConfigSnippet.fromJson(rawConfig);
        final overrideData = ref.read(
          getProfileOverrideDataProvider(widget.profileId),
        );
        ref.read(profileOverrideStateProvider.notifier).updateState(
              (state) => state.copyWith(
                snippet: snippet,
                overrideData: overrideData,
              ),
            );
      });
    });
  }

  void _handleSave(WidgetRef ref, OverrideData overrideData) {
    ref.read(profilesProvider.notifier).updateProfile(
          widget.profileId,
          (state) => state.copyWith(
            overrideData: overrideData,
          ),
        );
    globalState.appController.setupClashConfigDebounce();
  }

  Future<void> _handleDelete(WidgetRef ref) async {
    final res = await globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(
        text: appLocalizations.deleteMultipTip(
          appLocalizations.rule,
        ),
      ),
    );
    if (res != true) {
      return;
    }
    final selectedRules = ref.read(
      profileOverrideStateProvider.select(
        (state) => state.selectedRules,
      ),
    );
    ref.read(profileOverrideStateProvider.notifier).updateState(
      (state) {
        final overrideRule = state.overrideData!.rule.updateRules(
          (rules) => List.from(
            rules.where(
              (item) => !selectedRules.contains(item.id),
            ),
          ),
        );
        return state.copyWith.overrideData!(
          rule: overrideRule,
        );
      },
    );
    ref.read(profileOverrideStateProvider.notifier).updateState(
          (state) => state.copyWith(
            selectedRules: {},
          ),
        );
  }

  Consumer _buildContent() => Consumer(
      builder: (_, ref, child) {
        final isInit = ref.watch(
          profileOverrideStateProvider.select(
            (state) => state.snippet != null && state.overrideData != null,
          ),
        );
        if (!isInit) {
          return const Center(
            child: AdaptiveActivityIndicator(),
          );
        }
        return FadeBox(
          child: !isInit
              ? const Center(
                  child: AdaptiveActivityIndicator(),
                )
              : child!,
        );
      },
      child: AdaptivePlatform.useGlass ? _buildGlassList() : LayoutBuilder(
        builder: (_, constraints) {
          _currentMaxWidth = constraints.maxWidth - 104;
          return CommonAutoHiddenScrollBar(
            controller: _controller,
            child: CustomScrollView(
              controller: _controller,
              slivers: [
                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 8,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Consumer(
                    builder: (_, ref, child) {
                      final scriptMode = ref.watch(scriptStateProvider
                          .select((state) => state.realId != null));
                      if (!scriptMode) {
                        return const SizedBox();
                      }
                      return child!;
                    },
                    child: ListItem(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 0,
                      ),
                      title: Row(
                        spacing: 8,
                        children: [
                          const Icon(Icons.info),
                          Text(
                            appLocalizations.overrideInvalidTip,
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 8,
                  ),
                ),
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: OverrideSwitch(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 8,
                      right: 8,
                    ),
                    child: ChainTitle(
                      profileId: widget.profileId,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: ChainContent(
                      profileId: widget.profileId,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 8,
                      right: 8,
                    ),
                    child: RuleTitle(
                      profileId: widget.profileId,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
                  sliver: RuleContent(
                    maxWidth: _currentMaxWidth,
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 16,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

  /// Darwin: grouped sections on the plain background. Everything here
  /// scrolls, so nothing blurs (the rule list can hold hundreds of rows).
  Widget _buildGlassList() => LayoutBuilder(
        builder: (_, constraints) {
          final padding = GlassListSection.listPadding;
          final gap = GlassListSection.gap;
          final horizontal = EdgeInsets.symmetric(horizontal: padding.left);
          return CommonAutoHiddenScrollBar(
            controller: _controller,
            child: CustomScrollView(
              controller: _controller,
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: padding.top)),
                SliverPadding(
                  padding: horizontal,
                  sliver: SliverToBoxAdapter(
                    child: Consumer(
                      builder: (_, ref, child) {
                        final scriptMode = ref.watch(scriptStateProvider
                            .select((state) => state.realId != null));
                        if (!scriptMode) {
                          return const SizedBox();
                        }
                        return child!;
                      },
                      child: Padding(
                        padding: EdgeInsets.only(bottom: gap),
                        child: _GlassFootnote(
                          icon: Icons.info_outline_rounded,
                          text: appLocalizations.overrideInvalidTip,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: horizontal,
                  sliver: SliverList.list(
                    children: [
                      const OverrideSwitch(),
                      SizedBox(height: gap),
                      ChainTitle(profileId: widget.profileId),
                      ChainContent(profileId: widget.profileId),
                      SizedBox(height: gap),
                      RuleTitle(profileId: widget.profileId),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: horizontal.copyWith(bottom: padding.bottom),
                  sliver: RuleContent(
                    maxWidth: constraints.maxWidth -
                        padding.horizontal -
                        RuleContent.glassTextReserve,
                  ),
                ),
              ],
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) => ProviderScope(
      overrides: [
        profileOverrideStateProvider.overrideWith(ProfileOverrideState.new),
      ],
      child: Consumer(
        builder: (_, ref, child) {
          _initState(ref);
          return child!;
        },
        child: Consumer(
          builder: (_, ref, ___) {
            final editCount = ref.watch(
              profileOverrideStateProvider.select(
                (state) => state.selectedRules.length,
              ),
            );
            final isEdit = editCount != 0;
            return CommonScaffold(
              disableBackground: true,
              title: appLocalizations.override,
              body: _buildContent(),
              actions: [
                if (!isEdit)
                  Consumer(
                    builder: (_, ref, child) {
                      final overrideData = ref.watch(
                          getProfileOverrideDataProvider(widget.profileId));
                      final newOverrideData = ref.watch(
                        profileOverrideStateProvider.select(
                          (state) => state.overrideData,
                        ),
                      );
                      final equals = overrideData == newOverrideData;
                      if (equals || newOverrideData == null) {
                        return const SizedBox();
                      }
                      return CommonPopScope(
                        onPop: () async {
                          if (equals) {
                            return true;
                          }
                          final res = await globalState.showMessage(
                            message: TextSpan(
                              text: appLocalizations.saveChanges,
                            ),
                            confirmText: appLocalizations.save,
                          );
                          if (!context.mounted || res != true) {
                            return true;
                          }
                          _handleSave(ref, newOverrideData);
                          return true;
                        },
                        child: IconButton(
                          onPressed: () async {
                            final res = await globalState.showMessage(
                              message: TextSpan(
                                text: appLocalizations.saveTip,
                              ),
                              confirmText: appLocalizations.save,
                            );
                            if (res != true) {
                              return;
                            }
                            _handleSave(ref, newOverrideData);
                          },
                          icon: const Icon(
                            Icons.save,
                          ),
                        ),
                      );
                    },
                  ),
                if (editCount == 1)
                  IconButton(
                    onPressed: () {
                      final rule = ref.read(profileOverrideStateProvider.select(
                        (state) => state.overrideData?.rule.rules.firstWhere(
                            (item) => item.id == state.selectedRules.first,
                          ),
                      ));
                      if (rule == null) {
                        return;
                      }
                      globalState.appController.handleAddOrUpdate(
                        ref,
                        rule,
                      );
                    },
                    icon: const Icon(
                      Icons.edit,
                    ),
                  ),
                if (editCount > 0)
                  IconButton(
                    onPressed: () {
                      _handleDelete(ref);
                    },
                    icon: const Icon(
                      Icons.delete,
                    ),
                  )
              ],
              appBarEditState: AppBarEditState(
                isEdit: isEdit,
                editCount: editCount,
                onExit: () {
                  ref.read(profileOverrideStateProvider.notifier).updateState(
                        (state) => state.copyWith(
                          selectedRules: {},
                        ),
                      );
                },
              ),
            );
          },
        ),
      ),
    );
}

class OverrideSwitch extends ConsumerWidget {
  const OverrideSwitch({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enable = ref.watch(
      profileOverrideStateProvider.select(
        (state) => state.overrideData?.enable,
      ),
    );
    void setEnable({required bool value}) {
      ref.read(profileOverrideStateProvider.notifier).updateState(
            (state) => state.copyWith.overrideData!(
              enable: value,
            ),
          );
    }

    if (AdaptivePlatform.useGlass) {
      return GlassListSection(
        children: [
          GlassListRow(
            title: Text(appLocalizations.enableOverride),
            trailing: AdaptiveSwitch(
              value: enable ?? false,
              onChanged: (value) => setEnable(value: value),
            ),
            onTap: () => setEnable(value: !(enable ?? false)),
          ),
        ],
      );
    }
    return CommonCard(
      onPressed: () {},
      type: CommonCardType.filled,
      radius: 18,
      child: ListItem.switchItem(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
        ),
        title: Text(appLocalizations.enableOverride),
        delegate: SwitchDelegate(
          value: enable ?? false,
          onChanged: (value) => setEnable(value: value),
        ),
      ),
    );
  }
}

class RuleTitle extends ConsumerWidget {

  const RuleTitle({
    super.key,
    required this.profileId,
  });
  final String profileId;

  void _handleChangeType(WidgetRef ref, isOverrideRule) {
    ref.read(profileOverrideStateProvider.notifier).updateState(
          (state) => state.copyWith.overrideData!.rule(
            type: isOverrideRule
                ? OverrideRuleType.added
                : OverrideRuleType.override,
          ),
        );
  }

  void _handleSelectAll(WidgetRef ref, {required bool isSelectAll}) {
    ref.read(profileOverrideStateProvider.notifier).updateState(
          (state) => state.copyWith(
            selectedRules: isSelectAll
                ? <String>{}
                : state.overrideData?.rule.rules
                        .map((item) => item.id)
                        .toSet() ??
                    <String>{},
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm3 = ref.watch(
      profileOverrideStateProvider.select(
        (state) {
          final overrideRule = state.overrideData?.rule;
          return VM3(
            a: state.selectedRules.isNotEmpty,
            b: state.selectedRules.containsAll(
              overrideRule?.rules.map((item) => item.id).toSet() ?? {},
            ),
            c: overrideRule?.type == OverrideRuleType.override,
          );
        },
      ),
    );
    final isEdit = vm3.a;
    final isSelectAll = vm3.b;
    final isOverrideRule = vm3.c;
    if (AdaptivePlatform.useGlass) {
      return GlassSectionHeader(
        title: appLocalizations.rule,
        subtitle: isOverrideRule
            ? appLocalizations.overrideOriginRules
            : appLocalizations.addedOriginRules,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: GlassTokens.listRowTrailingGap,
          children: [
            if (!isEdit)
              GlassIconButton(
                icon: Icon(
                  isOverrideRule ? Icons.edit_document : Icons.note_add_rounded,
                ),
                onPressed: () => _handleChangeType(ref, isOverrideRule),
              ),
            if (!isEdit)
              GlassButton(
                label: appLocalizations.add,
                icon: Icons.add_rounded,
                onPressed: () =>
                    globalState.appController.handleAddOrUpdate(ref),
              )
            else
              GlassButton(
                label: appLocalizations.selectAll,
                kind: isSelectAll
                    ? GlassButtonKind.filled
                    : GlassButtonKind.tinted,
                onPressed: () =>
                    _handleSelectAll(ref, isSelectAll: isSelectAll),
              ),
          ],
        ),
      );
    }
    return FilledButtonTheme(
      data: const FilledButtonThemeData(
        style: ButtonStyle(
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(
            horizontal: 8,
          )),
          visualDensity: VisualDensity.compact,
        ),
      ),
      child: IconButtonTheme(
        data: const IconButtonThemeData(
          style: ButtonStyle(
            padding: WidgetStatePropertyAll(EdgeInsets.zero),
            visualDensity: VisualDensity.compact,
            iconSize: WidgetStatePropertyAll(20),
          ),
        ),
        child: ListHeader(
          title: appLocalizations.rule,
          subTitle: isOverrideRule
              ? appLocalizations.overrideOriginRules
              : appLocalizations.addedOriginRules,
          space: 8,
          actions: [
            if (!isEdit)
              IconButton.filledTonal(
                icon: Icon(
                  isOverrideRule ? Icons.edit_document : Icons.note_add,
                ),
                onPressed: () {
                  _handleChangeType(
                    ref,
                    isOverrideRule,
                  );
                },
              ),
            !isEdit
                ? FilledButton.tonal(
                    onPressed: () {
                      globalState.appController.handleAddOrUpdate(ref);
                    },
                    child: Text(appLocalizations.add),
                  )
                : isSelectAll
                    ? FilledButton(
                        onPressed: () {
                          _handleSelectAll(ref, isSelectAll: isSelectAll);
                        },
                        child: Text(appLocalizations.selectAll),
                      )
                    : FilledButton.tonal(
                        onPressed: () {
                          _handleSelectAll(ref, isSelectAll: isSelectAll);
                        },
                        child: Text(appLocalizations.selectAll),
                      ),
          ],
        ),
      ),
    );
  }
}

class RuleContent extends ConsumerWidget {

  const RuleContent({
    super.key,
    required this.maxWidth,
  });
  final double maxWidth;

  Widget _buildItem({
    required Rule rule,
    required bool isSelected,
    required VoidCallback onTab,
    required BuildContext context,
  }) => Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(
          vertical: 4,
        ),
        child: CommonCard(
          padding: EdgeInsets.zero,
          radius: 18,
          type: CommonCardType.filled,
          isSelected: isSelected,
          // decoration: BoxDecoration(
          //   color: isSelected
          //       ? context.colorScheme.secondaryContainer.opacity80
          //       : context.colorScheme.surfaceContainer,
          //   borderRadius: BorderRadius.circular(18),
          // ),
          onPressed: () {
            onTab();
          },
          child: ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            titleTextStyle: context.textTheme.bodyMedium?.toJetBrainsMono,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            trailing: SizedBox(
              width: 24,
              height: 24,
              child: CommonCheckBox(
                value: isSelected,
                isCircle: true,
                onChanged: (_) {
                  onTab();
                },
              ),
            ),
            title: Text(rule.value),
          ),
        ),
      ),
    );

  void _handleSelect(WidgetRef ref, String ruleId) {
    ref.read(profileOverrideStateProvider.notifier).updateState(
      (state) {
        final newSelectedRules = Set<String>.from(state.selectedRules);
        if (newSelectedRules.contains(ruleId)) {
          newSelectedRules.remove(ruleId);
        } else {
          newSelectedRules.add(ruleId);
        }
        return state.copyWith(
          selectedRules: newSelectedRules,
        );
      },
    );
  }

  void _handleGetOriginRules(WidgetRef ref) {
    final rules = ref.read(
      profileOverrideStateProvider.select(
        (state) => state.snippet?.rule ?? [],
      ),
    );
    ref.read(profileOverrideStateProvider.notifier).updateState(
          (state) => state.copyWith.overrideData!.rule(
            overrideRules: rules,
          ),
        );
  }

  static bool get _mac => AdaptivePlatform.isMacOSGlass;

  static double get _glassVerticalPadding => _mac
      ? GlassTokens.ruleRowVerticalPaddingMac
      : GlassTokens.ruleRowVerticalPaddingIos;

  static double get _glassCheckSize =>
      _mac ? GlassTokens.ruleCheckSizeMac : GlassTokens.ruleCheckSizeIos;

  /// Darwin: width a rule card takes besides its text.
  static double get glassTextReserve =>
      2 * GlassListSection.rowPadding +
      GlassTokens.listRowTrailingGap +
      _glassCheckSize;

  static TextStyle _glassTextStyle(BuildContext context) =>
      GlassTextStyles.codeLine(context.textTheme).toJetBrainsMono;

  double _glassItemExtent(BuildContext context, Rule rule) {
    final textHeight = globalState.measure
        .computeTextSize(
          Text(rule.value, style: _glassTextStyle(context)),
          maxWidth: maxWidth,
        )
        .height;
    final content =
        textHeight > _glassCheckSize ? textHeight : _glassCheckSize;
    return GlassTokens.ruleRowGap + 2 * _glassVerticalPadding + content;
  }

  /// Darwin: a flat card per rule (the list is long and scrolls, so no
  /// blur) with the selection circle at the end; lifted with a shadow while
  /// dragged.
  Widget _buildGlassItem({
    required Rule rule,
    required bool isSelected,
    required VoidCallback onTap,
    required BuildContext context,
    bool lifted = false,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget card = AdaptiveCard(
      isSelected: isSelected,
      checked: false,
      onPressed: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: GlassListSection.rowPadding,
          vertical: _glassVerticalPadding,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(rule.value, style: _glassTextStyle(context)),
            ),
            const SizedBox(width: GlassTokens.listRowTrailingGap),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: _glassCheckSize,
              color: isSelected
                  ? scheme.primary
                  : scheme.onSurfaceVariant
                      .withValues(alpha: GlassTokens.listRowChevronOpacity),
            ),
          ],
        ),
      ),
    );
    if (lifted) {
      card = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GlassTokens.cardRadius),
          boxShadow: GlassTokens.floatingShadow(theme.brightness),
        ),
        child: card,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: GlassTokens.ruleRowGap / 2,
      ),
      child: card,
    );
  }

  /// Darwin: the dragged rule grows a little (not with Reduce Motion).
  Widget _buildGlassProxy({
    required BuildContext context,
    required Rule rule,
    required bool isSelected,
    required Animation<double> animation,
  }) {
    final reduceMotion = GlassAccessibility.of(context).reduceMotion;
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) {
        final value = Curves.easeInOut.transform(animation.value);
        final scale =
            reduceMotion ? 1.0 : 1 + (GlassTokens.listRowDragScale - 1) * value;
        return Transform.scale(scale: scale, child: child);
      },
      child: _buildGlassItem(
        rule: rule,
        isSelected: isSelected,
        onTap: () {},
        context: context,
        lifted: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm3 = ref.watch(
      profileOverrideStateProvider.select(
        (state) {
          final overrideRule = state.overrideData?.rule;
          return VM3(
            a: overrideRule?.rules ?? [],
            b: overrideRule?.type ?? OverrideRuleType.added,
            c: state.selectedRules,
          );
        },
      ),
    );
    final rules = vm3.a;
    final type = vm3.b;
    final selectedRules = vm3.c;
    final glass = AdaptivePlatform.useGlass;
    if (rules.isEmpty && glass) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 300,
          child: type == OverrideRuleType.added
              ? AdaptiveEmptyState(
                  label: appLocalizations.noData,
                  icon: Icons.rule_rounded,
                )
              : Center(
                  child: GlassButton(
                    label: appLocalizations.getOriginRules,
                    icon: Icons.download_rounded,
                    kind: GlassButtonKind.filled,
                    onPressed: () => _handleGetOriginRules(ref),
                  ),
                ),
        ),
      );
    }
    if (rules.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 300,
          child: Center(
            child: type == OverrideRuleType.added
                ? Text(
                    appLocalizations.noData,
                  )
                : FilledButton(
                    onPressed: () {
                      _handleGetOriginRules(ref);
                    },
                    child: Text(appLocalizations.getOriginRules),
                  ),
          ),
        ),
      );
    }
    return CacheItemExtentSliverReorderableList(
      tag: CacheTag.rules,
      itemBuilder: (context, index) {
        final rule = rules[index];
        return ReorderableDelayedDragStartListener(
          key: ObjectKey(rule),
          index: index,
          child: glass
              ? _buildGlassItem(
                  rule: rule,
                  isSelected: selectedRules.contains(rule.id),
                  onTap: () => _handleSelect(ref, rule.id),
                  context: context,
                )
              : _buildItem(
                  rule: rule,
                  isSelected: selectedRules.contains(rule.id),
                  onTab: () {
                    _handleSelect(ref, rule.id);
                  },
                  context: context,
                ),
        );
      },
      proxyDecorator: glass
          ? (_, index, animation) => _buildGlassProxy(
                context: context,
                rule: rules[index],
                isSelected: selectedRules.contains(rules[index].id),
                animation: animation,
              )
          : proxyDecorator,
      itemCount: rules.length,
      onReorder: (oldIndex, newIndex) {
        if (oldIndex < newIndex) {
          newIndex -= 1;
        }
        final newRules = List<Rule>.from(rules);
        final item = newRules.removeAt(oldIndex);
        newRules.insert(newIndex, item);
        ref.read(profileOverrideStateProvider.notifier).updateState(
              (state) => state.copyWith.overrideData!(
                rule: state.overrideData!.rule.updateRules((_) => newRules),
              ),
            );
      },
      keyBuilder: (index) => glass
          ? '${_mac ? 'mac' : 'ios'}:${rules[index].value}'
          : rules[index].value,
      itemExtentBuilder: (index) {
        final rule = rules[index];
        if (glass) {
          return _glassItemExtent(context, rule);
        }
        return 40 +
            globalState.measure
                .computeTextSize(
                  Text(
                    rule.value,
                    style: context.textTheme.bodyMedium?.toJetBrainsMono,
                  ),
                  maxWidth: maxWidth,
                )
                .height;
      },
    );
  }
}

class AddRuleDialog extends StatefulWidget {

  const AddRuleDialog({
    super.key,
    required this.snippet,
    this.rule,
    this.chainNames = const <String>[],
  });
  final ClashConfigSnippet snippet;
  final Rule? rule;
  // Names of enabled proxy chains for this profile. They are injected as hidden
  // groups at config-build time (so they aren't in `snippet.proxyGroups`) but
  // are valid rule targets, so they're offered here explicitly.
  final List<String> chainNames;

  @override
  State<AddRuleDialog> createState() => _AddRuleDialogState();
}

class _AddRuleDialogState extends State<AddRuleDialog> {
  late RuleAction _ruleAction;
  final _ruleTargetController = TextEditingController();
  final _contentController = TextEditingController();
  final _ruleProviderController = TextEditingController();
  final _subRuleController = TextEditingController();
  bool _noResolve = false;
  bool _src = false;
  List<DropdownMenuEntry<String>> _targetItems = [];
  List<DropdownMenuEntry<String>> _ruleProviderItems = [];
  List<DropdownMenuEntry<String>> _subRuleItems = [];
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    _initState();
    super.initState();
  }

  void _initState() {
    _targetItems = [
      ...widget.chainNames.map(
        (name) => DropdownMenuEntry(
          value: name,
          label: name,
        ),
      ),
      ...widget.snippet.proxyGroups.map(
        (item) => DropdownMenuEntry(
          value: item.name,
          label: item.name,
        ),
      ),
      ...RuleTarget.values.map(
        (item) => DropdownMenuEntry(
          value: item.name,
          label: item.name,
        ),
      ),
    ];
    _ruleProviderItems = [
      ...widget.snippet.ruleProvider.map(
        (item) => DropdownMenuEntry(
          value: item.name,
          label: item.name,
        ),
      ),
    ];
    _subRuleItems = [
      ...widget.snippet.subRules.map(
        (item) => DropdownMenuEntry(
          value: item.name,
          label: item.name,
        ),
      ),
    ];
    if (widget.rule != null) {
      final parsedRule = ParsedRule.parseString(widget.rule!.value);
      _ruleAction = parsedRule.ruleAction;
      _contentController.text = parsedRule.content ?? "";
      _ruleTargetController.text = parsedRule.ruleTarget ?? "";
      _ruleProviderController.text = parsedRule.ruleProvider ?? "";
      _subRuleController.text = parsedRule.subRule ?? "";
      _noResolve = parsedRule.noResolve;
      _src = parsedRule.src;
      return;
    }
    _ruleAction = RuleAction.values.first;
    if (_targetItems.isNotEmpty) {
      _ruleTargetController.text = _targetItems.first.value;
    }
    if (_ruleProviderItems.isNotEmpty) {
      _ruleProviderController.text = _ruleProviderItems.first.value;
    }
    if (_subRuleItems.isNotEmpty) {
      _subRuleController.text = _subRuleItems.first.value;
    }
  }

  @override
  void didUpdateWidget(AddRuleDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rule != widget.rule) {
      _initState();
    }
  }

  void _handleSubmit() {
    final res = _formKey.currentState?.validate();
    if (res == false) {
      return;
    }
    final parsedRule = ParsedRule(
      ruleAction: _ruleAction,
      content: _contentController.text,
      ruleProvider: _ruleProviderController.text,
      ruleTarget: _ruleTargetController.text,
      subRule: _subRuleController.text,
      noResolve: _noResolve,
      src: _src,
    );
    final rule = widget.rule != null
        ? widget.rule!.copyWith(value: parsedRule.value)
        : Rule.value(
            parsedRule.value,
          );
    Navigator.of(context).pop(rule);
  }

  String? _emptyError(TextEditingController controller, String label) =>
      controller.text.isEmpty ? appLocalizations.emptyTip(label) : null;

  String? _ruleProviderError(Object? _) =>
      _emptyError(_ruleProviderController, appLocalizations.ruleProviders);

  String? _contentError(Object? _) =>
      _emptyError(_contentController, appLocalizations.content);

  String? _subRuleError(Object? _) =>
      _emptyError(_subRuleController, appLocalizations.subRule);

  String? _ruleTargetError(Object? _) =>
      _emptyError(_ruleTargetController, appLocalizations.ruleTarget);

  /// Darwin: an Apple pop-up button bound to [controller], validated by the
  /// same [validator] as the Material dropdown.
  Widget _glassPopUp({
    required String label,
    required TextEditingController controller,
    required List<DropdownMenuEntry<String>> items,
    required FormFieldValidator<String> validator,
  }) =>
      FormField<String>(
        validator: validator,
        builder: (field) => GlassPopUpButton<String>(
          label: label,
          value: controller.text.isEmpty ? null : controller.text,
          options: [for (final item in items) item.value],
          textBuilder: (item) => item,
          errorText: field.errorText,
          onChanged: (value) {
            setState(() => controller.text = value);
            field.didChange(value);
            if (field.hasError) field.validate();
          },
        ),
      );

  /// Darwin: pop-up buttons with a checkmark menu instead of the dropdowns
  /// and the rule-type dialog, switch rows for the parameters; the fields
  /// take the Apple style from the glass dialog.
  Widget _buildGlassForm(BuildContext context) {
    const gap = SizedBox(height: GlassTokens.dialogFieldGap);
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPopUpButton<RuleAction>(
            label: appLocalizations.ruleName,
            value: _ruleAction,
            options: RuleAction.values,
            textBuilder: (item) => item.value,
            onChanged: (value) => setState(() => _ruleAction = value),
          ),
          gap,
          if (_ruleAction == RuleAction.RULE_SET) ...[
            _glassPopUp(
              label: appLocalizations.ruleProviders,
              controller: _ruleProviderController,
              items: _ruleProviderItems,
              validator: _ruleProviderError,
            ),
            gap,
          ] else if (_ruleAction != RuleAction.MATCH) ...[
            TextFormField(
              controller: _contentController,
              decoration: InputDecoration(
                labelText: appLocalizations.content,
              ),
              validator: _contentError,
            ),
            gap,
          ],
          if (_ruleAction == RuleAction.SUB_RULE)
            _glassPopUp(
              label: appLocalizations.subRule,
              controller: _subRuleController,
              items: _subRuleItems,
              validator: _subRuleError,
            )
          else
            _glassPopUp(
              label: appLocalizations.ruleTarget,
              controller: _ruleTargetController,
              items: _targetItems,
              validator: _ruleTargetError,
            ),
          if (_ruleAction.hasParams) ...[
            gap,
            GlassListSection(
              children: [
                GlassListRow(
                  title: Text(appLocalizations.sourceIp),
                  trailing: AdaptiveSwitch(
                    value: _src,
                    onChanged: (value) => setState(() => _src = value),
                  ),
                  onTap: () => setState(() => _src = !_src),
                ),
                GlassListRow(
                  title: Text(appLocalizations.noResolve),
                  trailing: AdaptiveSwitch(
                    value: _noResolve,
                    onChanged: (value) => setState(() => _noResolve = value),
                  ),
                  onTap: () => setState(() => _noResolve = !_noResolve),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CommonDialog(
      title: appLocalizations.addRule,
      actions: [
        TextButton(
          onPressed: _handleSubmit,
          child: Text(
            appLocalizations.confirm,
          ),
        ),
      ],
      child: AdaptivePlatform.useGlass
          ? _buildGlassForm(context)
          : DropdownMenuTheme(
        data: DropdownMenuThemeData(
          inputDecorationTheme: InputDecorationTheme(
            border: const OutlineInputBorder(),
            labelStyle: context.textTheme.bodyLarge
                ?.copyWith(overflow: TextOverflow.ellipsis),
          ),
        ),
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (_, constraints) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton.tonal(
                    onPressed: () async {
                      _ruleAction =
                          await globalState.showCommonDialog<RuleAction>(
                                child: OptionsDialog<RuleAction>(
                                  title: appLocalizations.ruleName,
                                  options: RuleAction.values,
                                  textBuilder: (item) => item.value,
                                  value: _ruleAction,
                                ),
                              ) ??
                              _ruleAction;
                      setState(() {});
                    },
                    child: Text(_ruleAction.name),
                  ),
                  const SizedBox(
                    height: 24,
                  ),
                  if (_ruleAction == RuleAction.RULE_SET) ...[
                    FormField(
                      validator: _ruleProviderError,
                      builder: (field) => DropdownMenu(
                        expandedInsets: EdgeInsets.zero,
                        controller: _ruleProviderController,
                        label: Text(appLocalizations.ruleProviders),
                        menuHeight: 250,
                        errorText: field.errorText,
                        dropdownMenuEntries: _ruleProviderItems,
                      ),
                    ),
                    const SizedBox(
                      height: 24,
                    ),
                  ] else if (_ruleAction != RuleAction.MATCH) ...[
                    TextFormField(
                      controller: _contentController,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: appLocalizations.content,
                      ),
                      validator: _contentError,
                    ),
                    const SizedBox(
                      height: 24,
                    ),
                  ],
                  _ruleAction == RuleAction.SUB_RULE
                      ? FormField(
                          validator: _subRuleError,
                          builder: (filed) => DropdownMenu(
                              width: 200,
                              enableFilter: false,
                              enableSearch: false,
                              controller: _subRuleController,
                              label: Text(appLocalizations.subRule),
                              menuHeight: 250,
                              dropdownMenuEntries: _subRuleItems,
                            ),
                        )
                      : FormField<String>(
                          validator: _ruleTargetError,
                          builder: (filed) => DropdownMenu(
                              controller: _ruleTargetController,
                              label: Text(appLocalizations.ruleTarget),
                              width: 200,
                              menuHeight: 250,
                              enableFilter: false,
                              enableSearch: false,
                              dropdownMenuEntries: _targetItems,
                              errorText: filed.errorText,
                            ),
                        ),
                  if (_ruleAction.hasParams) ...[
                    const SizedBox(
                      height: 20,
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        CommonCard(
                          radius: 8,
                          isSelected: _src,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            child: Text(
                              appLocalizations.sourceIp,
                              style: context.textTheme.bodyMedium,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _src = !_src;
                            });
                          },
                        ),
                        CommonCard(
                          radius: 8,
                          isSelected: _noResolve,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            child: Text(
                              appLocalizations.noResolve,
                              style: context.textTheme.bodyMedium,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _noResolve = !_noResolve;
                            });
                          },
                        )
                      ],
                    ),
                  ],
                  const SizedBox(
                    height: 20,
                  ),
                ],
              ),
          ),
        ),
      ),
    );
}

class ChainTitle extends ConsumerWidget {
  const ChainTitle({
    super.key,
    required this.profileId,
  });
  final String profileId;

  Future<void> _handleAdd(WidgetRef ref) async {
    final snippet = ref.read(
      profileOverrideStateProvider.select(
        (state) => state.snippet,
      ),
    );
    if (snippet == null) {
      return;
    }
    final chain = await globalState.showCommonDialog<ProxyChain>(
      child: AddChainDialog(
        snippet: snippet,
      ),
    );
    if (chain == null) {
      return;
    }
    ref.read(profileOverrideStateProvider.notifier).updateState(
      (state) {
        if (state.overrideData == null) {
          return state;
        }
        final chains = List<ProxyChain>.from(state.overrideData!.chains)
          ..add(chain);
        return state.copyWith.overrideData!(
          chains: chains,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (AdaptivePlatform.useGlass) {
      return GlassSectionHeader(
        title: appLocalizations.proxyChains,
        subtitle: appLocalizations.proxyChainsDesc,
        trailing: GlassButton(
          label: appLocalizations.add,
          icon: Icons.add_rounded,
          onPressed: () => _handleAdd(ref),
        ),
      );
    }
    return FilledButtonTheme(
      data: const FilledButtonThemeData(
        style: ButtonStyle(
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(
            horizontal: 8,
          )),
          visualDensity: VisualDensity.compact,
        ),
      ),
      child: ListHeader(
        title: appLocalizations.proxyChains,
        subTitle: appLocalizations.proxyChainsDesc,
        space: 8,
        actions: [
          FilledButton.tonal(
            onPressed: () async {
              await _handleAdd(ref);
            },
            child: Text(appLocalizations.add),
          ),
        ],
      ),
    );
  }
}

class ChainContent extends ConsumerWidget {
  const ChainContent({
    super.key,
    required this.profileId,
  });
  final String profileId;

  Future<void> _handleEdit(WidgetRef ref, ProxyChain chain) async {
    final snippet = ref.read(
      profileOverrideStateProvider.select(
        (state) => state.snippet,
      ),
    );
    if (snippet == null) {
      return;
    }
    final result = await globalState.showCommonDialog<ProxyChain>(
      child: AddChainDialog(
        snippet: snippet,
        chain: chain,
      ),
    );
    if (result == null) {
      return;
    }
    ref.read(profileOverrideStateProvider.notifier).updateState(
      (state) {
        if (state.overrideData == null) {
          return state;
        }
        final chains = List<ProxyChain>.from(state.overrideData!.chains);
        final index = chains.indexWhere((item) => item.id == result.id);
        if (index == -1) {
          chains.add(result);
        } else {
          chains[index] = result;
        }
        return state.copyWith.overrideData!(
          chains: chains,
        );
      },
    );
  }

  Future<void> _handleDelete(WidgetRef ref, ProxyChain chain) async {
    final res = await globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(
        text: appLocalizations.deleteTip(
          appLocalizations.proxyChains,
        ),
      ),
    );
    if (res != true) {
      return;
    }
    ref.read(profileOverrideStateProvider.notifier).updateState(
      (state) {
        if (state.overrideData == null) {
          return state;
        }
        final chains = List<ProxyChain>.from(state.overrideData!.chains)
          ..removeWhere((item) => item.id == chain.id);
        return state.copyWith.overrideData!(
          chains: chains,
        );
      },
    );
  }

  void _handleToggle(WidgetRef ref, ProxyChain chain, bool value) {
    ref.read(profileOverrideStateProvider.notifier).updateState(
      (state) {
        if (state.overrideData == null) {
          return state;
        }
        final chains = state.overrideData!.chains
            .map(
              (item) =>
                  item.id == chain.id ? item.copyWith(enable: value) : item,
            )
            .toList();
        return state.copyWith.overrideData!(
          chains: chains,
        );
      },
    );
  }

  /// Darwin: one row per chain in a grouped section; a tap edits it.
  Widget _buildGlassItem(WidgetRef ref, ProxyChain chain) => GlassListRow(
        title: Text(
          chain.name.isEmpty ? appLocalizations.unnamed : chain.name,
        ),
        subtitle: Text(
          chain.hops.length < 2
              ? appLocalizations.chainHopsRequired
              : chain.hops.join('  \u2192  '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: GlassTokens.listRowTrailingGap,
          children: [
            if (chain.enable && chain.hops.length >= 2)
              _ChainTestButton(chainName: chain.name),
            AdaptiveSwitch(
              value: chain.enable,
              onChanged: (value) => _handleToggle(ref, chain, value),
            ),
            GlassIconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: appLocalizations.delete,
              onPressed: () => _handleDelete(ref, chain),
            ),
          ],
        ),
        onTap: () => _handleEdit(ref, chain),
      );

  Widget _buildItem(WidgetRef ref, ProxyChain chain) => Container(
        margin: const EdgeInsets.symmetric(
          vertical: 4,
        ),
        child: CommonCard(
          radius: 18,
          type: CommonCardType.filled,
          onPressed: () {
            _handleEdit(ref, chain);
          },
          child: ListTile(
            contentPadding: const EdgeInsets.only(
              left: 16,
              right: 8,
            ),
            title: Text(
              chain.name.isEmpty ? appLocalizations.unnamed : chain.name,
            ),
            subtitle: Text(
              chain.hops.length < 2
                  ? appLocalizations.chainHopsRequired
                  : chain.hops.join("  \u2192  "),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (chain.enable && chain.hops.length >= 2)
                  _ChainTestButton(chainName: chain.name),
                Switch(
                  value: chain.enable,
                  onChanged: (value) {
                    _handleToggle(ref, chain, value);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    _handleDelete(ref, chain);
                  },
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chains = ref.watch(
      profileOverrideStateProvider.select(
        (state) => state.overrideData?.chains ?? const <ProxyChain>[],
      ),
    );
    if (AdaptivePlatform.useGlass) {
      if (chains.isEmpty) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: GlassListSection.gap / 2),
          child: _GlassFootnote(
            text: appLocalizations.nullTip(appLocalizations.proxyChains),
            center: true,
          ),
        );
      }
      return GlassListSection(
        children: [
          for (final chain in chains) _buildGlassItem(ref, chain),
        ],
      );
    }
    if (chains.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 24,
        ),
        child: Center(
          child: Text(
            appLocalizations.nullTip(
              appLocalizations.proxyChains,
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final chain in chains) _buildItem(ref, chain),
      ],
    );
  }
}

class AddChainDialog extends StatefulWidget {
  const AddChainDialog({
    super.key,
    required this.snippet,
    this.chain,
  });
  final ClashConfigSnippet snippet;
  final ProxyChain? chain;

  @override
  State<AddChainDialog> createState() => _AddChainDialogState();
}

class _AddChainDialogState extends State<AddChainDialog> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<TextEditingController> _hopControllers = [];
  // Candidates for the entry hop: it is only used as a `dialer-proxy` value,
  // which may reference a group or a node, so any name is allowed.
  List<DropdownMenuEntry<String>> _entryHopItems = [];
  // Candidates for every later hop: concrete nodes are cloned directly; groups
  // are resolved to their selected concrete node when the config is built.
  List<DropdownMenuEntry<String>> _nodeHopItems = [];

  @override
  void initState() {
    _initState();
    super.initState();
  }

  void _initState() {
    final groupNames = <String>{};
    final memberNames = <String>{};
    for (final group in widget.snippet.proxyGroups) {
      groupNames.add(group.name);
      for (final proxy in group.proxies ?? const <String>[]) {
        memberNames.add(proxy);
      }
    }
    // Any hop may be a group or node. Non-entry groups are resolved to their
    // selected concrete node before cloning.
    final entryNames = <String>{...groupNames, ...memberNames};
    _entryHopItems = entryNames
        .map((name) => DropdownMenuEntry<String>(value: name, label: name))
        .toList();
    _nodeHopItems = entryNames
        .map((name) => DropdownMenuEntry<String>(value: name, label: name))
        .toList();
    final chain = widget.chain;
    if (chain != null) {
      _nameController.text = chain.name;
      _hopControllers = chain.hops
          .map((hop) => TextEditingController(text: hop))
          .toList();
    }
    while (_hopControllers.length < 2) {
      _hopControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final controller in _hopControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String _hopLabel(int index) {
    if (index == 0) {
      return appLocalizations.firstHop;
    }
    if (index == 1) {
      return appLocalizations.secondHop;
    }
    return "${appLocalizations.hop} ${index + 1}";
  }

  void _handleSubmit() {
    final res = _formKey.currentState?.validate();
    if (res == false) {
      return;
    }
    final hops = _hopControllers
        .map((controller) => controller.text.trim())
        .where((hop) => hop.isNotEmpty)
        .toList();
    if (hops.length < 2) {
      return;
    }
    final base = widget.chain ?? ProxyChain.create();
    final chain = base.copyWith(
      name: _nameController.text.trim(),
      hops: hops,
    );
    Navigator.of(context).pop(chain);
  }

  String? _nameError(String? _) {
    final value = _nameController.text.trim();
    if (value.isEmpty) {
      return appLocalizations.emptyTip(
        appLocalizations.chainName,
      );
    }
    final groupNames =
        widget.snippet.proxyGroups.map((group) => group.name).toSet();
    if (groupNames.contains(value)) {
      return appLocalizations.existsTip(
        appLocalizations.proxyGroup,
      );
    }
    return null;
  }

  String? _hopError(int index) => _hopControllers[index].text.trim().isEmpty
      ? appLocalizations.emptyTip(_hopLabel(index))
      : null;

  void _addHop() {
    setState(() {
      _hopControllers.add(TextEditingController());
    });
  }

  void _removeHop(int index) {
    setState(() {
      _hopControllers.removeAt(index).dispose();
    });
  }

  Widget _nameField() => TextFormField(
        controller: _nameController,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: appLocalizations.chainName,
        ),
        validator: _nameError,
      );

  /// Darwin: a pop-up button with a checkmark menu per hop (the menu scrolls
  /// for hundreds of nodes), a minus button to drop extra hops and an inline
  /// "Add hop" button; the same controllers and validators.
  Widget _buildGlassForm() {
    const gap = SizedBox(height: GlassTokens.dialogFieldGap);
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _nameField(),
          for (var index = 0; index < _hopControllers.length; index++) ...[
            gap,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FormField<String>(
                    validator: (_) => _hopError(index),
                    builder: (field) {
                      final controller = _hopControllers[index];
                      final items =
                          index == 0 ? _entryHopItems : _nodeHopItems;
                      return GlassPopUpButton<String>(
                        label: _hopLabel(index),
                        value: controller.text.isEmpty ? null : controller.text,
                        options: [for (final item in items) item.value],
                        textBuilder: (item) => item,
                        errorText: field.errorText,
                        onChanged: (value) {
                          setState(() => controller.text = value);
                          field.didChange(value);
                          if (field.hasError) field.validate();
                        },
                      );
                    },
                  ),
                ),
                if (_hopControllers.length > 2) ...[
                  const SizedBox(width: GlassTokens.listRowTrailingGap),
                  GlassIconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    tooltip: appLocalizations.delete,
                    onPressed: () => _removeHop(index),
                  ),
                ],
              ],
            ),
          ],
          gap,
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: GlassButton(
              label: appLocalizations.addHop,
              icon: Icons.add_rounded,
              kind: GlassButtonKind.plain,
              onPressed: _addHop,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CommonDialog(
        title: appLocalizations.proxyChains,
        actions: [
          TextButton(
            onPressed: _handleSubmit,
            child: Text(
              appLocalizations.confirm,
            ),
          ),
        ],
        child: AdaptivePlatform.useGlass
            ? _buildGlassForm()
            : DropdownMenuTheme(
          data: DropdownMenuThemeData(
            inputDecorationTheme: InputDecorationTheme(
              border: const OutlineInputBorder(),
              labelStyle: context.textTheme.bodyLarge
                  ?.copyWith(overflow: TextOverflow.ellipsis),
            ),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _nameField(),
                const SizedBox(
                  height: 24,
                ),
                ...List.generate(
                  _hopControllers.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: 24,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: FormField<String>(
                            validator: (_) => _hopError(index),
                            builder: (field) => DropdownMenu<String>(
                              expandedInsets: EdgeInsets.zero,
                              controller: _hopControllers[index],
                              label: Text(_hopLabel(index)),
                              menuHeight: 250,
                              requestFocusOnTap: true,
                              enableFilter: true,
                              errorText: field.errorText,
                              dropdownMenuEntries:
                                  index == 0 ? _entryHopItems : _nodeHopItems,
                            ),
                          ),
                        ),
                        if (_hopControllers.length > 2)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => _removeHop(index),
                          ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addHop,
                    icon: const Icon(Icons.add),
                    label: Text(appLocalizations.addHop),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Delay-tests a proxy chain end to end. The chain's exit node is a clone that
/// carries `dialer-proxy: <entry>`, so asking the core to test the (hidden)
/// chain group measures latency *through* the entry hop — i.e. it pings the
/// exit exactly as it is actually reached. Only meaningful once the chain has
/// been saved and applied (the hidden chain group must exist in the running
/// core); otherwise the test reports a timeout.
class _ChainTestButton extends StatefulWidget {
  const _ChainTestButton({required this.chainName});

  final String chainName;

  @override
  State<_ChainTestButton> createState() => _ChainTestButtonState();
}

class _ChainTestButtonState extends State<_ChainTestButton> {
  bool _testing = false;

  Future<void> _handleTest() async {
    if (_testing) {
      return;
    }
    setState(() {
      _testing = true;
    });
    try {
      final testUrl = globalState.appController.getRealTestUrl(null);
      final delay = await clashCore.getDelay(testUrl, widget.chainName);
      final value = delay.value;
      final message = value == null || value <= 0
          ? "${widget.chainName}: timeout"
          : "${widget.chainName}: $value ms";
      globalState.showNotifier(message);
    } catch (e) {
      globalState.showNotifier(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _testing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AdaptivePlatform.useGlass
      ? GlassIconButton(
          icon: const Icon(Icons.speed_rounded),
          busy: _testing,
          onPressed: _handleTest,
        )
      : IconButton(
        onPressed: _testing ? null : _handleTest,
        icon: _testing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.speed),
      );
}

/// Explanation in the section footer style, lined up with the row text;
/// optionally led by a symbol or centered (empty lists). Darwin only.
class _GlassFootnote extends StatelessWidget {
  const _GlassFootnote({
    required this.text,
    this.icon,
    this.center = false,
  });

  final String text;
  final IconData? icon;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    final style = GlassTextStyles.listSectionFooter(theme.textTheme)
        .copyWith(color: color);
    final icon = this.icon;
    Widget content = Text(
      text,
      style: style,
      textAlign: center ? TextAlign.center : null,
    );
    if (icon != null) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: GlassTokens.listRowTrailingGap,
        children: [
          Icon(icon, size: style.fontSize! * style.height!, color: color),
          Expanded(child: content),
        ],
      );
    }
    if (center) {
      content = Center(child: content);
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: GlassListSection.rowPadding),
      child: content,
    );
  }
}
