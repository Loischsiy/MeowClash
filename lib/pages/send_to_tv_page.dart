import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class SendToTvPage extends ConsumerStatefulWidget {
  const SendToTvPage({super.key, required this.profileUrl});
  final String profileUrl;

  @override
  ConsumerState<SendToTvPage> createState() => _SendToTvPageState();
}

class _SendToTvPageState extends ConsumerState<SendToTvPage> {
  static const _syncType = 'meowclash_tv_sync';

  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanComplete = false;

  Future<void> _handleQrCode(BarcodeCapture capture) async {
    if (_isScanComplete) return;

    if (capture.barcodes.isEmpty) {
      return;
    }
    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null) {
      return;
    }

    try {
      final sync = _parseSyncEndpoint(rawValue);
      if (sync == null) {
        return;
      }
      setState(() {
        _isScanComplete = true;
      });
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      await dio.post(
        sync.endpoint,
        data: {'url': widget.profileUrl, 'token': sync.token},
      );
      if (!mounted) return;
      _showResultDialog(
        appLocalizations.successTitle,
        appLocalizations.sentSuccessfullyMessage,
      );
    } catch (e) {
      commonPrint.log('Error sending profile to TV: $e');
      if (!mounted) return;
      setState(() {
        _isScanComplete = true;
      });
      _showResultDialog(
        appLocalizations.errorTitle,
        appLocalizations.invalidQrMessage,
      );
    }
  }

  ({String endpoint, String token})? _parseSyncEndpoint(String rawValue) {
    final dynamic payload;
    try {
      payload = jsonDecode(rawValue);
    } catch (_) {
      return null;
    }
    if (payload is! Map<String, dynamic>) {
      return null;
    }
    if (payload['type'] != _syncType) {
      return null;
    }
    final ip = payload['ip'];
    final port = payload['port'];
    final token = payload['token'];
    if (ip is! String || ip.isEmpty || port is! int) {
      return null;
    }
    if (token is! String || token.isEmpty) {
      return null;
    }
    if (port < 1 || port > 65535) {
      return null;
    }
    return (
      endpoint: Uri(
        scheme: 'http',
        host: ip,
        port: port,
        path: '/add-profile',
      ).toString(),
      token: token,
    );
  }

  void _showResultDialog(String title, String content) {
    if (!mounted) return;
    if (AdaptivePlatform.useGlass) {
      _showGlassResultDialog(title, content);
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Darwin: the glass alert; OK closes it and leaves the scanner page.
  void _showGlassResultDialog(String title, String content) {
    globalState.showCommonDialog<void>(
      child: Builder(
        builder: (dialogContext) => CommonDialog(
          title: title,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (mounted) Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
          child: Text(content),
        ),
      ),
    );
  }

  Widget _buildScanner() => MobileScanner(
        controller: _scannerController,
        onDetect: _handleQrCode,
      );

  @override
  Widget build(BuildContext context) {
    // Darwin: the glass navigation bar of every pushed page.
    if (AdaptivePlatform.useGlass) {
      return CommonScaffold(
        title: appLocalizations.sendToTvTitle,
        body: _buildScanner(),
      );
    }
    return Scaffold(
        appBar: AppBar(title: Text(appLocalizations.sendToTvTitle)),
        body: MobileScanner(
          controller: _scannerController,
          onDetect: _handleQrCode,
        ),
      );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
}
