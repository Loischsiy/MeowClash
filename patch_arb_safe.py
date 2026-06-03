import json
import os
import collections

updates = {
    'en': {
        "yearsAgo": "{count, plural, =1{1 year ago} other{{count} years ago}}",
        "monthsAgo": "{count, plural, =1{1 month ago} other{{count} months ago}}",
        "daysAgo": "{count, plural, =1{1 day ago} other{{count} days ago}}",
        "hoursAgo": "{count, plural, =1{1 hour ago} other{{count} hours ago}}",
        "minutesAgo": "{count, plural, =1{1 minute ago} other{{count} minutes ago}}",
        "justNow": "Just now",
        "addProfile": "Add profile",
        "editProfile": "Edit profile",
        "createProfile": "Create profile",
        "requestDetails": "Request details",
        "connectionDetails": "Connection details",
        "logDetails": "Log details"
    },
    'ru': {
        "yearsAgo": "{count, plural, one{{count} год назад} few{{count} года назад} many{{count} лет назад} other{{count} лет назад}}",
        "monthsAgo": "{count, plural, one{{count} месяц назад} few{{count} месяца назад} many{{count} месяцев назад} other{{count} месяцев назад}}",
        "daysAgo": "{count, plural, one{{count} день назад} few{{count} дня назад} many{{count} дней назад} other{{count} дней назад}}",
        "hoursAgo": "{count, plural, one{{count} час назад} few{{count} часа назад} many{{count} часов назад} other{{count} часов назад}}",
        "minutesAgo": "{count, plural, one{{count} минуту назад} few{{count} минуты назад} many{{count} минут назад} other{{count} минут назад}}",
        "justNow": "Только что",
        "addProfile": "Добавить профиль",
        "editProfile": "Редактировать профиль",
        "createProfile": "Создать профиль",
        "requestDetails": "Подробности запроса",
        "connectionDetails": "Подробности соединения",
        "logDetails": "Подробности лога"
    },
    'zh_CN': {
        "yearsAgo": "{count} 年前",
        "monthsAgo": "{count} 个月前",
        "daysAgo": "{count} 天前",
        "hoursAgo": "{count} 小时前",
        "minutesAgo": "{count} 分钟前",
        "justNow": "刚刚",
        "addProfile": "添加配置",
        "editProfile": "编辑配置",
        "createProfile": "创建配置",
        "requestDetails": "请求详情",
        "connectionDetails": "活跃连接详情",
        "logDetails": "日志详情"
    },
    'ja': {
        "yearsAgo": "{count} 年前",
        "monthsAgo": "{count} ヶ月前",
        "daysAgo": "{count} 日前",
        "hoursAgo": "{count} 時間前",
        "minutesAgo": "{count} 分前",
        "justNow": "たった今",
        "addProfile": "プロファイルを追加",
        "editProfile": "プロファイルを編集",
        "createProfile": "プロファイルを作成",
        "requestDetails": "リクエストの詳細",
        "connectionDetails": "接続の詳細",
        "logDetails": "ログの詳細"
    },
    'uk': {
        "yearsAgo": "{count, plural, one{{count} рік тому} few{{count} роки тому} many{{count} років тому} other{{count} років тому}}",
        "monthsAgo": "{count, plural, one{{count} місяць тому} few{{count} місяці тому} many{{count} місяців тому} other{{count} місяців тому}}",
        "daysAgo": "{count, plural, one{{count} день тому} few{{count} дні тому} many{{count} днів тому} other{{count} днів тому}}",
        "hoursAgo": "{count, plural, one{{count} годину тому} few{{count} години тому} many{{count} годин тому} other{{count} годин тому}}",
        "minutesAgo": "{count, plural, one{{count} хвилину тому} few{{count} хвилини тому} many{{count} хвилин тому} other{{count} хвилин тому}}",
        "justNow": "Щойно",
        "addProfile": "Додати профіль",
        "editProfile": "Редагувати профіль",
        "createProfile": "Створити профіль",
        "requestDetails": "Деталі запиту",
        "connectionDetails": "Деталі з'єднання",
        "logDetails": "Деталі журналу"
    }
}


for lang, new_data in updates.items():
    file_path = f"arb/intl_{lang}.arb"
    if not os.path.exists(file_path):
        continue

    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f, object_pairs_hook=collections.OrderedDict)

    # We DO NOT delete legacy 'days', 'years', 'months' keys so metainfo_widget.dart won't break
    for k, v in new_data.items():
        data[k] = v
        if "Ago" in k:
            data[f"@{k}"] = collections.OrderedDict({
                "placeholders": {
                    "count": {
                        "type": "int"
                    }
                }
            })

    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

print("Updated ARB files safely.")
