# Liquid Glass для macOS и iOS — рабочий план (этап 1: «хром»)

Временный файл-трекер. Отмечай `[x]` сразу после выполнения шага и коммить вместе с кодом шага.
Когда этап 1 закончен — перенеси устойчивые правила в `.agents/adaptive-ui.md`, а этот файл удали.

Исходное ТЗ: `liquid-glass-for-meowclash-agent-prompt.md` (передано в чате). Референс техник:
`FlClashX-0.5.0-dev/` (локальная копия, в `.git/info/exclude`, **не коммитить и не копировать визуал**).

## Как продолжить с любого места

1. `git switch feat/liquid-glass` (рабочая ветка всего этапа; в `main` вливается целиком, когда план выполнен)
2. Найди первый неотмеченный шаг ниже и прочитай его «Файлы» и «Готово, когда».
3. Проверки (writable-копия SDK, т.к. системный кэш Flutter недоступен на запись из песочницы агента):
   ```bash
   sh .cache_flutter/flutterw.sh analyze --no-fatal-infos --no-fatal-warnings lib test
   sh .cache_flutter/flutterw.sh test
   ```
   `.cache_flutter/` (игнорируется правилом `.cache*`) — APFS-клон `~/Documents/GitHub/flutter` (3.44.1) + `~/.pub-cache`, в `.gitignore`.
   Если папки нет: `mkdir .cache_flutter && cp -cR ~/Documents/GitHub/flutter .cache_flutter/flutter && cp -cR ~/.pub-cache .cache_flutter/pub-cache`
   и скрипт `flutterw.sh` (экспортирует `PUB_CACHE`, `HOME` внутрь `.cache_flutter`).
   Голый `flutter analyze` по корню цепляет `FlClashX-0.5.0-dev/` (56k диагностик) — анализируй `lib test`.
4. В `main` лежат чужие незакоммиченные правки (версия ядра, README, CHANGELOG, `navigation_page_view.dart`,
   `pubspec.yaml`, …). **Не трогать и не стейджить** — коммитить только свои файлы явными путями
   (`git add <paths>`, не `checkpoint` без `paths`).

## Решения (согласованы с владельцем)

| Вопрос | Решение |
|---|---|
| macOS: popover у строки меню или окно | **Обычное окно**, как на Windows/Linux. Иконка в строке меню остаётся: клик показывает/прячет окно, правый клик — меню. |
| Акцентный цвет на Darwin | **Системный.** macOS: `NSColor.controlAccentColor` (если выбран «Multicolor» — фирменный цвет MeowClash). iOS: у сторонних приложений нет системного акцента → `CupertinoColors.systemBlue` (динамический). |
| Шейдер преломления как в FlClashX | Не в первом проходе. Сначала размытие + тонировка + блик (шаги 1–6), шейдер — отдельный шаг 8 поверх, с фолбэком. На macOS фон окна — **нативное** стекло AppKit, шейдер там не нужен. |
| Контекстные меню на macOS | По умолчанию **системное `NSMenu`** (шаг 6). Если владелец захочет одинаковое стеклянное меню на Flutter — поменять только `AdaptiveContextMenu`. |
| Android / Windows / Linux | Пиксель-в-пиксель как сейчас; доказывается golden-тестами (шаг 1). |

## Ограничения (из ТЗ, жёсткие)

- Размытие только у: боковой панели, тулбара/заголовка, таб-бара, листов/модалок, контекстных меню.
  Никогда — вложенное размытие, размытие на скроллящемся контенте и элементах списков.
- Все числа стекла — только в `lib/widgets/adaptive/glass_tokens.dart`.
- Reduce Transparency → непрозрачные поверхности; Reduce Motion → без анимаций стекла;
  глобальный флаг отключения размытия для старых Mac.
- Не трогать ядро/mihomo, провайдеры Riverpod, модели. Коммиты `feat(ui): ...` / `feat(macos): ...`.

---

## Шаги

