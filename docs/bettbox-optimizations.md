# Memory and energy optimization review

Date: 2026-09-05. Compared MeowClash `fd50e56` with Bettbox `77edef5b`.

This is an adaptation to MeowClash's existing architecture, not a replacement of its core or a claim that every Bettbox optimization is appropriate here. Both repositories use GPL-3.0. No runtime dependency versions were changed. `fake_async`, already resolved through Flutter's test framework, is now explicitly declared as a development dependency.

## Applied

### 1. Stop idle UI polling reliably

Bettbox's task-loop invalidation and foreground-aware dashboard refresh provided the useful model (`lib/state.dart`, `lib/common/task.dart`, and the dashboard/connections views).

MeowClash now has a small shared polling implementation with one in-flight operation, generation-scoped results, at most one pending refresh, and a timer armed only after completion. Concurrent starts are idempotent. Stop/dispose invalidates outstanding work; an awaited response cannot resurrect the timer. Temporary errors do not permanently break the loop.

- Memory and connections polling follows both application lifecycle and the existing navigation `TickerMode`. Cached, hidden pages keep their UI state but do not keep polling.
- UI run-time/traffic polling stops reliably on Android background transitions; a stale resume callback cannot restart it.
- Periodic group refresh pauses while the app is in the background.
- Memory and connection results are checked after awaits, not just before them. Traffic updates also check that their widget context is still mounted.
- Subscription/provider update schedules are retained. Their callbacks no longer schedule another timer after the owning application is disposed.

An already-running core request is allowed to finish; it is not forcibly terminated. The polling loop does not launch an overlapping replacement.

Memory reporting semantics are unchanged: Android's in-process core is already included in app RSS. Desktop adds the separate core's reported memory.

### 2. Release profile-script resources

Bettbox's `lib/common/js_runtime_manager.dart` explicitly closes temporary JS engines in `finally`.

MeowClash now runs one-shot profile transformations in a short-lived Dart isolate using its existing `flutter_js` backend. The result is converted to Dart data before native teardown. Success, evaluation errors, and conversion errors all release the engine. Dart-backed JS timers are canceled and the package's static bridge entry is removed.

The fetch polyfill is loaded through the parent Flutter engine's asset bundle before spawning the worker. Inside the worker, XHR/fetch is initialized synchronously before evaluating the profile. This avoids the existing package factory's unawaited asset load trying to use an already disposed engine. The worker receives a snapshot of MeowClash's proxy/TUN routing decision and its existing loopback bypass; it does not silently fall back to unrelated network routing.

The existing profile transformation/result contract is preserved; this is not a new asynchronous-script API. Background fire-and-forget work is not kept alive after a one-shot transformation ends.

### 3. Remove idle forced Go collections

The old two-minute timer forced `runtime.GC()` immediately followed by `debug.FreeOSMemory()`. The latter already performs a collection.

The periodic timer is removed. Go's allocation-driven GC/scavenger remains active, with the existing GC percentage of 50 and soft memory limit of 192 MiB. Explicit/OS-pressure reclaim requests are coalesced into one outstanding reclaim. Shutdown still explicitly releases memory, without a redundant preceding GC.

**Trade-off:** this reduces unconditional idle work; it does not guarantee lower idle RSS. The runtime may return memory to the OS later than a forced periodic collection. The 192 MiB value is a soft limit for Go-managed memory, not a process-RSS limit and not a limit on Flutter/native memory or live configuration size.

### 4. Respect lazy provider health checks

The three-second delay-history forwarder previously called `Touch()` on every proxy provider, including while the VPN was stopped. In the installed mihomo implementation, `Touch()` updates the provider's last-use timestamp, so this defeated `lazy` health checks.

History forwarding is now observational. Initial health checks, explicit/manual tests, health checks of used providers, and configured non-lazy checks remain enabled. The existing manual concurrency limit of 10, queue deadlines, delay batching, and proxy UI/cache improvements are unchanged.

## Deliberately not copied

- Bettbox's aggressive suspend path (`core/suspend.go` and Android suspend module) can close active connections, suspend WireGuard, and alter NTP/health checks using private internals. That changes VPN behavior and was not transplanted.
- Vendor-specific trim/kill handling from `FairMemoryHelper.kt` is not a general-purpose memory optimization.
- Existing bounded histories and the previous lazy navigation/proxy rendering work are retained rather than replaced wholesale.
- Screen-off notification-refresh suspension remains a separate Android candidate. This patch does not change foreground-service lifecycle, notification stop actions, or UI/service Flutter-engine ownership. That change needs an Android build and device-level background-service tests; the configured environment currently has platform-tools but no usable JDK/full Android SDK.

## Verification

Regression coverage includes concurrent starts, stop during awaits, rapid stop/start, coalesced manual refreshes, recovery after errors, disposal, real cached navigation, actual memory/connections widget disposal, JS ownership/error paths, proxy-routing snapshots, native JS transformations, and concurrent Go memory-pressure requests.

Commands:

```sh
flutter test --no-pub --reporter expanded
flutter analyze --no-pub
(cd core && go test -race ./...)
git diff --check
```

Validated on macOS arm64 with Flutter 3.44.1 / Dart 3.12.1:

- **94 Flutter tests passed**, including 27 new regression tests and 10 native JavaScript transformations inside the native-runtime test.
- **Full Go race suite passed.** The three memory-reclaim tests also passed 20 repeated runs under the race detector.
- **No new analyzer diagnostics.** A multiset comparison by severity/message/file/code found 576 existing diagnostics versus 585 before the change, with nine removed and none added. `flutter analyze` still exits nonzero because the pre-existing diagnostics remain.
- **`git diff --check` passed.**
- The preceding manual-ping/IP-dialog implementation and native Android source files are unchanged.
- No APK, Android-device profiling, commit, or push was performed. Android native/service behavior remains a required device-level validation step.

## Android before/after measurement checklist

Use release builds, the same device/OS, profile/provider count, selected server, traffic workload, and test duration. Rebuild both the Go core and Flutter app for this patch.

1. Record PSS/RSS with `adb shell dumpsys meminfo com.meowclash.app` after warm-up, repeated profile changes, five minutes on another tab, and five minutes with the app backgrounded/screen off.
2. Check CPU wakeups and battery activity over a longer matched interval with Android profiling/battery tools. Do not infer battery savings from RAM alone.
3. Verify active downloads/streams and WireGuard survive backgrounding, screen-off, and removing the UI from recents. Confirm the persistent notification and its stop action still work.
4. Exercise repeated foreground/background transitions, delayed core replies, connection closing, manual ping batches, and profile scripts. Check logs for late callbacks and use-after-dispose errors.
5. Compare GC frequency and idle RSS: removing forced collections intentionally prioritizes avoiding unnecessary work, not forcing the smallest RSS at every instant.

No Android device RAM/battery/FPS measurements or percentage savings are claimed by this review.
