import 'dart:ui';

import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart' hide Action;
import 'package:meowclash/pages/pages.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/views/profiles/edit_profile.dart';
import 'package:meowclash/views/profiles/override_profile.dart';
import 'package:meowclash/views/profiles/scripts.dart';
import 'package:meowclash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'add_profile.dart';

class ProfilesView extends StatefulWidget {
  const ProfilesView({super.key});

  @override
  State<ProfilesView> createState() => _ProfilesViewState();
}

class _ProfilesViewState extends State<ProfilesView> with PageMixin {
  Function? applyConfigDebounce;

  void _handleShowAddExtendPage() {
    showExtend(
      globalState.navigatorKey.currentState!.context,
      builder: (_, type) => AdaptiveSheetScaffold(
          type: type,
          body: AddProfileView(
            context: globalState.navigatorKey.currentState!.context,
          ),
          title: appLocalizations.addProfile,
        ),
    );
  }

  Future<void> _updateProfiles() async {
    final profiles = globalState.config.profiles;
    final messages = [];
    final updateProfiles = profiles.map<Future>(
      (profile) async {
        if (profile.type == ProfileType.file) return;
        globalState.appController.setProfile(
          profile.copyWith(isUpdating: true),
        );
        try {
          await globalState.appController.updateProfile(profile);
        } catch (e) {
          messages.add("${profile.label ?? profile.id}: $e \n");
          globalState.appController.setProfile(
            profile.copyWith(
              isUpdating: false,
            ),
          );
        }
      },
    );
    final titleMedium = context.textTheme.titleMedium;
    await Future.wait(updateProfiles);
    if (messages.isNotEmpty) {
      globalState.showMessage(
        title: appLocalizations.tip,
        message: TextSpan(
          children: [
            for (final message in messages)
              TextSpan(text: message, style: titleMedium)
          ],
        ),
      );
    }
  }

  @override
  List<Widget> get actions => [
        IconButton(
          onPressed: _updateProfiles,
          icon: const Icon(Icons.sync),
        ),
        IconButton(
          onPressed: () {
            showExtend(
              context,
              builder: (_, type) => const ScriptsView(),
            );
          },
          icon: Consumer(
            builder: (context, ref, __) {
              final isScriptMode = ref.watch(
                  scriptStateProvider.select((state) => state.realId != null));
              return Icon(
                Icons.functions,
                color: isScriptMode ? context.colorScheme.primary : null,
              );
            },
          ),
        ),
        IconButton(
          onPressed: () {
            final profiles = globalState.config.profiles;
            showSheet(
              context: context,
              builder: (_, type) => ReorderableProfilesSheet(
                  type: type,
                  profiles: profiles,
                ),
            );
          },
          icon: const Icon(Icons.sort),
          iconSize: 26,
        ),
      ];

  @override
  Widget? get floatingActionButton => FloatingActionButton(
        heroTag: null,
        onPressed: _handleShowAddExtendPage,
        child: const Icon(
          Icons.add,
        ),
      );

