// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a uk locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'uk';

  static String m0(count) =>
      "${Intl.plural(count, one: '${count} день тому', few: '${count} дні тому', many: '${count} днів тому', other: '${count} днів тому')}";

  static String m1(label) =>
      "Ви впевнені, що хочете видалити вибрані ${label}?";

  static String m2(label) =>
      "Ви впевнені, що хочете видалити поточний ${label}?";

  static String m3(label) => "${label} не може бути порожнім";

  static String m4(label) => "Поточний ${label} вже існує";

  static String m5(count) =>
      "${Intl.plural(count, one: '${count} годину тому', few: '${count} години тому', many: '${count} годин тому', other: '${count} годин тому')}";

  static String m6(count) =>
      "${Intl.plural(count, one: '${count} хвилину тому', few: '${count} хвилини тому', many: '${count} хвилин тому', other: '${count} хвилин тому')}";

  static String m7(count) =>
      "${Intl.plural(count, one: '${count} місяць тому', few: '${count} місяці тому', many: '${count} місяців тому', other: '${count} місяців тому')}";

  static String m8(label) => "Зараз ${label} немає";

  static String m9(label) => "${label} має бути числом";

  static String m10(label) => "${label} має бути числом від 1024 до 49151";

  static String m11(count) => "Вибрано ${count} елементів";

  static String m12(days) => "Ваша підписка закінчується через ${days} дн.";

  static String m13(label) => "${label} має бути URL";

  static String m14(count) =>
      "${Intl.plural(count, one: '${count} рік тому', few: '${count} роки тому', many: '${count} років тому', other: '${count} років тому')}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("Про програму"),
    "accessControl": MessageLookupByLibrary.simpleMessage("Контроль доступу"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Лише вибрані застосунки використовуватимуть VPN",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "Керування доступом застосунків до проксі",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Вибрані застосунки не використовуватимуть VPN",
    ),
    "account": MessageLookupByLibrary.simpleMessage("Обліковий запис"),
    "action": MessageLookupByLibrary.simpleMessage("Дія"),
    "action_mode": MessageLookupByLibrary.simpleMessage("Перемкнути режим"),
    "action_proxy": MessageLookupByLibrary.simpleMessage("Системний проксі"),
    "action_start": MessageLookupByLibrary.simpleMessage("Старт/Стоп"),
    "action_tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "action_view": MessageLookupByLibrary.simpleMessage("Показати/Сховати"),
    "add": MessageLookupByLibrary.simpleMessage("Додати"),
    "addFromPhoneSubtitle": MessageLookupByLibrary.simpleMessage(
      "Сканувати QR-код телефоном",
    ),
    "addFromPhoneTitle": MessageLookupByLibrary.simpleMessage(
      "Додати з телефону",
    ),
    "addHop": MessageLookupByLibrary.simpleMessage("Додати ланку"),
    "addProfile": MessageLookupByLibrary.simpleMessage("Додати профіль"),
    "addRule": MessageLookupByLibrary.simpleMessage("Додати правило"),
    "addedOriginRules": MessageLookupByLibrary.simpleMessage(
      "Додати до оригінальних правил",
    ),
    "address": MessageLookupByLibrary.simpleMessage("Адреса"),
    "addressHelp": MessageLookupByLibrary.simpleMessage(
      "Адреса сервера WebDAV",
    ),
    "addressTip": MessageLookupByLibrary.simpleMessage(
      "Будь ласка, введіть дійсну адресу WebDAV",
    ),
    "adminAutoLaunch": MessageLookupByLibrary.simpleMessage(
      "Автозапуск від імені адміністратора",
    ),
    "adminAutoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Запускати з правами адміністратора під час старту системи",
    ),
    "ago": MessageLookupByLibrary.simpleMessage(" тому"),
    "agree": MessageLookupByLibrary.simpleMessage("Згоден"),
    "allApps": MessageLookupByLibrary.simpleMessage("Усі застосунки"),
    "allowBypass": MessageLookupByLibrary.simpleMessage("Дозволити обхід VPN"),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage(
      "Деякі застосунки зможуть обходити VPN",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("Дозволити LAN"),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage(
      "Дозволити доступ до проксі з локальної мережі",
    ),
    "announcement": MessageLookupByLibrary.simpleMessage("Оголошення"),
    "app": MessageLookupByLibrary.simpleMessage("Застосунок"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage(
      "Контроль доступу застосунків",
    ),
    "appDesc": MessageLookupByLibrary.simpleMessage(
      "Обробка налаштувань, пов\'язаних із застосунком",
    ),
    "application": MessageLookupByLibrary.simpleMessage(
      "Налаштування застосунку",
    ),
    "applicationDesc": MessageLookupByLibrary.simpleMessage(
      "Стандартні налаштування застосунку",
    ),
    "auto": MessageLookupByLibrary.simpleMessage("Авто"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage(
      "Автоперевірка оновлень",
    ),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "Перевіряти оновлення під час запуску",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage(
      "Автозакриття з\'єднань",
    ),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Автоматично закривати з\'єднання під час зміни сервера",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("Автозапуск застосунку"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Запускати разом із системою",
    ),
    "autoRun": MessageLookupByLibrary.simpleMessage("Автозапуск проксі"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage(
      "Автоматично запускати проксі під час відкриття застосунку",
    ),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage(
      "Автоматичне налаштування системного DNS",
    ),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("Автооновлення"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Інтервал автооновлення (хвилини)",
    ),
    "backup": MessageLookupByLibrary.simpleMessage("Резервне копіювання"),
    "backupAndRecovery": MessageLookupByLibrary.simpleMessage(
      "Резервне копіювання та відновлення",
    ),
    "backupAndRecoveryDesc": MessageLookupByLibrary.simpleMessage(
      "Синхронізація даних через WebDAV або файл",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage(
      "Резервне копіювання успішне",
    ),
    "basicConfig": MessageLookupByLibrary.simpleMessage("Конфігурація ядра"),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage(
      "Перевизначення конфігурації ядра",
    ),
    "bind": MessageLookupByLibrary.simpleMessage("Прив\'язати"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage(
      "Режим чорного списку",
    ),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("Обхід домену"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Діє лише при увімкненому системному проксі",
    ),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "Кеш пошкоджено. Очистити його?",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("Скасувати"),
    "cancelFilterSystemApp": MessageLookupByLibrary.simpleMessage(
      "Скасувати фільтрацію системних застосунків",
    ),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage(
      "Скасувати вибір усього",
    ),
    "chainHopsRequired": MessageLookupByLibrary.simpleMessage(
      "Виберіть щонайменше дві ланки",
    ),
    "chainMode": MessageLookupByLibrary.simpleMessage("Режим ланцюжків"),
    "chainName": MessageLookupByLibrary.simpleMessage("Назва ланцюжка"),
    "changeServer": MessageLookupByLibrary.simpleMessage("Змінити сервер"),
    "checkError": MessageLookupByLibrary.simpleMessage("Помилка перевірки"),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("Перевірити оновлення"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage(
      "Поточний застосунок уже є останньою версією",
    ),
    "checking": MessageLookupByLibrary.simpleMessage("Перевірка..."),
    "clearData": MessageLookupByLibrary.simpleMessage("Очистити дані"),
    "clearDataTip": MessageLookupByLibrary.simpleMessage(
      "Це видалить усі дані застосунку та перезапустить його. Ви впевнені?",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage(
      "Експорт у буфер обміну",
    ),
    "clipboardImport": MessageLookupByLibrary.simpleMessage(
      "Імпорт із буфера обміну",
    ),
    "color": MessageLookupByLibrary.simpleMessage("Колір"),
    "colorSchemes": MessageLookupByLibrary.simpleMessage("Колірні схеми"),
    "columns": MessageLookupByLibrary.simpleMessage("Стовпці"),
    "compatible": MessageLookupByLibrary.simpleMessage("Режим сумісності"),
    "compatibleDesc": MessageLookupByLibrary.simpleMessage(
      "Увімкнення призведе до втрати частини функціональності, але забезпечить повну сумісність із Clash",
    ),
    "confirm": MessageLookupByLibrary.simpleMessage("Підтвердити"),
    "connectionDetails": MessageLookupByLibrary.simpleMessage(
      "Деталі з\'єднання",
    ),
    "connections": MessageLookupByLibrary.simpleMessage("З\'єднання"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Перегляд поточних даних про з\'єднання",
    ),
    "connectivity": MessageLookupByLibrary.simpleMessage("Зв\'язок："),
    "contactMe": MessageLookupByLibrary.simpleMessage("Зв\'яжіться зі мною"),
    "content": MessageLookupByLibrary.simpleMessage("Вміст"),
    "contentScheme": MessageLookupByLibrary.simpleMessage("Контентна тема"),
    "copy": MessageLookupByLibrary.simpleMessage("Копіювати"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage(
      "Копіювання змінних середовища",
    ),
    "copyLink": MessageLookupByLibrary.simpleMessage("Копіювати посилання"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("Копіювання успішне"),
    "core": MessageLookupByLibrary.simpleMessage("Ядро"),
    "coreInfo": MessageLookupByLibrary.simpleMessage("Інформація про ядро"),
    "country": MessageLookupByLibrary.simpleMessage("Країна"),
    "crashTest": MessageLookupByLibrary.simpleMessage("Тест на збої"),
    "create": MessageLookupByLibrary.simpleMessage("Створити"),
    "createProfile": MessageLookupByLibrary.simpleMessage("Створити профіль"),
    "cut": MessageLookupByLibrary.simpleMessage("Вирізати"),
    "dark": MessageLookupByLibrary.simpleMessage("Темний"),
    "dashboard": MessageLookupByLibrary.simpleMessage("Головна"),
    "day": MessageLookupByLibrary.simpleMessage("день"),
    "days": MessageLookupByLibrary.simpleMessage("днів"),
    "daysAgo": m0,
    "daysGenitive": MessageLookupByLibrary.simpleMessage("дня"),
    "defaultNameserver": MessageLookupByLibrary.simpleMessage(
      "Сервер імен за замовчуванням",
    ),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Для розв\'язання DNS-сервера",
    ),
    "defaultSort": MessageLookupByLibrary.simpleMessage(
      "Сортування за замовчуванням",
    ),
    "defaultText": MessageLookupByLibrary.simpleMessage("За замовчуванням"),
    "delay": MessageLookupByLibrary.simpleMessage("Затримка"),
    "delaySort": MessageLookupByLibrary.simpleMessage(
      "Сортування за затримкою",
    ),
    "delete": MessageLookupByLibrary.simpleMessage("Видалити"),
    "deleteMultipTip": m1,
    "deleteTip": m2,
    "desc": MessageLookupByLibrary.simpleMessage(
      "Багатоплатформовий проксі-клієнт на основі ClashMeta, простий і зручний у використанні, з відкритим кодом і без реклами.",
    ),
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "Використовує сторонній API. Лише для довідки",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("Режим розробника"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "Режим розробника активовано.",
    ),
    "direct": MessageLookupByLibrary.simpleMessage("Прямий"),
    "disclaimer": MessageLookupByLibrary.simpleMessage(
      "Відмова від відповідальності",
    ),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "Дане програмне забезпечення призначене виключно для некомерційного використання в освітніх і дослідницьких цілях. Комерційне використання заборонено. Розробники не несуть відповідальності за будь-яку комерційну діяльність з використанням даного ПЗ.",
    ),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage(
      "Виявлено нову версію",
    ),
    "discovery": MessageLookupByLibrary.simpleMessage("Виявлено нову версію"),
    "dnsDesc": MessageLookupByLibrary.simpleMessage(
      "Оновлення налаштувань, пов\'язаних із DNS",
    ),
    "dnsMode": MessageLookupByLibrary.simpleMessage("Режим DNS"),
    "doYouWantToPass": MessageLookupByLibrary.simpleMessage(
      "Додаємо профіль за адресою",
    ),
    "domain": MessageLookupByLibrary.simpleMessage("Домен"),
    "download": MessageLookupByLibrary.simpleMessage("Завантаження"),
    "edit": MessageLookupByLibrary.simpleMessage("Редагувати"),
    "editProfile": MessageLookupByLibrary.simpleMessage("Редагувати профіль"),
    "emptyTip": m3,
    "en": MessageLookupByLibrary.simpleMessage("Англійська"),
    "enableOverride": MessageLookupByLibrary.simpleMessage(
      "Увімкнути перевизначення",
    ),
    "entries": MessageLookupByLibrary.simpleMessage(" записів"),
    "errorTitle": MessageLookupByLibrary.simpleMessage("Помилка"),
    "exclude": MessageLookupByLibrary.simpleMessage(
      "Сховати зі списку завдань",
    ),
    "excludeDesc": MessageLookupByLibrary.simpleMessage(
      "Приховувати застосунок зі списку останніх завдань у фоновому режимі",
    ),
    "existsTip": m4,
    "exit": MessageLookupByLibrary.simpleMessage("Вихід"),
    "expand": MessageLookupByLibrary.simpleMessage("Стандартний"),
    "expirationTime": MessageLookupByLibrary.simpleMessage("Час закінчення"),
    "expiresOn": MessageLookupByLibrary.simpleMessage("Закінчується"),
    "exportFile": MessageLookupByLibrary.simpleMessage("Експорт файлу"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("Експорт журналів"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("Експорт успішний"),
    "expressiveScheme": MessageLookupByLibrary.simpleMessage("Експресивні"),
    "externalController": MessageLookupByLibrary.simpleMessage(
      "Зовнішній контролер",
    ),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "Увімкнути керування ядром через API на порту 9090",
    ),
    "externalLink": MessageLookupByLibrary.simpleMessage("Зовнішнє посилання"),
    "externalResources": MessageLookupByLibrary.simpleMessage(
      "Зовнішні ресурси",
    ),
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Фільтр Fakeip"),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Діапазон Fakeip"),
    "fallback": MessageLookupByLibrary.simpleMessage("Резервний"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage(
      "Зазвичай використовується закордонний DNS",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage(
      "Фільтр резервного DNS",
    ),
    "fi": MessageLookupByLibrary.simpleMessage("Фінська"),
    "fidelityScheme": MessageLookupByLibrary.simpleMessage("Точна передача"),
    "file": MessageLookupByLibrary.simpleMessage("Файл"),
    "fileDesc": MessageLookupByLibrary.simpleMessage(
      "Завантажити профіль із файлу",
    ),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "Файл було змінено. Зберегти зміни?",
    ),
    "filterSystemApp": MessageLookupByLibrary.simpleMessage(
      "Фільтрувати системні застосунки",
    ),
    "findProcessMode": MessageLookupByLibrary.simpleMessage(
      "Режим пошуку процесу",
    ),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage(
      "Може незначно знизити продуктивність",
    ),
    "firstHop": MessageLookupByLibrary.simpleMessage("Перша ланка (вхід)"),
    "fontFamily": MessageLookupByLibrary.simpleMessage("Сімейство шрифтів"),
    "fourColumns": MessageLookupByLibrary.simpleMessage("Чотири стовпці"),
    "fruitSaladScheme": MessageLookupByLibrary.simpleMessage("Фруктовий мікс"),
    "general": MessageLookupByLibrary.simpleMessage("Загальні"),
    "generalDesc": MessageLookupByLibrary.simpleMessage(
      "Зміна загальних налаштувань",
    ),
    "geoData": MessageLookupByLibrary.simpleMessage("Геодані"),
    "geodataLoader": MessageLookupByLibrary.simpleMessage(
      "Економія пам\'яті для геоданих",
    ),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "Використовувати режим завантаження геоданих з низьким споживанням пам\'яті",
    ),
    "geoipCode": MessageLookupByLibrary.simpleMessage("Код Geoip"),
    "getOriginRules": MessageLookupByLibrary.simpleMessage(
      "Отримати оригінальні правила",
    ),
    "global": MessageLookupByLibrary.simpleMessage("Глобальний"),
    "go": MessageLookupByLibrary.simpleMessage("Перейти"),
    "goDownload": MessageLookupByLibrary.simpleMessage(
      "Перейти до завантаження",
    ),
    "gratitude": MessageLookupByLibrary.simpleMessage("Подяка"),
    "hasCacheChange": MessageLookupByLibrary.simpleMessage(
      "Зберегти зміни в кеші?",
    ),
    "hop": MessageLookupByLibrary.simpleMessage("Ланка"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("Додати Hosts"),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage(
      "Конфлікт гарячих клавіш",
    ),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage("Гарячі клавіші"),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage(
      "Керування застосунком за допомогою клавіатури",
    ),
    "hour": MessageLookupByLibrary.simpleMessage("година"),
    "hours": MessageLookupByLibrary.simpleMessage("Годин"),
    "hoursAgo": m5,
    "hoursGenitive": MessageLookupByLibrary.simpleMessage("годин"),
    "hoursPlural": MessageLookupByLibrary.simpleMessage("години"),
    "icon": MessageLookupByLibrary.simpleMessage("Іконка"),
    "iconConfiguration": MessageLookupByLibrary.simpleMessage(
      "Конфігурація іконки",
    ),
    "iconStyle": MessageLookupByLibrary.simpleMessage("Стиль іконки"),
    "import": MessageLookupByLibrary.simpleMessage("Імпорт"),
    "importFile": MessageLookupByLibrary.simpleMessage("Імпорт із файлу"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("Імпорт з URL"),
    "importUrl": MessageLookupByLibrary.simpleMessage("Імпорт за URL"),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("Довгострокова дія"),
    "init": MessageLookupByLibrary.simpleMessage("Ініціалізація"),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage(
      "Введіть коректну комбінацію клавіш",
    ),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage(
      "Інтелектуальний вибір",
    ),
    "internet": MessageLookupByLibrary.simpleMessage("Інтернет"),
    "interval": MessageLookupByLibrary.simpleMessage("Інтервал"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("Внутрішній IP"),
    "invalidQrMessage": MessageLookupByLibrary.simpleMessage("Невірний QR-код"),
    "ipcidr": MessageLookupByLibrary.simpleMessage("IPCIDR"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage(
      "Після увімкнення стане можливим отримувати трафік IPv6",
    ),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage(
      "Дозволити вхідний IPv6",
    ),
    "ja": MessageLookupByLibrary.simpleMessage("Японська"),
    "just": MessageLookupByLibrary.simpleMessage("Щойно"),
    "justNow": MessageLookupByLibrary.simpleMessage("Щойно"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "Інтервал підтримання TCP-з\'єднання",
    ),
    "key": MessageLookupByLibrary.simpleMessage("Ключ"),
    "language": MessageLookupByLibrary.simpleMessage("Мова"),
    "layout": MessageLookupByLibrary.simpleMessage("Макет"),
    "light": MessageLookupByLibrary.simpleMessage("Світлий"),
    "list": MessageLookupByLibrary.simpleMessage("Список"),
    "listen": MessageLookupByLibrary.simpleMessage("Слухати"),
    "local": MessageLookupByLibrary.simpleMessage("Локальний"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Резервне копіювання локальних даних на локальний диск",
    ),
    "localRecoveryDesc": MessageLookupByLibrary.simpleMessage(
      "Відновлення даних із файлу",
    ),
    "logDetails": MessageLookupByLibrary.simpleMessage("Деталі журналу"),
    "logLevel": MessageLookupByLibrary.simpleMessage("Рівень журналів"),
    "logcat": MessageLookupByLibrary.simpleMessage("Журналювання"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage(
      "Вести журнал подій застосунку",
    ),
    "logs": MessageLookupByLibrary.simpleMessage("Журнали"),
    "logsDesc": MessageLookupByLibrary.simpleMessage("Записи журналу подій"),
    "logsTest": MessageLookupByLibrary.simpleMessage("Тест журналів"),
    "loopback": MessageLookupByLibrary.simpleMessage("Розблокування Loopback"),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage(
      "Розблокувати Loopback для UWP-застосунків",
    ),
    "loose": MessageLookupByLibrary.simpleMessage("Вільний"),
    "managedByProvider": MessageLookupByLibrary.simpleMessage(
      "Заблокованими налаштуваннями керує ваш провайдер",
    ),
    "managedByProviderNetwork": MessageLookupByLibrary.simpleMessage(
      "Цими параметрами керує ваш провайдер",
    ),
    "memoryInfo": MessageLookupByLibrary.simpleMessage(
      "Інформація про пам\'ять",
    ),
    "messageTest": MessageLookupByLibrary.simpleMessage(
      "Тестування повідомлення",
    ),
    "messageTestTip": MessageLookupByLibrary.simpleMessage("Це повідомлення."),
    "min": MessageLookupByLibrary.simpleMessage("Мін"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage(
      "Згортати під час виходу",
    ),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage(
      "Згортати застосунок у трей замість закриття",
    ),
    "minutes": MessageLookupByLibrary.simpleMessage("Хвилин"),
    "minutesAgo": m6,
    "mixedPort": MessageLookupByLibrary.simpleMessage("Змішаний порт"),
    "mode": MessageLookupByLibrary.simpleMessage("Режим"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("Монохром"),
    "months": MessageLookupByLibrary.simpleMessage("Місяців"),
    "monthsAgo": m7,
    "more": MessageLookupByLibrary.simpleMessage("Ще"),
    "name": MessageLookupByLibrary.simpleMessage("Ім\'я"),
    "nameSort": MessageLookupByLibrary.simpleMessage("Сортування за іменем"),
    "nameserver": MessageLookupByLibrary.simpleMessage("Сервер імен"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Для розв\'язання домену",
    ),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage(
      "Політика сервера імен",
    ),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Вказати відповідну політику сервера імен",
    ),
    "network": MessageLookupByLibrary.simpleMessage("Мережа"),
    "networkDesc": MessageLookupByLibrary.simpleMessage(
      "Зміна налаштувань, пов\'язаних із мережею",
    ),
    "networkDetection": MessageLookupByLibrary.simpleMessage("Ваша IP-адреса"),
    "networkSpeed": MessageLookupByLibrary.simpleMessage("Швидкість мережі"),
    "neutralScheme": MessageLookupByLibrary.simpleMessage("Нейтральні"),
    "noData": MessageLookupByLibrary.simpleMessage("Немає даних"),
    "noHotKey": MessageLookupByLibrary.simpleMessage("Немає гарячої клавіші"),
    "noIcon": MessageLookupByLibrary.simpleMessage("Немає іконки"),
    "noInfo": MessageLookupByLibrary.simpleMessage("Немає інформації"),
    "noMoreInfoDesc": MessageLookupByLibrary.simpleMessage(
      "Додаткова інформація відсутня",
    ),
    "noNetwork": MessageLookupByLibrary.simpleMessage("Немає мережі"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage(
      "Застосунок без мережі",
    ),
    "noProxy": MessageLookupByLibrary.simpleMessage("Немає проксі"),
    "noProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Будь ласка, створіть профіль або додайте дійсний профіль",
    ),
    "noResolve": MessageLookupByLibrary.simpleMessage("Не розв\'язувати IP"),
    "none": MessageLookupByLibrary.simpleMessage("Немає"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "Поточна група проксі недоступна для вибору",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Профіль відсутній. Будь ласка, додайте профіль",
    ),
    "nullScriptTip": MessageLookupByLibrary.simpleMessage("Скрипти відсутні"),
    "nullTip": m8,
    "numberTip": m9,
    "oneColumn": MessageLookupByLibrary.simpleMessage("Один стовпець"),
    "oneline": MessageLookupByLibrary.simpleMessage("Лінія"),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("Лише іконка"),
    "onlyOtherApps": MessageLookupByLibrary.simpleMessage(
      "Лише сторонні застосунки",
    ),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage(
      "Враховувати лише проксі-трафік",
    ),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Враховувати в статистиці лише трафік через проксі",
    ),
    "openLogsFolder": MessageLookupByLibrary.simpleMessage(
      "Відкрити папку журналів",
    ),
    "options": MessageLookupByLibrary.simpleMessage("Опції"),
    "originalRepository": MessageLookupByLibrary.simpleMessage(
      "Оригінальний репозиторій",
    ),
    "other": MessageLookupByLibrary.simpleMessage("Інше"),
    "otherContributors": MessageLookupByLibrary.simpleMessage("Контрибютори"),
    "outboundMode": MessageLookupByLibrary.simpleMessage(
      "Режим вихідних підключень",
    ),
    "override": MessageLookupByLibrary.simpleMessage("Перевизначення"),
    "overrideDesc": MessageLookupByLibrary.simpleMessage(
      "Перевизначення конфігурації проксі",
    ),
    "overrideDns": MessageLookupByLibrary.simpleMessage("Перевизначити DNS"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "Перевизначити налаштування DNS із профілю",
    ),
    "overrideInvalidTip": MessageLookupByLibrary.simpleMessage(
      "У скриптовому режимі не діє",
    ),
    "overrideNetworkSettings": MessageLookupByLibrary.simpleMessage(
      "Перевизначення мережевих налаштувань",
    ),
    "overrideNetworkSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "Ігнорувати мережеві налаштування з конфігурації провайдера",
    ),
    "overrideOriginRules": MessageLookupByLibrary.simpleMessage(
      "Перевизначити оригінальне правило",
    ),
    "overrideProviderSettings": MessageLookupByLibrary.simpleMessage(
      "Перевизначення",
    ),
    "overrideProviderSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "Ігнорувати налаштування від провайдера та керувати вручну",
    ),
    "palette": MessageLookupByLibrary.simpleMessage("Палітра"),
    "password": MessageLookupByLibrary.simpleMessage("Пароль"),
    "paste": MessageLookupByLibrary.simpleMessage("Вставити"),
    "pasteFromClipboard": MessageLookupByLibrary.simpleMessage("Вставити"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage(
      "Будь ласка, прив\'яжіть WebDAV",
    ),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "Будь ласка, введіть назву скрипту",
    ),
    "pleaseInputAdminPassword": MessageLookupByLibrary.simpleMessage(
      "Будь ласка, введіть пароль адміністратора",
    ),
    "pleaseUploadFile": MessageLookupByLibrary.simpleMessage(
      "Будь ласка, завантажте файл",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "Будь ласка, завантажте дійсний QR-код",
    ),
    "port": MessageLookupByLibrary.simpleMessage("Порт"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage(
      "Введіть інший порт",
    ),
    "portTip": m10,
    "preferH3Desc": MessageLookupByLibrary.simpleMessage(
      "Використовувати HTTP/3 для DOH (якщо доступно)",
    ),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage("Натисніть клавішу"),
    "preview": MessageLookupByLibrary.simpleMessage("Попередній перегляд"),
    "profile": MessageLookupByLibrary.simpleMessage("Профіль"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage(
          "Будь ласка, введіть дійсний формат інтервалу часу",
        ),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage(
          "Будь ласка, введіть інтервал часу для автооновлення",
        ),
    "profileDecryptFailed": MessageLookupByLibrary.simpleMessage(
      "Не вдалося розшифрувати підписку",
    ),
    "profileDecryptIterationsInvalid": MessageLookupByLibrary.simpleMessage(
      "Кількість ітерацій має бути додатним числом",
    ),
    "profileDecryptPasswordRequired": MessageLookupByLibrary.simpleMessage(
      "Будь ласка, введіть пароль для розшифрування",
    ),
    "profileDecryptSourceMissing": MessageLookupByLibrary.simpleMessage(
      "Немає файлу підписки для розшифрування",
    ),
    "profileDecryptSuccess": MessageLookupByLibrary.simpleMessage(
      "Підписку успішно розшифровано",
    ),
    "profileDecryption": MessageLookupByLibrary.simpleMessage(
      "Розшифрування підписки",
    ),
    "profileDecryptionAction": MessageLookupByLibrary.simpleMessage(
      "Розшифрувати",
    ),
    "profileDecryptionDesc": MessageLookupByLibrary.simpleMessage(
      "Розшифрування зашифрованого файлу підписки (AES-256-CBC, ключ із пароля через PBKDF2HMAC-SHA256).",
    ),
    "profileDecryptionIterations": MessageLookupByLibrary.simpleMessage(
      "Ітерації PBKDF2",
    ),
    "profileDecryptionIterationsHelper": MessageLookupByLibrary.simpleMessage(
      "Має збігатися зі значенням, використаним під час шифрування (за замовчуванням 480000)",
    ),
    "profileDecryptionPassword": MessageLookupByLibrary.simpleMessage(
      "Пароль для розшифрування",
    ),
    "profileDecryptionPasswordOptionalHelper":
        MessageLookupByLibrary.simpleMessage(
          "Залиште порожнім для незашифрованих підписок",
        ),
    "profileEncryptedPasswordRequired": MessageLookupByLibrary.simpleMessage(
      "Підписка зашифрована. Будь ласка, вкажіть пароль для розшифрування.",
    ),
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "Профіль було змінено. Вимкнути автооновлення?",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Будь ласка, введіть ім\'я профілю",
    ),
    "profileParseErrorDesc": MessageLookupByLibrary.simpleMessage(
      "Помилка розбору профілю",
    ),
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Будь ласка, введіть дійсний URL профілю",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Будь ласка, введіть URL профілю",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("Профілі"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("Сортування профілів"),
    "project": MessageLookupByLibrary.simpleMessage("Проєкт"),
    "providers": MessageLookupByLibrary.simpleMessage("Провайдери"),
    "proxies": MessageLookupByLibrary.simpleMessage("Проксі"),
    "proxiesSetting": MessageLookupByLibrary.simpleMessage(
      "Налаштування проксі",
    ),
    "proxyChains": MessageLookupByLibrary.simpleMessage("Ланцюжки проксі"),
    "proxyChainsDesc": MessageLookupByLibrary.simpleMessage(
      "Об\'єднання проксі в ланцюжок: вхід → вихід",
    ),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("Група проксі"),
    "proxyNameserver": MessageLookupByLibrary.simpleMessage(
      "Проксі-сервер імен",
    ),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Домен для розв\'язання проксі-вузлів",
    ),
    "proxyPort": MessageLookupByLibrary.simpleMessage("Порт проксі"),
    "proxyPortDesc": MessageLookupByLibrary.simpleMessage(
      "Встановити порт прослуховування проксі-сервера",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("Провайдери проксі"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("Суто чорний режим"),
    "qrNotFound": MessageLookupByLibrary.simpleMessage("QR-код не знайдено"),
    "qrcode": MessageLookupByLibrary.simpleMessage("QR-код"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage(
      "Сканувати QR-код для отримання профілю",
    ),
    "rainbowScheme": MessageLookupByLibrary.simpleMessage("Райдужні"),
    "receiveSubscriptionTitle": MessageLookupByLibrary.simpleMessage(
      "Отримання підписки",
    ),
    "recovery": MessageLookupByLibrary.simpleMessage("Відновлення"),
    "recoveryAll": MessageLookupByLibrary.simpleMessage("Відновити всі дані"),
    "recoveryProfiles": MessageLookupByLibrary.simpleMessage(
      "Лише відновлення профілів",
    ),
    "recoveryStrategy": MessageLookupByLibrary.simpleMessage(
      "Стратегія відновлення",
    ),
    "recoveryStrategy_compatible": MessageLookupByLibrary.simpleMessage(
      "Сумісний",
    ),
    "recoveryStrategy_override": MessageLookupByLibrary.simpleMessage(
      "Перевизначення",
    ),
    "recoverySuccess": MessageLookupByLibrary.simpleMessage(
      "Відновлення успішне",
    ),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redir-порт"),
    "redo": MessageLookupByLibrary.simpleMessage("Повторити"),
    "regExp": MessageLookupByLibrary.simpleMessage("Регулярний вираз"),
    "remaining": MessageLookupByLibrary.simpleMessage("Залишилось"),
    "remainingPlural": MessageLookupByLibrary.simpleMessage("Залишилось"),
    "remainingSingular": MessageLookupByLibrary.simpleMessage("Залишився"),
    "remote": MessageLookupByLibrary.simpleMessage("Віддалений"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Резервне копіювання локальних даних на WebDAV",
    ),
    "remoteRecoveryDesc": MessageLookupByLibrary.simpleMessage(
      "Відновлення даних з WebDAV",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("Видалити"),
    "rename": MessageLookupByLibrary.simpleMessage("Перейменувати"),
    "renew": MessageLookupByLibrary.simpleMessage("Продовжити"),
    "requestDetails": MessageLookupByLibrary.simpleMessage("Деталі запиту"),
    "requests": MessageLookupByLibrary.simpleMessage("Запити"),
    "requestsDesc": MessageLookupByLibrary.simpleMessage(
      "Перегляд останніх записів запитів",
    ),
    "reset": MessageLookupByLibrary.simpleMessage("Скинути"),
    "resetTip": MessageLookupByLibrary.simpleMessage(
      "Переконайтеся, що хочете скинути",
    ),
    "resources": MessageLookupByLibrary.simpleMessage("Ресурси"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage(
      "Керування зовнішніми ресурсами",
    ),
    "respectRules": MessageLookupByLibrary.simpleMessage(
      "Дотримуватися правил",
    ),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "DNS-запити дотримуються правил маршрутизації (потрібне налаштування proxy-server-nameserver)",
    ),
    "restart": MessageLookupByLibrary.simpleMessage("Перезапустити"),
    "restartCore": MessageLookupByLibrary.simpleMessage("Перезапуск ядра"),
    "restartCoreDesc": MessageLookupByLibrary.simpleMessage(
      "Перезапустити службу проксі-ядра",
    ),
    "restartCoreSuccess": MessageLookupByLibrary.simpleMessage(
      "Ядро успішно перезапущено",
    ),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage(
      "Ви дійсно хочете перезапустити ядро? Активні з\'єднання буде на короткий час перервано.",
    ),
    "routeAddress": MessageLookupByLibrary.simpleMessage(
      "Адреса маршрутизації",
    ),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage(
      "Налаштування адреси прослуховування маршрутизації",
    ),
    "routeMode": MessageLookupByLibrary.simpleMessage("Режим маршрутизації"),
    "routeMode_bypassPrivate": MessageLookupByLibrary.simpleMessage(
      "Обхід приватних адрес маршрутизації",
    ),
    "routeMode_config": MessageLookupByLibrary.simpleMessage(
      "Використовувати конфігурацію",
    ),
    "ru": MessageLookupByLibrary.simpleMessage("Російська"),
    "rule": MessageLookupByLibrary.simpleMessage("За правилами"),
    "ruleName": MessageLookupByLibrary.simpleMessage("Назва правила"),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("Провайдери правил"),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("Ціль правила"),
    "running": MessageLookupByLibrary.simpleMessage("Запущено"),
    "save": MessageLookupByLibrary.simpleMessage("Зберегти"),
    "saveChanges": MessageLookupByLibrary.simpleMessage("Зберегти зміни?"),
    "saveTip": MessageLookupByLibrary.simpleMessage("Зберегти зміни?"),
    "script": MessageLookupByLibrary.simpleMessage("Скрипт"),
    "search": MessageLookupByLibrary.simpleMessage("Пошук"),
    "secondHop": MessageLookupByLibrary.simpleMessage("Друга ланка (вихід)"),
    "seconds": MessageLookupByLibrary.simpleMessage("Секунд"),
    "selectAll": MessageLookupByLibrary.simpleMessage("Вибрати все"),
    "selectProfile": MessageLookupByLibrary.simpleMessage("Вибрати профіль"),
    "selected": MessageLookupByLibrary.simpleMessage("Вибрано"),
    "selectedCountTitle": m11,
    "sendToTv": MessageLookupByLibrary.simpleMessage("Надіслати на ТВ"),
    "sendToTvTitle": MessageLookupByLibrary.simpleMessage("Надіслати на ТВ"),
    "sentSuccessfullyMessage": MessageLookupByLibrary.simpleMessage(
      "Надіслано успішно",
    ),
    "settings": MessageLookupByLibrary.simpleMessage("Налаштування"),
    "settingsSendDeviceDataSubtitle": MessageLookupByLibrary.simpleMessage(
      "Надсилати ідентифікатор пристрою, версію застосунку та назву пристрою на сервер проксі-провайдера",
    ),
    "settingsSendDeviceDataTitle": MessageLookupByLibrary.simpleMessage(
      "Надсилати HWID",
    ),
    "show": MessageLookupByLibrary.simpleMessage("Показати"),
    "shrink": MessageLookupByLibrary.simpleMessage("Стиснути"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("Прихований запуск"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Запускати у згорнутому вигляді",
    ),
    "size": MessageLookupByLibrary.simpleMessage("Розмір"),
    "socksPort": MessageLookupByLibrary.simpleMessage("Socks-порт"),
    "sort": MessageLookupByLibrary.simpleMessage("Сортування"),
    "source": MessageLookupByLibrary.simpleMessage("Джерело"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("Початковий IP"),
    "stackMode": MessageLookupByLibrary.simpleMessage("Режим стека"),
    "standard": MessageLookupByLibrary.simpleMessage("Стандартний"),
    "start": MessageLookupByLibrary.simpleMessage("Старт"),
    "startVpn": MessageLookupByLibrary.simpleMessage("Запуск VPN..."),
    "status": MessageLookupByLibrary.simpleMessage("Статус"),
    "statusDesc": MessageLookupByLibrary.simpleMessage(
      "Після вимкнення використовуватиметься системний DNS",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("Стоп"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("Зупинка VPN..."),
    "stopped": MessageLookupByLibrary.simpleMessage("Зупинено"),
    "style": MessageLookupByLibrary.simpleMessage("Стиль"),
    "subRule": MessageLookupByLibrary.simpleMessage("Підправило"),
    "submit": MessageLookupByLibrary.simpleMessage("Надіслати"),
    "subscriptionEternal": MessageLookupByLibrary.simpleMessage(
      "Безстрокова підписка",
    ),
    "subscriptionExpired": MessageLookupByLibrary.simpleMessage(
      "Ваша підписка закінчилася",
    ),
    "subscriptionExpiresInDays": m12,
    "subscriptionExpiresSoon": MessageLookupByLibrary.simpleMessage(
      "Підписка скоро закінчується",
    ),
    "subscriptionExpiresToday": MessageLookupByLibrary.simpleMessage(
      "Ваша підписка закінчується сьогодні",
    ),
    "subscriptionUnlimited": MessageLookupByLibrary.simpleMessage(
      "Безстрокова підписка",
    ),
    "successTitle": MessageLookupByLibrary.simpleMessage("Успішно"),
    "support": MessageLookupByLibrary.simpleMessage("Підтримка"),
    "sync": MessageLookupByLibrary.simpleMessage("Оновлення"),
    "system": MessageLookupByLibrary.simpleMessage("Система"),
    "systemApp": MessageLookupByLibrary.simpleMessage("Системний застосунок"),
    "systemFont": MessageLookupByLibrary.simpleMessage("Системний шрифт"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("Системний проксі"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Використовувати HTTP-проксі через VPN",
    ),
    "tab": MessageLookupByLibrary.simpleMessage("Вкладка"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("Анімація вкладок"),
    "tabAnimationDesc": MessageLookupByLibrary.simpleMessage(
      "Працює лише в мобільному режимі",
    ),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("Паралельний TCP"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage(
      "Використовувати паралельні TCP-з\'єднання",
    ),
    "testUrl": MessageLookupByLibrary.simpleMessage("Тест URL"),
    "textScale": MessageLookupByLibrary.simpleMessage("Масштабування тексту"),
    "thanks": MessageLookupByLibrary.simpleMessage("Дякуємо за внесок"),
    "theme": MessageLookupByLibrary.simpleMessage("Тема"),
    "themeColor": MessageLookupByLibrary.simpleMessage("Колір теми"),
    "themeDesc": MessageLookupByLibrary.simpleMessage(
      "Встановити темний режим, налаштувати колір",
    ),
    "themeMode": MessageLookupByLibrary.simpleMessage("Режим теми"),
    "threeColumns": MessageLookupByLibrary.simpleMessage("Три стовпці"),
    "tight": MessageLookupByLibrary.simpleMessage("Щільний"),
    "time": MessageLookupByLibrary.simpleMessage("Час"),
    "tip": MessageLookupByLibrary.simpleMessage("Підказка"),
    "toggle": MessageLookupByLibrary.simpleMessage("Перемкнути"),
    "tonalSpotScheme": MessageLookupByLibrary.simpleMessage("Тональний акцент"),
    "tooFrequentOperation": MessageLookupByLibrary.simpleMessage(
      "Будь ласка, зачекайте 15 секунд перед повторним оновленням",
    ),
    "tlsCertificateExpiredHint": MessageLookupByLibrary.simpleMessage(
        "Термін дії сертифіката сервера минув або ще не почався. Перевірте дату й час на пристрої."),
    "tlsErrorDetails":
        MessageLookupByLibrary.simpleMessage("Технічні подробиці"),
    "tlsGenericHint": MessageLookupByLibrary.simpleMessage(
        "Не вдалося завершити TLS-рукостискання із сервером."),
    "tlsHandshakeFailed": MessageLookupByLibrary.simpleMessage(
        "Не вдалося встановити захищене з'єднання (TLS)"),
    "tlsHostMismatchHint": MessageLookupByLibrary.simpleMessage(
        "Сертифікат сервера видано для іншого домену."),
    "tlsSelfSignedHint": MessageLookupByLibrary.simpleMessage(
        "Сервер надіслав самопідписаний сертифікат. Найімовірніше, з'єднання перехоплює антивірус, корпоративний проксі або captive-портал."),
    "tlsUntrustedChainHint": MessageLookupByLibrary.simpleMessage(
        "Сертифікат сервера не пройшов перевірку: ланцюжок сертифікатів неповний або його корінь не є довіреним на цьому пристрої. Якщо сервер підписки ваш — переконайтеся, що він віддає повний ланцюжок (fullchain.pem). Інакше встановіть оновлення системи та спробуйте ще раз."),
    "tools": MessageLookupByLibrary.simpleMessage("Налаштування"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Tproxy-порт"),
    "traffic": MessageLookupByLibrary.simpleMessage("Трафік"),
    "trafficUnlimited": MessageLookupByLibrary.simpleMessage(
      "Безлімітний трафік",
    ),
    "trafficUsage": MessageLookupByLibrary.simpleMessage(
      "Використання трафіку",
    ),
    "tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "tunDesc": MessageLookupByLibrary.simpleMessage(
      "Доступно лише в режимі адміністратора",
    ),
    "twoColumns": MessageLookupByLibrary.simpleMessage("Два стовпці"),
    "uk": MessageLookupByLibrary.simpleMessage("Українська"),
    "unableToUpdateCurrentProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Неможливо оновити поточний профіль",
    ),
    "undo": MessageLookupByLibrary.simpleMessage("Скасувати"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage(
      "Уніфікована затримка",
    ),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage(
      "Не враховувати додаткові затримки (наприклад, рукостискання)",
    ),
    "unknown": MessageLookupByLibrary.simpleMessage("Невідомо"),
    "unnamed": MessageLookupByLibrary.simpleMessage("Без імені"),
    "update": MessageLookupByLibrary.simpleMessage("Оновити"),
    "updateAllGeoData": MessageLookupByLibrary.simpleMessage(
      "Оновити всі гео-файли",
    ),
    "updated": MessageLookupByLibrary.simpleMessage("Оновлено"),
    "upload": MessageLookupByLibrary.simpleMessage("Відправлення"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage(
      "Завантажити профіль за URL",
    ),
    "urlTip": m13,
    "useHosts": MessageLookupByLibrary.simpleMessage("Використовувати hosts"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage(
      "Використовувати системні hosts",
    ),
    "value": MessageLookupByLibrary.simpleMessage("Значення"),
    "vibrantScheme": MessageLookupByLibrary.simpleMessage("Яскраві"),
    "view": MessageLookupByLibrary.simpleMessage("Перегляд"),
    "vpnDesc": MessageLookupByLibrary.simpleMessage(
      "Зміна налаштувань, пов\'язаних із VPN",
    ),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "Автоматично спрямовує весь системний трафік через VpnService",
    ),
    "vpnSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Використовувати HTTP-проксі через VPN",
    ),
    "vpnTip": MessageLookupByLibrary.simpleMessage(
      "Зміни набудуть чинності після перезапуску VPN",
    ),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage(
      "Конфігурація WebDAV",
    ),
    "whitelistMode": MessageLookupByLibrary.simpleMessage(
      "Режим білого списку",
    ),
    "years": MessageLookupByLibrary.simpleMessage("Років"),
    "yearsAgo": m14,
    "zh_CN": MessageLookupByLibrary.simpleMessage("Спрощена китайська"),
  };
}
