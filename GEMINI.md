# GEMINI.md

## AI Instructions for this Repo

1. **Context Awareness:** Before performing any task, always review the project structure. If you notice new technologies not described here, suggest updating this file.
2. **Analysis Mode:** When prompted to “Analyze and Update GEMINI.md,” you must rescan the entire project, identify changes in the architecture, and update the Tech Stack and Project Structure sections.
3. **Consistency:** Always follow the patterns already implemented in the `/src` folder (or equivalent). Do not suggest third-party libraries if the project already has a built-in solution.
4. **Recursive Improvement:** You are permitted to edit this file if you believe that adding a new rule will improve the quality of your work with the current code.

## Project Context

**MeowClash** is a fork of [MeowClash](https://github.com/Loischsiy/MeowClash) — a multi-platform proxy client based on **ClashMeta** (mihomo). It provides a Material You-based UI for configuring and managing proxy connections on Android, Windows, macOS, and Linux. The app supports subscription links, WebDAV sync, TUN mode, multiple color themes, and adaptive screen sizes.

**Package name:** `meowclash` (in pubspec)
**App display name:** MeowClash  
**Repository:** `Loischsiy/MeowClash`

---

## Tech Stack

| Layer               | Technology                                                                 |
|---------------------|----------------------------------------------------------------------------|
| **UI Framework**    | Flutter 3.35 (Dart 3.5+), Material Design 3                                |
| **State Management**| Riverpod (`flutter_riverpod`, `riverpod_generator`, `riverpod_annotation`) |
| **Code Generation** | `build_runner` + `freezed` (models) + `json_serializable` + `riverpod_generator` |
| **Proxy Engine**    | Go 1.20 (`github.com/metacubex/mihomo` v1.19.23), compiled via cgo → shared library |
| **Dart↔Go Bridge**  | FFI (`dart:ffi`) + FFIgen-generated bindings (`lib/clash/generated/clash_ffi.dart`) |
| **Windows Service** | Rust (`services/helper/`) — warp HTTP server + windows-service crate        |
| **Custom Plugins**  | Flutter plugin `proxy` (C++/Windows), `window_ext` (Swift/macOS)           |
| **Localization**    | ARB files (en, ru, ja, zh_CN), `flutter_intl` + `flutter_localizations`    |
| **Build**           | `setup.dart` CLI orchestrates Go cross-compile + Flutter build + packaging  |
| **Distribution**    | `flutter_distributor` (DMG, EXE, DEB, APK), GitHub Actions CI/CD           |
| **Linting**         | `flutter_lints` + strict custom rules in `analysis_options.yaml`           |
| **Packages of note**| `shared_preferences`, `shelf` (HTTP server), `dio`, `connectivity_plus`, `window_manager`, `tray_manager`, `flutter_js`, `dynamic_color`, `animations` |

---

## Project Structure

```
MeowClash/
├── lib/                        # Dart/Flutter source (167 files)
│   ├── main.dart               # App entry + background service isolate
│   ├── application.dart        # MaterialApp root, Riverpod ProviderScope
│   ├── state.dart              # GlobalState + DetectionState singletons
│   ├── controller.dart         # AppController (main business logic, 1800+ lines)
│   ├── clash/                  # Clash core FFI bridge, lib handler, core lifecycle
│   ├── models/                 # Freezed data classes (AppState, Config, Profile, etc.)
│   │   └── generated/         # *.freezed.dart + *.g.dart (gitignored)
│   ├── providers/              # Riverpod providers with code generation
│   │   └── generated/         # *.g.dart (gitignored)
│   ├── views/                  # UI pages/screens
│   │   ├── dashboard/          # Main dashboard with proxy status, speed, etc.
│   │   ├── proxies/            # Proxy list, proxy providers, group cards
│   │   ├── profiles/           # Subscription management, profile editor
│   │   ├── config/             # Clash config editor (general, DNS, network)
│   │   └── connection/         # Active connections list
│   ├── widgets/                # Reusable UI components (charts, dialogs, inputs, etc.)
│   ├── common/                 # Utility barrel — helpers, extensions, constants
│   ├── manager/                # Platform-specific managers (window, tray, VPN, tile)
│   ├── plugins/                # Platform bridge abstractions (app, service, tile, vpn)
│   ├── enum/                   # All enums in one file
│   ├── l10n/                   # Generated localization code
│   ├── pages/                  # Top-level pages (home, editor, scan)
│   ├── services/               # App-level services (subscription notifications)
│   └── utils/                  # Device info service
├── core/                       # Go ClashMeta proxy engine (28 .go files)
│   ├── go.mod / go.sum         # Go module (module core, requires mihomo)
│   ├── main.go / lib.go        # Cgo entry points for shared library builds
│   ├── lib_android.go          # Android-specific JNI exports
│   ├── hub.go / server.go      # Core server & hub (HTTP API, listeners)
│   ├── dart-bridge/            # FFI bridge: Dart ↔ Go (Dart API headers + binding glue)
│   ├── tun/                    # TUN device management
│   ├── platform/               # Platform-specific (procfs, limits)
│   └── state/                  # Shared core state types
├── services/helper/            # Rust Windows system service
│   ├── Cargo.toml              # tokio + warp + windows-service
│   └── src/                    # main.rs, service hub, Windows integration
├── plugins/                    # Custom Flutter plugins
│   ├── proxy/                  # System proxy management (Windows C++ implementation)
│   ├── window_ext/             # Window extensions (macOS Swift implementation)
│   └── flutter_distributor/    # Distribution tooling submodule (not version-controlled)
├── assets/                     # Static resources
│   ├── data/                   # GeoIP databases (ASN.mmdb, GeoIP.dat, etc.)
│   ├── fonts/                  # JetBrainsMono, Twemoji, Icons, Unbounded
│   └── images/                 # App icons, avatars
├── arb/                        # Application Resource Bundle (i18n source)
├── android/                    # Android platform code
├── macos/ / windows/ / linux/  # Desktop platform code
├── setup.dart                  # Build orchestrator CLI (Dart, args-based command runner)
├── Makefile                    # Common build shortcuts
├── build.yaml                  # build_runner config (custom output paths for generated code)
├── analysis_options.yaml       # Strict linter rules
├── distribute_options.yaml     # Distribution config (app_name: MeowClash, output: dist/)
├── .github/workflows/build.yaml # CI/CD: multi-platform builds + publishing
└── pubspec.yaml                # Flutter dependencies, assets, fonts, code-gen config
```

---

## Coding Standards

### Naming Conventions
- **Files:** `snake_case.dart` — one main class or concern per file
- **Classes/Enums:** `PascalCase`
- **Variables/Functions/Top-level shortcuts:** `camelCase`
- **Private members:** `_underscorePrefix`
- **Barrel files:** `common.dart`, `models.dart`, `widgets.dart` — re-export all public symbols in the directory

### State Management (Riverpod)
- Use `@riverpod` annotation + `build_runner` for auto-generated providers
- Notifier classes use `AutoDisposeNotifierMixin` by default
- Generated code goes in `*/generated/` subdirectories
- Shared mutable state via `GlobalState` singleton (factory pattern) with `ValueNotifier` for reactive fields

### Models (Freezed)
- All data models annotated with `@freezed` — immutable, with `copyWith` support
- `part 'generated/name.freezed.dart';` for freezed output
- `part 'generated/name.g.dart';` when JSON serialization needed
- Type aliases defined alongside models (e.g., `typedef DelayMap = Map<...>`)

### Imports
- Use **absolute** package imports: `import 'package:meowclash/path/to/file.dart';`
- `avoid_relative_lib_imports` linter rule is enabled
- Internally within a directory, relative `import 'common.dart';` is acceptable for barrel files

### Platform-Specific Code
- Check platform with `Platform.isAndroid`, `Platform.isWindows`, etc.
- Platform abstractions in `lib/plugins/` — use optional chaining (`app?.`, `vpn?.`, `tile?.`)
- Desktop platforms: `WindowManager` → `TrayManager` → `HotKeyManager` → `ProxyManager` widget tree
- Mobile platform: `AndroidManager` → `TileManager` tree + `VpnManager`
- `Platform.isDesktop` checks handled via `system.isDesktop` common helper

### Error Handling
- `globalState.safeRun()` wrapper for async operations — catches exceptions, logs, shows notifications
- `try/catch` with `debugPrint` for non-critical paths, `unawaited(...)` for fire-and-forget
- Explicit error checking: `if (res.isError)`, `if (value == null)`
- `commonPrint` for structured logging, `fileLogger` for persistent logs

### Linting (Strict)
- `always_declare_return_types`, `avoid_print`, `prefer_const_*`, `prefer_final_locals`
- `unawaited_futures` — fire-and-forget must use `unawaited()`
- `use_key_in_widget_constructors`
- `avoid_positional_boolean_parameters`
- `sort_child_properties_last`, `sort_constructors_first`, `sort_unnamed_constructors_first`
- Generated code excluded from analysis: `build/**`, `lib/clash/generated/**`, `lib/l10n/**`

### Widget Conventions
- `const` constructors everywhere possible
- `CommonScaffold` as the navigation shell
- Adaptive layout: `ViewMode` enum (`mobile`/`desktop`) via `viewSizeProvider`
- Custom themed components: `CommonCard`, `CommonDialog`, `CommonContainer`, etc.
- `WidgetRef ref` for accessing Riverpod providers in `ConsumerWidget`/`ConsumerStatefulWidget`

### General
- Prefer `final` over `var`; use `late` for deferred initialization
- `Function()` callbacks instead of `VoidCallback?` where practical
- Debouncing pattern: `debouncer.call(FunctionTag.tag, callback, duration:)` for UI-throttled operations
- `FixedList<T>` — custom fixed-length list for bounded collections (logs, requests, traffics)
- No comments in code unless strictly necessary (project convention)

---

## AI Rules & Constraints

1. **Dart analysis must pass** — all code must comply with the strict linter rules in `analysis_options.yaml`. Run `dart analyze` before considering work done.

2. **Use existing patterns** — before creating new providers, models, or widgets, study existing examples in `lib/providers/`, `lib/models/`, and `lib/widgets/`. Mirror the exact structure.

3. **Generated files are off-limits** — never edit `*.freezed.dart`, `*.g.dart`, or files in `lib/clash/generated/`, `lib/l10n/`. Run `dart run build_runner build` to regenerate.

4. **Riverpod code-gen workflow** — when adding a new provider:
   - Annotate with `@riverpod`
   - Add `part 'generated/name.g.dart';`
   - Run `build_runner`
   - Never write providers manually without the annotation

5. **Freezed model workflow** — when adding a new model:
   - Annotate with `@freezed`
   - Add `part 'generated/name.freezed.dart';` (+ `.g.dart` if JSON needed)
   - Never manually implement `==`, `hashCode`, `copyWith`, or `toString`

6. **No relative imports outside current directory** — always use `package:meowclash/` prefix for cross-directory imports.

7. **Do NOT edit `core/` Go files or `services/helper/` Rust files** unless explicitly asked. These are separate compilation units that require Go/Rust toolchains.

8. **Do NOT modify `plugins/flutter_distributor/`** — it's a git submodule.

9. **Platform code** (`android/`, `macos/`, `windows/`, `linux/`) should only be touched when the task explicitly involves platform-specific features.

10. **Localization** — if adding user-facing strings, add them to all `arb/intl_*.arb` files (en, ru, ja, zh_CN). Run `flutter gen-l10n` to regenerate.

11. **No `print()`** — use `commonPrint.log()` for logging, `debugPrint()` for debug-only output.

12. **Every widget constructor must have `super.key`** — enforced by `use_key_in_widget_constructors`.

13. **Asset paths** — assets are declared in `pubspec.yaml` under `flutter: assets:` and `fonts:`. All asset references use relative paths from the project root.

14. **Fire-and-forget** — use `unawaited()` wrapper (import from `dart:async`) for futures that are intentionally not awaited.

15. **Prefer `ref.watch()` in build methods**, `ref.read()` in callbacks/event handlers.

---

## Self-Update Protocol

When significant changes occur in the project, remind the user to update this `GEMINI.md` file. Specifically:

- New top-level directories or major architectural shifts
- Changes to the state management pattern or new code-generation tools
- New custom plugins or FFI bridges
- Changes to build system, CI/CD pipeline, or distribution flow
- Upgrades to the underlying framework (Flutter channel, Go version, Rust edition)
- New or removed major dependencies

If you detect such a change during a conversation, briefly note: *"This change affects the project structure described in GEMINI.md — you may want to update it to stay in sync."*