  @override
  Widget build(BuildContext context) => Consumer(
      builder: (_, ref, __) {
        ref.listenManual(
          isCurrentPageProvider(PageLabel.profiles),
          (prev, next) {
            if (prev != next && next == true) {
              initPageState();
            }
          },
          fireImmediately: true,
        );
        final profilesSelectorState = ref.watch(profilesSelectorStateProvider);
        if (profilesSelectorState.profiles.isEmpty) {
          return NullStatus(
            label: appLocalizations.nullProfileDesc,
          );
        }
        return Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 88,
            ),
            child: Grid(
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              crossAxisCount: profilesSelectorState.columns,
              children: [
                for (int i = 0; i < profilesSelectorState.profiles.length; i++)
                  GridItem(
                    child: ProfileItem(
                      key: Key(profilesSelectorState.profiles[i].id),
                      profile: profilesSelectorState.profiles[i],
                      groupValue: profilesSelectorState.currentProfileId,
                      onChanged: (profileId) {
                        ref.read(currentProfileIdProvider.notifier).value =
                            profileId;
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
}

class ProfileItem extends StatefulWidget {

  const ProfileItem({
    super.key,
    required this.profile,
    required this.groupValue,
    required this.onChanged,
  });
  final Profile profile;
  final String? groupValue;
  final void Function(String? value) onChanged;

  @override
  State<ProfileItem> createState() => _ProfileItemState();
}

class _ProfileItemState extends State<ProfileItem> {
  final FocusNode _menuFocusNode = FocusNode();
  bool _isMenuFocused = false;
  bool _isTV = false;

  @override
  void initState() {
    super.initState();
    _checkIfTV();
    _menuFocusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isMenuFocused = _menuFocusNode.hasFocus;
        });
      }
    });
  }

  Future<void> _checkIfTV() async {
    final isTV = await system.isAndroidTV;
    if (mounted) {
      setState(() {
        _isTV = isTV;
      });
    }
  }

  @override
  void dispose() {
    _menuFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleDeleteProfile(BuildContext context) async {
    final res = await globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.profile),
      ),
    );
    if (res != true) {
      return;
    }
    await globalState.appController.deleteProfile(widget.profile.id);
  }

  Future updateProfile() async {
    final appController = globalState.appController;
    if (widget.profile.type == ProfileType.file) return;
    await globalState.safeRun(silence: false, () async {
      try {
        appController.setProfile(
          widget.profile.copyWith(
            isUpdating: true,
          ),
        );
        await appController.updateProfile(widget.profile);
      } catch (e) {
        appController.setProfile(
          widget.profile.copyWith(
            isUpdating: false,
          ),
        );
        rethrow;
      }
    });
  }

  void _handleShowEditExtendPage(BuildContext context) {
    showExtend(
      context,
      builder: (_, type) => AdaptiveSheetScaffold(
          type: type,
          disableBackground: false,
          body: EditProfileView(
            profile: widget.profile,
            context: context,
          ),
          title: appLocalizations.editProfile,
        ),
    );
  }

  List<Widget> _buildUrlProfileInfo(BuildContext context) {
    final subscriptionInfo = profile.subscriptionInfo;
    final labelStyle = context.textTheme.labelMedium?.toLight;

    return [
      const SizedBox(
        height: 8,
      ),
      if (subscriptionInfo != null) ...[
        SubscriptionInfoView(
          subscriptionInfo: subscriptionInfo,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                '${_getTrafficText(subscriptionInfo)} · ${_getExpireText(subscriptionInfo)} - ',
                style: labelStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            LastUpdateTimeText(
              lastUpdateDate: profile.lastUpdateDate,
              style: labelStyle,
            ),
          ],
        ),
      ] else
        LastUpdateTimeText(
          lastUpdateDate: profile.lastUpdateDate,
          style: labelStyle,
        ),
    ];
  }



  Future<void> _handleExportFile(BuildContext context) async {
    final commonScaffoldState = context.commonScaffoldState;
    final res = await commonScaffoldState?.loadingRun<bool>(
      () async {
        final file = await widget.profile.getFile();
        final value = await picker.saveFile(
          widget.profile.label ?? widget.profile.id,
          file.readAsBytesSync(),
        );
        if (value == null) return false;
        return true;
      },
      title: appLocalizations.tip,
    );
    if (res == true && context.mounted) {
      context.showNotifier(appLocalizations.exportSuccess);
    }
  }

  void _handlePushGenProfilePage(BuildContext context, String id) {
    final overrideProfileView = OverrideProfileView(
      profileId: id,
    );
    BaseNavigator.modal(
      context,
      overrideProfileView,
    );
  }

  @override
  Widget build(BuildContext context) => CommonCard(
      isSelected: widget.profile.id == widget.groupValue,
      onPressed: _isTV
          ? null
          : () {
              widget.onChanged(widget.profile.id);
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _isTV ? () => widget.onChanged(widget.profile.id) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.profile.label ?? widget.profile.id,
                      style: context.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    ..._buildUrlProfileInfo(context)
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 40,
              width: 40,
              child: FadeThroughBox(
                child: widget.profile.isUpdating
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(),
                      )
                    : CommonPopupBox(
                        popup: CommonPopupMenu(
                          items: [
                            if (_isTV)
                              PopupMenuItemData(
                                icon: Icons.check_circle_outline,
                                label: appLocalizations.selectProfile,
                                onPressed: () {
                                  widget.onChanged(widget.profile.id);
                                },
                              ),
                            PopupMenuItemData(
                              icon: Icons.edit_outlined,
                              label: appLocalizations.edit,
                              onPressed: () {
                                _handleShowEditExtendPage(context);
                              },
                            ),
                            if (widget.profile.type == ProfileType.url) ...[
                              PopupMenuItemData(
                                icon: Icons.sync_alt_sharp,
                                label: appLocalizations.sync,
                                onPressed: updateProfile,
                              ),
                            ],
                            if (system.isMobile && !_isTV)
                              PopupMenuItemData(
                                icon: Icons.tv_outlined,
                                label: appLocalizations.sendToTv,
                                onPressed: () {
                                  BaseNavigator.push(context,
                                      SendToTvPage(profileUrl: widget.profile.url));
                                },
                              ),
                              if (widget.profile.providerHeaders['support-url'] != null && widget.profile.providerHeaders['support-url']!.isNotEmpty && !_isTV )
                            PopupMenuItemData(
                              icon: widget.profile.providerHeaders['support-url']!.toLowerCase().contains('t.me')
                              ? Icons.telegram
                              : Icons.insert_link,
                              label: appLocalizations.support,
                              onPressed: () {
                                globalState.openUrl(widget.profile.providerHeaders['support-url']!);
                              },
                            ),
                            PopupMenuItemData(
                              icon: Icons.extension_outlined,
                              label: appLocalizations.override,
                              onPressed: () {
                                _handlePushGenProfilePage(
                                    context, widget.profile.id);
                              },
                            ),
                            PopupMenuItemData(
                              icon: Icons.file_copy_outlined,
                              label: appLocalizations.exportFile,
                              onPressed: () {
                                _handleExportFile(context);
                              },
                            ),
                            PopupMenuItemData(
                              icon: Icons.delete_outlined,
                              label: appLocalizations.delete,
                              onPressed: () {
                                _handleDeleteProfile(context);
                              },
                            ),
                          ],
                        ),
                        targetBuilder: (open) => Focus(
                            focusNode: _menuFocusNode,
                            canRequestFocus: true,
                            child: Material(
                              color: _isMenuFocused
                                  ? Theme.of(context).focusColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              child: IconButton(
                                onPressed: open,
                                icon: const Icon(Icons.more_vert),
                              ),
                            ),
                          ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
}

class ReorderableProfilesSheet extends StatefulWidget {

  const ReorderableProfilesSheet({
    super.key,
    required this.profiles,
    required this.type,
  });
  final List<Profile> profiles;
  final SheetType type;

  @override
  State<ReorderableProfilesSheet> createState() =>
      _ReorderableProfilesSheetState();
}

class _ReorderableProfilesSheetState extends State<ReorderableProfilesSheet> {
  late List<Profile> profiles;

  @override
  void initState() {
    super.initState();
    profiles = List.from(widget.profiles);
  }

  Widget proxyDecorator(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    final profile = profiles[index];
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) {
        final animValue = Curves.easeInOut.transform(animation.value);
        final scale = lerpDouble(1, 1.02, animValue)!;
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        key: Key(profile.id),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: CommonCard(
          type: CommonCardType.filled,
          child: ListTile(
            contentPadding: const EdgeInsets.only(
              right: 44,
              left: 16,
            ),
            title: Text(profile.label ?? profile.id),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AdaptiveSheetScaffold(
      type: widget.type,
      actions: [
        IconButton(
          onPressed: () {
            Navigator.of(context).pop();
            globalState.appController.setProfiles(profiles);
          },
          icon: const Icon(
            Icons.save,
          ),
        )
      ],
      body: Padding(
        padding: const EdgeInsets.only(
          bottom: 32,
          top: 16,
        ),
        child: ReorderableListView.builder(
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          proxyDecorator: proxyDecorator,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final profile = profiles.removeAt(oldIndex);
              profiles.insert(newIndex, profile);
            });
          },
          itemBuilder: (_, index) {
            final profile = profiles[index];
            return Container(
              key: Key(profile.id),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: CommonCard(
                type: CommonCardType.filled,
                child: ListTile(
                  contentPadding: const EdgeInsets.only(
                    right: 16,
                    left: 16,
                  ),
                  title: Text(profile.label ?? profile.id),
                  trailing: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle),
                  ),
                ),
              ),
            );
          },
          itemCount: profiles.length,
        ),
      ),
      title: appLocalizations.profilesSort,
    );
}

class LastUpdateTimeText extends StatelessWidget {
  final DateTime? lastUpdateDate;
  final TextStyle? style;

  const LastUpdateTimeText({
    super.key,
    required this.lastUpdateDate,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (lastUpdateDate == null) {
      return Text('', style: style);
    }
    return TickBuilder(
      duration: const Duration(minutes: 1),
      builder: (context, _) {
        return Text(
          lastUpdateDate!.getLastUpdateTimeDesc(context),
          style: style,
        );
      },
    );
  }
}
