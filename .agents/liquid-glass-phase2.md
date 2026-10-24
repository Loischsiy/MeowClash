# Liquid Glass — фаза 2, экран «Прокси» (временный трекер)

Временный файл: удаляется в последнем коммите PR (как трекер фазы 1). Если работа прервалась —
продолжать с первого невыполненного пункта в «Шагах».

- Ветка: `feat/liquid-glass-proxies` от `main` @ `4f378b9`
  (план согласовывался на `34f5f86`; после него в main только `feat(service)` / `feat(win/tun)`, экран прокси не тронут).
- Платформы: стекло только macOS и iOS; Android/Linux/Windows — пиксель-в-пиксель как в main.

## Согласованные решения («ок» пользователя)

1. Режим «список»: заголовок раскрытой группы закрепляется одной стеклянной полосой при прокрутке (только Darwin).
2. Режим «вкладки»: сетка прокручивается под стеклянной полосой групп.
3. Листы экрана (настройки, провайдеры, выбор группы, иконки) — отдельным PR следом, не здесь.
4. Задержка — цветная «пилюля».
5. Кнопка теста задержки — стеклянный круг.

## Обёртки (lib/widgets/adaptive/)

| Обёртка | Стекло | Material (старый код без изменений) |
|---|---|---|
| AdaptiveCard | полупрозрачная карточка без блюра, выбранная — акцент + галочка, hover на macOS | CommonCard |
| AdaptiveDelayBadge | пилюля; тест — CupertinoActivityIndicator; не проверено — ⚡ | текст + спиннер |
| AdaptiveGroupHeader | заголовок группы в стиле iOS, шеврон | ProxyGroupCard |
| AdaptiveGroupSelector | одна стеклянная полоса, выбранная — капсула | TabBar |
| AdaptiveFloatingButton | стеклянный круг, без анимации при Reduce Motion | кнопка Material |
| AdaptiveEmptyState, AdaptiveActivityIndicator | в стиле Apple | NullStatus, спиннер Material |

Блюр: только закреплённая полоса (группы во вкладках / закреплённый заголовок в списке) и кнопка теста.
На карточках и строках — ноль. Число BackdropFilter не зависит от числа прокси.

## Шаги

Отмечать `[x]` сразу после выполнения; в «Журнал» — короткая строка с коммитом/результатом.

- [x] 0. Ветка создана, трекер заведён
- [x] 1. Изучить код экрана (tab.dart, list.dart, card.dart, common.dart, proxies.dart), CommonCard, NullStatus, существующие тесты/голдены
- [x] 2. Проверить, что тулчейн работает из среды агента (flutter test, analyze) — зафиксировать ограничения
- [x] 3. Эталонные голдены Material экрана «Прокси» на чистом коде (оба режима, типы карточек, пустое состояние) → `test/goldens/`, отдельный коммит
- [x] 4. Токены в glass_tokens.dart (карточка, пилюля, полоса групп, круглая кнопка, пустое состояние)
- [x] 5. AdaptiveCard + AdaptiveDelayBadge, подключить в card.dart
- [x] 6. AdaptiveGroupHeader, подключить в list.dart; закреплённый стеклянный заголовок (решение 1)
- [x] 7. AdaptiveGroupSelector, подключить в tab.dart; сетка под полосой (решение 2)
- [x] 8. AdaptiveFloatingButton (кнопка теста), AdaptiveEmptyState, AdaptiveActivityIndicator
- [x] 9. Тесты стекла: число слоёв блюра на 100+ прокси, фолбэки (Reduce Transparency/Motion, kill switch), переключение платформ
- [x] 10. Голдены Material совпадают; analyze без новых замечаний; flutter test зелёный; proxy_list_performance_test проходит
- [x] 10a. Фикс переполнения заголовка группы (эмодзи в подзаголовке): тест, analyze, коммит
- [ ] 11. iOS-симулятор: скриншоты светлая/тёмная — ЗАБЛОКИРОВАНО для агента (`simctl boot` падает), делает пользователь
- [x] 12. Обновить .agents/adaptive-ui.md (новые примитивы, правила экрана)
- [x] 14. Доводка под Apple (запрос пользователя 2026-10-24, «стекла мало, не похоже на Apple»), в ЭТОМ PR:
  - [x] 14.0 (сессия 4) Код 14.1 и тесты 14.2 найдены незакоммиченными: glass_text_styles.dart, токены типошкалы, Measure.heightOf, proxyCardLineHeights, правки card/common/list, adaptive_card/delay_badge/group_header, 5 новых тестов
  - [x] 14.1a Ревью диффа: Material-ветки не задеты (особенно `ProxyGroupCard` в list.dart, `getItemHeight`)
  - [x] 14.1b Тесты стекла + Material-голдены + perf-тест + analyze `lib test` → коммит `feat(ui): Apple type scale and quiet selection for glass proxy cards`
  - [x] 14.2 Прокрутка под закреплёнными полосами (п.4): прогнать тесты «cards scroll under…» / «grid scrolls under…» во всех режимах, доделать недостающее → коммит `test(ui): …` / `feat(ui): …`
  - [x] 14.3 Полный `flutter test`, обновить adaptive-ui.md (типошкала, выделение) и черновик PR → коммит `docs(agents): …`
