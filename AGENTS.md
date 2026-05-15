# AGENTS.md

## Project identity

MeowClash — multi-platform proxy client (Flutter/Dart), fork of FlClash.  
Package name in `pubspec.yaml`: `flclashx`. App display name: MeowClash / FlClashX.

## Architecture (three compile units)

| Layer | Lang | Location | Editable? |
|-------|------|----------|-----------|
| UI + controllers | Dart/Flutter | `lib/` | Yes |
| Proxy engine | Go (cgo → shared lib) | `core/` | Avoid — requires Go toolchain |
| Windows helper svc | Rust (warp HTTP) | `services/helper/` | Avoid — requires Rust toolchain |

The Go core is cross-compiled into `libclash/` (gitignored) by `setup.dart`. Dart talks to it via `dart:ffi` + FFIgen-generated bindings at `lib/clash/generated/clash_ffi.dart` (gitignored, regenerated).

## Build system

**Do NOT use `flutter build` directly.** The build goes through a custom CLI:

```
dart setup.dart <platform> --arch <arm64|amd64>
```

`setup.dart` orchestrates: Go cross-compile → Flutter build → packaging (via `flutter_distributor`).

Makefile shortcuts: `make macos_arm64`, `make android_app`. For local macOS: `make macLocal`.

`flutter_distributor` must be cloned into `plugins/flutter_distributor/` before building (CI does this; it is in `.gitignore`, not a git submodule).

## Workflow commands

```bash
# Analysis (must pass — strict rules in analysis_options.yaml)
dart analyze

# Regenerate freezed + json_serializable + riverpod providers
dart run build_runner build --delete-conflicting-outputs

# Run tests
flutter test

# Run a single test file
flutter test test/subscription_crypto_test.dart
```

## Code generation

Generator output lands in non-standard locations (configured in `build.yaml`):
- Freezed models: `lib/models/generated/*.freezed.dart`
- JSON serialization: `lib/models/generated/*.g.dart`
- Riverpod providers: `lib/providers/generated/*.g.dart`

**Never edit generated files.** If a model or provider changes, rerun `build_runner`.

When adding a new model with `@freezed`, add both parts:
```dart
part 'generated/name.freezed.dart';
part 'generated/name.g.dart';  // if JSON serialization needed
```

When adding a new provider with `@riverpod`:
```dart
part 'generated/name.g.dart';
```

## Key conventions

- **Imports**: always `package:flclashx/...` for cross-directory imports. Only use relative imports within the same directory (barrel files).
- **Logging**: use `commonPrint.log()`, never `print()`. `debugPrint()` for debug-only output.
- **Fire-and-forget**: wrap with `unawaited()` (import from `dart:async`).
- **Widget constructors**: always include `super.key`.
- **State management**: Riverpod. `ref.watch()` in build methods, `ref.read()` in callbacks/event handlers.
- **Global mutable state**: `GlobalState` singleton at `lib/state.dart` with `ValueNotifier` for reactivity.
- **Error handling**: `globalState.safeRun()` for async ops; logs errors and shows notifications.
- **No comments** unless strictly necessary (project convention).
- **Widgets**: `const` constructors everywhere possible.

## Platform-specific code

- `lib/plugins/` — platform bridge abstractions (`app`, `vpn`, `tile`, `service`).
- `plugins/proxy/` — Windows system proxy (C++).
- `plugins/window_ext/` — macOS window extensions (Swift).
- Platform code (`android/`, `macos/`, `windows/`, `linux/`) — only touch when task explicitly requires it.

## Localization

ARB files in `arb/`. Four locales: en, ru, ja, zh_CN.
Add new user-facing strings to all ARB files. Run `flutter gen-l10n` to regenerate `lib/l10n/`.

## CI

Tags trigger multi-platform builds + GitHub release + F-Droid repo push.
CI pins: Flutter 3.35.7 (stable), Go 1.24.0.

## Miscellaneous

- `libclash/`, `plugins/flutter_distributor/`, `dist/`, `build/` are gitignored.
- `.gitignore` also ignores `.opencode/`, `.gemini/`, `.claude/`, so those are not committed.
- Only 1 test file exists (`test/subscription_crypto_test.dart`). The project is test-light.
