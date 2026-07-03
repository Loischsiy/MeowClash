import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/services/zapret/zapret.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/widgets.dart';

/// Settings view for the additive zapret2 DPI-bypass mode: enable toggle, live
/// auto-selection progress, a re-check/reset action, and the required trust
/// disclaimers (antivirus / no-telemetry). All copy is localized; the mode is
/// off by default and never changes proxy behaviour.
class Zapret2View extends ConsumerWidget {
  const Zapret2View({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocale = AppLocalizations.of(context);
    return ListView(
      children: [
        ...generateSection(
          title: appLocale.zapret2,
          items: const [
            _Zapret2EnableItem(),
            _Zapret2StatusItem(),
            _Zapret2TargetsItem(),
            _Zapret2RescanItem(),
          ],
        ),
        const _Zapret2InfoBox(),
      ],
    );
  }
}

class _Zapret2EnableItem extends ConsumerWidget {
  const _Zapret2EnableItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(zapret2SettingProvider.select((s) => s.enable));
    return ListItem.switchItem(
      title: Text(appLocalizations.zapret2Enable),
      subtitle: Text(appLocalizations.zapret2EnableDesc),
      delegate: SwitchDelegate(
        value: enabled,
        onChanged: (value) async {
          final runtime = ref.read(zapret2RuntimeProvider.notifier);
          if (value) {
            await globalState.safeRun(runtime.enable, silence: false);
          } else {
            await globalState.safeRun(runtime.disable);
          }
        },
      ),
    );
  }
}

class _Zapret2TargetsItem extends ConsumerWidget {
  const _Zapret2TargetsItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targets = ref.watch(zapret2SettingProvider.select((s) => s.targets));
    final hosts = targets.map((t) => t.host).toList();
    return ListItem.open(
      title: Text(appLocalizations.domain),
      subtitle: Text(hosts.join(", ")),
      delegate: OpenDelegate(
        blur: false,
        title: appLocalizations.domain,
        widget: Consumer(
          builder: (_, ref, __) {
            final targets = ref.watch(
              zapret2SettingProvider.select((s) => s.targets),
            );
            return ListInputPage(
              title: appLocalizations.domain,
              items: targets.map((t) => t.host).toList(),
              titleBuilder: Text.new,
              onChange: (items) {
                ref.read(zapret2SettingProvider.notifier).updateState(
                      (state) => state.copyWith(
                        targets: items
                            .where((item) => item.trim().isNotEmpty)
                            .map((item) => Zapret2Target(host: item.trim()))
                            .toList(),
                      ),
                    );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Zapret2StatusItem extends ConsumerWidget {
  const _Zapret2StatusItem();

  String _statusText(BuildContext context, Zapret2Status status) {
    final l = AppLocalizations.of(context);
    switch (status.runState) {
      case Zapret2RunState.off:
        return l.zapret2StatusOff;
      case Zapret2RunState.selecting:
        final p = status.progress;
        if (p?.currentStrategy != null) {
          return l.zapret2Progress(
            p!.currentStrategy!.label,
            p.exploredStrategies,
            p.totalStrategies,
          );
        }
        return l.zapret2StatusSelecting;
      case Zapret2RunState.running:
        return l.zapret2StatusRunning(
          status.activeStrategy?.label ?? "",
        );
      case Zapret2RunState.failed:
        return status.message ?? l.zapret2StatusFailed;
      case Zapret2RunState.unavailable:
        return _unavailableText(l, status.unavailableReason);
    }
  }

  String _unavailableText(
    AppLocalizations l,
    Zapret2UnavailableReason? reason,
  ) {
    switch (reason) {
      case Zapret2UnavailableReason.unsupportedPlatform:
        return l.zapret2Unsupported;
      case Zapret2UnavailableReason.missingBinary:
        return l.zapret2MissingBinary;
      case Zapret2UnavailableReason.missingPrivileges:
        return l.zapret2MissingPrivileges;
      case Zapret2UnavailableReason.missingNativeSupport:
        return l.zapret2MissingNative;
      case null:
        return l.zapret2Unsupported;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(zapret2RuntimeProvider);
    final isBusy = status.runState == Zapret2RunState.selecting;
    return ListItem(
      leading: isBusy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              switch (status.runState) {
                Zapret2RunState.running => Icons.check_circle_outline,
                Zapret2RunState.failed => Icons.error_outline,
                Zapret2RunState.unavailable => Icons.block,
                _ => Icons.shield_outlined,
              },
            ),
      title: Text(AppLocalizations.of(context).zapret2),
      subtitle: Text(_statusText(context, status)),
    );
  }
}

class _Zapret2RescanItem extends ConsumerWidget {
  const _Zapret2RescanItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(zapret2SettingProvider.select((s) => s.enable));
    final isBusy = ref.watch(
      zapret2RuntimeProvider
          .select((s) => s.runState == Zapret2RunState.selecting),
    );
    return ListItem(
      leading: const Icon(Icons.refresh),
      title: Text(appLocalizations.zapret2Rescan),
      subtitle: Text(appLocalizations.zapret2RescanDesc),
      onTap: enabled && !isBusy
          ? () {
              globalState.safeRun(
                ref.read(zapret2RuntimeProvider.notifier).rescan,
                silence: false,
              );
            }
          : null,
    );
  }
}

class _Zapret2InfoBox extends StatelessWidget {
  const _Zapret2InfoBox();

  Widget _row(BuildContext context, IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(context, Icons.security, l.zapret2AntivirusWarning),
          _row(context, Icons.lock_outline, l.zapret2NoTelemetry),
        ],
      ),
    );
  }
}
