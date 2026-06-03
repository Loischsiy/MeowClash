import 'package:meowclash/l10n/l10n.dart';
import 'package:flutter/material.dart';

extension DateTimeExtension on DateTime {
  bool get isBeforeNow => isBefore(DateTime.now());

  bool isBeforeSecure(DateTime? dateTime) {
    if (dateTime == null) {
      return false;
    }
    return true;
  }

    String getLastUpdateTimeDesc(BuildContext context) {
    final currentDateTime = DateTime.now();
    final difference = currentDateTime.difference(this);
    final days = difference.inDays;
    final l10n = AppLocalizations.of(context);

    if (l10n == null) return show;

    if (days >= 365) {
      return l10n.yearsAgo((days / 365).floor());
    }
    if (days >= 30) {
      return l10n.monthsAgo((days / 30).floor());
    }
    if (days >= 1) {
      return l10n.daysAgo(days);
    }

    final hours = difference.inHours;
    if (hours >= 1) {
      return l10n.hoursAgo(hours);
    }

    final minutes = difference.inMinutes;
    if (minutes >= 1) {
      return l10n.minutesAgo(minutes);
    }

    return l10n.justNow;
  }


  String get show => toIso8601String().substring(0, 10);
}