### 0. Подготовка
- [x] Ветка `feat/liquid-glass` от `main` (коммит фундамента уже попал в `main` как `cc7c6d4` — он визуально ничего не меняет).
- [x] `FlClashX-0.5.0-dev/` в `.git/info/exclude`.
- [x] Writable SDK в `.cache_flutter/` + `flutterw.sh`; `pub get --offline` проходит.
- [x] `.cache_flutter/` в `.gitignore`.
- [x] Базовые прогоны записаны: `.agent/analyze_lib_baseline.txt`, `.agent/test_baseline.txt`
      (`.agent/` игнорируется — это только локальная точка отсчёта).
      Точка отсчёта на 2026-10-23: `analyze lib test` — 530 issues, **0 errors**; `flutter test` — 181 passed, 1 skipped.

### 1. Фундамент адаптивного слоя — PR `feat(ui): add adaptive glass foundation`
Визуально ничего не меняет ни на одной платформе.
- [x] `lib/widgets/adaptive/glass_tokens.dart` — sigma размытия, прозрачности light/dark, блик, радиусы, тени.
- [x] `lib/widgets/adaptive/adaptive_platform.dart` — `useGlass` (только macOS/iOS), `debugOverride`
      для тестов, `GlassFlags.backdropBlurEnabled` / `--dart-define=MEOWCLASH_GLASS_BLUR=false` (деградация для старых Mac).
- [x] `lib/widgets/adaptive/glass_accessibility.dart` — `GlassAccessibility` (`reduceTransparency`,
      `reduceMotion`, `accentColor`) + `GlassAccessibilityScope`; канал `meowclash/glass_accessibility`
      (метод `snapshot`, события `changed`). Reduce Motion берётся из `MediaQuery.disableAnimations`
      + нативного значения; Increase Contrast (натив + `MediaQuery.highContrast`) тоже делает стекло непрозрачным.
- [x] `lib/widgets/adaptive/glass_surface.dart` — единственный примитив с `BackdropFilter`
      (тень только снаружи → clip-суперэллипс → один `BackdropFilter.grouped` → тонировка → блик по краю);
      режим `GlassBackdrop.native` без фильтра (поверх нативного стекла AppKit); без `Opacity`; непрозрачный фолбэк.
- [x] `lib/widgets/adaptive/adaptive.dart` — barrel.
- [x] Нативная часть канала: `macos/Runner/AppDelegate.swift`
      (`NSWorkspace.accessibilityDisplayShouldReduceTransparency/ReduceMotion`,
      `accessibilityDisplayOptionsDidChangeNotification`, `NSColor.controlAccentColor`,
      `NSColor.systemColorsDidChangeNotification`) и `ios/Runner/AppDelegate.swift`
      (`UIAccessibility.isReduceTransparencyEnabled/isReduceMotionEnabled` + нотификации).
      Новые Swift-файлы не добавляем (иначе правка `project.pbxproj`) — код в существующих AppDelegate.
- [x] `test/adaptive_glass_test.dart` — `useGlass` false на android/linux/windows; фолбэк при
      reduceTransparency; отсутствие канала (`MissingPluginException`) не падает.
- [x] `test/adaptive_chrome_golden_test.dart` + `test/goldens/` — эталоны текущих нижней панели вкладок
      (android) и боковой `NavigationRail` (windows), light/dark, сняты **до** шагов 3–6.
- [ ] Дополнить goldens заголовком (`CommonScaffold` app bar) и нижним листом (`showSheet`) —
      сделать **до** шагов 4 и 5 соответственно.
- Готово, когда: analyze `lib test` без новых диагностик, все тесты зелёные, goldens закоммичены.

### 2. macOS: обычное окно вместо popover — PR `feat(macos): run as a regular window`
- [ ] `macos/Runner/Info.plist` — убрать `LSUIElement` (иконка в Dock, системное меню приложения).
- [ ] `macos/Runner/AppDelegate.swift` — убрать `NSPopover`/`PopoverContainerViewController`;
      не закрывать главное окно на старте; `applicationShouldHandleReopen` → показать окно;
      канал `status_bar_icon`: `isVisible` = видимость окна, `visibilityChanged` из
      `NSWindowDelegate` (miniaturize/occlusion/close→hide).
- [ ] `macos/Runner/StatusBarController.swift` — левый клик: показать/спрятать окно
      (`NSApp.activate` + `makeKeyAndOrderFront`); правый клик: меню «Показать MeowClash», «Выход».
