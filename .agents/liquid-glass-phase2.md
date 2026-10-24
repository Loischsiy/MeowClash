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

## Заметки / ограничения среды

- Голый `flutter` из среды агента не пишет в кеш SDK. Обёртка `.agent/flutterw` (в .gitignore): shadow FLUTTER_ROOT
  `.agent/flutter-shadow`, HOME=`.agent/home`, реальный PUB_CACHE. Пример: `.agent/flutterw test test/material_proxies_golden_test.dart`.
- Analyze только `lib test`: в корне лежит посторонняя `FlClashX-0.5.0-dev/` (исключена через .git/info/exclude).
  `.agent/flutterw analyze --no-fatal-infos --no-fatal-warnings lib test`; база сохранена в `.agent/baseline-analyze.txt`.
- Старые замечания в lib/views/proxies/* (directives_ordering, cascade_invocations, unawaited_futures tab.dart) — не наши.
- Тест perf ищет `IconButton` внутри `ProxyGroupCard` и `FloatingActionButton` — Material-ветки не менять.
- В голден-тесте группы должны быть `hidden: false`, иначе экран пустой.
