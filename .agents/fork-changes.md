# Fork changes — the `meowclash-*` provider-override system was removed (2026-05)

Router: `AGENTS.md`.

The custom `meowclash-*` override system was fully removed. These keys were read **only** from the
subscription's HTTP **response headers**, never from the profile YAML body — so writing them inside a
profile's YAML never had any effect. The decision (variant B) was full physical deletion, while keeping
subscription decryption fully working.

## Removed (now deleted / no-op)

Headers no longer handled: `meowclash-settings`, `meowclash-hex`, `meowclash-widgets`, `meowclash-view`,
`meowclash-custom`, `meowclash-androidsecure`, `meowclash-servicename`, `meowclash-servicelogo`,
`meowclash-serverinfo`, `meowclash-globalmode`, `meowclash-denywidgets`, `meowclash-background`.

## Kept (still functional — do NOT break)

- **Subscription decryption**: headers `meowclash-password`, `meowclash-password-iterations`;
  `_maybeDecrypt`, `SubscriptionCrypto.looksLikeEncryptedPayload`, `SubscriptionCrypto.decryptBase64`,
  `kDefaultPbkdf2Iterations`, `SubscriptionPasswordRequiredException`, import
  `package:meowclash/services/subscription_crypto.dart`, `Profile.update` params
  `decryptionPassword`/`decryptionIterations`.
- Non-override headers: `announce`, `support-url`, `profile-update-interval`, `x-hwid-limit` + the
  device-limit dialog.

## Files modified

- `lib/models/profile.dart` — replaced the generic `meowclash-*` collection loop with password-only
  collection (`headersToCollect` kept: `announce`, `support-url`, `profile-update-interval`,
  `x-hwid-limit`).
- `lib/providers/state.dart` — neutralized 4 providers: `globalModeEnabled → true`,
  `hasServiceInfoData → false`, `hasServerInfoData → false`, `backgroundUrl → null`
  (`hasAnnounceData` kept).
- `lib/views/dashboard/dashboard.dart` — removed the `denywidgets` `Consumer` gate; the button now
  renders directly.
- `lib/controller.dart` — deleted `applySubscriptionSettings`, `_applyAllHeaderSettings`,
  `_applyProviderSettings`, `_applyThemeColor`, `_applyThemeColorFromHex`, `_applyCustomViewSettings`
  and all their call sites; cleaned `initForegroundCache` (servicename/serverinfo decode) and
  `_setupClashConfig` (androidsecure mixedPort override).
- `lib/views/application_setting.dart` — removed the `OverrideProviderSettingsItem` toggle from the list
  and deleted the class; ungated `MinimizeItem` / `AutoLaunchItem` / `SilentLaunchItem` / `AutoRunItem` /
  `AutoCheckUpdateItem` (no longer wrapped in `Opacity`/`isEnabled`, now always user-controlled). The
  header→setting mapping that used to drive these: `minimize→minimizeOnExit`, `autorun→autoLaunch`,
  `shadowstart→silentLaunch`, `autostart→autoRun`, `autoupdate→autoCheckUpdate`.

## Known leftovers

- The `overrideProviderSettings` field is still present in the `appSetting` model — left intentionally to
  avoid a freezed cascade + persisted-state migration. Remove later if desired.