- [ ] `macos/Runner/MainFlutterWindow.swift` — `fullSizeContentView`, `titlebarAppearsTransparent`,
      `titleVisibility = .hidden`, unified `NSToolbar` (светофор сдвигается как в нативных приложениях),
      минимальный размер как в `Window.init`.
- [ ] `lib/common/window.dart` — macOS через `windowManager` (размер/позиция/`setPreventClose`),
      как на других десктопах; `show/hide/isVisible` перестают быть no-op.
- [ ] `lib/controller.dart` — убрать macOS-исключения вокруг `window?.show()/hide()`, `updateVisible`.
- [ ] `lib/manager/window_manager.dart` — подписка `windowManager.addListener` и на macOS;
      `WindowHeaderContainer` на macOS даёт drag-область высотой `kHeaderHeight` без своих кнопок.
- [ ] `lib/application.dart` — убрать `FittedBox` 500×800 для macOS.
- [ ] `lib/pages/home.dart` — логотип в боковой панели на macOS (или оставить скрытым под светофором — решить по виду).
- [ ] `test/statusbar_visibility_test.dart` — обновить под окно (сейчас моделирует popover).
- [ ] Документация: `.agents/platform-gotchas.md` / `.agents/runtime-contracts.md` (macOS теперь окно), 6 README, если там описан popover.
- Готово, когда: окно открывается/прячется из иконки и Dock, Cmd+Q/Cmd+W/Cmd+H работают,
  `silentLaunch` прячет окно, UI на ширине >600 переключается в режим с боковой панелью.

### 3. Тема для Darwin — PR `feat(ui): darwin glass theme`
- [ ] `lib/widgets/adaptive/glass_theme.dart` — `buildGlassTheme(ThemeData base, GlassAccessibility a11y)`:
      тот же `ColorScheme`, но seed = системный акцент; прозрачные `scaffoldBackgroundColor`
      для хрома, `NavigationBarTheme`/`NavigationRailTheme`/`BottomSheetTheme`/`PopupMenuTheme` под стекло.
- [ ] `lib/application.dart` — `theme`/`darkTheme` через `useGlass ? buildGlassTheme(...) : <как сейчас>`,
      обёртка `GlassAccessibilityScope` над `MaterialApp.builder`. Ветка не-Darwin — байт-в-байт прежняя.

### 4. Навигационный хром — PR `feat(ui): glass navigation chrome on Darwin`
- [ ] `AdaptiveTabBar` (`lib/widgets/adaptive/adaptive_tab_bar.dart`) — iOS/mobile: плавающая
      стеклянная капсула над safe area, контент прокручивается под ней (`extendBody`).
      Материал-ветка = нынешний `NavigationBar` из `home.dart`, перенесённый без изменений.
- [ ] `AdaptiveSidebar` (`adaptive_sidebar.dart`) — macOS: прозрачный фон поверх нативного
      `NSVisualEffectView(.sidebar)` (шаг 7), выделение — акцентная капсула. Материал-ветка = нынешний `NavigationRail`.
- [ ] `AdaptiveAppBar` (`adaptive_app_bar.dart`) — стеклянный тулбар; на macOS учитывает светофор и drag-область.
- [ ] `AdaptiveScaffold` (`adaptive_scaffold.dart`) — тонкая обёртка над `CommonScaffold`.
- [ ] `lib/pages/home.dart`, `lib/widgets/scaffold.dart` — переключить на обёртки.
- [ ] Goldens Android/Linux/Windows из шага 1 не изменились.

### 5. Листы — PR `feat(ui): glass sheets on Darwin`
- [ ] `AdaptiveSheet` / правка `lib/widgets/sheet.dart` и `side_sheet.dart`: стеклянная кромка
      и фон листа; размытие только на самом листе (сейчас `BackdropFilter` оборачивает весь лист —
      на Darwin заменить на один `GlassSurface`, на остальных оставить как есть).

### 6. Контекстные меню — PR `feat(ui): native context menus on macOS`
- [ ] `AdaptiveContextMenu` (`adaptive_context_menu.dart`), подключить в `lib/widgets/popup.dart`
      (`CommonPopupMenu`).