- [x] 13a. Черновик текста PR — `.agent/pr-liquid-glass-proxies.md` (в .gitignore), TODO на скриншоты/замеры/фолбэки на устройстве
- [ ] 13b. ЖДЁМ ПОЛЬЗОВАТЕЛЯ: скриншоты macOS + iOS (светлая/тёмная), замер прокрутки 100+ прокси в DevTools (main vs ветка), проверка Reduce Transparency/Motion на устройствах → вписать в черновик
- [ ] 13c. Удалить этот трекер последним коммитом (`chore(agents): drop the phase 2 proxies tracker`), пуш ветки и PR — пользователь (git push из среды заблокирован)

## Журнал

- 2026-10-24: ветка `feat/liquid-glass-proxies` от `4f378b9`, трекер создан.
- 2026-10-24: код изучен; тулчейн работает через `.agent/flutterw`; база: test 241 passed / 1 skipped, analyze `lib test` 0 errors.
- 2026-10-24: `test/material_proxies_golden_test.dart` + 20 эталонов `test/goldens/material_proxies_*.png` — коммит `test(ui): Material baseline goldens for the proxies screen`.
- 2026-10-24 (сессия 2): найдено незакоммиченное: токены, adaptive_card/delay_badge/floating_button/group_header/group_selector/status, glass_icon_button, правки card/list/tab.dart. Начата проверка.
- 2026-10-24 (сессия 2): Material-голдены прокси/хрома совпадают, perf-тест проходит, analyze — 0 ошибок, новое замечание только omit_local_variable_types в adaptive_card.dart (исправлено). Material-кнопка теста больше не делает лишний setState.
- 2026-10-24 (сессия 2): `test/adaptive_proxies_glass_test.dart` — 14 тестов (150 прокси на группу: список 0 блюров в покое / 1 после прокрутки, вкладки ровно 1; Reduce Transparency, kill switch, Reduce Motion, Material-ветки) — зелёные. Коммиты шагов 4–9: см. git log.
- 2026-10-24 (сессия 2): шаг 10 — `flutter test` 275 passed / 1 skipped; analyze `lib test` — 0 ошибок, 0 новых замечаний относительно базы. Шаг 12 — раздел «Inner screens (phase 2)» в `.agents/adaptive-ui.md`.
- 2026-10-24 (сессия 2): первая iOS-сборка упала — фаза Xcode «Flutter Build» разворачивала симлинк shadow `bin/flutter` до реального SDK и писала в его `bin/cache`. Исправлено в `.agent/flutter-shadow`: `bin/flutter`, `bin/dart` — копии, `bin/internal` — папка симлинков, `engine.stamp`/`engine.realm` — копии.
- 2026-10-24 (сессия 2): `flutter build ios --simulator --debug` собирается, но `simctl boot` из среды агента падает (runtime iOS 27.0 недоступен) — скриншоты с симулятора делает пользователь.
- 2026-10-24 (сессия 2): баг — `cupertino_icons` нет в pubspec, `CupertinoIcons.*` рисовались бы пустыми квадратами. Заменены на `Icons.*_rounded` во всех примитивах и экране; правило добавлено в `.agents/adaptive-ui.md`.
- 2026-10-24 (сессия 3): найдено незакоммиченное — фикс переполнения AdaptiveGroupHeader (подзаголовок с эмодзи выше замера → `Flexible`) + тест `group header absorbs a subtitle taller than measured`. Проверяю и коммичу (шаг 10a).
- 2026-10-24 (сессия 3): тест падал с LateInitializationError (`globalState.measure` читался до `host()`), перенесён в `Builder`. Без фикса красный (RenderFlex overflowed by 6 px), с фиксом зелёный. `flutter test` 276 passed / 1 skipped; analyze `lib test` — 0 ошибок, 0 новых замечаний. Коммит `fix(ui): group header absorbs emoji-tall subtitles`.
- 2026-10-24 (сессия 3): черновик PR в `.agent/pr-liquid-glass-proxies.md`. Код экрана готов; остались только шаги 11/13b/13c со стороны пользователя.
- 2026-10-24 (сессия 3): ПОБОЧНЫЙ БАГ фазы 1 (не этот PR): на iOS «Edit/Add profile» серые. `showExtend` на mobile пушит `SheetType.page` непрозрачным маршрутом, а `AdaptiveSheetScaffold` рисует его стеклом (прозрачный фон + GlassSurface) — тонировка поверх пустоты. Тест `adaptive_sheet_test.dart` покрывал только sideSheet/bottomSheet. Фикс в отдельной ветке `fix/glass-sheet-pages` от main (см. «Побочные задачи»).
- 2026-10-24 (сессия 4): ревью незакоммиченного 14.1 — Material-пути (`_buildMaterial`, `getItemHeight`, Material-бейдж) не тронуты, новые стили только под `useGlass`. Тесты стекла + Material-голдены + perf: 43 passed. Тесты прокрутки под полосами (список и вкладки) расширены с одной платформы на macOS+iOS — зелёные; доделывать в коде п.4 нечего (`AdaptiveGroupSelector.floats` = вся Darwin). Новое замечание analyze `prefer_const_constructors` в тесте исправлено. Запущен полный `flutter test` + analyze.
- 2026-10-24 (сессия 4): `flutter test` 284 passed / 1 skipped; analyze `lib test` — 0 ошибок, 0 новых замечаний. Коммит `9a47e76 feat(ui): Apple type scale and quiet selection for glass proxy cards` (код 14.1 + тесты 14.1/14.2). 14.2: код не понадобился, только тесты. adaptive-ui.md (типошкала, выделение) и черновик PR обновлены. Шаг 14 закрыт; дальше — побочная задача `feat/darwin-system-font`.

