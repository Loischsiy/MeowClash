import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/pages/editor.dart';
import 'package:meowclash/providers/config.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/card.dart';
import 'package:meowclash/widgets/input.dart';
import 'package:meowclash/widgets/list.dart';
import 'package:meowclash/widgets/null_status.dart';
import 'package:meowclash/widgets/popup.dart';
import 'package:meowclash/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ScriptsView extends ConsumerStatefulWidget {
  const ScriptsView({super.key});

  @override
  ConsumerState<ScriptsView> createState() => _ScriptsViewState();
}

class _ScriptsViewState extends ConsumerState<ScriptsView> {
  Future<void> _handleDelScript(String label) async {
    final res = await globalState.showMessage(
      message:
          TextSpan(text: appLocalizations.deleteTip(appLocalizations.script)),
    );
    if (res != true) {
      return;
    }
    ref.read(scriptStateProvider.notifier).del(label);
  }

  Widget _buildContent() => Consumer(builder: (_, ref, __) {
      final vm2 = ref.watch(scriptStateProvider.select(
        (state) => VM2(a: state.currentId, b: state.scripts),
      ));
      final currentId = vm2.a;
      final scripts = vm2.b;
      if (AdaptivePlatform.useGlass) {
        return _buildGlassContent(currentId, scripts);
      }
      if (scripts.isEmpty) {
        return NullStatus(
          label: appLocalizations.nullScriptTip,
        );
      }
      return ListView.builder(
        padding: kMaterialListPadding.copyWith(
          bottom: 16 + 64,
        ),
        itemCount: scripts.length,
        itemBuilder: (_, index) {
          final script = scripts[index];
          return Container(
            padding: kTabLabelPadding,
            margin: const EdgeInsets.symmetric(
              vertical: 6,
            ),
            child: CommonCard(
              type: CommonCardType.filled,
              radius: 16,
              child: ListItem.radio(
                padding: const EdgeInsets.only(
                  left: 12,
                  right: 12,
                ),
                title: Text(script.label),
                delegate: RadioDelegate(
                  value: script.id,
                  groupValue: currentId,
                  onChanged: (_) {
                    ref.read(scriptStateProvider.notifier).setId(
                          script.id,
                        );
                  },
                ),
                trailing: CommonPopupBox(
                  targetBuilder: (open) => IconButton(
                      onPressed: () {
                        open();
                      },
                      icon: const Icon(
                        Icons.more_vert,
                      ),
                    ),
                  popup: _buildScriptMenu(script),
                ),
              ),
            ),
          );
        },
      );
    });

  CommonPopupMenu _buildScriptMenu(Script script) => CommonPopupMenu(
        items: [
          PopupMenuItemData(
            icon: Icons.edit,
            label: appLocalizations.edit,
            onPressed: () {
              _handleToEditor(
                script: script,
              );
            },
          ),
          PopupMenuItemData(
            icon: Icons.delete,
            label: appLocalizations.delete,
            type: PopupMenuItemType.danger,
            onPressed: () {
              _handleDelScript(
                script.label,
              );
            },
          ),
        ],
      );

  /// Apple: one grouped section, the current script marked by a leading
  /// checkmark (single choice, no radio), a "⋯" menu per row. Flat rows, no
  /// blur; the floating add button is the only glass layer.
  Widget _buildGlassContent(String? currentId, List<Script> scripts) {
    if (scripts.isEmpty) {
      return AdaptiveEmptyState(
        label: appLocalizations.nullScriptTip,
        icon: Icons.code_rounded,
      );
    }
    final padding = GlassListSection.listPadding;
    return ListView(
      padding: padding.copyWith(
        bottom: padding.bottom +
            GlassTokens.floatingButtonSize +
            kFloatingActionButtonMargin * 2,
      ),
      children: [
        GlassListSection(
          children: [
            for (final script in scripts)
              GlassListRow(
                key: ValueKey(script.id),
                leading: script.id == currentId
                    ? const Icon(Icons.check_rounded)
                    : const SizedBox.shrink(),
                title: Text(
                  script.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: script.id == currentId,
                onTap: () {
                  ref.read(scriptStateProvider.notifier).setId(script.id);
                },
                trailing: CommonPopupBox(
                  targetBuilder: (open) => GlassIconButton(
                    icon: const Icon(Icons.more_horiz_rounded),
                    onPressed: open,
                  ),
                  popup: _buildScriptMenu(script),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleEditorSave(_, String title, String content, {Script? script}) async {
    var newScript = script?.copyWith(
          label: title,
          content: content,
        ) ??
        Script.create(
          label: title,
          content: content,
        );
    if (newScript.label.isEmpty) {
      final res = await globalState.showCommonDialog<String>(
        child: InputDialog(
          title: appLocalizations.save,
          value: "",
          hintText: appLocalizations.pleaseEnterScriptName,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return appLocalizations.emptyTip(appLocalizations.name);
            }
            if (value != script?.label) {
              final isExits =
                  ref.read(scriptStateProvider.notifier).isExits(value);
              if (isExits) {
                return appLocalizations.existsTip(
                  appLocalizations.name,
                );
              }
            }
            return null;
          },
        ),
      );
      if (res == null || res.isEmpty) {
        return;
      }
      newScript = newScript.copyWith(label: res);
    }
    if (newScript.label != script?.label) {
      final isExits =
          ref.read(scriptStateProvider.notifier).isExits(newScript.label);
      if (isExits) {
        globalState.showMessage(
          message: TextSpan(
            text: appLocalizations.existsTip(appLocalizations.name),
          ),
        );
        return;
      }
    }
    ref.read(scriptStateProvider.notifier).setScript(newScript);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _handleEditorPop(
    _,
    String title,
    String content,
    String raw, {
    Script? script,
  }) async {
    if (content == raw) {
      return true;
    }
    final res = await globalState.showMessage(
      message: TextSpan(
        text: appLocalizations.saveChanges,
      ),
    );
    if (res == true && mounted) {
      _handleEditorSave(
        context,
        title,
        content,
        script: script,
      );
    } else {
      return true;
    }
    return false;
  }

  void _handleToEditor({Script? script}) {
    final title = script?.label ?? "";
    final raw = script?.content ?? scriptTemplate;
    BaseNavigator.modal(
      context,
      EditorPage(
        titleEditable: true,
        title: title,
        supportRemoteDownload: true,
        onSave: (context, title, content) {
          _handleEditorSave(
            context,
            title,
            content,
            script: script,
          );
        },
        onPop: (context, title, content) => _handleEditorPop(
            context,
            title,
            content,
            raw,
            script: script,
          ),
        languages: const [
          Language.javaScript,
        ],
        content: raw,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CommonScaffold(
      disableBackground: true,
      floatingActionButton: AdaptivePlatform.useGlass
          ? AdaptiveFloatingButton(
              onPressed: _handleToEditor,
              icon: const Icon(Icons.add),
              glassIcon: const Icon(Icons.add_rounded),
            )
          : FloatingActionButton(
              onPressed: _handleToEditor,
              child: const Icon(Icons.add),
            ),
      body: _buildContent(),
      title: appLocalizations.script,
    );
}