- [ ] macOS: канал `meowclash/context_menu` → `NSMenu.popUp(positioning:at:in:)` в `AppDelegate.swift`
      (текст, SF Symbol, disabled, danger-пункт; возвращает индекс).
- [ ] iOS: стеклянное Flutter-меню на `GlassSurface`.
- [ ] Остальные платформы — нынешний `CommonPopupMenu`.

### 7. Нативное стекло окна macOS — PR `feat(macos): native glass window backdrop`
- [ ] `MainFlutterWindow.swift` — `FlutterViewController.backgroundColor = .clear`, под ним
      `NSVisualEffectView` (`.sidebar`, `.behindWindow`); на macOS 26 — `NSGlassEffectView`
      под `#if compiler(>=6.2)` + `if #available(macOS 26, *)` (deployment target 11.0).
- [ ] Reduce Transparency на macOS → AppKit сам делает материал непрозрачным; проверить, что Flutter-хром тоже.
- [ ] Иконка строки меню — шаблонный SF Symbol (уже есть), стиль меню совпадает.

### 8. (Опционально) Преломление как у Liquid Glass — PR `feat(ui): refraction shader for glass chrome`
- [ ] Лёгкий фрагментный шейдер (`shaders/glass_refraction.frag`, ассет в `pubspec.yaml`) только для
      таб-бара iOS и капсулы выделения; через `ImageFilter.shader` при `ImageFilter.isShaderFilterSupported`,
      иначе — размытие из шагов 1–6. Без перехвата слоёв как в FlClashX.

### 9. Проверка и отчёт
- [ ] (По желанию владельца) dev-сборка под iOS Simulator только для UI: срез `iphonesimulator arm64`
      в `MeowCore.xcframework` или заглушка ядра; VPN в симуляторе не заработает. Релизная сборка
      по-прежнему отклоняет симулятор. Быстрая альтернатива без симулятора: запуск macOS-версии
      с `debugDefaultTargetPlatformOverride = TargetPlatform.iOS` показывает iOS-хром в окне Mac.
      Замеры производительности в симуляторе непоказательны (GPU и драйвер Mac) — цифры для PR с iPhone.
- [ ] macOS и iOS, светлая/тёмная тема — скриншоты в описание PR.
- [ ] Reduce Transparency / Reduce Motion — проверено на обеих Darwin-платформах.
- [ ] DevTools timeline до/после: прокрутка списка прокси под размытой боковой панелью (macOS),
      таб-бар (iOS). Цифры (avg/p90/p99 build+raster ms, jank frames) — в описание PR, не в репозиторий.
- [ ] `flutter analyze` (lib test) без новых диагностик, `flutter test` зелёный.
- [ ] Перенести правила в `.agents/adaptive-ui.md`, строка в таблицу `AGENTS.md`,
      обновить `.agents/project-structure.md`; удалить этот файл.

## Журнал

- 2026-10-23: план создан, шаг 0 выполнен.
- 2026-10-23: шаг 1 — фундамент (`lib/widgets/adaptive/`), нативный канал в обоих AppDelegate
  (только `swiftc -parse`, сборка Xcode ещё не прогонялась), 18 новых тестов + 4 golden. Без визуальных изменений:
  ничего из `adaptive/` пока не подключено к экранам. Осталось: goldens заголовка и листа.
- 2026-10-23: фундамент попал в `main` (`cc7c6d4`), план и заметка в `.agents/testing.md` при этом потерялись —
  восстановлены в новой ветке `feat/liquid-glass`. Перепроверено на ветке: `flutter test` 199 passed / 1 skipped,
  `analyze lib test` 530 issues, 0 errors (как до работ).
- 2026-10-23: **блокер нативных шагов 2, 6, 7 и проверки на iOS:** на машине нет Xcode (активны только
  Command Line Tools), поэтому `flutter build macos`/iOS и iOS Simulator недоступны. Нужно поставить Xcode
  из App Store, затем `xcode-select -s /Applications/Xcode.app` и `xcodebuild -runFirstLaunch` (от администратора).
  Для симулятора iOS: `ios/build_core.sh` собирает ядро только под `iphoneos arm64`, а VPN (PacketTunnel)
  в симуляторе не работает — для проверки UI нужен отдельный dev-путь (см. шаг 9).