## Побочные задачи (отдельные ветки)

Порядок после шага 14 (согласовано 2026-10-24): сначала шрифт, потом панель. Оба — хром фазы 1, отдельные ветки от main.

- [ ] `feat/darwin-system-font` (п.1): на macOS/iOS не задавать NotoSans → системный San Francisco; Android/Win/Linux — NotoSans как было (голдены). Учесть настройку шрифта в views/theme.dart.
- [ ] `feat/glass-toolbar` (п.2): панель как в macOS 26 — компактный заголовок, кнопки в стеклянных капсулах, контент прокручивается под панелью. Перед кодом — короткий план пользователю (задевает все экраны).

- [x] `fix/glass-sheet-pages` от main: для `SheetType.page` без стекла, непрозрачный фон темы + тест, analyze, flutter test, коммит. Готово: `b75e81b fix(ui): opaque Darwin page for full-screen sheets` (тест без фикса красный, с фиксом зелёный; `flutter test` на ветке зелёный; Material-голдены хрома совпадают; новых замечаний analyze нет). Правило добавлено в `.agents/adaptive-ui.md` на той же ветке.
- [ ] Пользователь: пуш `fix/glass-sheet-pages` и отдельный PR (маленький, можно влить до PR «Прокси»). После вливания — rebase `feat/liquid-glass-proxies` на main.

## Заметки / ограничения среды

- Голый `flutter` из среды агента не пишет в кеш SDK. Обёртка `.agent/flutterw` (в .gitignore): shadow FLUTTER_ROOT
  `.agent/flutter-shadow`, HOME=`.agent/home`, реальный PUB_CACHE. Пример: `.agent/flutterw test test/material_proxies_golden_test.dart`.
- Analyze только `lib test`: в корне лежит посторонняя `FlClashX-0.5.0-dev/` (исключена через .git/info/exclude).
  `.agent/flutterw analyze --no-fatal-infos --no-fatal-warnings lib test`; база сохранена в `.agent/baseline-analyze.txt`.
- Старые замечания в lib/views/proxies/* (directives_ordering, cascade_invocations, unawaited_futures tab.dart) — не наши.
- Тест perf ищет `IconButton` внутри `ProxyGroupCard` и `FloatingActionButton` — Material-ветки не менять.
- В голден-тесте группы должны быть `hidden: false`, иначе экран пустой.
