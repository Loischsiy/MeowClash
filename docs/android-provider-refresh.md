# Android background provider refresh

## Ownership and intervals

`ProviderRefreshService` belongs to the Android service engine, not the Activity or `Application` widget. Normal setup IPC and quick-settings cold starts supply a snapshot of the effective provider configuration, including profile-script changes and decryption credentials.

- Ordinary HTTP providers without profile decryption credentials retain mihomo's native updater.
- In profiles with a `meowclash-password`, the service owns downloads for both HTTP `proxy-providers` and HTTP `rule-providers`. Plaintext responses in those profiles are supported too.
- The saved YAML is not rewritten. Each provider retains its original interval in the service plan; only the native runtime interval is set to zero for service-managed HTTP providers, preventing two competing downloaders.
- `interval: 1200` means 20 minutes since that provider's last successful refresh. Initial cache timestamps are captured at setup; providers sharing a cache path still keep independent deadlines. Due checks run once a minute while the VPN is running, after the preceding check finishes. Network work and OS scheduling may add delay; this is not an exact alarm.
- `interval: 0` disables automatic downloads. File/inline providers and `health-check.interval` retain their existing behavior.

## Refresh safety

- Automatic and manual updates share one in-flight operation per provider type/name. The two namespaces may contain identical names; automatic updates remain separate. An ambiguous legacy name-only manual request returns an error rather than updating the wrong namespace.
- Downloads are streamed with a 16 MiB cap, request timeouts, configured HTTP headers and user-agent. Internal decryption credentials are not added as HTTP headers or passed into mihomo's setup config.
- Decryption does not require UI state. Binary MRS bytes are transferred without UTF-8 conversion.
- Native updates validate the live provider's type, name and cache path. Rejected payloads do not replace a valid cache. The service writes its cache atomically only after native acceptance.
- Setup/start/stop and native commits are serialized. Stop, shutdown and profile changes cancel pending downloads and invalidate late responses. A late start reply cannot resurrect a stopped polling loop. Stopping during setup retains the successfully applied plan for a later explicit start; shutdown or a newer setup invalidates it.
- Individual failures do not block other providers or advance the success timestamp. Automatic retries happen at subsequent checks while the VPN is running.
- The service uses Android system/TUN socket routing, as the previous custom Dart downloader did. It does not add per-provider mihomo `proxy:` selection to the Dart HTTP client; ordinary native-managed profiles retain native routing behavior.

## Validation

Local validation on macOS arm64 uses synthetic credentials, mocked HTTP and loopback-only native fixtures, never the user's subscription or VPN:

```sh
flutter test --no-pub --reporter expanded \
  test/provider_refresh_service_test.dart \
  test/provider_payload_test.dart \
  test/provider_headless_script_test.dart
flutter test --no-pub --reporter expanded
flutter analyze --no-pub
(cd core && go test -race -count=1 ./...)
(cd core && CGO_ENABLED=0 go test -tags=with_gvisor,cmfa -count=1 ./...)
(cd core && CGO_ENABLED=0 go build -tags=with_gvisor,cmfa -o ../.agent/provider-MeowClashCore .)
git diff --check
```

The focused suite has 24 tests, and the full Flutter suite has 131. Native integration covers real proxy/rule providers sharing a name, live group membership, invalid input and stale profile paths. Analyzer results must be compared with the existing repository baseline (576 diagnostics); the command is not a clean-zero baseline.

## Android acceptance checklist

Both Flutter code and the Go core must be rebuilt into the APK. The local desktop core build is not an Android APK validation.

1. Use a test profile with encrypted proxy and rule providers, known-good cached payloads and a short positive refresh interval. Confirm each namespace and group membership update without opening the providers screen.
2. Close the Activity while leaving the VPN service running; repeat with the screen off. Compare server access timestamps and actual provider changes, not just a widget refresh.
3. Go offline across an interval, reconnect, and check retry/recovery. Serve invalid/encrypted-with-wrong-key data and confirm the previous usable cache survives.
4. Stop or change profiles during a deliberately delayed response. Confirm no stale data lands in the new profile. Exercise quick-settings cold start with a profile script too.
5. Repeat with `interval: 1200` and the device's normal battery settings.

No permanent wake lock or exact alarm is introduced. Android Doze, vendor battery restrictions, force-stop or service termination may delay or prevent execution. Physical screen-off/Doze testing and an Android APK build have not been performed as part of the local tests above.
