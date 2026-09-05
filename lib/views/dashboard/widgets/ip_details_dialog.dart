import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:meowclash/common/ip_country_names.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:meowclash/models/common.dart';
import 'package:meowclash/models/ip_details.dart';
import 'package:url_launcher/url_launcher.dart';

typedef IpDetailsLoader = Future<IpDetails?> Function({
  required String ip,
  required String languageCode,
  CancelToken? cancelToken,
});

class IpDetailsDialog extends StatefulWidget {
  const IpDetailsDialog({
    super.key,
    required this.ipInfo,
    required this.loadDetails,
    required this.onRefresh,
    this.isIpLoading = false,
    this.openLink,
  });

  final IpInfo? ipInfo;
  final bool isIpLoading;
  final IpDetailsLoader loadDetails;
  final VoidCallback onRefresh;
  final Future<bool> Function(Uri)? openLink;

  @override
  State<IpDetailsDialog> createState() => _IpDetailsDialogState();
}

class _IpDetailsDialogState extends State<IpDetailsDialog> {
  IpDetails? _details;
  CancelToken? _cancelToken;
  String? _languageCode;
  int _generation = 0;
  bool _loading = false;
  bool _failed = false;
  bool _linkFailed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode = Localizations.localeOf(context).languageCode;
    if (_languageCode != languageCode) {
      _languageCode = languageCode;
      unawaited(_loadDetails());
    }
  }

  @override
  void didUpdateWidget(covariant IpDetailsDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ipInfo?.ip != widget.ipInfo?.ip) {
      unawaited(_loadDetails());
    }
  }

  Future<void> _loadDetails() async {
    final generation = ++_generation;
    _cancelToken?.cancel();
    final ip = widget.ipInfo?.ip;
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    setState(() {
      _details = null;
      _loading = ip != null;
      _failed = false;
      _linkFailed = false;
    });
    if (ip == null) return;

    IpDetails? details;
    try {
      details = await widget.loadDetails(
        ip: ip,
        languageCode: _languageCode ?? 'en',
        cancelToken: cancelToken,
      );
    } on Exception {
      details = null;
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _details = details;
      _loading = false;
      _failed = details == null;
    });
  }

  Future<void> _openIp() async {
    final address = InternetAddress.tryParse(widget.ipInfo?.ip ?? '');
    if (address == null) return;
    final uri = Uri.https('ipinfo.io', '/${address.address}');
    var opened = false;
    try {
      opened = await (widget.openLink?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
    } on Exception {
      opened = false;
    }
    if (mounted) setState(() => _linkFailed = !opened);
  }

  @override
  void dispose() {
    _generation++;
    _cancelToken?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final countryCode = _details?.countryCode ?? widget.ipInfo?.countryCode;
    final country = countryCode == null
        ? null
        : localizedIpCountryName(countryCode, _languageCode ?? 'en');
    final busy = _loading || widget.isIpLoading;
    final missing = busy ? '…' : l10n.ipDetailsUnavailable;
    final ip = widget.ipInfo?.ip;

    // Let AlertDialog scroll title + content together on narrow/landscape
    // screens and with large system fonts; actions remain reachable.
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.92),
      title: Text(l10n.ipDetailsTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _IpDetailRow(
              icon: Icons.location_on_outlined,
              label: l10n.ipDetailsAddress,
              value: ip ?? missing,
              emphasize: true,
              action: ip == null
                  ? null
                  : IconButton(
                      tooltip: l10n.ipDetailsOpenInBrowser,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: _openIp,
                      icon: const Icon(Icons.open_in_new),
                    ),
            ),
            _IpDetailRow(
              icon: Icons.flag_outlined,
              label: l10n.ipDetailsCountry,
              value: country ?? missing,
            ),
            _IpDetailRow(
              icon: Icons.location_city_outlined,
              label: l10n.ipDetailsRegionCity,
              value: _details?.regionAndCity ?? missing,
            ),
            _IpDetailRow(
              icon: Icons.link,
              label: l10n.ipDetailsDomain,
              value: _details?.domain ?? missing,
            ),
            if (busy) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(semanticsLabel: l10n.ipDetailsLoading),
              const SizedBox(height: 12),
            ],
            if (_failed) ...[
              Text(l10n.ipDetailsLoadFailed),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _loadDetails,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.ipDetailsRetry),
                ),
              ),
            ],
            if (_linkFailed) Text(l10n.ipDetailsOpenFailed),
            if (_details?.regionAndCity != null &&
                _details!.geographyLanguage != _languageCode) ...[
              Text(
                l10n.ipDetailsEnglishFallback,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              l10n.detectionTip,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: widget.isIpLoading ? null : widget.onRefresh,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: const Icon(Icons.refresh),
          label: Text(l10n.ipDetailsRefresh),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}

class _IpDetailRow extends StatelessWidget {
  const _IpDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasize = false,
    this.action,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasize;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: emphasize ? FontWeight.w600 : FontWeight.normal,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 4),
            action!,
          ],
        ],
      ),
    );
  }
}
