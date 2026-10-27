import 'package:meowclash/common/common.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/views/profiles/add_profile.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class MetainfoWidget extends ConsumerWidget {
  const MetainfoWidget({super.key});

  String _getDaysDeclension(int days) {
    if (days % 100 >= 11 && days % 100 <= 19) {
      return appLocalizations.days;
    }
    switch (days % 10) {
      case 1:
        return appLocalizations.day;
      case 2:
      case 3:
      case 4:
        return appLocalizations.daysGenitive;
      default:
        return appLocalizations.days;
    }
  }

  String _getHoursDeclension(int hours) {
    if (hours % 100 >= 11 && hours % 100 <= 19) {
      return appLocalizations.hoursGenitive;
    }
    switch (hours % 10) {
      case 1:
        return appLocalizations.hour;
      case 2:
      case 3:
      case 4:
        return appLocalizations.hoursPlural;
      default:
        return appLocalizations.hoursGenitive;
    }
  }

  String _getRemainingDeclension(int value) {
    if (value % 100 != 11 && value % 10 == 1) {
      return appLocalizations.remainingSingular;
    }
    return appLocalizations.remainingPlural;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allProfiles = ref.watch(profilesProvider);
    final currentProfile = ref.watch(currentProfileProvider);
    final theme = Theme.of(context);

    if (allProfiles.isEmpty) {
      if (AdaptivePlatform.useGlass) {
        return _buildGlassEmpty(context, onAdd: _addProfile);
      }
      return CommonCard(
        onPressed: () async {
          final result = await globalState.showCommonDialog<URLFormResult>(
            child: const URLFormDialog(),
          );
          if (result != null) {
            globalState.appController.addProfileFormURL(
              result.url,
              decryptionPassword: result.password,

              decryptionIterations: result.iterations,
            );
          }
        },
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_circle_outline,
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(appLocalizations.addProfile),
              ],
            ),
          ),
        ),
      );
    }

    final subscriptionInfo = currentProfile?.subscriptionInfo;

    if (currentProfile == null || subscriptionInfo == null) {
      return const SizedBox.shrink();
    }

    final isUnlimitedTraffic = subscriptionInfo.total == 0;
    final isPerpetual = subscriptionInfo.expire == 0;
    final supportUrl = currentProfile.providerHeaders['support-url'];

    var timeLeftValue = '';
    var timeLeftUnit = '';
    var remainingText = '';
    var showTimeLeft = false;

    if (!isPerpetual) {
      final expireDateTime =
          DateTime.fromMillisecondsSinceEpoch(subscriptionInfo.expire * 1000);
      final difference = expireDateTime.difference(DateTime.now());
      final days = difference.inDays;

      if (days >= 0 && days <= 3) {
        showTimeLeft = true;
        if (days > 0) {
          timeLeftValue = days.toString();
          timeLeftUnit = _getDaysDeclension(days);
          remainingText = _getRemainingDeclension(days);
        } else {
          final hours = difference.inHours;
          if (hours >= 0) {
            timeLeftValue = hours.toString();
            timeLeftUnit = _getHoursDeclension(hours);
            remainingText = _getRemainingDeclension(hours);
          } else {
            showTimeLeft = false;
          }
        }
      }
    }

    if (AdaptivePlatform.useGlass) {
      return _buildGlass(
        context,
        profile: currentProfile,
        info: subscriptionInfo,
        supportUrl: supportUrl,
        timeLeft: showTimeLeft
            ? (
                value: timeLeftValue,
                unit: timeLeftUnit,
                remaining: remainingText,
              )
            : null,
      );
    }

    return CommonCard(
      onPressed: null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            currentProfile.label ?? appLocalizations.profile,
                            style: theme.textTheme.headlineSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (supportUrl != null && supportUrl.isNotEmpty)
                          IconButton(
                            icon: Icon(
                              supportUrl.toLowerCase().contains('t.me')
                                  ? Icons.telegram
                                  : Icons.launch,
                            ),
                            iconSize: 34,
                            color: theme.colorScheme.primary,
                            onPressed: () {
                              globalState.openUrl(supportUrl);
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.sync),
                          iconSize: 34,
                          color: theme.colorScheme.primary,
                          onPressed: () {
                            globalState.appController
                                .updateProfile(currentProfile);
                          },
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (!isUnlimitedTraffic)
                      Builder(builder: (context) {
                        final totalTraffic =
                            TrafficValue(value: subscriptionInfo.total);
                        final usedTrafficValue =
                            subscriptionInfo.upload + subscriptionInfo.download;
                        final usedTraffic =
                            TrafficValue(value: usedTrafficValue);

                        var progress = 0.0;
                        if (subscriptionInfo.total > 0) {
                          progress = usedTrafficValue / subscriptionInfo.total;
                        }
                        progress = progress.clamp(0.0, 1.0);

                        Color progressColor = Colors.green;
                        if (progress > 0.9) {
                          progressColor = Colors.red;
                        } else if (progress > 0.7) {
                          progressColor = Colors.orange;
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${appLocalizations.traffic} ${usedTraffic.showValue} ${usedTraffic.showUnit} / ${totalTraffic.showValue} ${totalTraffic.showUnit}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    progressColor),
                              ),
                            ),
                          ],
                        );
                      })
                    else
                      Text(
                        appLocalizations.trafficUnlimited,
                        style: theme.textTheme.bodyMedium,
                      ),
                    const SizedBox(height: 12),
                    Text(
                      isPerpetual
                          ? appLocalizations.subscriptionEternal
                          : '${appLocalizations.expiresOn} ${DateFormat('dd.MM.yyyy').format(DateTime.fromMillisecondsSinceEpoch(subscriptionInfo.expire * 1000))}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (showTimeLeft) ...[
                const VerticalDivider(width: 32),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      remainingText,
                      style: theme.textTheme.bodySmall,
                    ),
                    FittedBox(
                      fit: BoxFit.contain,
                      child: Text(
                        timeLeftValue,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    Text(
                      timeLeftUnit,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addProfile() async {
    final result = await globalState.showCommonDialog<URLFormResult>(
      child: const URLFormDialog(),
    );
    if (result != null) {
      await globalState.appController.addProfileFormURL(
        result.url,
        decryptionPassword: result.password,
        decryptionIterations: result.iterations,
      );
    }
  }

  /// Darwin: no profiles yet — an empty state with the add action.
  Widget _buildGlassEmpty(BuildContext context, {required VoidCallback onAdd}) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    return AdaptiveWidgetTile(
      onPressed: onAdd,
      child: Padding(
        padding: EdgeInsets.all(AdaptiveWidgetTile.glassPadding()),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              appLocalizations.nullProfileDesc,
              textAlign: TextAlign.center,
              style: GlassTextStyles.widgetCaption(theme.textTheme)
                  .copyWith(color: secondary),
            ),
            const SizedBox(height: GlassTokens.emptyStateGap),
            GlassButton(
              label: appLocalizations.addProfile,
              icon: Icons.add,
              kind: GlassButtonKind.filled,
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }

  /// Darwin: the subscription as a macOS / iOS widget — profile name as the
  /// figure, traffic quota bar in the system traffic colors, expiry caption
  /// and, close to expiry, the time left in system orange.
  Widget _buildGlass(
    BuildContext context, {
    required Profile profile,
    required SubscriptionInfo info,
    required String? supportUrl,
    required ({String value, String unit, String remaining})? timeLeft,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final brightness = theme.brightness;
    final secondary = theme.colorScheme.onSurfaceVariant;
    final caption =
        GlassTextStyles.widgetCaption(textTheme).copyWith(color: secondary);
    final mac = AdaptivePlatform.isMacOSGlass;
    final padding = AdaptiveWidgetTile.glassPadding();
    final buttonSize = mac
        ? GlassTokens.widgetHeaderButtonSizeMac
        : GlassTokens.widgetHeaderButtonSizeIos;
    final buttonIconSize = mac
        ? GlassTokens.widgetHeaderButtonIconSizeMac
        : GlassTokens.widgetHeaderButtonIconSizeIos;
    final isUnlimitedTraffic = info.total == 0;
    final isPerpetual = info.expire == 0;

    Widget traffic;
    if (isUnlimitedTraffic) {
      traffic = Text(appLocalizations.trafficUnlimited, style: caption);
    } else {
      final total = TrafficValue(value: info.total);
      final usedValue = info.upload + info.download;
      final used = TrafficValue(value: usedValue);
      final progress = (usedValue / info.total).clamp(0.0, 1.0);
      final color = GlassTokens.trafficColor(progress, brightness);
      traffic = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${appLocalizations.traffic} ${used.showValue} ${used.showUnit}'
            ' / ${total.showValue} ${total.showUnit}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: caption,
          ),
          const SizedBox(height: GlassTokens.widgetRowGap),
          AdaptiveProgressBar(
            value: progress,
            color: color,
            glassColor: color,
          ),
        ],
      );
    }

    final expiry = Text(
      isPerpetual
          ? appLocalizations.subscriptionEternal
          : '${appLocalizations.expiresOn} ${DateFormat('dd.MM.yyyy').format(DateTime.fromMillisecondsSinceEpoch(info.expire * 1000))}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: caption,
    );

    return AdaptiveWidgetTile(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassWidgetTileHeader(
            info: Info(
              label: appLocalizations.profile,
              iconData: Icons.description_outlined,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (supportUrl != null && supportUrl.isNotEmpty) ...[
                  GlassIconButton(
                    size: buttonSize,
                    iconSize: buttonIconSize,
                    icon: Icon(
                      supportUrl.toLowerCase().contains('t.me')
                          ? Icons.telegram
                          : Icons.launch,
                    ),
                    onPressed: () => globalState.openUrl(supportUrl),
                  ),
                  const SizedBox(width: GlassTokens.widgetHeaderButtonGap),
                ],
                GlassIconButton(
                  tooltip: appLocalizations.update,
                  size: buttonSize,
                  iconSize: buttonIconSize,
                  icon: const Icon(Icons.sync),
                  onPressed: () {
                    globalState.appController.updateProfile(profile);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              padding,
              GlassTokens.widgetRowGap,
              padding,
              padding,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        profile.label ?? appLocalizations.profile,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GlassTextStyles.widgetValue(textTheme)
                            .copyWith(color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: GlassTokens.widgetRowGap),
                      traffic,
                      const SizedBox(height: GlassTokens.widgetRowGap),
                      expiry,
                    ],
                  ),
                ),
                if (timeLeft != null) ...[
                  SizedBox(width: padding),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(timeLeft.remaining, style: caption),
                      Text(
                        timeLeft.value,
                        style: GlassTextStyles.widgetValue(textTheme).copyWith(
                          color: GlassTokens.systemOrange(brightness),
                        ),
                      ),
                      Text(timeLeft.unit, style: caption),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
