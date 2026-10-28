# RAM optimization: work plan and progress

Router: `AGENTS.md`. **Temporary file.** It tracks one piece of work across agent sessions and is
deleted, together with the "Active work" section in `AGENTS.md`, in the last step. Before/after numbers
end up in PR descriptions; this file only holds them until then.

## How to resume (any agent)

1. Run `git status`, `git branch --list 'perf/*' 'fix/*' 'test/*'` and `git log --oneline -5`.
2. Check out the newest branch of the stack (see the progress log). Uncommitted changes mean a step was
   interrupted: finish it or discard it deliberately, never silently.
3. Raw measurement output lives in `.agent/ram/` (gitignored, local to this machine only).
   In the folder MCP sandbox the Flutter SDK cache is read-only and plain `flutter` fails. The local
   wrapper `.agent/flutter.sh` (gitignored) runs the flutter_tools snapshot directly with
   `FLUTTER_ALREADY_LOCKED=true` and `HOME=.agent/home`; `.agent/flutter.sh dart ...` runs the Dart
   binary. Use it in place of `flutter` there, and pass `--no-pub` to `test` for repeated runs.
4. Continue from the first unchecked box. After each step, tick its boxes, add a progress-log row, fill
   the measurements table, and commit these edits **in the same commit as the step's code**.

## Goal

Lower the app's memory use (Dart heap, native text-layout and raster memory, allocation churn on hot
paths) without changing behavior, visuals or user defaults.

## Working rules

- One topic, one branch, one commit (conventional commits: `perf(ui): ...`, `fix(state): ...`). Code
  comments stay short and in English.
- Branches are **stacked**: each one starts from the previous one, because steps 3, 6 and 7 all edit
  `lib/views/logs.dart`. PRs are opened in order. If an earlier PR is merged, rebase the rest onto `main`.
- The agent never pushes; the maintainer pushes and opens PRs.
- Regenerate generated files, never hand-edit them: `dart run build_runner build --delete-conflicting-outputs`.
- Do not update goldens: the Material look must not change.
- Ask the maintainer before long jobs (`setup.dart` core builds, `flutter run --profile`, nix).
- Never invent numbers. If something was not measured, write "not measured" and give the maintainer
  the steps to measure it.
- Verify after every step:

  ```bash
  flutter analyze --no-fatal-infos --no-fatal-warnings
  dart run custom_lint
  flutter test
  ```

  Notes from step 0: `flutter analyze` from the root also scans `FlClashX-0.5.0-dev/`, a local
  reference copy excluded through `.git/info/exclude`, so it exits 1 with ~56k issues. Count only
  repo files (`grep -v FlClashX-0.5.0-dev/`); the base has 0 errors, 4 warnings and 569 infos there.
  `dart run custom_lint` does not run on the base: `custom_lint` and `riverpod_lint` are not in
  `pubspec.yaml`, so skip it and say so in the PRs.

## Already done (do not redo)

- Go memory tuning: GC percent 50, 192 MiB soft limit, no periodic forced GC (`runtime-contracts.md`).
- UI suspension clears `cacheHeightMap` and reusable images on hide (`lib/services/ui_lifecycle.dart`,
  `lib/widgets/suspendable_ui.dart`, `onUnload` in `lib/application.dart`).
- Liquid Glass is Darwin-only (`AdaptivePlatform.useGlass`); Android, Windows and Linux never blur.
  It uses one `BackdropFilter` per surface, list rows have no blur (`GlassStreamRow`), and there is a
  kill switch (`GlassFlags.backdropBlurEnabled`), a Reduce Transparency fallback and blur-budget tests.
- Core logs are off by default (`openLogs: false` in `lib/models/config.dart`), and the default
  `log-level` is already `error` (`lib/models/clash_config.dart`).

## Out of scope

- `android:largeHeap`, swap tricks, removing features, changing user defaults.
- Collecting logs only while the Logs page is visible (users who enabled logs lose history), or
  exporting logs from the file log (changes the export content).
