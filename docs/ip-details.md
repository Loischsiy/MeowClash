# Dashboard IP details

- Tapping the current-IP card opens details; long-press and **Refresh IP** keep
  the existing IP recheck/cooldown behavior. Repeated taps cannot stack dialogs.
- IP and country are available immediately from the existing detection result.
  Extra data is requested only while the dialog is open, through the existing
  proxy-aware HTTP client, for that exact IP (IPv4 or IPv6), not the caller's
  possibly changed exit IP. Responses for another IP are rejected.
- HTTPS `ipwho.is/<ip>?lang=...` provides region, city and connection domain.
  Request timeouts and cancellation are bounded; closing the dialog, changing
  the IP, or changing app language cancels/invalidates the old lookup. Successful
  responses are cached for 5 minutes in a 16-entry IP/language LRU cache. Failures
  are not cached, and don't discard the IP/country. No additional periodic poll.
- All labels, loading/error states and country names support the app's six
  languages: English, Finnish, Japanese, Russian, Ukrainian and Chinese.
  Country names use bundled Unicode CLDR data, never a translated API country
  string. Regenerate with `node tool/generate_ip_country_names.cjs` (Node with
  full ICU), then `dart format lib/common/ip_country_names.dart`.
- `ipwho.is` supports en, ru, ja and zh-CN among our locales. It does **not**
  translate region/city names to Finnish/Ukrainian. Those geographic names use
  explicit English fallback with a localized notice. Countries remain Finnish/
  Ukrainian. Missing domains remain unavailable, never an ISP masquerading as
  a domain. Geographic information is approximate, as noted in the dialog.
- The external-link action opens `https://ipinfo.io/<ip>` only on user action.

## Checks

```sh
flutter test --no-pub
go test -C core -race ./...
```

Before release, rebuild **both** native core and Flutter app (the shared manual
ping limit is now 10 on all platforms). Check a real Android device for smooth
scrolling/navigation during 2000–5000-server checks; desktop/widget tests are
not a device FPS/ANR measurement. Also exercise dark/light themes, all locales,
large text, IPv6, unavailable details, retry, rotation and a VPN switch while
this dialog is open.
