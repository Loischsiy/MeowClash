import re

with open("lib/common/datetime.dart", "r") as f:
    content = f.read()

new_method = """  String get lastUpdateTimeDesc {
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
"""

content = re.sub(r'String get lastUpdateTimeDesc \{.*?\n  \}', new_method, content, flags=re.DOTALL)

with open("lib/common/datetime.dart", "w") as f:
    f.write(content)
print("Patched datetime.dart")