- Defaults for `log-level`, `store-fake-ip` and `external-controller` (the profile value always wins,
  see `lib/state.dart` around line 545). `find-process-mode` (default `always`) changes UX: propose it
  separately at most.
- `--split-debug-info` / `--obfuscate`: they shrink the APK, not RAM, and touch `setup.dart`,
  `test/build_platforms_test.dart` (asserts on `setup.dart` text) and CI symbol storage.

## Measurement

- Host: the existing `test/*_performance_test.dart` files (host workload, not device FPS) plus the new
  `test/fixed_buffers_performance_test.dart` from step 1.
- macOS (only with the maintainer's OK): `flutter run --profile -d macos` and DevTools Memory. Shell RAM
  (`ProcessInfo.currentRss`) is also shown in the core status dialog (tap the dashboard memory card).
- Android only with a device on adb: `adb shell dumpsys meminfo <package>` (Total PSS, Native Heap,
  Graphics).
- Scenarios:
  - (a) cold start to the dashboard;
  - (b) Requests page open, 10 minutes under load;
  - (c) logs enabled (`openLogs`, `log-level: info`), Logs page open, 10 minutes;
  - (d) three profile switches in a row;
  - (e) background and resume.

## Steps

### 0. Environment

- [x] Clean tree; record the base commit in the progress log.
- [x] `flutter --version` and `flutter pub get` work from the agent shell. In the folder MCP sandbox
  `flutter --version` once printed nothing; if the sandbox blocks the Flutter cache, ask the maintainer.
  (Blocked cache worked around with `.agent/flutter.sh`, see "How to resume".)
- [x] Run `flutter test` and analyze on the base. Save any failures that already existed to
  `.agent/ram/00-base-tests.txt`. (No failures: 822 passed, 1 platform-gated skip.)

### 1. Benchmark and baseline: branch `test/ram-bench`

Commit: `test(perf): host benchmark for log/request buffers and height cache`

- [x] Write `test/fixed_buffers_performance_test.dart` on top of `test/performance_test_support.dart`.
  It measures 10 000 `addLog` and 10 000 `addRequest` with an active `select` listener (like an open
  page), the count and size of list copies, and 10 000 `FixedMap.updateCacheValue` calls on a full map.
  It prints numbers and has no hard thresholds.
- [x] Run the existing perf tests: `connections_logs`, `dashboard`, `proxy_list`, `navigation`.
  (`proxy_list` and `navigation` only assert and print no numbers.)
- [x] Save the raw output to `.agent/ram/01-baseline.txt` and copy the key numbers into the table below.
- [ ] With the maintainer's OK: macOS profile run, scenarios a–e. Android only if a device is attached;
  otherwise mark it "not measured". (Waiting for the OK; no Android device on adb.)

### 2. Buffer capacity after a profile switch: branch `fix/buffer-capacity-profile-switch`

Commit: `fix(state): keep log/request buffers at maxLength after profile switch`

- [x] In `handleChangeProfile()` (`lib/controller.dart`, around line 764), `logsProvider` and
  `requestsProvider` are recreated as `FixedList(500)`, while `initApp` in `lib/state.dart` uses
  `FixedList(maxLength)` with `maxLength = 150` (`lib/common/constant.dart`). Use `maxLength`; ideally
  create both buffers through one factory. (Factory `createEventBuffer<T>()` in
  `lib/common/fixed.dart`, used by `initApp` and `handleChangeProfile`. Step 6 must keep it.)
- [x] Test: after a profile switch, both buffers have a capacity of `maxLength`.
  (`test/event_buffer_capacity_test.dart`: three real `handleChangeProfile()` calls with the core
  stubbed out; it fails on the old code with `Expected: <150> Actual: <500>`.)

### 3. A cache tag of its own for the Logs page: branch `fix/logs-cache-tag`

Commit: `fix(ui): give the logs page its own height/scroll cache tag`

- [x] `lib/views/logs.dart` uses `_tag = CacheTag.rules`, the same tag as the rules editor
  (`lib/views/profiles/override_profile.dart`, around line 857), so the two pages share
  `cacheHeightMap` and `cacheScrollPosition`. Switch to the existing `CacheTag.logs`.
- [x] Check that nothing else uses `CacheTag.logs`, and that the Logs tests and goldens still pass.
  (Nothing else used it. `test/adaptive_connections_logs_glass_test.dart` passes `CacheTag.rules`
  to a bare `ScrollToEndBox` as an arbitrary tag; left as is. New `test/logs_cache_tag_test.dart`
  fails on the old code: log rows evicted the rules editor's height entry.)

### 4. Dispose TextPainter after measuring: branch `perf/text-painter-dispose`

Commit: `perf(ui): dispose TextPainter after measuring text`

- [x] `Measure.computeTextSize` (`lib/common/measure.dart`) creates a `TextPainter` for every
  measurement and never calls `dispose()`, so the native `ui.Paragraph` stays alive until a GC
  finalizer runs. It runs for every Logs and Requests row height. Store the size, dispose the painter,
  then return the size. (`try`/`finally` around `layout`.)
- [x] Look for other `TextPainter(` instances in `lib/` that are never disposed, and fix them the same way.
  (One more: `_CatPainter._drawZ` in `lib/views/dashboard/widgets/start_button.dart` made a painter
  on every frame of the idle cat animation. Now disposed after the loop.)
- [x] Measure with the step 1 benchmark and, if a build is available, external/native memory while
  opening Logs and Requests. (New `test/text_painter_dispose_test.dart` counts undisposed painters,
  raw output in `.agent/ram/04-before.txt` / `04-after.txt`; timings in `.agent/ram/04-perf.txt`, no
  regression. Native memory on a device: not measured, no build.)
- [x] Add one line to `.agents/runtime-contracts.md`: text measurements dispose their `TextPainter`.

### 5. FixedMap eviction without rebuilding: branch `perf/fixed-map-eviction`

Commit: `perf(ui): evict FixedMap entries in O(1)`

- [x] On overflow, `FixedMap._adjustMap()` (`lib/common/fixed.dart`) builds `Map.unmodifiable`, then
  `entries.toList()`, then `Map.fromEntries`: three copies for every new entry over the limit. On top
  of that, `CacheItemExtentListView` (`lib/widgets/scroll.dart`) calls `updateMaxLength` on every
  `itemExtentBuilder` call. Instead, remove `_map.keys.first` while `length > maxLength` (a
  `LinkedHashMap` keeps insertion order). Make `updateMaxLength` a no-op when the size is unchanged.
  Never use the copying `map` getter inside the class.
  (Done: `_adjustMap` is replaced by `_evictOldest()`. With the same size it only compares the
  length, so `updateMaxLength` is a no-op. FIFO by insertion order is kept; a hit does not refresh
  the entry's age, as before. `updateMap` copies the map only when it must trim it, so the caller's
  map is never mutated, as before. Nothing in `lib/` passes its own map to the constructor or
  `updateMap`. The debug-only `truncate` assert for `maxLength` 0 is gone; release behavior is the same.)
- [x] Keep the public API: `updateCacheValue`, `get`, `containsKey`, `clear`, `updateMaxLength`,
  `updateMap`, `length`, `map`.
- [x] Tests in `test/fixed_map_test.dart`: the oldest entries are evicted first, `maxLength` can
  shrink and grow, `clear`, `updateMap`. (Also: a hit does not refresh age, the overflowing key's
  value is returned, `map` is an unmodifiable snapshot, and 5000 random operations match a copy of
  the old algorithm. On the old code 9 of 10 pass; `maxLength 0` fails on the debug assert,
  `.agent/ram/05-fixed-map-old-code.txt`.)
- [x] Note: the `log.payload` key is a reference to the existing string, not a copy. Change the key
  only if a measurement shows a gain. (Key unchanged.)

### 6. FixedList as a ring buffer with a version: branch `perf/fixed-list-ring-buffer`

Commit: `perf(state): ring buffer with version for FixedList`. This is the riskiest step.

- [x] Today `FixedList.list` returns `List.unmodifiable(_list)`, a full copy on every call. The Logs
  and Requests pages listen to `select((s) => s.list)` and compare with `ListEquality`, so every message
  from the core costs a 150-item copy plus an O(n) comparison, and the throttler repeats the comparison
  (`lib/views/logs.dart`, `lib/views/connection/requests.dart`).
- [x] Before editing, check how `AutoDisposeNotifierMixin` and `updateShouldNotify` decide whether to
  notify. Two current behaviors must keep working: `copyWith()` returns a new wrapper over the **same**
  backing list (this is what makes Riverpod notify), and `AppController.addLog` (`lib/controller.dart`,
  around line 554) mutates the buffer in place without notifying.
  (Checked: the mixin calls Riverpod 2.6's `updateShouldNotify`, which is `!identical(prev, next)`, so a
  new wrapper is enough; `select` compares the selected value with `==`. Because wrappers share storage,
  `prev.version` and `next.version` of two wrappers are always equal: compare versions only through
  `select`, which keeps the value from the previous notification. A per-buffer counter would collide
  after a profile switch (a new buffer restarts at 0), so versions come from one global counter and
  never repeat across buffers. In-place `AppController.addLog` callers: `lib/common/print.dart` and
  `lib/views/developer.dart`.)
- [x] Implement a fixed-capacity ring buffer with a monotonic `version`, bumped by `add` and `clear`.
  The chronological `list` snapshot is cached per version. Keep the public API (`maxLength`, `add`,
  `clear`, `list`, `length`, `[]`, `copyWith`) and the type name, so the freezed `AppState` does not
  need regenerating.
  (Storage `_Ring<T>` in `lib/common/fixed.dart`, shared by every `copyWith` wrapper: a growable list
  up to capacity, then overwritten in place from `head`. The snapshot is built with one copy and
  dropped on `add`/`clear`. One change: the constructor's `list:` is copied, no longer aliased and
  truncated in place; nothing in `lib/` passes one. The debug `maxLength > 0` assert is kept.)
- [x] Consumers: switch to `select((s) => s.version)`, take one snapshot per throttled UI update, and
  drop `ListEquality` from the hot path. Also check `exportLogs` (`lib/controller.dart`),
  `network_speed.dart` (traffics, `FixedList(30)`), `ScrollToEndBox` and `lib/views/developer.dart`.
  (`logs.dart` / `requests.dart`: the listener only schedules the throttler; the post-frame callback
  reads the provider once, skips when the version equals the shown one, then takes one snapshot.
  `exportLogs`, `network_speed.dart` and `developer.dart` need no change: they read `list` once per
  call or build, now cached per version. `ScrollToEndBox` keeps its `ListEquality`: it runs per page
  build on the filtered list, not per core message, and `ListEquality` returns early on `identical`.)
  Finding: the page applies updates in `addPostFrameCallback`, which does not schedule a frame, so on
  an idle screen new rows waited for the next frame from something else; the old code did the same.
  Fixed in step 10a by a second commit on this branch: `ensureVisualUpdate()` after the callback.
- [x] Tests in `test/fixed_list_test.dart`: overflow, order, `clear`, version bumps, `maxLength = 1`,
  snapshot immutability, `copyWith` and in-place mutation.
  (18 tests: "behavior kept" (9, pass on the old code), version, snapshot cache, Riverpod select with
  in-place add, buffer replacement and traffics `clear`. Plus `test/event_buffer_live_update_test.dart`:
  open Logs/Requests pages (Material and glass) show new events and a buffer replaced by a profile
  switch. It passes on the old code and fails with a per-buffer counter.)
- [x] Measure with the step 1 benchmark and, if a build is available, scenarios b and c.
  (The benchmark now mirrors the new listener: select on `version`, one snapshot after the burst.
  Numbers in the table, raw output in `.agent/ram/06-perf.txt`. Scenarios b and c: not measured, no
  build. The remaining ~12 ms per 10 000 events is not profiled; candidates are the Riverpod
  notification and `AppState.copyWith` in `onUpdate` for every message.)
- [x] Document the `FixedList` and version semantics in `.agents/runtime-contracts.md`.
  ("Event buffers" entry.)

### 7. Lazy Material log rows: branch `perf/logs-lazy-rows`

Commit: `perf(ui): build Material log rows lazily`

- [x] The Material branch of `LogsView.build` (`lib/views/logs.dart`) builds every `LogItem` and
  divider up front on each update (`logs.map(...).separated(...).toList()`), even though
  `ListView.builder` is lazy. Build each item in `itemBuilder` by index instead: even index for a
  `LogItem`, odd index for a `Divider`. The glass branch is already lazy.
  (Done: `itemCount = 2n - 1`; the row keeps its `Key(log.dateTime)` and the `onClick` closure on the
  page `context`; the divider is the same `const Divider(height: 0)`. Extents and height-cache keys
  are unchanged.)
- [x] Check `lib/views/connection/requests.dart` for the same pattern.
  (Same pattern, same fix, `Key(connection.id)`. The other `.separated(...)` users in `lib/` are
  short settings lists and the scaffold actions, built once per page, not per core event: left as is.)
- [x] `test/material_connections_logs_golden_test.dart` must pass without updating goldens.
  (Passes. New `test/material_lazy_rows_test.dart`: every index of a 150-row list gives the same row,
  key, extent and cache key; a row chip still filters the page (logs and requests); a printed
  benchmark of 60 page updates on a full buffer. All 5 pass on the old code too.)

### 8. Structural equality in select: branch `perf/proxies-select-equality`

Commit: `perf(providers): structural select for proxy group names`

- [x] In `proxiesListSelectorState` (`lib/providers/state.dart`, around line 300),
  `select((s) => s.value.map((e) => e.name).toList())` returns a new `List` that is never `==` to the
  previous one, so the select fires on every change. Select a value with structural equality instead.
  (Done: `proxiesListSelectorState` and `proxiesSelectorState` watch `groupNamesStateProvider`
  (freezed `GroupNamesState`, deep list equality), so `groupNamesState` is the only place that maps
  groups to names. Riverpod 2.6.1 compares a selected value with `!=`, so the old select fired on
  every `currentGroupsState` change (a new selection, a delay refresh). Widgets did not rebuild
  before either, because the freezed selector states compare deeply, but both providers recomputed.)
- [x] Search the other providers for the same `select(...toList())` / `select(...where...)` pattern.
  (Same select in the unfold-all button `Consumer` in `lib/views/proxies/proxies.dart`: it rebuilt on
  every groups change; now it watches `groupNamesStateProvider`. Left as is, not hot:
  `moreToolsSelectorState` (`where().toList()` on navigation items, freezed result), `selectedMap` /
  `unfoldSet` `?? {}` (a new set only without a profile), one-shot `ref.read(...select(...))` in
  `access.dart`, `controller.dart` and `override_profile.dart`, `override_profile.dart` `VM3` (deep
  equality), and selects that return a `bool` or a `Group`.)
- [x] Test the rebuild count before and after.
  (New `test/proxies_select_equality_test.dart`, 3 tests: 100 selection changes that keep the names,
  one added group, and names that follow mode, hidden groups and order. On the old code the first
  test fails on the recompute count, the other two pass (`.agent/ram/08-select-old-code.txt`).)
- [x] Run build_runner if annotated providers changed.
  (Done: only the two provider hashes in `lib/providers/generated/state.g.dart` changed.)

### 9. Verify only (open a PR only for a confirmed problem; record findings here)

- [ ] `_yamlToDart` (`lib/state.dart`, around line 849): take a heap snapshot after a profile is
  applied, and check whether any `YamlMap` or converted `Map` is retained (the maps are function-local).
- [ ] `configState`: how often it really recomputes. It assembles the whole `Config` by design; do not
  split it without data.
- [ ] `currentGroupsState`: recompute count under load.
- [ ] Image cache (32 MB / 128 entries is a ceiling): check `imageCache.currentSizeBytes` in the
  scenarios. If it needs changing, update `test/image_memory_test.dart`, which asserts exactly
  32 MB and 128.
- [ ] Darwin glass GPU memory on macOS (DevTools or Instruments).

### 10. Final verification

- [ ] On the last branch of the stack, repeat every step 1 measurement and fill the "After" column.
- [ ] Run the full checklist in `.agents/testing.md`. Go, Python and Rust only if they were touched.
- [ ] Draft PR descriptions with before/after numbers for each branch.
- [ ] Prepare a manual smoke test for the maintainer: start, connect, Requests and Logs under load,
  log export, profile switch, rules-editor scrolling, background and resume, and on macOS glass on/off
  (Reduce Transparency).

### 11. Cleanup

- [ ] On the last branch, delete this file and the "Active work" section in `AGENTS.md`.

## Measurements

| Scenario / metric | Baseline | After | Source |
| --- | --- | --- | --- |
| 10 000 `addLog` with Logs open, time | 24.5–25.6 ms | after step 6: 12.4–12.7 ms | benchmark, 3 runs |
| 10 000 `addLog`, list copies / bytes | 10 001 snapshots, 1 488 825 slots (~11.4 MiB at 8 B/slot) | after step 6: 1 snapshot per throttled update, 150 slots (~1.2 KiB); the select reads only `version` | benchmark |
| 10 000 `addRequest` with Requests open, time | 17.0–17.9 ms (copies as for logs) | after step 6: 9.1–10.2 ms (copies as for logs) | benchmark, 3 runs |
| 10 000 `FixedMap.updateCacheValue`, time | misses 135.7–138.3 ms, hits 0.34 ms | after step 5: misses 4.28–4.84 ms, hits 0.66–2.67 ms (sub-ms noise, code path unchanged), `updateMaxLength` same size 0.03–0.34 ms (0.35 before) | benchmark, 3 runs (`.agent/ram/05-perf.txt`) |
| Logs scroll, 1000 rows, 120 frames, mean | glass macOS 24.30 ms, iOS 15.63 ms, material 29.05 ms | after step 4: glass macOS 21.05–22.36 ms, iOS 13.68–14.88 ms, material 26.34–27.95 ms (host noise, no regression); after step 6: 21.35 / 14.87 / 26.92 ms (1 run) | `connections_logs` perf test, 1 run / 3 runs |
| Material page update, 150 rows: row widgets built | 150 rows + 150 `onClick` closures + a 299-slot list per update (read from code) | after step 7: only the rows the list keeps built, 5 logs / 6 requests at 400×900 | `material_lazy_rows_test`, code |
| Material page update, 150 rows, wall time (throttle + 3 frames) | logs 25.3–25.6 ms, requests 18.3–18.7 ms | after step 7: logs 25.6–25.7 ms, requests 18.1 ms (no change beyond noise; host debug JIT, not profiled) | `material_lazy_rows_test`, 3 runs each (`.agent/ram/07-lazy-*.txt`) |
| 100 group selection changes, names unchanged: recomputes / notifications | `proxiesListSelectorState` 100, `proxiesSelectorState` 100, notifications 0; the unfold-all button select fired 100 times | after step 8: 0 and 0 recomputes, 0 notifications; the button watches `groupNamesState`, 0 notifications; 1 added group: 1 recompute and 1 notification each, as before | `proxies_select_equality_test` (`.agent/ram/08-select-*.txt`) |
| Undisposed `TextPainter`s, Logs page with 150 rows, open + close | 152 of 203 created | 0 (step 4) | `text_painter_dispose_test` |
| Undisposed `TextPainter`s, Requests page with 150 rows, open + close | 301 of 375 created | 0 (step 4) | `text_painter_dispose_test` |
| Undisposed `TextPainter`s, dashboard with idle cat, ~2 s of frames | 86 of 256 created (about one per frame) | 0 (step 4) | `text_painter_dispose_test` |
| a. Cold start, RSS | not measured | | macOS |
| b. Requests 10 min, RSS / Dart heap | not measured | | macOS |
| c. Logs (info) 10 min, RSS / Dart heap | not measured | | macOS |
| d. 3 profile switches, buffer capacity / RSS | 500 per buffer (read from code, test in step 2) / RSS not measured | 150 per buffer (step 2) / RSS not measured | `event_buffer_capacity_test` / macOS |
| e. Background and resume, RSS | not measured | | macOS |
| Android Total PSS (b, c) | not measured (no device) | | adb |

Host numbers come from `flutter test` on the maintainer's Mac (JIT `flutter_tester`, Flutter 3.44.1).
They are for before/after comparison on the same machine only.

## Progress log

| Date | Step | Status | Branch | Commit | Notes |
| --- | --- | --- | --- | --- | --- |
| 2026-10-28 | plan | added | `test/ram-bench` | `4603025` | base `main` at `ea15a7e`; waiting for the maintainer's OK to start |
| 2026-10-28 | 0 | done | `test/ram-bench` | (no code) | base `4603025`; tests 822 passed, 1 skipped; analyze 0 errors / 4 warnings in repo files; `custom_lint` not configured |
| 2026-10-28 | 1 | host part done | `test/ram-bench` | `b3bb381` | benchmark added, baseline in `.agent/ram/01-baseline.txt`; macOS profile run waits for the OK; Android not measured |
| 2026-10-28 | 2 | done | `fix/buffer-capacity-profile-switch` | `f33e7cb` | tests 827 passed, 1 skipped (`.agent/ram/02-tests-raw.txt`); analyze: no new diagnostics in touched files |
| 2026-10-28 | 3 | done | `fix/logs-cache-tag` | `74db5cc` | tests 828 passed, 1 skipped, Material goldens unchanged (`.agent/ram/03-tests-raw.txt`); analyze: no new diagnostics |
| 2026-10-28 | 4 | done | `perf/text-painter-dispose` | `6a39487` | tests 832 passed, 1 skipped, goldens unchanged (`.agent/ram/04-tests-raw.txt`); analyze: no new diagnostics |
| 2026-10-28 | 5 | done | `perf/fixed-map-eviction` | `c8a5960` | tests 842 passed, 1 skipped (`.agent/ram/05-tests-raw.txt`); analyze: touched files clean (`.agent/ram/05-analyze.txt`) |
| 2026-10-28 | 6 | done | `perf/fixed-list-ring-buffer` | `5fe9b44` | tests 864 passed, 1 skipped, goldens unchanged (`.agent/ram/06-tests-raw.txt`, touched files re-run after lint fixes: `06-tests-touched.txt`); analyze: no new diagnostics in touched files (`06-analyze.txt`); old-code and per-buffer-counter runs in `.agent/ram/06-*.txt` |
| 2026-10-28 | 7 | done | `perf/logs-lazy-rows` | `a2652bf` | tests 869 passed, 1 skipped, goldens unchanged (`.agent/ram/07-tests-raw.txt`); analyze: no new diagnostics in touched files (`07-analyze.txt`); old-code runs in `07-lazy-old-code.txt` |
| 2026-10-28 | 8 | done | `perf/proxies-select-equality` | (this commit) | tests 872 passed, 1 skipped, goldens unchanged (`.agent/ram/08-tests-raw.txt`); analyze: no new diagnostics in touched files (`08-analyze.txt`); build_runner: 2 provider hashes (`08-build-runner.txt`); old-code run in `08-select-old-code.txt` |
