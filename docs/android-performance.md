# Android responsiveness regression checks

## Changes

- One shared manual URL-test queue; concurrency is capped at 10 on every platform.
  Single-node, group and all-group checks share the limit. Inputs are consumed
  lazily, duplicate effective `(proxy, URL)` targets share in-flight work, and
  the loop yields between requests. Distinct group test URLs are preserved.
- Profile/core changes discard queued manual work and ignore old responses.
  Started loading indicators are settled on cancellation, failure or timeout.
- Native tests have a deadline including queue wait (maximum 5 seconds). The
  old process-lifetime Batch and duplicate manual DelayMessage were removed.
  Provider lookup indexes are rebuilt only when provider identity/version
  changes, not by copying the complete proxy map for every URL test.
- Delay updates coalesce for 50 ms and copy only changed URL buckets. Existing
  immutable snapshots are not mutated; unchanged scalar selectors do not
  notify. The final batch is flushed before one explicit delay-sort update.
- Expanded groups use lazy sliver grids, with no keep-alive for offscreen
  cards. Polls reuse equal group objects and do not notify on unchanged data.
- Proxy model conversion runs with `compute`; shared nodes are parsed once.
  Sorting uses data snapshots, not one provider instance per offscreen proxy.
- Adjacent-page animations remain enabled. Distant navigation jumps directly
  rather than initializing intermediate pages. Hidden pages have TickerMode,
  focus and semantics disabled, with repaint isolation and retained page state.

## Automated checks

```sh
dart run build_runner build --delete-conflicting-outputs
flutter test --no-pub
flutter analyze --no-pub
go test -C core -race ./...
```

The regression tests cover concurrency, cancellation, timeouts, lazy input,
per-group URLs, immutable batching, scalar notification isolation, equal group
polls, shared parsing, lazy mounted-card count for two 5000-node groups,
scrolling/search/collapse, repeated presses and lazy page navigation/tickers.
These are functional/workload checks, not a device FPS benchmark.

## Device acceptance (still required)

Rebuild both the Go core and Flutter app using the repository's Android setup
workflow (`dart setup.dart android --arch arm64` for an arm64 release). Do not
ship only a Flutter rebuild with an old native library. Use the normal project
profile-build workflow / `flutter run --profile` for the DevTools timeline.
Android SDK platforms, build-tools and NDK must be installed.

Run on a low-memory Android phone and a 120 Hz device, with identical profiles
and network conditions before and after the change:

1. Use 2000–5000 proxies, including working, refused and timed-out endpoints.
   Expand several groups and run all-group checks repeatedly. Verify scrolling,
   Back and other navigation stay responsive while measurements are running.
2. Switch profile and restart the core during a slow sweep. Queued old targets
   must not start; old manual replies must not repopulate the new profile.
3. Switch Dashboard ↔ Proxies and between distant menu pages during the sweep;
   scroll to the end, collapse/expand, filter and switch sort/layout/card modes.
4. Exercise automatic provider refresh, screen rotation, large text scaling,
   keyboard/Android TV focus and background/foreground transitions.
5. Capture Flutter DevTools frame timings and a CPU profile in **profile mode**;
   inspect UI and raster times separately. The nominal budgets are 16.7 ms at
   60 Hz and 8.3 ms at 120 Hz. Do not infer production FPS from debug builds or
   desktop widget tests.
6. Capture `adb logcat` (and an Android bug report / ANR trace if a hang remains).
   Verify no ANR, unbounded active URL-test count, repeated full-list rebuilds,
   or growth in mounted cards while traversing a large list.

A full sweep may take longer with bounded concurrency, especially when many
nodes time out; navigation must remain responsive throughout it. This change
addresses demonstrated load amplification, not a proven synchronous HTTP call
on Android's main thread. Real-device traces are required to certify the
reported 15-minute hang is gone and to investigate any residual native issue.
