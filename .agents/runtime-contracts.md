# Feature mechanics worth knowing

Router: `AGENTS.md`. Non-obvious runtime contracts — breaking one looks like a UI bug, not a build
failure.

- **Manual delay tests** (`lib/services/delay_test_runner.dart`): one shared queue; single-node, group
  and all-group checks share its limit. Default **32** on Windows/macOS/Linux, **10** on Android/iOS;
  `AppSettingProps.delayTestConcurrency` overrides it (`null` = platform default, `0` = unlimited,
  max 1000). Each native request carries `concurrency`, and `core/delay.go` resizes its process-wide
  limiter to match (requests without it keep the current limit, initially 10).
  Duplicate effective `(proxy, URL)` targets share in-flight work, and native tests have a **5 s**
  deadline that includes queue wait. Profile/core changes discard queued work and ignore late responses,
  settling any started loading indicator. Delay updates coalesce for **50 ms** and copy only changed URL
  buckets — never mutate existing immutable snapshots, and do not notify on unchanged scalars.
- **Provider refresh** (`lib/services/provider_refresh_service.dart`): owned by the **Android service
  engine**, not the Activity or the `Application` widget. Setup IPC and quick-settings cold starts hand
  it a snapshot of the effective provider configuration, including profile-script changes and
  decryption credentials.
- **UI suspension** (`lib/services/ui_lifecycle.dart`, `lib/widgets/suspendable_ui.dart`):
  run-time/traffic polling must stop on Android background transitions and a stale resume callback must
  not restart it; periodic group refresh pauses in the background. Check `mounted`/results **after**
  awaits, not only before. An in-flight core request is allowed to finish instead of being killed, and
  the polling loop must not launch an overlapping replacement.
- **Site availability** (`lib/common/media_unlock_state.dart`): checks run only while the core is
  running and a site-availability dashboard widget is present; node-change rechecks are debounced
  (800 ms), skipped in the background, and re-run on resume only if the route signature changed.
- **Core status dialog** (`lib/views/dashboard/widgets/core_status_dialog.dart`, Go `core/core_status.go`):
  tapping the memory card opens it; the card itself keeps its 2 s RSS polling. The dialog polls
  `getCoreStatus` (which calls `runtime.ReadMemStats`, a short stop-the-world) every **1 s** only while it
  is open and the UI is foreground. Shell RAM is `ProcessInfo.currentRss/maxRss`; core RAM is the core
  process RSS (`getMemory`) plus Go `MemStats.Sys`. On Android the core shares the app process, so no
  separate core RSS is shown. Manual GC moved from the card tap to the dialog's "Free memory" button.
- **Profile scripts** (`lib/services/profile_script_evaluator.dart`): one-shot transforms run in a
  short-lived isolate on `flutter_js`; results are converted to Dart data before native teardown, and
  success, evaluation errors and conversion errors all release the engine. The fetch polyfill is loaded
  through the parent engine's asset bundle before spawning the worker, and XHR/fetch is initialized
  synchronously inside it before evaluating the profile.
- **Go memory**: there is no periodic forced GC (the old two-minute `runtime.GC()` +
  `debug.FreeOSMemory()` timer was removed). Allocation-driven GC stays active with GC percent **50** and
  a **192 MiB** soft limit on desktop/Android (the iOS extension uses 32 MiB); explicit (core status dialog) and OS-pressure
  reclaims coalesce into one outstanding request. Do not call `Touch()` on providers just to forward
  delay history — it updates their last-use timestamp and defeats `lazy` health checks.
- **IP details** (`lib/services/ip_details_service.dart`): extra data is fetched only while the dialog is
  open, through the proxy-aware client, for that exact IP; responses for a different IP are rejected.
  Successful lookups are cached **5 min** in a **16-entry** IP/language LRU; failures are not cached.
  Country names always come from bundled CLDR data, never the API's translated string, and `ipwho.is`
  has no Finnish/Ukrainian region names — those fall back to English with a localized notice.
