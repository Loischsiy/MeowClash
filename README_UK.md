<div align="center">

# MeowClash

[![Downloads](https://img.shields.io/github/downloads/Loischsiy/MeowClash/total?style=flat-square&logo=github&color=b966cf)](https://github.com/Loischsiy/MeowClash/releases/)
[![Last Version](https://img.shields.io/github/release/Loischsiy/MeowClash/all.svg?style=flat-square&color=8c52ff)](https://github.com/Loischsiy/MeowClash/releases/)
[![License](https://img.shields.io/github/license/Loischsiy/MeowClash?style=flat-square&color=4296f4)](LICENSE)
[![Platform Support](https://img.shields.io/badge/platform-Android%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux-e84393?style=flat-square)](#завантажити)

[**English**](README.md) | [**Русский**](README_RU.md) | **Українська** | [**日本語**](README_JA.md) | [**简体中文**](README_ZH.md)

</div>

---

**MeowClash** — це сучасний, багатофункціональний мультиплатформний проксі-клієнт із відкритим вихідним кодом на базі ядра **ClashMeta (mihomo)**. Він пропонує гарний інтерфейс у стилі Material You для керування вашими проксі-з'єднаннями, повністю позбавлений реклами та нативно працює на Android, Windows, macOS та Linux.

*MeowClash є форком чудового проєкту [FlClashX](https://github.com/pluralplay/FlClashX).*

---

## 📸 Попередній перегляд

### На комп'ютері (Десктоп)
<div align="center">
  <img alt="Інтерфейс MeowClash для десктопа" src="snapshots/desktop.gif" width="85%" style="border-radius: 8px; box-shadow: 0 4px 10px rgba(0,0,0,0.3);">
</div>

### На мобільних пристроях
<div align="center">
  <img alt="Мобільний інтерфейс MeowClash" src="snapshots/mobile.gif" width="35%" style="border-radius: 8px; box-shadow: 0 4px 10px rgba(0,0,0,0.3);">
</div>

---

## 🎨 Ключові можливості

### ✨ Інтерфейс та стиль (Material You)
- **Інтерфейс Material 3**: Чистий, сучасний, адаптивний дизайн, натхненний Surfboard.
- **Динамічні теми**: Безліч колірних схем (TonalSpot, Fidelity, Monochrome, Neutral, Vibrant, Expressive, Content, Rainbow, FruitSalad) із підтримкою темного, світлого та глибокого чорного режимів.
- **Налаштування сітки та відступів**: Регулюйте щільність інтерфейсу (компактний, стандартний, просторий) та кількість колонок (від 1 до 4) під розмір екрана вашого пристрою.
- **Адаптивний макет**: Автоматичний перехід між мобільним та десктопним інтерфейсами.

### ⚙️ Проксі-движок (ClashMeta / mihomo)
- **Високопродуктивне ядро**: Під капотом використовується потужне ядро `mihomo` (написане на Go).
- **Режими маршрутизації**: Підтримка режимів «Правила» (Rule), «Глобальний» (Global) та «Прямий» (Direct).
- **Статистика в реальному часі**: Динамічні графіки швидкості мережі (завантаження/віддача) та облік загального трафіку.
- **Керування групами проксі**: Сортування вузлів проксі за затримкою, назвою або конфігурацією за замовчуванням.
- **Автозакриття з'єднань**: Автоматичний розрив активних підключень при зміні проксі-вузла.
- **Ланцюжки проксі (режим ланцюжків)**: Створення багатовузлових ланцюжків (вхід → вихід), які пропускають трафік через кілька проксі послідовно за допомогою `dialer-proxy`. Вмикайте **режим ланцюжків** прямо зі сторінки «Проксі», щоб спрямувати весь трафік через обраний ланцюжок, зберігаючи правила підписки; при вимкненні (або видаленні всіх ланцюжків) автоматично повертається звичайний режим.

### 🛡️ Мережеві та системні налаштування
- **Системний проксі**: Швидке ввімкнення та вимкнення системних налаштувань проксі для Windows та macOS.
- **Режим TUN**: Маршрутизація всього мережевого трафіку системи через віртуальний мережевий адаптер (потрібні права адміністратора/root).
- **Роздільне тунелювання (Access Control)**: (Android) Налаштування чорних та білих списків додатків, фільтрація системних додатків.
- **Перевизначення DNS**: Налаштування серверів імен (nameservers), DNS за замовчуванням, fallback-серверів, проксі-серверів DNS, а також пріоритет використання DOH (DNS-over-HTTPS) із підтримкою HTTP/3.
- **Доступ із локальної мережі (AllowLan)**: Дозвіл іншим пристроям у локальній мережі підключатися через ваш проксі.
- **Обхід доменів (Bypass)**: Налаштування списків доменів, які мають спрямовуватися в обхід системного проксі.
- **Підтримка IPv6**: Повне перемикання маршрутизації вхідного та вихідного IPv6-трафіку.
- **Режим низької пам'яті**: Ввімкнення режиму низького споживання пам'яті для баз даних Geo (Geo Low Memory Mode).

### ☁️ Синхронізація, шифрування та функції провайдерів
- **Синхронізація через WebDAV**: Резервне копіювання та відновлення ваших профілів та налаштувань у хмарі.
- **Дешифрування захищених підписок**: Підтримка розшифрування зашифрованих підписок у форматі base64 (AES-256-CBC, ключ виводиться через PBKDF2) з використанням користувацьких заголовків `meowclash-password` та `meowclash-password-iterations`.
- **Обробка кастомних заголовків відповідей**:
  - `announce`: Відображення оголошень та важливих повідомлень всередині додатку.
  - `support-url`: Прямі посилання на техпідтримку в деталях профілю.
  - `profile-update-interval`: Задання інтервалу автооновлення підписки.
  - `x-hwid-limit`: Перевірка лімітів пристроїв із виведенням спеціального діалогового вікна реєстрації HWID.

### 💻 Десктопна інтеграція та утиліти
- **Згортання в системний трей**: Робота додатку у фоновому режимі після закриття головного вікна.
- **Параметри автозапуску**: Налаштування запуску разом із системою (Auto-launch) та прихованого запуску в фоні (Silent-launch).
- **Глобальні гарячі клавіші**: Призначення клавіатурних сполучень для показу/приховування вікна, запуску/зупинки VPN, перемикання режимів та керування TUN-режимом.
- **Розблокування UWP-додатків (Loopback)**: (Windows) Утиліта для швидкого ввімкнення мережевого доступу до локального хоста для додатків із Windows Store (UWP).
- **Надіслати на ТВ (TV Sync)**: Зручна передача профілів конфігурації на Android TV / Smart TV через сканування QR-коду або локальну мережу.
- **Інструменти діагностики**: Перегляд поточних запитів у реальному часі, керування списком активних з'єднань, зручне виведення логів з експортом у файл та скидання всіх налаштувань додатку.

---

## 🔧 Системні вимоги для ОС

### Linux
Перед запуском додатку обов'язково встановіть необхідні системні бібліотеки:
```bash
# Ubuntu / Debian
sudo apt-get install libayatana-appindicator3-dev libkeybinder-3.0-dev

# Arch Linux
sudo pacman -S libayatana-appindicator libkeybinder3

# Fedora
sudo dnf install libayatana-appindicator-gtk3-devel keybinder3-devel

# Alpine
sudo apk add libayatana-appindicator-dev keybinder3-dev
```

### NixOS (Flake)

Якщо ви використовуєте NixOS, ви можете скористатися наданим Flake та модулем NixOS.

Додайте репозиторій у вхідні дані (inputs) вашого `flake.nix`:
```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    meowclash.url = "github:Loischsiy/MeowClash";
  };

  outputs = { self, nixpkgs, meowclash, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      modules = [
        # Імпорт модуля
        meowclash.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

Потім налаштуйте програму у `configuration.nix`:
```nix
{
  # Увімкнення програми та (опціонально) режиму TUN (налаштування обгортки з cap_net_admin для ядра)
  programs.meowclash = {
    enable = true;
    tunMode.enable = true; # Необхідно для роботи режиму TUN без прав root
  };
}
```

### Android
Підтримується керування через сторонні інструменти автоматизації (наприклад, Tasker) за допомогою Intents (дій):
- **Запуск VPN**: `com.meowclash.app.action.START`
- **Зупинка VPN**: `com.meowclash.app.action.STOP`
- **Перемикання стану**: `com.meowclash.app.action.TOGGLE`

---

## 📥 Завантажити

Завантажте останні скомпільовані версії на сторінках релізів:

<a href="https://github.com/Loischsiy/MeowClash/releases">
  <img alt="Get it on GitHub" src="snapshots/get-it-on-github.svg" width="220px"/>
</a>
<a href="https://gitlab.com/Loischsiy/MeowClash/-/releases">
  <img alt="Get it on GitLab" src="https://img.shields.io/badge/Get_it_on-GitLab-FC6D26?logo=gitlab&logoColor=white" width="220px"/>
</a>
<a href="https://gitverse.ru/Loischsiy/MeowClash/releases">
  <img alt="Get it on GitVerse" src="https://img.shields.io/badge/Get_it_on-GitVerse-245BDB" width="220px"/>
</a>

---

## 🛠️ Збірка з вихідного коду

### Вимоги
1. Установіть **Flutter SDK (3.35.7)**.
2. Установіть **Golang (1.24.0)** (потрібно для збірки проксі-ядра).
3. При збірці для Windows: Установіть **Rust** (актуальна версія, для допоміжної служби Helper), **GCC** та **Inno Setup**.
4. При збірці для Android: Установіть **Android SDK** та **NDK**, а також задайте змінну оточення `ANDROID_NDK`.

### Інструкція зі збірки
1. **Клонуйте репозиторій разом із підмодулями:**
   ```bash
   git clone https://github.com/Loischsiy/MeowClash.git
   cd MeowClash
   git submodule update --init --recursive
   ```

2. **Завантажте залежності Flutter:**
   ```bash
   flutter pub get
   ```

3. **Згенеруйте файли моделей, провайдерів та локалізації:**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   flutter pub run intl_utils:generate
   ```

4. **Зберіть додаток за допомогою скрипта збірки:**

   - **Android:**
     ```bash
     dart setup.dart android
     ```
   - **Windows:**
     ```bash
     dart setup.dart windows --arch <arm64 | amd64>
     ```
   - **Linux:**
     ```bash
     dart setup.dart linux --arch <arm64 | amd64>
     ```
   - **macOS:**
     ```bash
     dart setup.dart macos --arch <arm64 | amd64>
     ```

---

## 🔄 Особливості форка та важливі зміни

### Рефакторинг системи перевизначення провайдерів (Травень 2026 р.)
Користувацька система перевизначення заголовків `meowclash-*` була повністю вилучена. Раніше ці налаштування зчитувалися тільки з HTTP-заголовків відповіді сервера підписки (а не з тіла YAML самого профілю), через що локальне перевизначення в YAML-файлах профілів не працювало.

- **Збережено та повністю функціонує**:
  - **Дешифрування підписок**: Заголовки `meowclash-password` та `meowclash-password-iterations` для нативного розшифрування захищеного base64-вмісту підписки.
  - **Службові заголовки відповідей**: `announce` (інформаційний банер), `support-url`, `profile-update-interval` (частота автооновлення профілю) та `x-hwid-limit` (вікно ліміту прив'язаних пристроїв).
- **Вилучені параметри (тепер повністю налаштовуються користувачем вручну)**:
  `meowclash-settings`, `meowclash-hex`, `meowclash-widgets`, `meowclash-view`, `meowclash-custom`, `meowclash-androidsecure`, `meowclash-servicename`, `meowclash-servicelogo`, `meowclash-serverinfo`, `meowclash-globalmode`, `meowclash-denywidgets`, `meowclash-background`. Тепер налаштування автозапуску, фонового оформлення та тем завжди під повним контролем користувача.

---

## 🤝 Подяки

- [FlClashX](https://github.com/pluralplay/FlClashX) — оригінальний проєкт, на основі якого створено цей додаток.
- [mihomo (ClashMeta)](https://github.com/MetaCubeX/mihomo) — високопродуктивний проксі-движок, що використовується як ядро.
- Усім учасникам, які допомагали з тестуванням та локалізацією додатку.

## 📄 Ліцензія
Вихідний код MeowClash поширюється на умовах вільної ліцензії [GPL-3.0 License](LICENSE).
