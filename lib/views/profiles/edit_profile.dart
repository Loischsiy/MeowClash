import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meowclash/clash/clash.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/pages/editor.dart';
import 'package:meowclash/services/subscription_crypto.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/widgets.dart';
import 'package:flutter/material.dart';

class EditProfileView extends StatefulWidget {

  const EditProfileView({
    super.key,
    required this.context,
    required this.profile,
  });
  final Profile profile;
  final BuildContext context;

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  late TextEditingController labelController;
  late TextEditingController urlController;
  late TextEditingController autoUpdateDurationController;
  late TextEditingController decryptPasswordController;
  late TextEditingController decryptIterationsController;
  late bool autoUpdate;
  bool _showDecryptPassword = false;
  bool _isDecrypting = false;
  Profile? _updatedProfile;
  String? rawText;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final fileInfoNotifier = ValueNotifier<FileInfo?>(null);
  Uint8List? fileData;

  Profile get profile => widget.profile;

  @override
  void initState() {
    super.initState();
    labelController = TextEditingController(text: widget.profile.label);
    urlController = TextEditingController(text: widget.profile.url);
    autoUpdate = widget.profile.autoUpdate;
    autoUpdateDurationController = TextEditingController(
      text: widget.profile.autoUpdateDuration.inMinutes.toString(),
    );
    decryptPasswordController =
        TextEditingController(text: widget.profile.providerHeaders['meowclash-password']);
    decryptIterationsController = TextEditingController(
      text: (widget.profile.providerHeaders['meowclash-password-iterations'] ??
            kDefaultPbkdf2Iterations.toString()),
    );
    appPath.getProfilePath(widget.profile.id).then((path) async {
      fileInfoNotifier.value = await _getFileInfo(path);
    });
  }

