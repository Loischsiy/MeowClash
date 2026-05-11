import 'package:meow_clash/common/common.dart';
import 'package:meow_clash/models/models.dart';
import 'package:flutter/material.dart';

class SubscriptionInfoView extends StatelessWidget {
  final SubscriptionInfo? subscriptionInfo;

  const SubscriptionInfoView({super.key, this.subscriptionInfo});

  @override
  Widget build(BuildContext context) {
    if (subscriptionInfo == null) {
      return Container();
    }

    final use = subscriptionInfo!.upload + subscriptionInfo!.download;
    final total = subscriptionInfo!.total;

    // No traffic info
    if (use == 0 && total == 0) {
      return Container();
    }

    // Show progress bar
    final progress = total > 0 ? use / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          minHeight: 6,
          value: progress,
          backgroundColor: context.colorScheme.primary.opacity15,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
