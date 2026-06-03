import 'package:meowclash/common/app_localizations.dart';

extension DateTimeExtension on DateTime {
  bool get isBeforeNow => isBefore(DateTime.now());

  bool isBeforeSecure(DateTime? dateTime) {
    if (dateTime == null) {
      return false;
    }
    return true;
  }

    String get lastUpdateTimeDesc {
    final currentDateTime = DateTime.now();
    final difference = currentDateTime.difference(this);
    final days = difference.inDays;

    if (days >= 365) {
      return appLocalizations.yearsAgo((days / 365).floor());
    }
    if (days >= 30) {
      return appLocalizations.monthsAgo((days / 30).floor());
    }
    if (days >= 1) {
      return appLocalizations.daysAgo(days);
    }

    final hours = difference.inHours;
    if (hours >= 1) {
      return appLocalizations.hoursAgo(hours);
    }

    final minutes = difference.inMinutes;
    if (minutes >= 1) {
      return appLocalizations.minutesAgo(minutes);
    }

    return appLocalizations.justNow;
  }


  String get show => toIso8601String().substring(0, 10);
}
