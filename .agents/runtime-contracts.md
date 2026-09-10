# Feature mechanics worth knowing

Router: `AGENTS.md`. Non-obvious runtime contracts — breaking one looks like a UI bug, not a build
failure.

- **Manual delay tests** (`lib/services/delay_test_runner.dart`): one shared queue with concurrency
  capped at **10** on every platform; single-node, group and all-group checks share that limit.
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
- **Profile scripts** (`lib/services/profile_script_evaluator.dart`): one-shot transforms run in a
  short-lived isolate on `flutter_js`; results are converted to Dart data before native teardown, and
  success, evaluation errors and conversion errors all release the engine. The fetch polyfill is loaded
  through the parent engine's asset bundle before spawning the worker, and XHR/fetch is initialized
  synchronously inside it before evaluating the profile.
- **Go memory**: there is no periodic forced GC (the old two-minute `runtime.GC()` +
  `debug.FreeOSMemory()` timer was removed). Allocation-driven GC stays active with GC percent **50** and
  a **192 MiB** soft limit on desktop/Android (the iOS extension uses 32 MiB); explicit and OS-pressure
  reclaims coalesce into one outstanding request. Do not call `Touch()` on providers just to forward
  delay history — it updates their last-use timestamp and defeats `lazy` health checks.
- **IP details** (`lib/services/ip_details_service.dart`): extra data is fetched only while the dialog is
  open, through the proxy-aware client, for that exact IP; responses for a different IP are rejected.
  Successful lookups are cached **5 min** in a **16-entry** IP/language LRU; failures are not cached.
  Country names always come from bundled CLDR data, never the API's translated string, and `ipwho.is`
  has no Finnish/Ukrainian region names — those fall back to English with a localized notice.
