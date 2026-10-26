import 'dart:convert';
import 'dart:io';

import 'package:meowclash/clash/clash.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/models/core.dart';
import 'package:meowclash/providers/app.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef UpdatingMap = Map<String, bool>;

class ProvidersView extends ConsumerStatefulWidget {
  const ProvidersView({
    super.key,
  });

  @override
  ConsumerState<ProvidersView> createState() => _ProvidersViewState();
}

class _ProvidersViewState extends ConsumerState<ProvidersView> {
  Future<void> _updateProviders() async {
    final providers = ref.read(providersProvider);
    final providersNotifier = ref.read(providersProvider.notifier);
    final messages = [];
    final updateProviders = providers.map<Future>(
      (provider) async {
        providersNotifier.setProvider(
          provider.copyWith(isUpdating: true),
        );
        final message = await clashCore.updateExternalProvider(
          providerName: provider.name,
        );
        if (message.isNotEmpty) {
          messages.add("${provider.name}: $message \n");
        }
        providersNotifier.setProvider(
          await clashCore.getExternalProvider(provider.name),
        );
      },
    );
    final titleMedium = context.textTheme.titleMedium;
    await Future.wait(updateProviders);
    globalState.appController.updateGroupsDebounce();
    if (messages.isNotEmpty) {
      globalState.showMessage(
        title: appLocalizations.tip,
        message: TextSpan(
          children: [
            for (final message in messages)
              TextSpan(
                text: message,
                style: titleMedium,
              )
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final providers = ref.watch(providersProvider);
    final proxyProviders = providers.where((item) => item.type == "Proxy").map(
          (item) => ProviderItem(
            provider: item,
          ),
        );
    final ruleProviders = providers.where((item) => item.type == "Rule").map(
          (item) => ProviderItem(
            provider: item,
          ),
        );
    final proxySection = generateSection(
      title: appLocalizations.proxyProviders,
      items: proxyProviders,
    );
    final ruleSection = generateSection(
      title: appLocalizations.ruleProviders,
      items: ruleProviders,
    );
    return CommonScaffold(
      actions: [
        IconButton(
          onPressed: _updateProviders,
          icon: const Icon(
            Icons.sync,
          ),
        )
      ],
      body: generateListView([
        ...proxySection,
        ...ruleSection,
      ]),
      title: appLocalizations.providers,
    );
  }
}

class ProviderItem extends StatelessWidget {
  const ProviderItem({
    super.key,
    required this.provider,
  });
  final ExternalProvider provider;

  Future<void> _handleUpdateProvider() async {
    final appController = globalState.appController;
    if (provider.vehicleType != "HTTP") return;
    await globalState.safeRun(
      () async {
        appController.setProvider(
          provider.copyWith(
            isUpdating: true,
          ),
        );
        final message = await clashCore.updateExternalProvider(
          providerName: provider.name,
        );
        if (message.isNotEmpty) throw message;
      },
      silence: false,
    );
    appController.setProvider(
      await clashCore.getExternalProvider(provider.name),
    );
    globalState.appController.updateGroupsDebounce();
  }

  Future<void> _handleSideLoadProvider() async {
    await globalState.safeRun<void>(() async {
      final platformFile = await picker.pickerFile();
      final bytes = platformFile?.bytes;
      if (bytes == null || provider.path == null) return;
      final file = File(provider.path!);
      await file.parent.create(recursive: true);
      final temporary =
          File('${file.path}.tmp.${DateTime.now().microsecondsSinceEpoch}');
      try {
        await temporary.writeAsBytes(bytes, flush: true);
        await temporary.rename(file.path);
      } finally {
        if (temporary.existsSync()) await temporary.delete();
      }
      final providerName = provider.name;
      final message = await clashCore.sideLoadExternalProvider(
        providerName: providerName,
        data: utf8.decode(bytes),
      );
      if (message.isNotEmpty) throw message;
      globalState.appController.setProvider(
        await clashCore.getExternalProvider(provider.name),
      );
      if (message.isNotEmpty) throw message;
    });
    globalState.appController.updateGroupsDebounce();
  }

  String _buildProviderDesc() {
    final baseInfo = provider.updateAt.lastUpdateTimeDesc;
    final count = provider.count;
    return switch (count == 0) {
      true => baseInfo,
      false => "$baseInfo  ·  $count${appLocalizations.entries}",
    };
  }

  /// Darwin: a plain row; the actions are capsule buttons under the subtitle
  /// and Sync shows its own spinner while updating.
  Widget _buildGlass() {
    final canSync = provider.vehicleType == "HTTP";
    return ListItem(
      title: Text(provider.name),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_buildProviderDesc()),
          if (provider.subscriptionInfo != null) ...[
            const SizedBox(height: GlassTokens.listRowSubtitleGap),
            SubscriptionInfoView(
              subscriptionInfo: provider.subscriptionInfo,
            ),
          ],
          const SizedBox(height: GlassTokens.listRowActionsGap),
          Wrap(
            spacing: GlassTokens.listRowActionsSpacing,
            runSpacing: GlassTokens.listRowActionsSpacing,
            children: [
              GlassButton(
                icon: Icons.upload_rounded,
                label: appLocalizations.upload,
                onPressed: _handleSideLoadProvider,
              ),
              if (canSync)
                GlassButton(
                  icon: Icons.sync_rounded,
                  label: appLocalizations.sync,
                  busy: provider.isUpdating,
                  onPressed: _handleUpdateProvider,
                ),
            ],
          ),
        ],
      ),
      trailing: provider.isUpdating && !canSync
          ? const AdaptiveActivityIndicator()
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AdaptivePlatform.useGlass) return _buildGlass();
    return _buildMaterial();
  }

  Widget _buildMaterial() => ListItem(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        title: Text(provider.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 4,
            ),
            Text(
              _buildProviderDesc(),
            ),
            const SizedBox(
              height: 4,
            ),
            if (provider.subscriptionInfo != null)
              SubscriptionInfoView(
                subscriptionInfo: provider.subscriptionInfo,
              ),
            const SizedBox(
              height: 8,
            ),
            Wrap(
              runSpacing: 6,
              spacing: 12,
              children: [
                CommonChip(
                  avatar: const Icon(Icons.upload),
                  label: appLocalizations.upload,
                  onPressed: _handleSideLoadProvider,
                ),
                if (provider.vehicleType == "HTTP")
                  CommonChip(
                    avatar: const Icon(Icons.sync),
                    label: appLocalizations.sync,
                    onPressed: _handleUpdateProvider,
                  ),
              ],
            ),
            const SizedBox(
              height: 4,
            ),
          ],
        ),
        trailing: SizedBox(
          height: 48,
          width: 48,
          child: FadeThroughBox(
            child: provider.isUpdating
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  )
                : const SizedBox(),
          ),
        ),
      );
}
