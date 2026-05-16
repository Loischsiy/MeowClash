import 'package:meowclash/common/common.dart';
import 'package:meowclash/pages/scan.dart';
import 'package:meowclash/services/subscription_crypto.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'receive_profile_dialog.dart';

/// Result returned by [URLFormDialog].
///
/// Holds the subscription URL plus optional decryption parameters used
/// when the subscription file is encrypted with the companion
/// `crypto.py` AES-256-CBC helper.
class URLFormResult {
  const URLFormResult({
    required this.url,
    this.password,

    this.iterations,
  });

  final String url;
  final String? password;
  final int? iterations;
}

class AddProfileView extends StatelessWidget {

  const AddProfileView({
    super.key,
    required this.context,
  });
  final BuildContext context;

  Future<void> _handleAddProfileFormFile() async {
    globalState.appController.addProfileFormFile();
  }

  Future<void> _handleAddProfileFormURL(
    String url, {
    String? password,
    int? iterations,
  }) async {
    globalState.appController.addProfileFormURL(
      url,
      decryptionPassword: password,
      decryptionIterations: iterations,

    );
  }

  Future<void> _toScan() async {
    if (system.isDesktop) {
      globalState.appController.addProfileFormQrCode();
      return;
    }
    final url = await BaseNavigator.push(
      context,
      const ScanPage(),
    );
    if (url != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleAddProfileFormURL(url);
      });
    }
  }

  Future<void> _toAdd() async {
    final result = await globalState.showCommonDialog<URLFormResult>(
      child: const URLFormDialog(),
    );
    if (result != null) {
      _handleAddProfileFormURL(
        result.url,
        password: result.password,

        iterations: result.iterations,
      );
    }
  }

  Future<void> _handleReceiveFromPhone() async {
  final url = await showDialog<String>(
    context: context,
    builder: (_) => const ReceiveProfileDialog(),
  );
  if (url != null && url.isNotEmpty) {
    _handleAddProfileFormURL(url);
  }
}

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
      future: system.isAndroidTV,
      builder: (context, snapshot) {
        final isTV = snapshot.data ?? false;
        return ListView(
          children: [
            if (isTV)
              ListItem(
                leading: const Icon(Icons.tv_outlined),
                title: Text(appLocalizations.addFromPhoneTitle),
                subtitle: Text(appLocalizations.addFromPhoneSubtitle),
                onTap: _handleReceiveFromPhone,
              ),
            ListItem(
              leading: const Icon(Icons.qr_code_sharp),
              title: Text(appLocalizations.qrcode),
              subtitle: Text(appLocalizations.qrcodeDesc),
              onTap: _toScan,
            ),
            ListItem(
              leading: const Icon(Icons.upload_file_sharp),
              title: Text(appLocalizations.file),
              subtitle: Text(appLocalizations.fileDesc),
              onTap: _handleAddProfileFormFile,
            ),
            ListItem(
              leading: const Icon(Icons.cloud_download_sharp),
              title: Text(appLocalizations.url),
              subtitle: Text(appLocalizations.urlDesc),
              onTap: _toAdd,
            ),
          ],
        );
      },
    );
}

class URLFormDialog extends StatefulWidget {
  const URLFormDialog({super.key});

  @override
  State<URLFormDialog> createState() => _URLFormDialogState();
}

class _URLFormDialogState extends State<URLFormDialog> {
  final urlController = TextEditingController();
  final passwordController = TextEditingController();
  final iterationsController = TextEditingController(
    text: kDefaultPbkdf2Iterations.toString(),
  );
  bool _showPassword = false;

  @override
  void dispose() {
    urlController.dispose();
    passwordController.dispose();

    iterationsController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final url = urlController.text.trim();
    if (url.isEmpty) {
      return;
    }
    final password = passwordController.text;
    final iterationsText = iterationsController.text.trim();
    final iterations = iterationsText.isEmpty
        ? null
        : int.tryParse(iterationsText);
    if (iterationsText.isNotEmpty &&
        (iterations == null || iterations <= 0)) {
      globalState.showNotifier(
        appLocalizations.profileDecryptIterationsInvalid,
      );
      return;
    }
    Navigator.of(context).pop<URLFormResult>(

      URLFormResult(
        url: url,
        password: password.isEmpty ? null : password,
        iterations: iterations,
      ),
    );
  }

  Future<void> _handlePaste() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      urlController.text = clipboardData!.text!;
    }
  }

  @override
  Widget build(BuildContext context) => CommonDialog(
      title: appLocalizations.importFromURL,
      actions: [
        TextButton(
          onPressed: _handlePaste,
          child: Text(appLocalizations.pasteFromClipboard),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _handleSubmit,
          child: Text(appLocalizations.submit),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              autofocus: true,
              minLines: 1,
              maxLines: 5,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: appLocalizations.url,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: !_showPassword,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: appLocalizations.profileDecryptionPassword,
                helperText:
                    appLocalizations.profileDecryptionPasswordOptionalHelper,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _showPassword = !_showPassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: iterationsController,
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _handleSubmit(),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: appLocalizations.profileDecryptionIterations,
                helperText:
                    appLocalizations.profileDecryptionIterationsHelper,
              ),
            ),

          ],
        ),
      ),
    );
}