  @override
  void dispose() {
    labelController.dispose();
    urlController.dispose();
    autoUpdateDurationController.dispose();
    decryptPasswordController.dispose();
    decryptIterationsController.dispose();
    fileInfoNotifier.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    if (!_formKey.currentState!.validate()) return;
    final appController = globalState.appController;
    final password = decryptPasswordController.text;
    final iterationsText = decryptIterationsController.text.trim();

    final newProviderHeaders = Map<String, String>.from(this.profile.providerHeaders);
    if (password.isNotEmpty) {
      newProviderHeaders['meowclash-password'] = password;
    } else {
      newProviderHeaders.remove('meowclash-password');
    }

    if (iterationsText.isNotEmpty) {
      newProviderHeaders['meowclash-password-iterations'] = iterationsText;
    } else {
      newProviderHeaders.remove('meowclash-password-iterations');
    }

    var profile = (_updatedProfile ?? this.profile).copyWith(
          url: urlController.text,
          label: labelController.text,
          autoUpdate: autoUpdate,
          autoUpdateDuration: Duration(
            minutes: int.parse(
              autoUpdateDurationController.text,
            ),
          ),
          providerHeaders: newProviderHeaders,
        );
    final hasUpdate = widget.profile.url != profile.url;
    if (fileData != null) {
      if (profile.type == ProfileType.url && autoUpdate) {
        final res = await globalState.showMessage(
          title: appLocalizations.tip,
          message: TextSpan(
            text: appLocalizations.profileHasUpdate,
          ),
        );
        if (res == true) {
          profile = profile.copyWith(
            autoUpdate: false,
          );
        }
      }
      appController.setProfileAndAutoApply(await profile.saveFile(fileData!));
    } else if (!hasUpdate) {
      appController.setProfileAndAutoApply(profile);
    } else {
      globalState.homeScaffoldKey.currentState?.loadingRun(
        () async {
          await Future.delayed(
            commonDuration,
          );
          if (hasUpdate) {
            await appController.updateProfile(profile);
          }
        },
      );
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _setAutoUpdate(bool value) {
    if (autoUpdate == value) return;
    setState(() {
      autoUpdate = value;
    });
  }

  Future<FileInfo?> _getFileInfo(path) async {
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    final lastModified = await file.lastModified();
    final size = await file.length();
    return FileInfo(
      size: size,
      lastModified: lastModified,
    );
  }

  Future<void> _handleSaveEdit(BuildContext context, String data) async {
    final message = await globalState.safeRun<String>(
      () async {
        final message = await clashCore.validateConfig(data);
        return message;
      },
      silence: false,
    );
    if (message?.isNotEmpty == true) {
      globalState.showMessage(
        title: appLocalizations.tip,
        message: TextSpan(text: message),
      );
      return;
    }
    if (context.mounted) {
      Navigator.of(context).pop(data);
    }
  }

  Future<void> _editProfileFile() async {
    if (rawText == null) {
      final profilePath = await appPath.getProfilePath(widget.profile.id);
      final file = File(profilePath);
      if (await file.exists()) {
        rawText = await file.readAsString();
      }
    }
    if (!mounted) return;
    final title = widget.profile.label ?? widget.profile.id;
    final editorPage = EditorPage(
      title: title,
      content: rawText!,
      onSave: (context, _, content) {
        _handleSaveEdit(context, content);
      },
      onPop: (context, _, content) async {
        if (content == rawText) {
          return true;
        }
        final res = await globalState.showMessage(
          title: title,
          message: TextSpan(
            text: appLocalizations.hasCacheChange,
          ),
        );
        if (res == true && context.mounted) {
          _handleSaveEdit(context, content);
        } else {
          return true;
        }
        return false;
      },
    );
    final data = await BaseNavigator.modal<String>(
      globalState.homeScaffoldKey.currentContext!,
      editorPage,
    );
    if (data == null) {
      return;
    }
    rawText = data;
    fileData = Uint8List.fromList(utf8.encode(data));
    fileInfoNotifier.value = fileInfoNotifier.value?.copyWith(
      size: fileData?.length ?? 0,
      lastModified: DateTime.now(),
    );
  }

  Future<void> _uploadProfileFile() async {
    final platformFile = await globalState.safeRun(picker.pickerFile);
    if (platformFile?.bytes == null) return;
    fileData = platformFile?.bytes;
    rawText = null;
    fileInfoNotifier.value = fileInfoNotifier.value?.copyWith(
      size: fileData?.length ?? 0,
      lastModified: DateTime.now(),
    );
  }

  Future<String?> _readCurrentProfileText() async {
    if (fileData != null) {
      try {
        return utf8.decode(fileData!);
      } catch (_) {
        return null;
      }
    }
    final profilePath = await appPath.getProfilePath(widget.profile.id);
    final file = File(profilePath);
    if (!await file.exists()) {
      return null;
    }
    try {
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleDecryptProfile() async {
    if (_isDecrypting) return;
    final password = decryptPasswordController.text;
    if (password.isEmpty) {
      globalState.showNotifier(
        appLocalizations.profileDecryptPasswordRequired,
      );
      return;
    }
    final iterationsText = decryptIterationsController.text.trim();
    final iterations = iterationsText.isEmpty
        ? kDefaultPbkdf2Iterations
        : int.tryParse(iterationsText);
    if (iterations == null || iterations <= 0) {
      globalState.showNotifier(
        appLocalizations.profileDecryptIterationsInvalid,
      );
      return;
    }
    setState(() {
      _isDecrypting = true;
    });
    try {
      if (profile.type == ProfileType.url) {
        final updatedProfile = await globalState.safeRun<Profile>(
          () => globalState.appController.updateProfile(
            profile,
            decryptionPassword: password,
            decryptionIterations: iterations,
          ),
          silence: false,
          title: appLocalizations.profileDecryptFailed,
        );
        if (updatedProfile == null || !mounted) return;
        _updatedProfile = updatedProfile;
        fileInfoNotifier.value = await _getFileInfo(
          await appPath.getProfilePath(profile.id),
        );
        globalState.showNotifier(
          appLocalizations.profileDecryptSuccess,
        );
        return;
      }

      final encoded = await _readCurrentProfileText();
      if (encoded == null || encoded.isEmpty) {
        globalState.showNotifier(
          appLocalizations.profileDecryptSourceMissing,
        );
        return;
      }
      final plaintext = await globalState.safeRun<Uint8List>(
        () async => await SubscriptionCrypto.decryptBase64(
          encoded,
          password: password,
          iterations: iterations,
        ),
        silence: false,
        title: appLocalizations.profileDecryptFailed,
      );
      if (plaintext == null) return;
      final validationMessage = await globalState.safeRun<String>(
        () async => clashCore.validateConfig(utf8.decode(plaintext)),
        silence: false,
        title: appLocalizations.profileDecryptFailed,
      );
      if (validationMessage == null) return;
      if (validationMessage.isNotEmpty) {
        await globalState.showMessage(
          title: appLocalizations.profileDecryptFailed,
          message: TextSpan(text: validationMessage),
        );
        return;
      }
      fileData = plaintext;
      rawText = utf8.decode(plaintext);
      final existingInfo = fileInfoNotifier.value;
      fileInfoNotifier.value = existingInfo == null
          ? FileInfo(
              size: plaintext.length,
              lastModified: DateTime.now(),
            )
          : existingInfo.copyWith(
              size: plaintext.length,
              lastModified: DateTime.now(),
            );
      globalState.showNotifier(
        appLocalizations.profileDecryptSuccess,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDecrypting = false;
        });
      }
    }
  }

  Future<void> _handleBack() async {
    final res = await globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(text: appLocalizations.fileIsUpdate),
    );
    if (res == true) {
      _handleConfirm();
    } else {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _toggleDecryptPassword() {
    setState(() {
      _showDecryptPassword = !_showDecryptPassword;
    });
  }

  // The fields are shared by the Material and the Apple layouts; on Darwin
  // GlassListField restyles them through GlassTheme.form.

  Widget _nameField() => TextFormField(
        textInputAction: TextInputAction.next,
        controller: labelController,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: appLocalizations.name,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return appLocalizations.profileNameNullValidationDesc;
          }
          return null;
        },
      );

  Widget _urlField() => TextFormField(
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.url,
        controller: urlController,
        maxLines: 5,
        minLines: 1,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: appLocalizations.url,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return appLocalizations.profileUrlNullValidationDesc;
          }
          if (!value.isUrl) {
            return appLocalizations.profileUrlInvalidValidationDesc;
          }
          return null;
        },
      );

  Widget _autoUpdateIntervalField() => TextFormField(
        textInputAction: TextInputAction.next,
        controller: autoUpdateDurationController,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: appLocalizations.autoUpdateInterval,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return appLocalizations
                .profileAutoUpdateIntervalNullValidationDesc;
          }
          try {
            int.parse(value);
          } catch (_) {
            return appLocalizations
                .profileAutoUpdateIntervalInvalidValidationDesc;
          }
          return null;
        },
      );

  Widget _decryptPasswordField({required Widget suffixIcon}) => TextFormField(
        controller: decryptPasswordController,
        obscureText: !_showDecryptPassword,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.password],
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: appLocalizations.profileDecryptionPassword,
          suffixIcon: suffixIcon,
        ),
      );

  Widget _decryptIterationsField() => TextFormField(
        controller: decryptIterationsController,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: appLocalizations.profileDecryptionIterations,
          helperText: appLocalizations.profileDecryptionIterationsHelper,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return null;
          }
          final parsed = int.tryParse(value.trim());
          if (parsed == null || parsed <= 0) {
            return appLocalizations.profileDecryptIterationsInvalid;
          }
          return null;
        },
      );

  bool _onPop() {
    if (fileData == null) {
      return true;
    }
    _handleBack();
    return false;
  }

  /// Apple: grouped sections (fields, auto update, profile file,
  /// decryption) and a glass "Save" capsule. Same fields and handlers as the
  /// Material layout.
  Widget _buildGlass(BuildContext context) {
    final isUrl = widget.profile.type == ProfileType.url;
    final gap = SizedBox(height: GlassListSection.gap);
    final listPadding = GlassListSection.listPadding;
    final sections = <Widget>[
      GlassListSection(
        children: [
          GlassListField(child: _nameField()),
          if (isUrl) GlassListField(child: _urlField()),
        ],
      ),
      if (isUrl) ...[
        gap,
        GlassListSection(
          children: [
            GlassListRow(
              title: Text(appLocalizations.autoUpdate),
              trailing: AdaptiveSwitch(
                value: autoUpdate,
                onChanged: _setAutoUpdate,
              ),
              onTap: () => _setAutoUpdate(!autoUpdate),
            ),
            if (autoUpdate) GlassListField(child: _autoUpdateIntervalField()),
          ],
        ),
      ],
      ValueListenableBuilder<FileInfo?>(
        valueListenable: fileInfoNotifier,
        builder: (_, fileInfo, __) => fileInfo == null
            ? const SizedBox.shrink()
            : Padding(
                padding: EdgeInsets.only(top: GlassListSection.gap),
                child: GlassListSection(
                  header: appLocalizations.profile,
                  footer: fileInfo.desc,
                  children: [
                    GlassListRow(
                      leading: const Icon(Icons.edit_rounded),
                      title: Text(appLocalizations.edit),
                      accessory: GlassRowAccessory.chevron,
                      onTap: _editProfileFile,
                    ),
                    GlassListRow(
                      leading: const Icon(Icons.upload_rounded),
                      title: Text(appLocalizations.upload),
                      onTap: _uploadProfileFile,
                    ),
                  ],
                ),
              ),
      ),
      gap,
      GlassListSection(
        header: appLocalizations.profileDecryption,
        footer: appLocalizations.profileDecryptionDesc,
        children: [
          GlassListField(
            child: _decryptPasswordField(
              suffixIcon: GlassIconButton(
                icon: Icon(
                  _showDecryptPassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
                onPressed: _toggleDecryptPassword,
              ),
            ),
          ),
          GlassListField(child: _decryptIterationsField()),
          GlassListField(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: GlassButton(
                label: appLocalizations.profileDecryptionAction,
                icon: Icons.lock_open_rounded,
                busy: _isDecrypting,
                onPressed: _handleDecryptProfile,
              ),
            ),
          ),
        ],
      ),
    ];
    return CommonPopScope(
      onPop: _onPop,
      child: FloatLayout(
        floatingWidget: FloatWrapper(
          child: AdaptiveFloatingButton(
            onPressed: _handleConfirm,
            label: appLocalizations.save,
            icon: const Icon(Icons.save),
            glassIcon: const Icon(Icons.save_rounded),
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: listPadding.copyWith(
              bottom: listPadding.bottom +
                  GlassTokens.floatingButtonSize +
                  kFloatingActionButtonMargin * 2,
            ),
            children: sections,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AdaptivePlatform.useGlass) {
      return _buildGlass(context);
    }
    final items = [
      ListItem(
        title: _nameField(),
      ),
      if (widget.profile.type == ProfileType.url) ...[
        ListItem(
          title: _urlField(),
        ),
        ListItem.switchItem(
          title: Text(appLocalizations.autoUpdate),
          delegate: SwitchDelegate<bool>(
            value: autoUpdate,
            onChanged: _setAutoUpdate,
          ),
        ),
        if (autoUpdate)
          ListItem(
            title: _autoUpdateIntervalField(),
          ),
      ],
      ValueListenableBuilder<FileInfo?>(
        valueListenable: fileInfoNotifier,
        builder: (_, fileInfo, __) => FadeThroughBox(
            child: fileInfo == null
                ? Container()
                : ListItem(
                    title: Text(
                      appLocalizations.profile,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          fileInfo.desc,
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        Wrap(
                          runSpacing: 6,
                          spacing: 12,
                          children: [
                            CommonChip(
                              avatar: const Icon(Icons.edit),
                              label: appLocalizations.edit,
                              onPressed: _editProfileFile,
                            ),
                            CommonChip(
                              avatar: const Icon(Icons.upload),
                              label: appLocalizations.upload,
                              onPressed: _uploadProfileFile,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
      ),
      ListItem(
        title: Text(appLocalizations.profileDecryption),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appLocalizations.profileDecryptionDesc,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _decryptPasswordField(
                suffixIcon: IconButton(
                  icon: Icon(
                    _showDecryptPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: _toggleDecryptPassword,
                ),
              ),
              const SizedBox(height: 12),
              _decryptIterationsField(),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _isDecrypting ? null : _handleDecryptProfile,
                  icon: _isDecrypting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_open),
                  label: Text(appLocalizations.profileDecryptionAction),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
    return CommonPopScope(
      onPop: _onPop,
      child: FloatLayout(
        floatingWidget: FloatWrapper(
          child: FloatingActionButton.extended(
            heroTag: null,
            onPressed: _handleConfirm,
            label: Text(appLocalizations.save),
            icon: const Icon(Icons.save),
          ),
        ),
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 16,
            ),
            child: ListView.separated(
              padding: kMaterialListPadding.copyWith(
                bottom: 72,
              ),
              itemBuilder: (_, index) => items[index],
              separatorBuilder: (_, __) => const SizedBox(
                  height: 24,
                ),
              itemCount: items.length,
            ),
          ),
        ),
      ),
    );
  }
}
