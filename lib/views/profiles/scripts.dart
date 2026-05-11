import 'dart:convert';

import 'package:meow_clash/common/common.dart';
import 'package:meow_clash/enum/enum.dart';
import 'package:meow_clash/models/models.dart';
import 'package:meow_clash/pages/editor.dart';
import 'package:meow_clash/providers/config.dart';
import 'package:meow_clash/state.dart';
import 'package:meow_clash/widgets/card.dart';
import 'package:meow_clash/widgets/dialog.dart';
import 'package:meow_clash/widgets/input.dart';
import 'package:meow_clash/widgets/list.dart';
import 'package:meow_clash/widgets/null_status.dart';
import 'package:meow_clash/widgets/popup.dart';
import 'package:meow_clash/widgets/scaffold.dart';
import 'package:meow_clash/widgets/scroll.dart';
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
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.script),
      ),
    );
    if (res != true) {
      return;
    }
    ref.read(scriptStateProvider.notifier).del(label);
  }

  Future<void> _handleSyncScript(String id) async {
    await globalState.appController.safeRun(
      silence: false,
      () async {
        await ref.read(scriptStateProvider.notifier).syncScript(id);
        globalState.showNotifier(appLocalizations.success);
      },
    );
  }

  Widget _buildContent() {
    return Consumer(
      builder: (_, ref, _) {
        final vm2 = ref.watch(
          scriptStateProvider.select(
            (state) => VM2(a: state.currentId, b: state.scripts),
          ),
        );
        final currentId = vm2.a;
        final scripts = vm2.b;
        if (scripts.isEmpty) {
          return NullStatus(
            label: appLocalizations.nullTip(appLocalizations.script),
          );
        }
        return CommonScrollBar(
          controller: null,
          child: ListView.builder(
            padding: kMaterialListPadding.copyWith(bottom: 16 + 64),
            itemCount: scripts.length,
            itemBuilder: (_, index) {
            final script = scripts[index];
            return Container(
              padding: kTabLabelPadding,
              margin: EdgeInsets.symmetric(vertical: 6),
              child: CommonCard(
                type: CommonCardType.filled,
                radius: 16,
                child: ListItem.radio(
                  padding: const EdgeInsets.only(left: 12, right: 12),
                  title: Text(script.label),
                  delegate: RadioDelegate(
                    value: script.id,
                    groupValue: currentId,
                    onChanged: (_) {
                      ref.read(scriptStateProvider.notifier).setId(script.id);
                    },
                  ),
                  trailing: CommonPopupBox(
                    targetBuilder: (open) {
                      return IconButton(
                        onPressed: () {
                          open();
                        },
                        icon: Icon(Icons.more_vert),
                      );
                    },
                    popup: CommonPopupMenu(
                      items: [
                        PopupMenuItemData(
                          icon: Icons.edit,
                          label: appLocalizations.edit,
                          onPressed: () {
                            _handleToEditor(script: script);
                          },
                        ),
                        // URL 导入的脚本才显示同步按鈕
                        if (script.url != null && script.url!.isNotEmpty)
                          PopupMenuItemData(
                            icon: Icons.sync,
                            label: appLocalizations.sync,
                            onPressed: () {
                              _handleSyncScript(script.id);
                            },
                          ),
                        PopupMenuItemData(
                          icon: Icons.delete,
                          label: appLocalizations.delete,
                          onPressed: () {
                            _handleDelScript(script.label);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            },
          ),
        );
      },
    );
  }

  Future<void> _handleEditorSave(
    BuildContext _,
    String title,
    String content, {
    Script? script,
    String? url,
  }) async {
    Script newScript =
        script?.copyWith(label: title, content: content, url: url) ??
        Script.create(label: title, content: content, url: url);
    if (newScript.label.isEmpty) {
      final res = await globalState.showCommonDialog<String>(
        child: InputDialog(
          title: appLocalizations.save,
          value: '',
          hintText: appLocalizations.pleaseEnterScriptName,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return appLocalizations.emptyTip(appLocalizations.name);
            }
            if (value != script?.label) {
              final isExits = ref
                  .read(scriptStateProvider.notifier)
                  .isExits(value);
              if (isExits) {
                return appLocalizations.existsTip(appLocalizations.name);
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
      final isExits = ref
          .read(scriptStateProvider.notifier)
          .isExits(newScript.label);
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
    BuildContext _,
    String title,
    String content,
    String raw, {
    Script? script,
  }) async {
    if (content == raw) {
      return true;
    }
    final res = await globalState.showMessage(
      message: TextSpan(text: appLocalizations.saveChanges),
    );
    if (res == true && mounted) {
      _handleEditorSave(context, title, content, script: script, url: script?.url);
    } else {
      return true;
    }
    return false;
  }

  void _handleToEditor({Script? script, String? initialContent, String? url}) {
    final title = script?.label ?? '';
    final raw = script?.content ?? initialContent ?? scriptTemplate;
    String? importedUrl = url ?? script?.url;
    BaseNavigator.push(
      context,
      EditorPage(
        titleEditable: true,
        title: title,
        supportRemoteDownload: true,
        onUrlImport: (downloadedUrl) {
          importedUrl = downloadedUrl;
        },
        onSave: (context, title, content) {
          final scriptToSave = script != null
              ? script.copyWith(url: importedUrl)
              : null;
          _handleEditorSave(context, title, content, script: scriptToSave, url: importedUrl);
        },
        onPop: (context, title, content) {
          return _handleEditorPop(context, title, content, raw, script: script);
        },
        languages: const [Language.javaScript],
        content: raw,
      ),
    );
  }

  Future<void> _handleImport() async {
    final option = await globalState.showCommonDialog<ImportOption>(
      child: const _ScriptImportOptionsDialog(),
    );
    if (option == null) {
      return;
    }

    switch (option) {
      case ImportOption.code:
        _handleToEditor();
      case ImportOption.url:
        await _handleUrlImport();
      case ImportOption.file:
        await _handleFileImport();
    }
  }

  Future<void> _handleUrlImport() async {
    final url = await globalState.showCommonDialog<String>(
      child: InputDialog(
        title: appLocalizations.importUrl,
        value: '',
        labelText: appLocalizations.url,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return appLocalizations.emptyTip(appLocalizations.value);
          }
          if (!value.isUrl) {
            return appLocalizations.urlTip(appLocalizations.value);
          }
          return null;
        },
      ),
    );
    if (url == null || url.isEmpty) {
      return;
    }

    try {
      final res = await request.getTextResponseForUrl(url);
      if (mounted) {
        _handleToEditor(initialContent: res.data, url: url);
      }
    } catch (e) {
      globalState.showMessage(
        message: TextSpan(text: '${appLocalizations.importFailed}: $e'),
      );
    }
  }

  Future<void> _handleFileImport() async {
    final file = await picker.pickerFile();
    if (file == null) {
      return;
    }
    final bytes = file.bytes;
    if (bytes == null) {
      return;
    }
    final content = utf8.decode(bytes);
    if (mounted) {
      _handleToEditor(initialContent: content);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _handleImport();
        },
        child: Icon(Icons.add),
      ),
      body: _buildContent(),
      title: appLocalizations.script,
    );
  }
}

class _ScriptImportOptionsDialog extends StatelessWidget {
  const _ScriptImportOptionsDialog();

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: appLocalizations.import,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Wrap(
        children: [
          ListItem(
            onTap: () {
              Navigator.of(context).pop(ImportOption.code);
            },
            leading: const Icon(Icons.code),
            title: Text(appLocalizations.importFromCode),
          ),
          ListItem(
            onTap: () {
              Navigator.of(context).pop(ImportOption.url);
            },
            leading: const Icon(Icons.link),
            title: Text(appLocalizations.importUrl),
          ),
          ListItem(
            onTap: () {
              Navigator.of(context).pop(ImportOption.file);
            },
            leading: const Icon(Icons.file_open),
            title: Text(appLocalizations.importFile),
          ),
        ],
      ),
    );
  }
}
